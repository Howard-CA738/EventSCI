import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class EvaluacionesGeneralExcelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Genera y descarga un reporte general de TODAS las evaluaciones
  /// Una sola hoja agrupada por categoría y código de proyecto
  Future<String> generarReporteGeneralEvaluaciones() async {
    debugPrint('🔍 Iniciando obtención de datos...');

    // Obtener todos los eventos
    final eventsSnapshot = await _firestore.collection('events').get();

    if (eventsSnapshot.docs.isEmpty) {
      throw Exception('No hay eventos registrados');
    }

    debugPrint('📦 Eventos encontrados: ${eventsSnapshot.docs.length}');

    final List<Map<String, dynamic>> todasLasEvaluaciones = [];
    final Map<String, String> juradosNombresCache = {};

    // Recorrer cada evento
    for (final eventDoc in eventsSnapshot.docs) {
      final eventId = eventDoc.id;
      final eventData = eventDoc.data();

      debugPrint('📋 Procesando evento: $eventId');

      // Obtener proyectos del evento
      final proyectosSnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .get();

      debugPrint('  - Proyectos en evento: ${proyectosSnapshot.docs.length}');

      for (final proyectoDoc in proyectosSnapshot.docs) {
        final proyectoData = proyectoDoc.data();
        final proyectoId = proyectoDoc.id;

        // Obtener código del proyecto (puede estar con mayúscula o minúscula)
        final codigoProyecto =
            proyectoData['Código'] ?? proyectoData['codigo'] ?? 'N/A';

        // Obtener evaluaciones del proyecto
        final evaluacionesSnapshot = await _firestore
            .collection('events')
            .doc(eventId)
            .collection('proyectos')
            .doc(proyectoId)
            .collection('evaluaciones')
            .get();

        debugPrint(
          '    - Evaluaciones en $codigoProyecto: ${evaluacionesSnapshot.docs.length}',
        );

        for (final evalDoc in evaluacionesSnapshot.docs) {
          final evalData = evalDoc.data();
          final juradoId = evalDoc.id;

          // Obtener nombre del jurado (con cache para evitar múltiples consultas)
          String juradoNombre = 'Jurado Desconocido';

          if (juradosNombresCache.containsKey(juradoId)) {
            juradoNombre = juradosNombresCache[juradoId]!;
          } else {
            // Intentar obtener de la evaluación misma
            if (evalData.containsKey('juradoNombre')) {
              juradoNombre = evalData['juradoNombre'];
              juradosNombresCache[juradoId] = juradoNombre;
            } else {
              // Buscar en la colección users
              try {
                final juradoDoc = await _firestore
                    .collection('users')
                    .doc(juradoId)
                    .get();

                if (juradoDoc.exists) {
                  final juradoData = juradoDoc.data();
                  // El campo es 'name' según PrefsHelper
                  juradoNombre = juradoData?['name'] ?? 'Jurado Desconocido';
                  juradosNombresCache[juradoId] = juradoNombre;
                  debugPrint('      ✅ Jurado encontrado: $juradoNombre');
                } else {
                  debugPrint('      ⚠️ Jurado no encontrado en users: $juradoId');
                }
              } catch (e) {
                debugPrint('      ❌ Error obteniendo jurado $juradoId: $e');
              }
            }
          }

          // Agregar evaluación con toda la información
          todasLasEvaluaciones.add({
            ...evalData,
            'eventId': eventId,
            'proyectoId': proyectoId,
            'codigoGrupo': codigoProyecto,
            'tituloProyecto':
                proyectoData['Título'] ??
                proyectoData['titulo'] ??
                'Sin título',
            'integrantes':
                proyectoData['Integrantes'] ??
                proyectoData['integrantes'] ??
                '',
            'sala': proyectoData['Sala'] ?? proyectoData['sala'] ?? '',
            'facultad': evalData['facultad'] ?? eventData['facultad'] ?? 'N/A',
            'carrera': evalData['carrera'] ?? eventData['carrera'] ?? 'N/A',
            'categoria':
                evalData['categoria'] ?? eventData['categoria'] ?? 'N/A',
            'juradoId': juradoId,
            'juradoNombre': juradoNombre,
          });
        }
      }
    }

    if (todasLasEvaluaciones.isEmpty) {
      throw Exception(
        'No hay evaluaciones disponibles para generar el reporte',
      );
    }

    debugPrint(
      '✅ Total de evaluaciones encontradas: ${todasLasEvaluaciones.length}',
    );

    // Crear el libro de Excel
    final excel = Excel.createExcel();

    // Eliminar la hoja por defecto
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Crear una sola hoja con todas las evaluaciones
    _construirHojaCompleta(excel, todasLasEvaluaciones);

    // Guardar el archivo
    final filePath = await _guardarArchivo(excel);

    return filePath;
  }

  void _construirHojaCompleta(
    Excel excel,
    List<Map<String, dynamic>> evaluaciones,
  ) {
    final sheet = excel['Evaluaciones Generales'];

    // Título principal
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('L1'));
    var titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue(
      'REPORTE GENERAL DE EVALUACIONES - TODAS LAS CATEGORÍAS',
    );
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.white,
    );

    // Información general
    var row = 2;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue(
      'Fecha de generación: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
    );
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .cellStyle = CellStyle(
      fontSize: 11,
      italic: true,
    );

    row++;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue(
      'Total de evaluaciones: ${evaluaciones.length}',
    );
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .cellStyle = CellStyle(
      fontSize: 11,
      bold: true,
    );

    // Obtener criterios de la primera evaluación
    List<dynamic> criterios = [];
    if (evaluaciones.isNotEmpty) {
      criterios = evaluaciones[0]['criterios'] as List<dynamic>? ?? [];
    }

    // Construir headers dinámicamente
    row += 2;
    final baseHeaders = [
      'N°',
      'Facultad',
      'Carrera',
      'Categoría',
      'Código\nProyecto',
      'Título del\nProyecto',
      'Integrantes',
      'Sala',
      'Jurado',
      'Estado',
    ];

    final headers = [...baseHeaders];

    // Agregar headers de criterios
    for (var i = 0; i < criterios.length; i++) {
      final criterio = criterios[i];
      headers.add('${criterio['descripcion']}\n(${criterio['escala']})');
    }

    headers.add('Nota Total');
    headers.add('Fecha\nEvaluación');

    // Escribir headers
    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#2196F3'),
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
      );
    }

    // Ordenar evaluaciones por facultad, carrera, categoría, proyecto y jurado
    evaluaciones.sort((a, b) {
      final cmpFacultad = (a['facultad'] as String).compareTo(
        b['facultad'] as String,
      );
      if (cmpFacultad != 0) return cmpFacultad;

      final cmpCarrera = (a['carrera'] as String).compareTo(
        b['carrera'] as String,
      );
      if (cmpCarrera != 0) return cmpCarrera;

      final cmpCategoria = (a['categoria'] as String).compareTo(
        b['categoria'] as String,
      );
      if (cmpCategoria != 0) return cmpCategoria;

      final cmpProyecto = (a['codigoGrupo'] as String).compareTo(
        b['codigoGrupo'] as String,
      );
      if (cmpProyecto != 0) return cmpProyecto;

      return (a['juradoNombre'] as String).compareTo(
        b['juradoNombre'] as String,
      );
    });

    // Datos de las evaluaciones
    row++;
    var contador = 1;

    for (final eval in evaluaciones) {
      final evaluada = eval['evaluada'] ?? false;
      final bloqueada = eval['bloqueada'] ?? false;
      final notas = eval['notas'] as Map<String, dynamic>? ?? {};
      final notaTotal = eval['notaTotal'] ?? 0;
      final fecha = eval['fechaEvaluacion'] as Timestamp?;

      var col = 0;

      // Color de fondo según estado
      final bgColor = evaluada
          ? ExcelColor.fromHexString('#D4EDDA')
          : ExcelColor.fromHexString('#FFF3CD');

      // N°
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      cell.value = IntCellValue(contador);
      cell.cellStyle = CellStyle(
        backgroundColorHex: bgColor,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Facultad
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      cell.value = TextCellValue(eval['facultad']);
      cell.cellStyle = CellStyle(backgroundColorHex: bgColor);

      // Carrera
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      cell.value = TextCellValue(eval['carrera']);
      cell.cellStyle = CellStyle(backgroundColorHex: bgColor);

      // Categoría
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      cell.value = TextCellValue(eval['categoria']);
      cell.cellStyle = CellStyle(backgroundColorHex: bgColor);

      // Código Proyecto
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      cell.value = TextCellValue(eval['codigoGrupo']);
      cell.cellStyle = CellStyle(backgroundColorHex: bgColor, bold: true);

      // Título del Proyecto
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      cell.value = TextCellValue(eval['tituloProyecto']);
      cell.cellStyle = CellStyle(
        backgroundColorHex: bgColor,
        textWrapping: TextWrapping.WrapText,
      );

      // Integrantes
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      cell.value = TextCellValue(eval['integrantes']);
      cell.cellStyle = CellStyle(
        backgroundColorHex: bgColor,
        textWrapping: TextWrapping.WrapText,
      );

      // Sala
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      cell.value = TextCellValue(eval['sala']);
      cell.cellStyle = CellStyle(
        backgroundColorHex: bgColor,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Jurado
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      cell.value = TextCellValue(eval['juradoNombre']);
      cell.cellStyle = CellStyle(backgroundColorHex: bgColor);

      // Estado
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      String estadoTexto = evaluada ? 'Evaluada' : 'Pendiente';
      if (bloqueada) estadoTexto += '\n(Bloqueada)';
      cell.value = TextCellValue(estadoTexto);
      cell.cellStyle = CellStyle(
        backgroundColorHex: bgColor,
        horizontalAlign: HorizontalAlign.Center,
        textWrapping: TextWrapping.WrapText,
      );

      // Notas por criterio
      if (evaluada) {
        for (var i = 0; i < criterios.length; i++) {
          final nota = notas[i.toString()] ?? 0;
          cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
          );
          cell.value = TextCellValue(nota.toString());
          cell.cellStyle = CellStyle(
            backgroundColorHex: bgColor,
            horizontalAlign: HorizontalAlign.Center,
          );
        }

        // Nota Total
        cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
        );
        cell.value = TextCellValue(notaTotal.toStringAsFixed(2));
        cell.cellStyle = CellStyle(
          backgroundColorHex: bgColor,
          horizontalAlign: HorizontalAlign.Center,
          bold: true,
        );
      } else {
        // Si no está evaluada, llenar con guiones
        for (var i = 0; i < criterios.length + 1; i++) {
          cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
          );
          cell.value = TextCellValue('-');
          cell.cellStyle = CellStyle(
            backgroundColorHex: bgColor,
            horizontalAlign: HorizontalAlign.Center,
            italic: true,
          );
        }
      }

      // Fecha de Evaluación
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      if (fecha != null && evaluada) {
        final fechaFormat = fecha.toDate();
        cell.value = TextCellValue(
          DateFormat('dd/MM/yyyy HH:mm').format(fechaFormat),
        );
      } else {
        cell.value = TextCellValue('-');
      }
      cell.cellStyle = CellStyle(
        backgroundColorHex: bgColor,
        horizontalAlign: HorizontalAlign.Center,
      );

      row++;
      contador++;
    }

    // Agregar fila de resumen al final
    row++;

    // Calcular estadísticas
    final totalEvaluaciones = evaluaciones.length;
    final evaluacionesCompletas = evaluaciones
        .where((e) => e['evaluada'] == true)
        .length;
    final evaluacionesPendientes = totalEvaluaciones - evaluacionesCompletas;

    final notasEvaluadas = evaluaciones
        .where((e) => e['evaluada'] == true)
        .map((e) => (e['notaTotal'] as num).toDouble())
        .toList();

    final promedioNotas = notasEvaluadas.isNotEmpty
        ? notasEvaluadas.reduce((a, b) => a + b) / notasEvaluadas.length
        : 0.0;

    // Fusionar celdas para "RESUMEN:"
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
    );

    var resumenCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    resumenCell.value = TextCellValue('RESUMEN GENERAL:');
    resumenCell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#FFC107'),
      horizontalAlign: HorizontalAlign.Center,
      fontSize: 12,
    );

    // Total Evaluaciones
    var startCol = 4;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: startCol + 1, rowIndex: row),
    );
    var totalCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
    );
    totalCell.value = TextCellValue('Total: $totalEvaluaciones');
    totalCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    // Evaluadas
    startCol += 2;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: startCol + 1, rowIndex: row),
    );
    var evaluadasCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
    );
    evaluadasCell.value = TextCellValue('Evaluadas: $evaluacionesCompletas');
    evaluadasCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    // Pendientes
    startCol += 2;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: startCol + 1, rowIndex: row),
    );
    var pendientesCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
    );
    pendientesCell.value = TextCellValue('Pendientes: $evaluacionesPendientes');
    pendientesCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    // Promedio
    startCol += 2;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: startCol + 1, rowIndex: row),
    );
    var promedioCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
    );
    promedioCell.value = TextCellValue(
      'Promedio General: ${promedioNotas.toStringAsFixed(2)}',
    );
    promedioCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    // Ajustar ancho de columnas
    sheet.setColumnWidth(0, 8); // N°
    sheet.setColumnWidth(1, 25); // Facultad
    sheet.setColumnWidth(2, 25); // Carrera
    sheet.setColumnWidth(3, 20); // Categoría
    sheet.setColumnWidth(4, 15); // Código
    sheet.setColumnWidth(5, 40); // Título
    sheet.setColumnWidth(6, 40); // Integrantes
    sheet.setColumnWidth(7, 10); // Sala
    sheet.setColumnWidth(8, 30); // Jurado
    sheet.setColumnWidth(9, 15); // Estado

    // Columnas de criterios
    for (var i = 0; i < criterios.length; i++) {
      sheet.setColumnWidth(10 + i, 12);
    }

    // Nota Total y Fecha
    sheet.setColumnWidth(10 + criterios.length, 12);
    sheet.setColumnWidth(11 + criterios.length, 18);
  }

  /// Guarda el archivo Excel en el dispositivo
  Future<String> _guardarArchivo(Excel excel) async {
    try {
      // Solicitar permisos según la versión de Android
      if (Platform.isAndroid) {
        if (await Permission.photos.isPermanentlyDenied ||
            await Permission.videos.isPermanentlyDenied) {
          await openAppSettings();
          throw Exception('Por favor, habilita los permisos en configuración');
        }

        Map<Permission, PermissionStatus> statuses = await [
          Permission.photos,
          Permission.videos,
        ].request();

        if (!statuses.values.every((status) => status.isGranted)) {
          var storageStatus = await Permission.storage.request();
          if (!storageStatus.isGranted) {
            var manageStatus = await Permission.manageExternalStorage.request();
            if (!manageStatus.isGranted) {
              throw Exception('Permisos de almacenamiento denegados');
            }
          }
        }
      }

      // Generar nombre de archivo
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Evaluaciones_General_Completo_$timestamp.xlsx';

      // Obtener directorio
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Documents');
        if (!await directory.exists()) {
          try {
            await directory.create(recursive: true);
          } catch (e) {
            directory = Directory('/storage/emulated/0/Download');
          }
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('No se pudo acceder al directorio de descargas');
      }

      // Guardar archivo
      final filePath = '${directory.path}/$fileName';
      final fileBytes = excel.save();

      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        debugPrint('✅ Archivo guardado exitosamente en: $filePath');
        debugPrint('📁 Ubicación: Documentos del dispositivo');
        return filePath;
      } else {
        throw Exception('Error al generar el archivo Excel');
      }
    } catch (e) {
      debugPrint('Error al guardar archivo: $e');
      rethrow;
    }
  }
}
