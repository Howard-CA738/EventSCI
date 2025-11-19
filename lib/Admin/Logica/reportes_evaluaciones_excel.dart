import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ReportesEvaluacionesExcelService {
  Future<Map<String, dynamic>> generarReporteEvaluaciones({
    required List<Map<String, dynamic>> evaluaciones,
    required String eventoNombre,
    required String facultad,
    String? carrera,
  }) async {
    try {
      print('📊 Iniciando generación de reporte Excel...');

      // 1. Solicitar permisos primero
      final permisoConcedido = await _solicitarPermisos();
      if (!permisoConcedido) {
        return {
          'success': false,
          'message': 'Permisos de almacenamiento denegados',
        };
      }

      // 2. Crear el Excel
      final excel = Excel.createExcel();

      // Crear hojas
      _crearHojaResumen(excel, evaluaciones, eventoNombre, facultad, carrera);
      _crearHojaDetallada(excel, evaluaciones);
      _crearHojaPorProyecto(excel, evaluaciones);
      _crearHojaPorJurado(excel, evaluaciones);

      // Eliminar hoja por defecto
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // 3. Guardar archivo
      final resultado = await _guardarArchivo(
        excel,
        eventoNombre,
        facultad,
        carrera,
      );

      return resultado;
    } catch (e) {
      print('❌ Error al generar Excel: $e');
      return {'success': false, 'message': 'Error al generar el archivo: $e'};
    }
  }

  Future<bool> _solicitarPermisos() async {
    if (!Platform.isAndroid) {
      return true; // iOS no necesita permisos especiales
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      print('📱 Android SDK: $sdkInt');

      // Android 13+ (API 33+)
      if (sdkInt >= 33) {
        // No necesita permisos para guardar en Downloads
        return true;
      }
      // Android 10-12 (API 29-32)
      else if (sdkInt >= 29) {
        // Tampoco necesita permisos por Scoped Storage
        return true;
      }
      // Android 9 o menor (API 28-)
      else {
        final status = await Permission.storage.request();
        if (status.isGranted) {
          return true;
        } else if (status.isPermanentlyDenied) {
          await openAppSettings();
          return false;
        } else {
          return false;
        }
      }
    } catch (e) {
      print('❌ Error al verificar permisos: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> _guardarArchivo(
    Excel excel,
    String eventoNombre,
    String facultad,
    String? carrera,
  ) async {
    try {
      // Generar nombre de archivo
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final nombreEvento = _limpiarNombre(eventoNombre);

      String sufijo = '';
      if (carrera != null && carrera != 'General') {
        sufijo = '_${_limpiarNombre(carrera)}';
      }

      final fileName = 'Reporte_${nombreEvento}${sufijo}_$timestamp.xlsx';

      Directory? directory;
      String rutaCompleta = '';

      if (Platform.isAndroid) {
        // SOLUCIÓN: Usar getExternalStorageDirectory + Documents
        final Directory? baseDir = await getExternalStorageDirectory();

        if (baseDir == null) {
          throw Exception('No se pudo acceder al almacenamiento externo');
        }

        // Navegar hasta la carpeta Documents pública
        // Ruta típica: /storage/emulated/0/Documents
        final List<String> paths = baseDir.path.split('/');
        final int index = paths.indexOf('Android');

        if (index != -1) {
          // Crear ruta hasta /storage/emulated/0/Documents
          final String publicPath = paths.sublist(0, index).join('/');
          directory = Directory('$publicPath/Documents/ReportesEvaluaciones');

          print('📁 Intentando crear directorio: ${directory.path}');

          // Crear carpeta si no existe
          if (!await directory.exists()) {
            try {
              await directory.create(recursive: true);
              print('✅ Directorio creado exitosamente');
            } catch (e) {
              print('⚠️ No se pudo crear en Documents, usando Downloads...');
              directory = Directory('$publicPath/Download');
              if (!await directory.exists()) {
                await directory.create(recursive: true);
              }
            }
          }
        } else {
          // Fallback: usar el directorio de la app
          directory = Directory('${baseDir.path}/ReportesEvaluaciones');
          await directory.create(recursive: true);
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('No se pudo determinar el directorio de guardado');
      }

      // Guardar archivo
      rutaCompleta = '${directory.path}/$fileName';
      final fileBytes = excel.save();

      if (fileBytes != null) {
        final file = File(rutaCompleta);
        await file.writeAsBytes(fileBytes);

        print('✅ Archivo guardado exitosamente');
        print('📁 Ubicación: $rutaCompleta');

        return {
          'success': true,
          'message': 'Archivo guardado exitosamente',
          'path': rutaCompleta,
          'fileName': fileName,
          'directory': directory.path,
        };
      } else {
        throw Exception('Error al generar los bytes del archivo');
      }
    } catch (e) {
      print('❌ Error al guardar archivo: $e');
      return {'success': false, 'message': 'Error al guardar: $e'};
    }
  }

  String _limpiarNombre(String nombre) {
    // Limpiar caracteres especiales
    String limpio = nombre
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');

    // Limitar longitud DESPUÉS de limpiar
    if (limpio.length > 30) {
      return limpio.substring(0, 30);
    }

    return limpio.isEmpty ? 'reporte' : limpio;
  }

  void _crearHojaResumen(
    Excel excel,
    List<Map<String, dynamic>> evaluaciones,
    String eventoNombre,
    String facultad,
    String? carrera,
  ) {
    final sheet = excel['Resumen'];

    int row = 0;

    // Título principal
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('D1'));
    var titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('REPORTE DE EVALUACIONES');
    titleCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#27AE60'),
      fontColorHex: ExcelColor.white,
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
    );
    row += 2;

    // Información del evento
    _agregarFilaSimple(sheet, row++, 'Evento:', eventoNombre);
    _agregarFilaSimple(sheet, row++, 'Facultad:', facultad);
    if (carrera != null && carrera != 'General') {
      _agregarFilaSimple(sheet, row++, 'Carrera:', carrera);
    }
    _agregarFilaSimple(
      sheet,
      row++,
      'Fecha de generación:',
      DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
    );
    row += 1;

    // Estadísticas generales
    final totalEvaluaciones = evaluaciones.length;
    final evaluadas = evaluaciones.where((e) => e['evaluada'] as bool).length;
    final pendientes = totalEvaluaciones - evaluadas;
    final bloqueadas = evaluaciones.where((e) => e['bloqueada'] as bool).length;

    var statsHeader = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    statsHeader.value = TextCellValue('ESTADÍSTICAS GENERALES');
    statsHeader.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.white,
      bold: true,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
    );
    row += 1;

    _agregarFilaSimple(
      sheet,
      row++,
      'Total de evaluaciones:',
      totalEvaluaciones.toString(),
    );
    _agregarFilaSimple(
      sheet,
      row++,
      'Evaluaciones completadas:',
      evaluadas.toString(),
    );
    _agregarFilaSimple(
      sheet,
      row++,
      'Evaluaciones pendientes:',
      pendientes.toString(),
    );
    _agregarFilaSimple(
      sheet,
      row++,
      'Evaluaciones bloqueadas:',
      bloqueadas.toString(),
    );
    row += 1;

    // Estadísticas por categoría
    final proyectosPorCategoria = <String, List<Map<String, dynamic>>>{};
    for (var eval in evaluaciones) {
      final categoria = eval['clasificacion'] as String;
      if (!proyectosPorCategoria.containsKey(categoria)) {
        proyectosPorCategoria[categoria] = [];
      }
      proyectosPorCategoria[categoria]!.add(eval);
    }

    var catHeader = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    catHeader.value = TextCellValue('EVALUACIONES POR CATEGORÍA');
    catHeader.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.white,
      bold: true,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
    );
    row += 1;

    _agregarFilaHeader(sheet, row++, [
      'Categoría',
      'Total',
      'Evaluadas',
      'Pendientes',
    ]);

    for (var entry in proyectosPorCategoria.entries) {
      final categoria = entry.key;
      final evals = entry.value;
      final totalCat = evals.length;
      final evaluadasCat = evals.where((e) => e['evaluada'] as bool).length;
      final pendientesCat = totalCat - evaluadasCat;

      _agregarFilaDatos(sheet, row++, [
        categoria,
        totalCat.toString(),
        evaluadasCat.toString(),
        pendientesCat.toString(),
      ]);
    }

    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(2, 15);
    sheet.setColumnWidth(3, 15);
  }

  void _crearHojaDetallada(
    Excel excel,
    List<Map<String, dynamic>> evaluaciones,
  ) {
    final sheet = excel['Detalle Completo'];

    int row = 0;

    final headers = [
      'Código',
      'Título',
      'Categoría',
      'Integrantes',
      'Sala',
      'Jurado',
      'Rúbrica',
      'Estado',
      'Nota Total',
      'Fecha Evaluación',
    ];

    _agregarFilaHeader(sheet, row++, headers);

    for (var eval in evaluaciones) {
      final datos = [
        eval['codigo'],
        eval['titulo'],
        eval['clasificacion'],
        eval['integrantes'],
        eval['sala'],
        eval['juradoNombre'],
        eval['rubricaNombre'],
        _getEstadoTexto(eval),
        eval['notaTotal'].toStringAsFixed(2),
        _formatearFecha(eval['fechaEvaluacion']),
      ];

      for (int i = 0; i < datos.length; i++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row),
        );
        cell.value = TextCellValue(datos[i]);

        if (i == 7) {
          if (eval['bloqueada'] as bool) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#FFEBEE'),
              fontColorHex: ExcelColor.fromHexString('#C62828'),
            );
          } else if (eval['evaluada'] as bool) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
              fontColorHex: ExcelColor.fromHexString('#2E7D32'),
            );
          } else {
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#FFF3E0'),
              fontColorHex: ExcelColor.fromHexString('#E65100'),
            );
          }
        }
      }
      row++;
    }

    sheet.setColumnWidth(0, 12);
    sheet.setColumnWidth(1, 35);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 40);
    sheet.setColumnWidth(4, 12);
    sheet.setColumnWidth(5, 25);
    sheet.setColumnWidth(6, 30);
    sheet.setColumnWidth(7, 12);
    sheet.setColumnWidth(8, 12);
    sheet.setColumnWidth(9, 18);
  }

  void _crearHojaPorProyecto(
    Excel excel,
    List<Map<String, dynamic>> evaluaciones,
  ) {
    final sheet = excel['Por Proyecto'];
    int row = 0;

    final proyectosMap = <String, List<Map<String, dynamic>>>{};
    for (var eval in evaluaciones) {
      final codigo = eval['codigo'] as String;
      if (!proyectosMap.containsKey(codigo)) {
        proyectosMap[codigo] = [];
      }
      proyectosMap[codigo]!.add(eval);
    }

    for (var entry in proyectosMap.entries) {
      final codigo = entry.key;
      final evals = entry.value;
      final primerEval = evals.first;

      var proyectoHeader = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      );
      proyectoHeader.value = TextCellValue(
        'PROYECTO: $codigo - ${primerEval['titulo']}',
      );
      proyectoHeader.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#27AE60'),
        fontColorHex: ExcelColor.white,
        bold: true,
      );
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
      );
      row++;

      _agregarFilaSimple(
        sheet,
        row++,
        'Categoría:',
        primerEval['clasificacion'],
      );
      _agregarFilaSimple(
        sheet,
        row++,
        'Integrantes:',
        primerEval['integrantes'],
      );
      _agregarFilaSimple(sheet, row++, 'Sala:', primerEval['sala']);
      row++;

      _agregarFilaHeader(sheet, row++, [
        'Jurado',
        'Rúbrica',
        'Estado',
        'Nota Total',
        'Fecha Evaluación',
      ]);

      for (var eval in evals) {
        _agregarFilaDatos(sheet, row++, [
          eval['juradoNombre'],
          eval['rubricaNombre'],
          _getEstadoTexto(eval),
          eval['notaTotal'].toStringAsFixed(2),
          _formatearFecha(eval['fechaEvaluacion']),
        ]);
      }

      final evaluadasProyecto = evals
          .where((e) => e['evaluada'] as bool)
          .toList();
      if (evaluadasProyecto.isNotEmpty) {
        final promedio =
            evaluadasProyecto
                .map((e) => e['notaTotal'] as double)
                .reduce((a, b) => a + b) /
            evaluadasProyecto.length;

        var promedioCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        );
        promedioCell.value = TextCellValue('PROMEDIO:');
        promedioCell.cellStyle = CellStyle(bold: true);

        var valorPromedio = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
        );
        valorPromedio.value = TextCellValue(promedio.toStringAsFixed(2));
        valorPromedio.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
          fontColorHex: ExcelColor.fromHexString('#2E7D32'),
        );
        row++;
      }

      row += 2;
    }

    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 30);
    sheet.setColumnWidth(2, 12);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 18);
  }

  void _crearHojaPorJurado(
    Excel excel,
    List<Map<String, dynamic>> evaluaciones,
  ) {
    final sheet = excel['Por Jurado'];
    int row = 0;

    final juradosMap = <String, List<Map<String, dynamic>>>{};
    for (var eval in evaluaciones) {
      final jurado = eval['juradoNombre'] as String;
      if (!juradosMap.containsKey(jurado)) {
        juradosMap[jurado] = [];
      }
      juradosMap[jurado]!.add(eval);
    }

    for (var entry in juradosMap.entries) {
      final jurado = entry.key;
      final evals = entry.value;

      var juradoHeader = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      );
      juradoHeader.value = TextCellValue('JURADO: $jurado');
      juradoHeader.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#FF9800'),
        fontColorHex: ExcelColor.white,
        bold: true,
      );
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
      );
      row++;

      final rubricaJurado = evals.first['rubricaNombre'];
      _agregarFilaSimple(sheet, row++, 'Rúbrica asignada:', rubricaJurado);

      final totalAsignados = evals.length;
      final completadas = evals.where((e) => e['evaluada'] as bool).length;
      final pendientes = totalAsignados - completadas;

      _agregarFilaSimple(
        sheet,
        row++,
        'Total proyectos asignados:',
        totalAsignados.toString(),
      );
      _agregarFilaSimple(
        sheet,
        row++,
        'Evaluaciones completadas:',
        completadas.toString(),
      );
      _agregarFilaSimple(
        sheet,
        row++,
        'Evaluaciones pendientes:',
        pendientes.toString(),
      );
      row++;

      _agregarFilaHeader(sheet, row++, [
        'Código',
        'Título',
        'Categoría',
        'Estado',
        'Nota Total',
        'Fecha Evaluación',
      ]);

      for (var eval in evals) {
        final datos = [
          eval['codigo'],
          eval['titulo'],
          eval['clasificacion'],
          _getEstadoTexto(eval),
          eval['notaTotal'].toStringAsFixed(2),
          _formatearFecha(eval['fechaEvaluacion']),
        ];

        for (int i = 0; i < datos.length; i++) {
          var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row),
          );
          cell.value = TextCellValue(datos[i]);

          if (i == 3) {
            if (eval['bloqueada'] as bool) {
              cell.cellStyle = CellStyle(
                backgroundColorHex: ExcelColor.fromHexString('#FFEBEE'),
                fontColorHex: ExcelColor.fromHexString('#C62828'),
              );
            } else if (eval['evaluada'] as bool) {
              cell.cellStyle = CellStyle(
                backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
                fontColorHex: ExcelColor.fromHexString('#2E7D32'),
              );
            } else {
              cell.cellStyle = CellStyle(
                backgroundColorHex: ExcelColor.fromHexString('#FFF3E0'),
                fontColorHex: ExcelColor.fromHexString('#E65100'),
              );
            }
          }
        }
        row++;
      }

      row += 2;
    }

    sheet.setColumnWidth(0, 12);
    sheet.setColumnWidth(1, 35);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 12);
    sheet.setColumnWidth(5, 18);
  }

  void _agregarFilaSimple(Sheet sheet, int row, String label, String value) {
    var labelCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    labelCell.value = TextCellValue(label);
    labelCell.cellStyle = CellStyle(bold: true);

    var valueCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
    );
    valueCell.value = TextCellValue(value);
  }

  void _agregarFilaHeader(Sheet sheet, int row, List<String> valores) {
    for (int i = 0; i < valores.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row),
      );
      cell.value = TextCellValue(valores[i]);
      cell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
        fontColorHex: ExcelColor.white,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );
    }
  }

  void _agregarFilaDatos(Sheet sheet, int row, List<String> valores) {
    for (int i = 0; i < valores.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row),
      );
      cell.value = TextCellValue(valores[i]);
    }
  }

  String _getEstadoTexto(Map<String, dynamic> eval) {
    if (eval['bloqueada'] as bool) return 'Bloqueada';
    if (eval['evaluada'] as bool) return 'Evaluada';
    return 'Pendiente';
  }

  String _formatearFecha(dynamic fecha) {
    if (fecha == null) return '-';

    try {
      if (fecha is Timestamp) {
        final DateTime dt = fecha.toDate();
        return DateFormat('dd/MM/yyyy HH:mm').format(dt);
      }
      return '-';
    } catch (e) {
      return '-';
    }
  }
}
