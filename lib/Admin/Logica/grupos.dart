import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'dart:typed_data';

class GruposService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cargar proyectos existentes desde Firebase
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

      final proyectos = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();

      return proyectos;
    } catch (e) {
      print('Error al cargar proyectos existentes: $e');
      rethrow;
    }
  }

  Future<void> actualizarCategoriaDeScansPorProyecto(
    String eventId,
    String codigoProyecto,
    String nuevaCategoria,
  ) async {
    try {
      print('🔄 Actualizando scans del proyecto: $codigoProyecto');
      print('📝 Nueva categoría: $nuevaCategoria');

      // Obtener todas las asistencias del evento
      final asistenciasSnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias')
          .get();

      int scansActualizados = 0;
      final batch = _firestore.batch();

      // Recorrer cada estudiante
      for (final estudianteDoc in asistenciasSnapshot.docs) {
        // Buscar scans con el código del proyecto
        final scansSnapshot = await _firestore
            .collection('events')
            .doc(eventId)
            .collection('asistencias')
            .doc(estudianteDoc.id)
            .collection('scans')
            .where('codigoProyecto', isEqualTo: codigoProyecto)
            .get();

        // Actualizar cada scan encontrado
        for (final scanDoc in scansSnapshot.docs) {
          batch.update(scanDoc.reference, {
            'categoria': nuevaCategoria,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          scansActualizados++;
        }
      }

      // Ejecutar todas las actualizaciones
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

  // Importar Excel y retornar los datos procesados
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

  // Procesar archivo Excel desde bytes con DETECCIÓN AUTOMÁTICA
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

        // 🔍 DETECCIÓN AUTOMÁTICA DEL FORMATO
        final tipoFormato = detectarFormatoExcel(headers);
        print('Formato detectado: $tipoFormato');

        // 📌 Variable para recordar el último SUBEVENTOS/EVENTO (para merged cells)
        String? ultimoSubevento;
        String? ultimoEvento;

        for (int i = 1; i < sheet.maxRows; i++) {
          final row = sheet.rows[i];
          Map<String, dynamic> proyecto = {};

          if (tipoFormato == 'PROYECTOS') {
            // Formato original: CÓDIGO, TÍTULO, INTEGRANTES, CLASIFICACIÓN
            proyecto = procesarFormatoProyectos(headers, row);
            // Validar que tenga los datos mínimos requeridos
            if (proyecto.containsKey('Código') &&
                proyecto.containsKey('Clasificación')) {
              proyectos.add(proyecto);
            }
          } else if (tipoFormato == 'EVENTOS') {
            // Formato nuevo: EVENTO, SUBEVENTOS, TÍTULO DE PROGRAMA, ENCARGADO, LUGAR
            proyecto = procesarFormatoEventos(
              headers,
              row,
              i,
              ultimoSubevento,
              ultimoEvento,
            );

            // Actualizar los últimos valores conocidos
            if (proyecto.containsKey('Subevento') &&
                proyecto['Subevento'] != null) {
              ultimoSubevento = proyecto['Subevento'];
            }
            if (proyecto.containsKey('EventoPrincipal') &&
                proyecto['EventoPrincipal'] != null) {
              ultimoEvento = proyecto['EventoPrincipal'];
            }

            // Para eventos, validar que tenga al menos título y clasificación
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

  // 🔍 Detectar el formato del Excel basado en los headers
  String detectarFormatoExcel(List<String> headers) {
    final headersUpper = headers.map((h) => h.toUpperCase().trim()).toList();

    // Verificar si es formato de EVENTOS
    bool tieneEvento = headersUpper.any((h) => h.contains('EVENTO'));
    bool tieneSubeventos = headersUpper.any((h) => h.contains('SUBEVENTOS'));
    bool tieneEncargado = headersUpper.any((h) => h.contains('ENCARGADO'));
    bool tieneLugar = headersUpper.any((h) => h.contains('LUGAR'));

    if (tieneEvento || tieneSubeventos || tieneEncargado || tieneLugar) {
      return 'EVENTOS';
    }

    // Verificar si es formato de PROYECTOS
    bool tieneCodigo = headersUpper.any((h) => h.contains('CÓDIGO'));
    bool tieneClasificacion = headersUpper.any(
      (h) => h.contains('CLASIFICACIÓN'),
    );

    if (tieneCodigo || tieneClasificacion) {
      return 'PROYECTOS';
    }

    // Por defecto, asumir formato de proyectos
    return 'PROYECTOS';
  }

  // 📋 Procesar formato PROYECTOS (original)
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

  // 🎭 Procesar formato EVENTOS (nuevo)
  Map<String, dynamic> procesarFormatoEventos(
    List<String> headers,
    List<Data?> row,
    int rowIndex,
    String? ultimoSubevento,
    String? ultimoEvento,
  ) {
    Map<String, dynamic> proyecto = {};

    // Crear un mapa temporal con los datos
    Map<String, String> datosRaw = {};
    for (int j = 0; j < headers.length && j < row.length; j++) {
      final cellValue = row[j]?.value?.toString().trim();
      if (cellValue != null && cellValue.isNotEmpty) {
        String headerKey = headers[j].toUpperCase().trim();
        // Normalizar variaciones del nombre de columna
        if (headerKey.contains('TÍTULO') && headerKey.contains('PROGRAMA')) {
          headerKey = 'TÍTULO DE PROGRAMA / PONENCIA';
        }
        datosRaw[headerKey] = cellValue;
      }
    }

    // TÍTULO: Usamos TÍTULO DE PROGRAMA/PONENCIA (este será nuestro identificador único)
    String titulo = datosRaw['TÍTULO DE PROGRAMA / PONENCIA'] ?? '';
    if (titulo.isEmpty) {
      return {}; // Si no hay título, no procesamos esta fila
    }
    proyecto['Título'] = titulo;

    // CÓDIGO: Generamos uno corto y limpio basado en el índice de la fila
    proyecto['Código'] = 'PON-${rowIndex.toString().padLeft(3, '0')}';

    // INTEGRANTES: Usamos ENCARGADO
    if (datosRaw.containsKey('ENCARGADO')) {
      proyecto['Integrantes'] = datosRaw['ENCARGADO'];
    }

    // 🔑 CLASIFICACIÓN: Usamos SUBEVENTOS con manejo de merged cells
    String? clasificacion;

    // Intentar obtener de la celda actual primero
    if (datosRaw.containsKey('SUBEVENTOS') &&
        datosRaw['SUBEVENTOS']!.isNotEmpty) {
      clasificacion = datosRaw['SUBEVENTOS'];
    }
    // Si la celda está vacía (merged), usar el último valor conocido
    else if (ultimoSubevento != null && ultimoSubevento.isNotEmpty) {
      clasificacion = ultimoSubevento;
      print(
        'Usando último subevento conocido: $ultimoSubevento para fila $rowIndex',
      );
    }
    // Último recurso: usar EVENTO
    else if (datosRaw.containsKey('EVENTO') && datosRaw['EVENTO']!.isNotEmpty) {
      clasificacion = datosRaw['EVENTO'];
    }
    // O el último evento conocido
    else if (ultimoEvento != null && ultimoEvento.isNotEmpty) {
      clasificacion = ultimoEvento;
    }

    if (clasificacion != null && clasificacion.isNotEmpty) {
      proyecto['Clasificación'] = clasificacion;
    } else {
      print('⚠️ Fila $rowIndex sin clasificación: ${datosRaw}');
      return {}; // Si no hay clasificación, no procesamos esta fila
    }

    // SALA: Usamos LUGAR (también puede estar merged)
    if (datosRaw.containsKey('LUGAR') && datosRaw['LUGAR']!.isNotEmpty) {
      proyecto['Sala'] = datosRaw['LUGAR'];
    }

    // Agregar campos adicionales para referencia
    proyecto['TipoImportacion'] = 'EVENTOS';

    // Guardar EVENTO actual o el último conocido
    if (datosRaw.containsKey('EVENTO') && datosRaw['EVENTO']!.isNotEmpty) {
      proyecto['EventoPrincipal'] = datosRaw['EVENTO'];
    } else if (ultimoEvento != null) {
      proyecto['EventoPrincipal'] = ultimoEvento;
    }

    // Guardar SUBEVENTOS actual o el último conocido
    if (datosRaw.containsKey('SUBEVENTOS') &&
        datosRaw['SUBEVENTOS']!.isNotEmpty) {
      proyecto['Subevento'] = datosRaw['SUBEVENTOS'];
    } else if (ultimoSubevento != null) {
      proyecto['Subevento'] = ultimoSubevento;
    }

    return proyecto;
  }

  // Normalizar las claves de las columnas del Excel (formato PROYECTOS)
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

  // Guardar proyectos en Firebase
  Future<void> guardarProyectosEnEvento(
    String eventId,
    List<Map<String, dynamic>> proyectos,
  ) async {
    if (proyectos.isEmpty) return;

    try {
      final batch = _firestore.batch();

      for (final proyecto in proyectos) {
        final docRef = _firestore
            .collection('events')
            .doc(eventId)
            .collection('proyectos')
            .doc();

        batch.set(docRef, {
          ...proyecto,
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

  Future<void> actualizarProyecto(
    String eventId,
    String docId,
    Map<String, dynamic> nuevosDatos,
  ) async {
    try {
      // Primero, obtener los datos actuales del proyecto
      final proyectoDoc = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .doc(docId)
          .get();

      final datosAntiguos = proyectoDoc.data();

      // Actualizar el proyecto
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .doc(docId)
          .update({...nuevosDatos, 'updatedAt': FieldValue.serverTimestamp()});

      // ✅ Si cambió la clasificación, actualizar todos los scans relacionados
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

  // Eliminar un proyecto individual de Firebase
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

  // Eliminar todos los proyectos de Firebase
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

  // Agrupar proyectos por categoría
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

  // Formatear fecha de timestamp
  String formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'N/A';
  }
}
