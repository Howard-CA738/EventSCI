import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReportesEvaluacionesExcelService {
  Future<bool> generarReporteEvaluaciones({
    required List<Map<String, dynamic>> evaluaciones,
    required String eventoNombre,
    required String facultad,
    String? carrera,
  }) async {
    try {
      print('📊 Iniciando generación de reporte Excel...');

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

      // Guardar archivo
      await _guardarArchivo(excel, eventoNombre, facultad, carrera);

      return true;
    } catch (e) {
      print('❌ Error al generar Excel: $e');
      return false;
    }
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

    // Headers de tabla
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

    // Ajustar anchos de columna
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

    // Headers
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

    // Datos
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

        // Colorear según estado
        if (i == 7) {
          // Columna Estado
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

    // Ajustar anchos
    sheet.setColumnWidth(0, 12); // Código
    sheet.setColumnWidth(1, 35); // Título
    sheet.setColumnWidth(2, 20); // Categoría
    sheet.setColumnWidth(3, 40); // Integrantes
    sheet.setColumnWidth(4, 12); // Sala
    sheet.setColumnWidth(5, 25); // Jurado
    sheet.setColumnWidth(6, 30); // Rúbrica
    sheet.setColumnWidth(7, 12); // Estado
    sheet.setColumnWidth(8, 12); // Nota
    sheet.setColumnWidth(9, 18); // Fecha
  }

  void _crearHojaPorProyecto(
    Excel excel,
    List<Map<String, dynamic>> evaluaciones,
  ) {
    final sheet = excel['Por Proyecto'];
    int row = 0;

    // Agrupar por proyecto
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

      // Información del proyecto
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

      // Headers de evaluaciones
      _agregarFilaHeader(sheet, row++, [
        'Jurado',
        'Rúbrica',
        'Estado',
        'Nota Total',
        'Fecha Evaluación',
      ]);

      // Evaluaciones del proyecto
      for (var eval in evals) {
        _agregarFilaDatos(sheet, row++, [
          eval['juradoNombre'],
          eval['rubricaNombre'],
          _getEstadoTexto(eval),
          eval['notaTotal'].toStringAsFixed(2),
          _formatearFecha(eval['fechaEvaluacion']),
        ]);
      }

      // Promedio si hay evaluaciones completadas
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

      row += 2; // Espacio entre proyectos
    }

    // Ajustar anchos
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

    // Agrupar por jurado
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

      // Información del jurado
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

      // Headers de proyectos
      _agregarFilaHeader(sheet, row++, [
        'Código',
        'Título',
        'Categoría',
        'Estado',
        'Nota Total',
        'Fecha Evaluación',
      ]);

      // Proyectos del jurado
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

          // Colorear según estado
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

      row += 2; // Espacio entre jurados
    }

    // Ajustar anchos
    sheet.setColumnWidth(0, 12);
    sheet.setColumnWidth(1, 35);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 12);
    sheet.setColumnWidth(5, 18);
  }

  // Métodos auxiliares
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

  Future<void> _guardarArchivo(
    Excel excel,
    String eventoNombre,
    String facultad,
    String? carrera,
  ) async {
    try {
      // Solicitar permisos solo si es necesario (Android < 10)
      if (Platform.isAndroid) {
        // Para Android 10+ (API 29+) no se necesitan permisos para Documents/Download
        // Solo para versiones anteriores
        final storageStatus = await Permission.storage.status;

        if (storageStatus.isDenied) {
          final result = await Permission.storage.request();

          if (result.isDenied || result.isPermanentlyDenied) {
            throw Exception(
              'Se necesitan permisos de almacenamiento para guardar el archivo',
            );
          }
        }
      }

      // Generar nombre de archivo
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final nombreEvento = eventoNombre.replaceAll(' ', '_');

      // Agregar carrera al nombre si existe
      String sufijo = '';
      if (carrera != null && carrera != 'General') {
        sufijo = '_${carrera.replaceAll(' ', '_')}';
      }

      final fileName =
          'Reporte_Evaluaciones_${nombreEvento}${sufijo}_$timestamp.xlsx';

      // Obtener directorio de Documentos
      Directory? directory;
      if (Platform.isAndroid) {
        // Usar Downloads que es más accesible sin permisos especiales
        directory = Directory('/storage/emulated/0/Download');

        // Verificar si existe, si no, intentar con Documents
        if (!await directory.exists()) {
          directory = Directory('/storage/emulated/0/Documents');

          if (!await directory.exists()) {
            try {
              await directory.create(recursive: true);
            } catch (e) {
              // Si falla, usar getExternalStorageDirectory
              final appDir = await getExternalStorageDirectory();
              directory = Directory('${appDir?.path}/Download');
              await directory.create(recursive: true);
            }
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
        print('✅ Archivo guardado exitosamente en: $filePath');
        print('📁 Ubicación: ${directory.path}');
        print('📄 Nombre: $fileName');
      } else {
        throw Exception('Error al generar el archivo Excel');
      }
    } catch (e) {
      print('❌ Error al guardar archivo: $e');
      rethrow;
    }
  }
}
