import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class GruposService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Cargar proyectos existentes desde Firebase ────────────────────────────
  Future<List<Map<String, dynamic>>> cargarProyectosExistentes(
    String eventId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .orderBy('importedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error al cargar proyectos existentes: $e');
      rethrow;
    }
  }
Future<int> corregirSalasPorCodigo(
  String eventId,
  Map<String, String> codigoSala,
) async {
  // Normaliza un código: quita espacios y ceros a la izquierda.
  String norm(String c) {
    final t = c.trim();
    final sinCeros = t.replaceFirst(RegExp(r'^0+'), '');
    return sinCeros.isEmpty ? t : sinCeros;
  }

  // Mapa normalizado para comparar sin importar el formato de los ceros.
  final Map<String, String> mapaNorm = {
    for (final e in codigoSala.entries) norm(e.key): e.value,
  };

  int actualizados = 0;
  try {
    final snap = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('proyectos')
        .get();

    for (int i = 0; i < snap.docs.length; i += 500) {
      final batch = _firestore.batch();
      final lote = snap.docs.skip(i).take(500);
      for (final doc in lote) {
        final codigo = (doc.data()['Código'] ?? '').toString();
        final nuevaSala = mapaNorm[norm(codigo)];
        if (nuevaSala != null && nuevaSala.isNotEmpty) {
          batch.update(doc.reference, {
            'Sala': nuevaSala,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          actualizados++;
        }
      }
      await batch.commit();
    }
    debugPrint('✅ Salas corregidas: $actualizados');
  } catch (e) {
    debugPrint('❌ Error corrigiendo salas: $e');
    rethrow;
  }
  return actualizados;
}
  // ── Actualizar categoría de scans por proyecto ────────────────────────────
  // FIX: batches parciales para no superar el límite de 500 operaciones
  Future<void> actualizarCategoriaDeScansPorProyecto(
    String eventId,
    String codigoProyecto,
    String nuevaCategoria,
  ) async {
    try {
      debugPrint('🔄 Actualizando scans del proyecto: $codigoProyecto');
      debugPrint('📝 Nueva categoría: $nuevaCategoria');

      final asistenciasSnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias')
          .get();

      int scansActualizados = 0;
      final List<WriteBatch> batches = [];
WriteBatch currentBatch = _firestore.batch();
      int operaciones = 0;

      for (final estudianteDoc in asistenciasSnapshot.docs) {
        final scansSnapshot = await _firestore
            .collection('events')
            .doc(eventId)
            .collection('asistencias')
            .doc(estudianteDoc.id)
            .collection('scans')
            .where('codigoProyecto', isEqualTo: codigoProyecto)
            .get();

        for (final scanDoc in scansSnapshot.docs) {
          if (operaciones == 500) {
            batches.add(currentBatch);
            currentBatch = _firestore.batch();
            operaciones = 0;
          }
          currentBatch.update(scanDoc.reference, {
            'categoria': nuevaCategoria,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          operaciones++;
          scansActualizados++;
        }
      }

      if (operaciones > 0) batches.add(currentBatch);
      for (final b in batches) await b.commit();

      if (scansActualizados > 0) {
        debugPrint('✅ Se actualizaron $scansActualizados scans');
      } else {
        debugPrint('ℹ️ No se encontraron scans para actualizar');
      }
    } catch (e) {
      debugPrint('❌ Error al actualizar scans: $e');
      rethrow;
    }
  }

  // ── Importar Excel y retornar los datos procesados ────────────────────────
  Future<List<Map<String, dynamic>>?> importarExcel() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        return await procesarArchivoBytesExcel(result.files.single.bytes!);
      } else if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        return await procesarArchivoBytesExcel(bytes);
      }
      return null;
    } catch (e) {
      debugPrint('Error al importar archivo: $e');
      rethrow;
    }
  }

  // ── Procesar archivo Excel desde bytes con DETECCIÓN AUTOMÁTICA ───────────
  Future<List<Map<String, dynamic>>> procesarArchivoBytesExcel(
    Uint8List bytes,
  ) async {
    try {
      final excel = Excel.decodeBytes(bytes);
      List<Map<String, dynamic>> proyectos = [];

      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null || sheet.maxRows < 2) continue;

        final List<String> headers = [];              // L130: final
        final headerRow = sheet.rows.first;
        for (final cell in headerRow) {              // L132: final
          headers.add(cell?.value?.toString().trim() ?? '');
        }

        debugPrint('Headers encontrados: $headers');

        final tipoFormato = detectarFormatoExcel(headers);
        debugPrint('Formato detectado: $tipoFormato');

        if (tipoFormato == 'PROYECTOS') {
          proyectos = procesarFormatoProyectosConMerge(headers, sheet);
        } else if (tipoFormato == 'EVENTOS') {
          String? ultimoSubevento;
          String? ultimoEvento;

          for (int i = 1; i < sheet.maxRows; i++) {
            final row = sheet.rows[i];
            final proyecto = procesarFormatoEventos(
              headers,
              row,
              i,
              ultimoSubevento,
              ultimoEvento,
            );

            if (proyecto.containsKey('Subevento') &&
                proyecto['Subevento'] != null) {
              ultimoSubevento = proyecto['Subevento'];
            }
            if (proyecto.containsKey('EventoPrincipal') &&
                proyecto['EventoPrincipal'] != null) {
              ultimoEvento = proyecto['EventoPrincipal'];
            }

            if (proyecto.isNotEmpty &&
                proyecto.containsKey('Título') &&
                proyecto['Título'].toString().isNotEmpty &&
                proyecto.containsKey('Clasificación') &&
                proyecto['Clasificación'].toString().isNotEmpty) {
              proyectos.add(proyecto);
            }
          }
        }
      }

      return proyectos;
    } catch (e) {
      debugPrint('Error al procesar el archivo Excel: $e');
      rethrow;
    }
  }

  // ── Detectar el formato del Excel basado en los headers ───────────────────
  String detectarFormatoExcel(List<String> headers) {
    final headersUpper = headers.map((h) => h.toUpperCase().trim()).toList();

    final bool tieneEvento = headersUpper.any((h) => h.contains('EVENTO'));          // L188: final
    final bool tieneSubeventos = headersUpper.any((h) => h.contains('SUBEVENTOS')); // L189: final
    final bool tieneEncargado = headersUpper.any((h) => h.contains('ENCARGADO'));   // L190: final
    final bool tieneLugar = headersUpper.any((h) => h.contains('LUGAR'));           // L191: final

    if (tieneEvento || tieneSubeventos || tieneEncargado || tieneLugar) {
      return 'EVENTOS';
    }

    final bool tieneCodigo = headersUpper.any((h) => h.contains('CÓDIGO'));         // L197: final
    final bool tieneClasificacion = headersUpper.any(                               // L198: final
      (h) => h.contains('CLASIFICACIÓN'),
    );

    if (tieneCodigo || tieneClasificacion) {
      return 'PROYECTOS';
    }

    return 'PROYECTOS';
  }

  List<Map<String, dynamic>> procesarFormatoProyectosConMerge(
    List<String> headers,
    Sheet sheet,
  ) {
    final List<Map<String, dynamic>> proyectos = [];

    final int idxCodigo = _findHeaderIndex(headers, ['CÓDIGO', 'CODIGO']);
    final int idxTitulo = _findHeaderIndex(headers, [
      'TÍTULO DE INVESTIGACIÓN/PROYECTO',
      'TITULO DE INVESTIGACIÓN/PROYECTO',
      'TÍTULO',
      'TITULO',
    ]);
    final int idxIntegrantes = _findHeaderIndex(headers, ['INTEGRANTES']);
    final int idxClasificacion =
        _findHeaderIndex(headers, ['CLASIFICACIÓN', 'CLASIFICACION']);
    final int idxSala = _findHeaderIndex(headers, ['SALA']);

    debugPrint(
      '📋 Índices → Código:$idxCodigo Título:$idxTitulo '
      'Integrantes:$idxIntegrantes Clasificación:$idxClasificacion Sala:$idxSala',
    );

    Map<String, dynamic>? proyectoActual;
    List<String> integrantesActuales = [];

    // ── Memoria de celdas combinadas (merge) ──
    String ultimaClasificacion = '';
    String ultimaSala = '';

    void cerrarProyectoActual() {
      if (proyectoActual != null) {
        proyectoActual!['Integrantes'] = List<String>.from(integrantesActuales);
        proyectoActual!['totalIntegrantes'] = integrantesActuales.length;
        proyectos.add(Map<String, dynamic>.from(proyectoActual!));
        debugPrint(
          '✅ Proyecto cerrado: ${proyectoActual!['Código']} '
          '— ${integrantesActuales.length} integrante(s): $integrantesActuales',
        );
        proyectoActual = null;
        integrantesActuales = [];
      }
    }

    for (int i = 1; i < sheet.maxRows; i++) {
      final row = sheet.rows[i];

      final String codigo = _cellValue(row, idxCodigo);
      final String titulo = _cellValue(row, idxTitulo);
      final String integrante = _cellValue(row, idxIntegrantes);
      final String clasificacion = _cellValue(row, idxClasificacion);
      final String sala = _cellValue(row, idxSala);

      // ── Arrastrar hacia abajo el último valor visto de columnas combinadas ──
      if (clasificacion.isNotEmpty) ultimaClasificacion = clasificacion;
      if (sala.isNotEmpty) ultimaSala = sala;

      final bool esFilaPrincipal = codigo.isNotEmpty || titulo.isNotEmpty;

      if (esFilaPrincipal) {
        cerrarProyectoActual();

        final String clasifEfectiva =
            clasificacion.isNotEmpty ? clasificacion : ultimaClasificacion;
        final String salaEfectiva = sala.isNotEmpty ? sala : ultimaSala;

        proyectoActual = {
          'Código': codigo,
          'Título': titulo,
          'Clasificación': clasifEfectiva,
          if (salaEfectiva.isNotEmpty) 'Sala': salaEfectiva,
        };
        if (integrante.isNotEmpty) integrantesActuales.add(integrante);
        debugPrint('📌 Nuevo proyecto: $codigo — $titulo');
      } else {
        if (integrante.isNotEmpty && proyectoActual != null) {
          integrantesActuales.add(integrante);
          debugPrint('   ➕ Integrante añadido: $integrante');
        }
        // Si el proyecto se abrió sin clasificación pero luego aparece
        // (o ya teníamos una arrastrada), completarla.
        if (proyectoActual != null &&
            (proyectoActual!['Clasificación'] as String).isEmpty &&
            ultimaClasificacion.isNotEmpty) {
          proyectoActual!['Clasificación'] = ultimaClasificacion;
        }
        // Igual para la sala, por si el proyecto se abrió antes de verla.
        if (proyectoActual != null &&
            (proyectoActual!['Sala'] == null ||
                (proyectoActual!['Sala'] as String).isEmpty) &&
            ultimaSala.isNotEmpty) {
          proyectoActual!['Sala'] = ultimaSala;
        }
      }
    }

    cerrarProyectoActual();

    return proyectos.where((p) {
      final tieneIdentificador =
          (p['Código'] as String).isNotEmpty ||
          (p['Título'] as String).isNotEmpty;
      final tieneClasificacion = (p['Clasificación'] as String).isNotEmpty;
      return tieneIdentificador && tieneClasificacion;
    }).toList();
  }

  // ── Helper: encontrar índice de columna por posibles nombres ─────────────
  int _findHeaderIndex(List<String> headers, List<String> posibleNombres) {
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toUpperCase().trim();
      for (final nombre in posibleNombres) {
        if (h == nombre.toUpperCase().trim()) return i;
      }
    }
    return -1;
  }

  // ── Helper: leer valor de celda de forma segura ───────────────────────────
  String _cellValue(List<Data?> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index]?.value?.toString().trim() ?? '';
  }

  // ── Procesar formato PROYECTOS legado ─────────────────────────────────────
  Map<String, dynamic> procesarFormatoProyectos(
    List<String> headers,
    List<Data?> row,
  ) {
    final Map<String, dynamic> proyecto = {};    // L338: final
    for (int j = 0; j < headers.length && j < row.length; j++) {
      final cellValue = row[j]?.value?.toString().trim();
      if (cellValue != null && cellValue.isNotEmpty) {
        proyecto[normalizarClaveProyectos(headers[j])] = cellValue;
      }
    }
    return proyecto;
  }

  // ── Procesar formato EVENTOS ──────────────────────────────────────────────
  Map<String, dynamic> procesarFormatoEventos(
    List<String> headers,
    List<Data?> row,
    int rowIndex,
    String? ultimoSubevento,
    String? ultimoEvento,
  ) {
    final Map<String, dynamic> proyecto = {};    // L356: final
    final Map<String, String> datosRaw = {};     // L357: final

    for (int j = 0; j < headers.length && j < row.length; j++) {
      final cellValue = row[j]?.value?.toString().trim();
      if (cellValue != null && cellValue.isNotEmpty) {
        String headerKey = headers[j].toUpperCase().trim();
        if (headerKey.contains('TÍTULO') && headerKey.contains('PROGRAMA')) {
          headerKey = 'TÍTULO DE PROGRAMA / PONENCIA';
        }
        datosRaw[headerKey] = cellValue;
      }
    }

    final String titulo = datosRaw['TÍTULO DE PROGRAMA / PONENCIA'] ?? ''; // L370: final
    if (titulo.isEmpty) return {};
    proyecto['Título'] = titulo;
    proyecto['Código'] = 'PON-${rowIndex.toString().padLeft(3, '0')}';

    if (datosRaw.containsKey('ENCARGADO')) {
      proyecto['Integrantes'] = [datosRaw['ENCARGADO']!];
    }

    String? clasificacion;
    if (datosRaw.containsKey('SUBEVENTOS') &&
        datosRaw['SUBEVENTOS']!.isNotEmpty) {
      clasificacion = datosRaw['SUBEVENTOS'];
    } else if (ultimoSubevento != null && ultimoSubevento.isNotEmpty) {
      clasificacion = ultimoSubevento;
    } else if (datosRaw.containsKey('EVENTO') &&
        datosRaw['EVENTO']!.isNotEmpty) {
      clasificacion = datosRaw['EVENTO'];
    } else if (ultimoEvento != null && ultimoEvento.isNotEmpty) {
      clasificacion = ultimoEvento;
    }

    if (clasificacion != null && clasificacion.isNotEmpty) {
      proyecto['Clasificación'] = clasificacion;
    } else {
      return {};
    }

    if (datosRaw.containsKey('LUGAR') && datosRaw['LUGAR']!.isNotEmpty) {
      proyecto['Sala'] = datosRaw['LUGAR'];
    }

    proyecto['TipoImportacion'] = 'EVENTOS';

    if (datosRaw.containsKey('EVENTO') && datosRaw['EVENTO']!.isNotEmpty) {
      proyecto['EventoPrincipal'] = datosRaw['EVENTO'];
    } else if (ultimoEvento != null) {
      proyecto['EventoPrincipal'] = ultimoEvento;
    }

    if (datosRaw.containsKey('SUBEVENTOS') &&
        datosRaw['SUBEVENTOS']!.isNotEmpty) {
      proyecto['Subevento'] = datosRaw['SUBEVENTOS'];
    } else if (ultimoSubevento != null) {
      proyecto['Subevento'] = ultimoSubevento;
    }

    return proyecto;
  }

  // ── Normalizar claves del Excel ───────────────────────────────────────────
  String normalizarClaveProyectos(String clave) {
    switch (clave.toUpperCase().trim()) {
      case 'CÓDIGO':
      case 'CODIGO':
        return 'Código';
      case 'TÍTULO DE INVESTIGACIÓN/PROYECTO':
      case 'TITULO DE INVESTIGACIÓN/PROYECTO':
      case 'TÍTULO':
      case 'TITULO':
        return 'Título';
      case 'INTEGRANTES':
        return 'Integrantes';
      case 'CLASIFICACIÓN':
      case 'CLASIFICACION':
        return 'Clasificación';
      case 'SALA':
        return 'Sala';
      default:
        return clave;
    }
  }

  // ── Guardar proyectos en Firebase ─────────────────────────────────────────
  Future<void> guardarProyectosEnEvento(
    String eventId,
    List<Map<String, dynamic>> proyectos, {
    Map<String, dynamic>? eventData,
  }) async {
    if (proyectos.isEmpty) return;

    try {
      final String? filialId = eventData?['filialId'] as String?;
      final String? facultad = eventData?['facultad'] as String?;
      final String? carreraId = eventData?['carreraId'] as String?;
      final String? carreraNombre = eventData?['carreraNombre'] as String?;

      // FIX: lotes de 500 para no superar el límite de Firestore
      for (int i = 0; i < proyectos.length; i += 500) {
        final batch = _firestore.batch();
        final lote = proyectos.skip(i).take(500);

        for (final proyecto in lote) {
          final docRef = _firestore
              .collection('events')
              .doc(eventId)
              .collection('proyectos')
              .doc();

          final integrantes = proyecto['Integrantes'];
          final List<String> integrantesList;
          if (integrantes is List) {
            integrantesList = integrantes.map((e) => e.toString()).toList();
          } else if (integrantes is String && integrantes.isNotEmpty) {
            integrantesList = [integrantes];
          } else {
            integrantesList = [];
          }

          batch.set(docRef, {
            ...proyecto,
            'Integrantes': integrantesList,
            'totalIntegrantes': integrantesList.length,
            if (filialId != null) 'filialId': filialId,
            if (facultad != null) 'facultad': facultad,
            if (carreraId != null) 'carreraId': carreraId,
            if (carreraNombre != null) 'carreraNombre': carreraNombre,
            'importedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
      }

      await _firestore.collection('events').doc(eventId).update({
        'lastImportAt': FieldValue.serverTimestamp(),
        'proyectosCount': FieldValue.increment(proyectos.length),
      });
    } catch (e) {
      debugPrint('Error al guardar proyectos: $e');
      rethrow;
    }
  }

  // ── Actualizar proyecto ───────────────────────────────────────────────────
  Future<void> actualizarProyecto(
    String eventId,
    String docId,
    Map<String, dynamic> nuevosDatos,
  ) async {
    try {
      final proyectoDoc = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .doc(docId)
          .get();

      final datosAntiguos = proyectoDoc.data();

      if (nuevosDatos.containsKey('Integrantes') &&
          nuevosDatos['Integrantes'] is String) {
        final raw = nuevosDatos['Integrantes'] as String;
        nuevosDatos['Integrantes'] = raw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        nuevosDatos['totalIntegrantes'] =
            (nuevosDatos['Integrantes'] as List).length;
      }

      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .doc(docId)
          .update({...nuevosDatos, 'updatedAt': FieldValue.serverTimestamp()});

      if (datosAntiguos != null &&
          nuevosDatos.containsKey('Clasificación') &&
          datosAntiguos['Clasificación'] != nuevosDatos['Clasificación']) {
        final codigoProyecto =
            nuevosDatos['Código'] ?? datosAntiguos['Código'];
        final nuevaCategoria = nuevosDatos['Clasificación'];
        debugPrint('⚠️ La clasificación cambió. Actualizando scans...');
        await actualizarCategoriaDeScansPorProyecto(
          eventId,
          codigoProyecto,
          nuevaCategoria,
        );
      }
    } catch (e) {
      debugPrint('Error al actualizar proyecto: $e');
      rethrow;
    }
  }

  // ── Resolver nombres de estudiantes por sus códigos universitarios ─────────
  // FIX: lotes correctos y break cuando ya se resolvieron todos
  Future<Map<String, String>> resolverNombresPorCodigos(
    List<String> codigos, {
    String? filialId,
    String? carreraId,
  }) async {
    if (codigos.isEmpty) return {};

    final Map<String, String> resultado = {};

    try {
      // Primero buscar en el doc de la filial/carrera del evento
      if (filialId != null && carreraId != null) {
        final docKey = '${filialId}_$carreraId';
        for (int i = 0; i < codigos.length; i += 10) {
          final lote = codigos.skip(i).take(10).toList();
          final snap = await _firestore
              .collection('users')
              .doc(docKey)
              .collection('students')
              .where('codigoUniversitario', whereIn: lote)
              .get();
          for (final doc in snap.docs) {
            final codigo =
                doc.data()['codigoUniversitario']?.toString() ?? '';
            final nombre = doc.data()['name']?.toString() ?? '';
            if (codigo.isNotEmpty && nombre.isNotEmpty) {
              resultado[codigo] = nombre;
            }
          }
        }
      }

      // FIX: calcular pendientes dinámicamente y hacer break cuando terminen
      final codigosNoResueltos =
          codigos.where((c) => !resultado.containsKey(c)).toList();

      if (codigosNoResueltos.isNotEmpty) {
        final usersSnapshot = await _firestore.collection('users').get();
        final Set<String> yaResueltos = {};

        for (final userDoc in usersSnapshot.docs) {
          final pendientes = codigosNoResueltos
              .where((c) =>
                  !yaResueltos.contains(c) && !resultado.containsKey(c))
              .toList();
          if (pendientes.isEmpty) break;

          for (int i = 0; i < pendientes.length; i += 10) {
            final lote = pendientes.skip(i).take(10).toList();
            final snap = await _firestore
                .collection('users')
                .doc(userDoc.id)
                .collection('students')
                .where('codigoUniversitario', whereIn: lote)
                .get();
            for (final doc in snap.docs) {
              final codigo =
                  doc.data()['codigoUniversitario']?.toString() ?? '';
              final nombre = doc.data()['name']?.toString() ?? '';
              if (codigo.isNotEmpty && nombre.isNotEmpty) {
                resultado[codigo] = nombre;
                yaResueltos.add(codigo);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error al resolver nombres por códigos: $e');
    }

    return resultado;
  }

  // ── Eliminar un proyecto individual ──────────────────────────────────────
  Future<void> eliminarProyectoIndividual(String eventId, String docId) async {
    try {
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .doc(docId)
          .delete();

      await _firestore.collection('events').doc(eventId).update({
        'proyectosCount': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('Error al eliminar proyecto: $e');
      rethrow;
    }
  }

  // ── Eliminar todos los proyectos ──────────────────────────────────────────
  // FIX: lotes de 500 para no superar el límite de Firestore
  Future<void> eliminarTodosLosProyectos(String eventId) async {
    try {
      final querySnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .get();

      final docs = querySnapshot.docs;
      for (int i = 0; i < docs.length; i += 500) {
        final batch = _firestore.batch();
        final lote = docs.skip(i).take(500);
        for (final doc in lote) batch.delete(doc.reference);
        await batch.commit();
      }

      await _firestore.collection('events').doc(eventId).update({
        'proyectosCount': 0,
        'lastImportAt': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('Error al eliminar todos los proyectos: $e');
      rethrow;
    }
  }

  // ── Agrupar proyectos por categoría ──────────────────────────────────────
  Map<String, List<Map<String, dynamic>>> agruparPorCategoria(
    List<Map<String, dynamic>> proyectos,
  ) {
    final Map<String, List<Map<String, dynamic>>> grupos = {};
    for (final proyecto in proyectos) {
      final categoria = proyecto['Clasificación'] ?? 'Sin categoría';
      grupos.putIfAbsent(categoria, () => []).add(proyecto);
    }
    return grupos;
  }

  // ── Formatear fecha de timestamp ──────────────────────────────────────────
  String formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'N/A';
  }
}