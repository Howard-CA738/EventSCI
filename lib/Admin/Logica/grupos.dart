import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'dart:typed_data';

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
      print('Error al cargar proyectos existentes: $e');
      rethrow;
    }
  }

  // ── Actualizar categoría de scans por proyecto ────────────────────────────
  Future<void> actualizarCategoriaDeScansPorProyecto(
    String eventId,
    String codigoProyecto,
    String nuevaCategoria,
  ) async {
    try {
      print('🔄 Actualizando scans del proyecto: $codigoProyecto');
      print('📝 Nueva categoría: $nuevaCategoria');

      final asistenciasSnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias')
          .get();

      int scansActualizados = 0;
      final batch = _firestore.batch();

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
          batch.update(scanDoc.reference, {
            'categoria': nuevaCategoria,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          scansActualizados++;
        }
      }

      if (scansActualizados > 0) {
        await batch.commit();
        print('✅ Se actualizaron $scansActualizados scans');
      } else {
        print('ℹ️ No se encontraron scans para actualizar');
      }
    } catch (e) {
      print('❌ Error al actualizar scans: $e');
      rethrow;
    }
  }

  // ── Importar Excel y retornar los datos procesados ────────────────────────
  Future<List<Map<String, dynamic>>?> importarExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
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
      print('Error al importar archivo: $e');
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

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null || sheet.maxRows < 2) continue;

        List<String> headers = [];
        final headerRow = sheet.rows.first;
        for (var cell in headerRow) {
          headers.add(cell?.value?.toString().trim() ?? '');
        }

        print('Headers encontrados: $headers');

        final tipoFormato = detectarFormatoExcel(headers);
        print('Formato detectado: $tipoFormato');

        String? ultimoSubevento;
        String? ultimoEvento;

        for (int i = 1; i < sheet.maxRows; i++) {
          final row = sheet.rows[i];
          Map<String, dynamic> proyecto = {};

          if (tipoFormato == 'PROYECTOS') {
            proyecto = procesarFormatoProyectos(headers, row);
            if (proyecto.containsKey('Código') &&
                proyecto.containsKey('Clasificación')) {
              proyectos.add(proyecto);
            }
          } else if (tipoFormato == 'EVENTOS') {
            proyecto = procesarFormatoEventos(
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
              print(
                'Proyecto agregado: ${proyecto['Título']} - ${proyecto['Clasificación']}',
              );
            }
          }
        }
      }

      return proyectos;
    } catch (e) {
      print('Error al procesar el archivo Excel: $e');
      rethrow;
    }
  }

  // ── Detectar el formato del Excel basado en los headers ───────────────────
  String detectarFormatoExcel(List<String> headers) {
    final headersUpper = headers.map((h) => h.toUpperCase().trim()).toList();

    bool tieneEvento = headersUpper.any((h) => h.contains('EVENTO'));
    bool tieneSubeventos = headersUpper.any((h) => h.contains('SUBEVENTOS'));
    bool tieneEncargado = headersUpper.any((h) => h.contains('ENCARGADO'));
    bool tieneLugar = headersUpper.any((h) => h.contains('LUGAR'));

    if (tieneEvento || tieneSubeventos || tieneEncargado || tieneLugar) {
      return 'EVENTOS';
    }

    bool tieneCodigo = headersUpper.any((h) => h.contains('CÓDIGO'));
    bool tieneClasificacion = headersUpper.any(
      (h) => h.contains('CLASIFICACIÓN'),
    );

    if (tieneCodigo || tieneClasificacion) {
      return 'PROYECTOS';
    }

    return 'PROYECTOS';
  }

  // ── Procesar formato PROYECTOS (original) ─────────────────────────────────
  Map<String, dynamic> procesarFormatoProyectos(
    List<String> headers,
    List<Data?> row,
  ) {
    Map<String, dynamic> proyecto = {};

    for (int j = 0; j < headers.length && j < row.length; j++) {
      final cellValue = row[j]?.value?.toString().trim();
      if (cellValue != null && cellValue.isNotEmpty) {
        String normalizedKey = normalizarClaveProyectos(headers[j]);
        proyecto[normalizedKey] = cellValue;
      }
    }

    return proyecto;
  }

  // ── Procesar formato EVENTOS (nuevo) ──────────────────────────────────────
  Map<String, dynamic> procesarFormatoEventos(
    List<String> headers,
    List<Data?> row,
    int rowIndex,
    String? ultimoSubevento,
    String? ultimoEvento,
  ) {
    Map<String, dynamic> proyecto = {};

    Map<String, String> datosRaw = {};
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

    String titulo = datosRaw['TÍTULO DE PROGRAMA / PONENCIA'] ?? '';
    if (titulo.isEmpty) return {};
    proyecto['Título'] = titulo;

    proyecto['Código'] = 'PON-${rowIndex.toString().padLeft(3, '0')}';

    if (datosRaw.containsKey('ENCARGADO')) {
      proyecto['Integrantes'] = datosRaw['ENCARGADO'];
    }

    String? clasificacion;

    if (datosRaw.containsKey('SUBEVENTOS') &&
        datosRaw['SUBEVENTOS']!.isNotEmpty) {
      clasificacion = datosRaw['SUBEVENTOS'];
    } else if (ultimoSubevento != null && ultimoSubevento.isNotEmpty) {
      clasificacion = ultimoSubevento;
      print(
        'Usando último subevento conocido: $ultimoSubevento para fila $rowIndex',
      );
    } else if (datosRaw.containsKey('EVENTO') &&
        datosRaw['EVENTO']!.isNotEmpty) {
      clasificacion = datosRaw['EVENTO'];
    } else if (ultimoEvento != null && ultimoEvento.isNotEmpty) {
      clasificacion = ultimoEvento;
    }

    if (clasificacion != null && clasificacion.isNotEmpty) {
      proyecto['Clasificación'] = clasificacion;
    } else {
      print('⚠️ Fila $rowIndex sin clasificación: $datosRaw');
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

  // ── Normalizar claves del Excel (formato PROYECTOS) ───────────────────────
  String normalizarClaveProyectos(String clave) {
    final claveNormalizada = clave.toUpperCase().trim();

    switch (claveNormalizada) {
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
  // [FIX] Ahora recibe eventData para guardar filialId, facultad y carrera
  // en cada proyecto, haciendo que sean filtrables de forma segura.
  Future<void> guardarProyectosEnEvento(
    String eventId,
    List<Map<String, dynamic>> proyectos, {
    Map<String, dynamic>? eventData, // ← nuevo parámetro opcional
  }) async {
    if (proyectos.isEmpty) return;

    try {
      // Extraer campos de ubicación del evento si están disponibles
      final String? filialId = eventData?['filialId'] as String?;
      final String? facultad = eventData?['facultad'] as String?;
      final String? carreraId = eventData?['carreraId'] as String?;
      final String? carreraNombre = eventData?['carreraNombre'] as String?;

      final batch = _firestore.batch();

      for (final proyecto in proyectos) {
        final docRef = _firestore
            .collection('events')
            .doc(eventId)
            .collection('proyectos')
            .doc();

        batch.set(docRef, {
          ...proyecto,
          // ── Campos de ubicación ──────────────────────────────────────
          // Solo se agregan si el evento los tiene disponibles.
          // Permiten filtrar proyectos con collectionGroup en el futuro.
          if (filialId != null) 'filialId': filialId,
          if (facultad != null) 'facultad': facultad,
          if (carreraId != null) 'carreraId': carreraId,
          if (carreraNombre != null) 'carreraNombre': carreraNombre,
          // ────────────────────────────────────────────────────────────
          'importedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      await _firestore.collection('events').doc(eventId).update({
        'lastImportAt': FieldValue.serverTimestamp(),
        'proyectosCount': FieldValue.increment(proyectos.length),
      });
    } catch (e) {
      print('Error al guardar proyectos: $e');
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

      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .doc(docId)
          .update({...nuevosDatos, 'updatedAt': FieldValue.serverTimestamp()});

      if (datosAntiguos != null &&
          nuevosDatos.containsKey('Clasificación') &&
          datosAntiguos['Clasificación'] != nuevosDatos['Clasificación']) {
        final codigoProyecto = nuevosDatos['Código'] ?? datosAntiguos['Código'];
        final nuevaCategoria = nuevosDatos['Clasificación'];

        print('⚠️ La clasificación cambió. Actualizando scans...');
        await actualizarCategoriaDeScansPorProyecto(
          eventId,
          codigoProyecto,
          nuevaCategoria,
        );
      }
    } catch (e) {
      print('Error al actualizar proyecto: $e');
      rethrow;
    }
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
      print('Error al eliminar proyecto: $e');
      rethrow;
    }
  }

  // ── Eliminar todos los proyectos ──────────────────────────────────────────
  Future<void> eliminarTodosLosProyectos(String eventId) async {
    try {
      final batch = _firestore.batch();

      final querySnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .get();

      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      await _firestore.collection('events').doc(eventId).update({
        'proyectosCount': 0,
        'lastImportAt': FieldValue.delete(),
      });
    } catch (e) {
      print('Error al eliminar todos los proyectos: $e');
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
      if (!grupos.containsKey(categoria)) {
        grupos[categoria] = [];
      }
      grupos[categoria]!.add(proyecto);
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