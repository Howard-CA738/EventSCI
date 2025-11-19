import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class ReportesGanadoresExcelService {
  Future<bool> generarReporteGanadores({
    required Map<String, List<Map<String, dynamic>>> ganadoresPorCategoria,
    required String facultad,
    required String carrera,
    required int totalEventos,
  }) async {
    try {
      print('🏆 Iniciando generación de reporte de ganadores Excel...');

      final excel = Excel.createExcel();

      // Crear hojas
      _crearHojaResumen(
        excel,
        ganadoresPorCategoria,
        facultad,
        carrera,
        totalEventos,
      );
      _crearHojaPorCategoria(excel, ganadoresPorCategoria);
      _crearHojaDetallada(excel, ganadoresPorCategoria);
      _crearHojaEstadisticas(excel, ganadoresPorCategoria);

      // Eliminar hoja por defecto
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Guardar archivo
      await _guardarArchivo(excel, facultad, carrera);

      return true;
    } catch (e) {
      print('❌ Error al generar Excel de ganadores: $e');
      return false;
    }
  }

  void _crearHojaResumen(
    Excel excel,
    Map<String, List<Map<String, dynamic>>> ganadoresPorCategoria,
    String facultad,
    String carrera,
    int totalEventos,
  ) {
    final sheet = excel['Resumen General'];

    int row = 0;

    // Título principal
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('E1'));
    var titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('REPORTE DE PROYECTOS GANADORES');
    titleCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFD700'),
      fontColorHex: ExcelColor.fromHexString('#1E3A5F'),
      bold: true,
      fontSize: 16,
      horizontalAlign: HorizontalAlign.Center,
    );
    row += 2;

    // Información general
    _agregarFilaSimple(sheet, row++, 'Facultad:', facultad);
    _agregarFilaSimple(sheet, row++, 'Carrera:', carrera);
    _agregarFilaSimple(
      sheet,
      row++,
      'Total de Eventos:',
      totalEventos.toString(),
    );
    _agregarFilaSimple(
      sheet,
      row++,
      'Fecha de generación:',
      DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
    );
    row += 1;

    // Estadísticas generales
    final totalGanadores = ganadoresPorCategoria.values.fold<int>(
      0,
      (sum, lista) => sum + lista.length,
    );
    final totalCategorias = ganadoresPorCategoria.length;

    var statsHeader = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    statsHeader.value = TextCellValue('ESTADÍSTICAS GENERALES');
    statsHeader.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.white,
      bold: true,
      fontSize: 12,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
    );
    row += 1;

    _agregarFilaSimple(
      sheet,
      row++,
      'Total de categorías:',
      totalCategorias.toString(),
    );
    _agregarFilaSimple(
      sheet,
      row++,
      'Total de ganadores:',
      totalGanadores.toString(),
    );
    _agregarFilaSimple(
      sheet,
      row++,
      'Promedio por categoría:',
      (totalGanadores / totalCategorias).toStringAsFixed(2),
    );
    row += 1;

    // Distribución por posición
    var distHeader = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    distHeader.value = TextCellValue('DISTRIBUCIÓN POR POSICIÓN');
    distHeader.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.white,
      bold: true,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
    );
    row += 1;

    final primeros = ganadoresPorCategoria.values.fold<int>(
      0,
      (sum, lista) => sum + lista.where((g) => g['posicion'] == 1).length,
    );
    final segundos = ganadoresPorCategoria.values.fold<int>(
      0,
      (sum, lista) => sum + lista.where((g) => g['posicion'] == 2).length,
    );
    final terceros = ganadoresPorCategoria.values.fold<int>(
      0,
      (sum, lista) => sum + lista.where((g) => g['posicion'] == 3).length,
    );

    _agregarFilaSimple(
      sheet,
      row++,
      '🥇 Primeros lugares:',
      primeros.toString(),
    );
    _agregarFilaSimple(
      sheet,
      row++,
      '🥈 Segundos lugares:',
      segundos.toString(),
    );
    _agregarFilaSimple(
      sheet,
      row++,
      '🥉 Terceros lugares:',
      terceros.toString(),
    );
    row += 1;

    // Resumen por categoría
    var catHeader = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    catHeader.value = TextCellValue('RESUMEN POR CATEGORÍA');
    catHeader.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.white,
      bold: true,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
    );
    row += 1;

    // Headers
    _agregarFilaHeader(sheet, row++, [
      'Categoría',
      'Total Ganadores',
      'Promedio Nota',
      'Mejor Proyecto',
    ]);

    // Datos por categoría
    for (var entry in ganadoresPorCategoria.entries) {
      final categoria = entry.key;
      final ganadores = entry.value;

      final promedioNotas =
          ganadores.fold<double>(
            0,
            (sum, g) => sum + (g['promedioFinal'] ?? 0.0),
          ) /
          ganadores.length;

      final mejorProyecto = ganadores.isNotEmpty
          ? ganadores[0]['projectName']
          : 'N/A';

      _agregarFilaDatos(sheet, row++, [
        categoria,
        ganadores.length.toString(),
        promedioNotas.toStringAsFixed(2),
        mejorProyecto,
      ]);
    }

    // Ajustar anchos de columna
    sheet.setColumnWidth(0, 35);
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 45);
    sheet.setColumnWidth(4, 15);
  }

  void _crearHojaPorCategoria(
    Excel excel,
    Map<String, List<Map<String, dynamic>>> ganadoresPorCategoria,
  ) {
    final sheet = excel['Por Categoría'];
    int row = 0;

    for (var entry in ganadoresPorCategoria.entries) {
      final categoria = entry.key;
      final ganadores = entry.value;

      // Header de categoría
      var categoriaHeader = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      );
      categoriaHeader.value = TextCellValue('CATEGORÍA: $categoria');
      categoriaHeader.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
        fontColorHex: ExcelColor.white,
        bold: true,
        fontSize: 12,
      );
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
      );
      row += 1;

      // Headers
      _agregarFilaHeader(sheet, row++, [
        'Posición',
        'Código',
        'Proyecto',
        'Promedio',
        'Sala',
        'Evento',
        'Fecha',
      ]);

      // Datos de ganadores
      for (var ganador in ganadores) {
        final posicion = ganador['posicion'] ?? 0;
        final winnerDate = ganador['winnerDate']?.toDate();

        // Determinar color según posición
        String colorHex = '#FFFFFF';
        if (posicion == 1) {
          colorHex = '#FFD700'; // Oro
        } else if (posicion == 2) {
          colorHex = '#C0C0C0'; // Plata
        } else if (posicion == 3) {
          colorHex = '#CD7F32'; // Bronce
        }

        final datos = [
          '$posicion° Lugar',
          ganador['codigo'] ?? 'Sin código',
          ganador['projectName'] ?? 'Sin nombre',
          (ganador['promedioFinal'] ?? 0.0).toStringAsFixed(2),
          ganador['sala'] ?? 'Sin sala',
          ganador['eventName'] ?? 'Sin evento',
          winnerDate != null
              ? DateFormat('dd/MM/yyyy').format(winnerDate)
              : '-',
        ];

        for (int i = 0; i < datos.length; i++) {
          var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row),
          );
          cell.value = TextCellValue(datos[i]);

          // Colorear fila según posición
          if (posicion <= 3) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString(colorHex),
              fontColorHex: posicion == 1
                  ? ExcelColor.fromHexString('#1E3A5F')
                  : ExcelColor.black,
              bold: posicion == 1,
            );
          }
        }
        row++;
      }

      // Integrantes de cada proyecto
      _agregarFilaHeader(sheet, row++, ['', 'Integrantes del Proyecto']);

      for (var ganador in ganadores) {
        final posicion = ganador['posicion'] ?? 0;
        final integrantes = _parseIntegrantes(ganador['integrantes']);

        var proyectoCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        );
        proyectoCell.value = TextCellValue('$posicion°');
        proyectoCell.cellStyle = CellStyle(bold: true);

        var integrantesText = integrantes.join(', ');
        var integrantesCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
        );
        integrantesCell.value = TextCellValue(integrantesText);

        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
          CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
        );

        row++;
      }

      row += 2; // Espacio entre categorías
    }

    // Ajustar anchos
    sheet.setColumnWidth(0, 15);
    sheet.setColumnWidth(1, 15);
    sheet.setColumnWidth(2, 45);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 15);
    sheet.setColumnWidth(5, 30);
    sheet.setColumnWidth(6, 15);
  }

  void _crearHojaDetallada(
    Excel excel,
    Map<String, List<Map<String, dynamic>>> ganadoresPorCategoria,
  ) {
    final sheet = excel['Detalle Completo'];

    int row = 0;

    // Headers
    final headers = [
      'Posición',
      'Categoría',
      'Código',
      'Título del Proyecto',
      'Integrantes',
      'Promedio Final',
      'Sala',
      'Evento',
      'Facultad',
      'Carrera',
      'Fecha Designación',
    ];

    _agregarFilaHeader(sheet, row++, headers);

    // Recopilar todos los ganadores
    for (var entry in ganadoresPorCategoria.entries) {
      final categoria = entry.key;

      for (var ganador in entry.value) {
        final posicion = ganador['posicion'] ?? 0;
        final integrantes = _parseIntegrantes(ganador['integrantes']);
        final winnerDate = ganador['winnerDate']?.toDate();

        final datos = [
          '$posicion° Lugar',
          categoria,
          ganador['codigo'] ?? 'Sin código',
          ganador['projectName'] ?? 'Sin nombre',
          integrantes.join(', '),
          (ganador['promedioFinal'] ?? 0.0).toStringAsFixed(2),
          ganador['sala'] ?? 'Sin sala',
          ganador['eventName'] ?? 'Sin evento',
          ganador['eventFacultad'] ?? 'Sin facultad',
          ganador['eventCarrera'] ?? 'Sin carrera',
          winnerDate != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(winnerDate)
              : '-',
        ];

        for (int i = 0; i < datos.length; i++) {
          var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row),
          );
          cell.value = TextCellValue(datos[i]);

          // Colorear columna de promedio
          if (i == 5) {
            final promedio = ganador['promedioFinal'] ?? 0.0;
            if (promedio >= 18) {
              cell.cellStyle = CellStyle(
                backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
                fontColorHex: ExcelColor.fromHexString('#2E7D32'),
                bold: true,
              );
            } else if (promedio >= 15) {
              cell.cellStyle = CellStyle(
                backgroundColorHex: ExcelColor.fromHexString('#FFF3E0'),
                fontColorHex: ExcelColor.fromHexString('#E65100'),
              );
            }
          }

          // Colorear columna de posición
          if (i == 0) {
            String colorHex = '#FFFFFF';
            if (posicion == 1) {
              colorHex = '#FFD700';
            } else if (posicion == 2) {
              colorHex = '#C0C0C0';
            } else if (posicion == 3) {
              colorHex = '#CD7F32';
            }

            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString(colorHex),
              fontColorHex: posicion == 1
                  ? ExcelColor.fromHexString('#1E3A5F')
                  : ExcelColor.black,
              bold: true,
            );
          }
        }
        row++;
      }
    }

    // Ajustar anchos
    sheet.setColumnWidth(0, 15);
    sheet.setColumnWidth(1, 25);
    sheet.setColumnWidth(2, 15);
    sheet.setColumnWidth(3, 45);
    sheet.setColumnWidth(4, 50);
    sheet.setColumnWidth(5, 15);
    sheet.setColumnWidth(6, 15);
    sheet.setColumnWidth(7, 30);
    sheet.setColumnWidth(8, 35);
    sheet.setColumnWidth(9, 35);
    sheet.setColumnWidth(10, 18);
  }

  void _crearHojaEstadisticas(
    Excel excel,
    Map<String, List<Map<String, dynamic>>> ganadoresPorCategoria,
  ) {
    final sheet = excel['Estadísticas'];
    int row = 0;

    // Título
    var titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('ESTADÍSTICAS DETALLADAS');
    titleCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.white,
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
    );
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('E1'));
    row += 2;

    // Estadísticas por categoría
    var catHeader = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    catHeader.value = TextCellValue('ANÁLISIS POR CATEGORÍA');
    catHeader.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.white,
      bold: true,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
    );
    row += 1;

    // Headers
    _agregarFilaHeader(sheet, row++, [
      'Categoría',
      'Total Ganadores',
      'Promedio Notas',
      'Nota Máxima',
      'Nota Mínima',
    ]);

    // Calcular estadísticas por categoría
    for (var entry in ganadoresPorCategoria.entries) {
      final categoria = entry.key;
      final ganadores = entry.value;

      final notas = ganadores
          .map((g) => (g['promedioFinal'] ?? 0.0) as double)
          .toList();

      final promedio =
          notas.fold<double>(0, (sum, nota) => sum + nota) / notas.length;
      final notaMaxima = notas.reduce((a, b) => a > b ? a : b);
      final notaMinima = notas.reduce((a, b) => a < b ? a : b);

      _agregarFilaDatos(sheet, row++, [
        categoria,
        ganadores.length.toString(),
        promedio.toStringAsFixed(2),
        notaMaxima.toStringAsFixed(2),
        notaMinima.toStringAsFixed(2),
      ]);
    }

    row += 2;

    // Distribución de notas
    var notasHeader = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    notasHeader.value = TextCellValue('DISTRIBUCIÓN DE NOTAS');
    notasHeader.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.white,
      bold: true,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
    );
    row += 1;

    final todasLasNotas = ganadoresPorCategoria.values
        .expand((lista) => lista)
        .map((g) => (g['promedioFinal'] ?? 0.0) as double)
        .toList();

    final excelentes = todasLasNotas.where((n) => n >= 18).length;
    final buenas = todasLasNotas.where((n) => n >= 15 && n < 18).length;
    final regulares = todasLasNotas.where((n) => n >= 11 && n < 15).length;
    final bajas = todasLasNotas.where((n) => n < 11).length;

    _agregarFilaHeader(sheet, row++, ['Rango', 'Cantidad', 'Porcentaje']);

    final total = todasLasNotas.length;
    _agregarFilaDatos(sheet, row++, [
      '18 - 20 (Excelente)',
      excelentes.toString(),
      '${((excelentes / total) * 100).toStringAsFixed(1)}%',
    ]);
    _agregarFilaDatos(sheet, row++, [
      '15 - 17 (Bueno)',
      buenas.toString(),
      '${((buenas / total) * 100).toStringAsFixed(1)}%',
    ]);
    _agregarFilaDatos(sheet, row++, [
      '11 - 14 (Regular)',
      regulares.toString(),
      '${((regulares / total) * 100).toStringAsFixed(1)}%',
    ]);
    _agregarFilaDatos(sheet, row++, [
      '0 - 10 (Bajo)',
      bajas.toString(),
      '${((bajas / total) * 100).toStringAsFixed(1)}%',
    ]);

    row += 2;

    // Top 5 proyectos con mejor nota
    var topHeader = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    topHeader.value = TextCellValue('TOP 5 MEJORES PROYECTOS');
    topHeader.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFD700'),
      fontColorHex: ExcelColor.fromHexString('#1E3A5F'),
      bold: true,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
    );
    row += 1;

    _agregarFilaHeader(sheet, row++, [
      'Ranking',
      'Proyecto',
      'Categoría',
      'Promedio',
    ]);

    final todosGanadores = ganadoresPorCategoria.entries
        .expand(
          (entry) => entry.value.map((g) {
            g['_categoria'] = entry.key;
            return g;
          }),
        )
        .toList();

    todosGanadores.sort(
      (a, b) =>
          (b['promedioFinal'] ?? 0.0).compareTo(a['promedioFinal'] ?? 0.0),
    );

    for (int i = 0; i < todosGanadores.length && i < 5; i++) {
      final ganador = todosGanadores[i];
      _agregarFilaDatos(sheet, row++, [
        '${i + 1}°',
        ganador['projectName'] ?? 'Sin nombre',
        ganador['_categoria'] ?? 'Sin categoría',
        (ganador['promedioFinal'] ?? 0.0).toStringAsFixed(2),
      ]);
    }

    // Ajustar anchos
    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 15);
  }

  // Métodos auxiliares
  List<String> _parseIntegrantes(dynamic integrantesData) {
    if (integrantesData == null) return [];
    String integrantesStr = integrantesData.toString();
    if (integrantesStr.contains(',')) {
      return integrantesStr
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return integrantesStr.isNotEmpty ? [integrantesStr.trim()] : [];
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

  Future<void> _guardarArchivo(
    Excel excel,
    String facultad,
    String carrera,
  ) async {
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final nombreCarrera = carrera.replaceAll(' ', '_');
      final fileName = 'Reporte_Ganadores_${nombreCarrera}_$timestamp.xlsx';

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');

        if (!await directory.exists()) {
          directory = Directory('/storage/emulated/0/Documents');

          if (!await directory.exists()) {
            try {
              await directory.create(recursive: true);
            } catch (e) {
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

      final filePath = '${directory.path}/$fileName';
      final fileBytes = excel.save();

      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        print('✅ Reporte de ganadores guardado exitosamente en: $filePath');
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
