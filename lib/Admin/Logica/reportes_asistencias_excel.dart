import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReportesAsistenciasExcelService {
  Future<bool> generarReporteAsistencias({
    required List<Map<String, dynamic>> estudiantes,
    required String eventoNombre,
    required String facultad,
    String? carrera,
  }) async {
    try {
      print('📊 Iniciando generación de reporte de asistencias Excel...');

      final excel = Excel.createExcel();

      // Crear hojas
      _crearHojaResumen(excel, estudiantes, eventoNombre, facultad, carrera);
      _crearHojaDetallada(excel, estudiantes);
      _crearHojaPorEstudiante(excel, estudiantes);
      _crearHojaEstadisticas(excel, estudiantes);

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
    List<Map<String, dynamic>> estudiantes,
    String eventoNombre,
    String facultad,
    String? carrera,
  ) {
    final sheet = excel['Resumen'];

    int row = 0;

    // Título principal
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('D1'));
    var titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('REPORTE DE ASISTENCIAS');
    titleCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#4A90E2'),
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
    final totalEstudiantes = estudiantes.length;
    final totalAsistencias = estudiantes.fold<int>(
      0,
      (sum, e) => sum + (e['totalScans'] as int),
    );
    final promedioAsistencias = totalEstudiantes > 0
        ? totalAsistencias / totalEstudiantes
        : 0;

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
      'Total de estudiantes:',
      totalEstudiantes.toString(),
    );
    _agregarFilaSimple(
      sheet,
      row++,
      'Total de asistencias:',
      totalAsistencias.toString(),
    );
    _agregarFilaSimple(
      sheet,
      row++,
      'Promedio por estudiante:',
      promedioAsistencias.toStringAsFixed(2),
    );
    row += 1;

    // Distribución de asistencias
    var distHeader = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    distHeader.value = TextCellValue('DISTRIBUCIÓN DE ASISTENCIAS');
    distHeader.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.white,
      bold: true,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
    );
    row += 1;

    // Contar estudiantes por rango de asistencias
    final con1a3 = estudiantes
        .where((e) => e['totalScans'] >= 1 && e['totalScans'] <= 3)
        .length;
    final con4a6 = estudiantes
        .where((e) => e['totalScans'] >= 4 && e['totalScans'] <= 6)
        .length;
    final con7a9 = estudiantes
        .where((e) => e['totalScans'] >= 7 && e['totalScans'] <= 9)
        .length;
    final con10oMas = estudiantes.where((e) => e['totalScans'] >= 10).length;

    _agregarFilaSimple(sheet, row++, '1-3 asistencias:', con1a3.toString());
    _agregarFilaSimple(sheet, row++, '4-6 asistencias:', con4a6.toString());
    _agregarFilaSimple(sheet, row++, '7-9 asistencias:', con7a9.toString());
    _agregarFilaSimple(
      sheet,
      row++,
      '10 o más asistencias:',
      con10oMas.toString(),
    );
    row += 1;

    // Top 10 estudiantes con más asistencias
    var topHeader = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    topHeader.value = TextCellValue('TOP 10 ESTUDIANTES');
    topHeader.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.white,
      bold: true,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
    );
    row += 1;

    // Headers
    _agregarFilaHeader(sheet, row++, ['Nombre', 'Código', 'Total Asistencias']);

    // Ordenar y tomar top 10
    final estudiantesOrdenados = List<Map<String, dynamic>>.from(estudiantes);
    estudiantesOrdenados.sort(
      (a, b) => (b['totalScans'] as int).compareTo(a['totalScans'] as int),
    );

    for (int i = 0; i < estudiantesOrdenados.length && i < 10; i++) {
      final est = estudiantesOrdenados[i];
      _agregarFilaDatos(sheet, row++, [
        est['nombre'],
        est['codigo'],
        est['totalScans'].toString(),
      ]);
    }

    // Ajustar anchos de columna
    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 15);
  }

  void _crearHojaDetallada(
    Excel excel,
    List<Map<String, dynamic>> estudiantes,
  ) {
    final sheet = excel['Detalle Completo'];

    int row = 0;

    // Headers
    final headers = [
      'Nombre',
      'Usuario',
      'DNI',
      'Código',
      'Facultad',
      'Carrera',
      'Total Asistencias',
      'Última Asistencia',
    ];

    _agregarFilaHeader(sheet, row++, headers);

    // Datos
    for (var estudiante in estudiantes) {
      final lastScan = (estudiante['lastScan'] as Timestamp?)?.toDate();

      final datos = [
        estudiante['nombre'],
        '@${estudiante['username']}',
        estudiante['dni'],
        estudiante['codigo'],
        estudiante['facultad'],
        estudiante['carrera'],
        estudiante['totalScans'].toString(),
        lastScan != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(lastScan)
            : '-',
      ];

      for (int i = 0; i < datos.length; i++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row),
        );
        cell.value = TextCellValue(datos[i]);

        // Colorear columna de total asistencias
        if (i == 6) {
          final total = estudiante['totalScans'] as int;
          if (total >= 10) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
              fontColorHex: ExcelColor.fromHexString('#2E7D32'),
              bold: true,
            );
          } else if (total >= 7) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#FFF3E0'),
              fontColorHex: ExcelColor.fromHexString('#E65100'),
            );
          } else if (total >= 4) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
              fontColorHex: ExcelColor.fromHexString('#1565C0'),
            );
          }
        }
      }
      row++;
    }

    // Ajustar anchos
    sheet.setColumnWidth(0, 30); // Nombre
    sheet.setColumnWidth(1, 15); // Usuario
    sheet.setColumnWidth(2, 12); // DNI
    sheet.setColumnWidth(3, 15); // Código
    sheet.setColumnWidth(4, 35); // Facultad
    sheet.setColumnWidth(5, 35); // Carrera
    sheet.setColumnWidth(6, 18); // Total
    sheet.setColumnWidth(7, 18); // Última
  }

  void _crearHojaPorEstudiante(
    Excel excel,
    List<Map<String, dynamic>> estudiantes,
  ) {
    final sheet = excel['Por Estudiante'];
    int row = 0;

    for (var estudiante in estudiantes) {
      // Información del estudiante
      var estudianteHeader = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      );
      estudianteHeader.value = TextCellValue(
        'ESTUDIANTE: ${estudiante['nombre']}',
      );
      estudianteHeader.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#4A90E2'),
        fontColorHex: ExcelColor.white,
        bold: true,
      );
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row),
      );
      row++;

      _agregarFilaSimple(sheet, row++, 'Código:', estudiante['codigo']);
      _agregarFilaSimple(sheet, row++, 'DNI:', estudiante['dni']);
      _agregarFilaSimple(
        sheet,
        row++,
        'Usuario:',
        '@${estudiante['username']}',
      );
      _agregarFilaSimple(sheet, row++, 'Facultad:', estudiante['facultad']);
      _agregarFilaSimple(sheet, row++, 'Carrera:', estudiante['carrera']);
      _agregarFilaSimple(
        sheet,
        row++,
        'Total de asistencias:',
        estudiante['totalScans'].toString(),
      );
      row++;

      // Headers de asistencias
      _agregarFilaHeader(sheet, row++, [
        'Código Proyecto',
        'Título',
        'Categoría',
        'Grupo',
        'Fecha y Hora',
      ]);

      // Scans del estudiante
      final scans = estudiante['scans'] as List<dynamic>;
      for (var scan in scans) {
        final timestamp = (scan['timestamp'] as Timestamp?)?.toDate();

        _agregarFilaDatos(sheet, row++, [
          scan['codigoProyecto'] ?? 'Sin código',
          scan['tituloProyecto'] ?? 'Sin título',
          scan['categoria'] ?? 'Sin categoría',
          scan['grupo'] ?? '-',
          timestamp != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp)
              : '-',
        ]);
      }

      row += 2; // Espacio entre estudiantes
    }

    // Ajustar anchos
    sheet.setColumnWidth(0, 15); // Código Proyecto
    sheet.setColumnWidth(1, 40); // Título
    sheet.setColumnWidth(2, 20); // Categoría
    sheet.setColumnWidth(3, 12); // Grupo
    sheet.setColumnWidth(4, 18); // Fecha
  }

  void _crearHojaEstadisticas(
    Excel excel,
    List<Map<String, dynamic>> estudiantes,
  ) {
    final sheet = excel['Estadísticas'];
    int row = 0;

    // Título
    var titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('ESTADÍSTICAS POR CATEGORÍA');
    titleCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.white,
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
    );
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('D1'));
    row += 2;

    // Agrupar por categoría
    final categoriasMap = <String, List<Map<String, dynamic>>>{};

    for (var estudiante in estudiantes) {
      final scans = estudiante['scans'] as List<dynamic>;
      for (var scan in scans) {
        final categoria = scan['categoria'] ?? 'Sin categoría';
        if (!categoriasMap.containsKey(categoria)) {
          categoriasMap[categoria] = [];
        }
        categoriasMap[categoria]!.add(scan);
      }
    }

    // Headers
    _agregarFilaHeader(sheet, row++, [
      'Categoría',
      'Total Asistencias',
      'Proyectos Únicos',
    ]);

    // Datos por categoría
    final categorias = categoriasMap.keys.toList()..sort();

    for (var categoria in categorias) {
      final scans = categoriasMap[categoria]!;
      final proyectosUnicos = scans
          .map((s) => s['codigoProyecto'])
          .toSet()
          .length;

      _agregarFilaDatos(sheet, row++, [
        categoria,
        scans.length.toString(),
        proyectosUnicos.toString(),
      ]);
    }

    row += 2;

    // Estadísticas por grupo (si existen)
    var grupoHeader = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    grupoHeader.value = TextCellValue('ESTADÍSTICAS POR GRUPO');
    grupoHeader.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.white,
      bold: true,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
    );
    row += 1;

    // Agrupar por grupo
    final gruposMap = <String, int>{};

    for (var estudiante in estudiantes) {
      final scans = estudiante['scans'] as List<dynamic>;
      for (var scan in scans) {
        final grupo = scan['grupo'];
        if (grupo != null && grupo.toString().isNotEmpty) {
          gruposMap[grupo] = (gruposMap[grupo] ?? 0) + 1;
        }
      }
    }

    if (gruposMap.isNotEmpty) {
      _agregarFilaHeader(sheet, row++, ['Grupo', 'Total Asistencias']);

      final grupos = gruposMap.keys.toList()..sort();
      for (var grupo in grupos) {
        _agregarFilaDatos(sheet, row++, [grupo, gruposMap[grupo].toString()]);
      }
    } else {
      var noGrupoCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      );
      noGrupoCell.value = TextCellValue('No hay datos de grupos registrados');
      row++;
    }

    // Ajustar anchos
    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(2, 20);
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

  Future<void> _guardarArchivo(
    Excel excel,
    String eventoNombre,
    String facultad,
    String? carrera,
  ) async {
    try {
      // Generar nombre de archivo
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final nombreEvento = eventoNombre.replaceAll(' ', '_');

      // Agregar carrera al nombre si existe
      String sufijo = '';
      if (carrera != null && carrera != 'General') {
        sufijo = '_${carrera.replaceAll(' ', '_')}';
      }

      final fileName =
          'Reporte_Asistencias_${nombreEvento}${sufijo}_$timestamp.xlsx';

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
