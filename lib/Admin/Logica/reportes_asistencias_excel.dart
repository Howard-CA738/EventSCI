import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReportesAsistenciasExcelService {
  // Umbral de tiempo en minutos para considerar asistencias sospechosas
  static const int _umbralMinutos = 5;
  // Número mínimo de grupos sospechosos para incluir en reporte de fraude
  static const int _minimoGruposSospechosos = 3;

  Future<bool> generarReporteAsistencias({
    required List<Map<String, dynamic>> estudiantes,
    required String eventoNombre,
    required String facultad,
    String? carrera,
  }) async {
    try {
      print('📊 Iniciando generación de reporte de asistencias Excel...');

      final excel = Excel.createExcel();

      // Analizar estudiantes con asistencias sospechosas
      final estudiantesConAnalisis = _analizarAsistenciasSospechosas(
        estudiantes,
      );

      // Crear hojas
      _crearHojaResumen(
        excel,
        estudiantesConAnalisis,
        eventoNombre,
        facultad,
        carrera,
      );
      _crearHojaDetallada(excel, estudiantesConAnalisis);
      _crearHojaPorEstudiante(excel, estudiantesConAnalisis);
      _crearHojaEstadisticas(excel, estudiantesConAnalisis);

      // ✅ NUEVA HOJA: Reporte de asistencias sospechosas
      _crearHojaAsistenciasSospechosas(excel, estudiantesConAnalisis);

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

  // ✅ NUEVA FUNCIÓN: Analizar asistencias sospechosas (CORREGIDA)
  List<Map<String, dynamic>> _analizarAsistenciasSospechosas(
    List<Map<String, dynamic>> estudiantes,
  ) {
    print('🔍 Analizando asistencias sospechosas...');

    for (var estudiante in estudiantes) {
      final scans = estudiante['scans'] as List<dynamic>;

      if (scans.isEmpty) continue;

      // Ordenar scans por timestamp
      scans.sort((a, b) {
        final timestampA = (a['timestamp'] as Timestamp?)?.toDate();
        final timestampB = (b['timestamp'] as Timestamp?)?.toDate();
        if (timestampA == null || timestampB == null) return 0;
        return timestampA.compareTo(timestampB);
      });

      // Inicializar todos como no sospechosos
      for (var scan in scans) {
        scan['esSospechoso'] = false;
      }

      // Analizar grupos de asistencias cercanas
      List<List<int>> gruposSospechosos = [];

      for (int i = 0; i < scans.length; i++) {
        // Saltar si ya fue marcado como parte de un grupo
        if (scans[i]['esSospechoso'] == true) continue;

        final timestampActual = (scans[i]['timestamp'] as Timestamp?)?.toDate();
        if (timestampActual == null) continue;

        // Buscar todos los scans cercanos a este
        List<int> grupoActual = [i];

        for (int j = i + 1; j < scans.length; j++) {
          final timestampSiguiente = (scans[j]['timestamp'] as Timestamp?)
              ?.toDate();
          if (timestampSiguiente == null) continue;

          final diferencia = timestampSiguiente
              .difference(timestampActual)
              .inMinutes
              .abs();

          // Si está dentro del umbral, agregarlo al grupo
          if (diferencia <= _umbralMinutos) {
            grupoActual.add(j);
          } else {
            // Ya no hay más scans cercanos
            break;
          }
        }

        // Si encontramos un grupo (2 o más asistencias cercanas)
        if (grupoActual.length >= 2) {
          gruposSospechosos.add(List.from(grupoActual));

          // Marcar todos los scans del grupo como sospechosos
          for (int index in grupoActual) {
            scans[index]['esSospechoso'] = true;
          }

          print(
            '   📍 Grupo detectado: ${grupoActual.length} scans entre ${DateFormat('HH:mm').format((scans[grupoActual.first]['timestamp'] as Timestamp).toDate())} - ${DateFormat('HH:mm').format((scans[grupoActual.last]['timestamp'] as Timestamp).toDate())}',
          );
        }
      }

      // Guardar información de análisis
      estudiante['gruposSospechosos'] = gruposSospechosos;
      estudiante['totalGruposSospechosos'] = gruposSospechosos.length;
      estudiante['totalAsistenciasSospechosas'] = scans
          .where((s) => s['esSospechoso'] == true)
          .length;
      estudiante['tieneFraude'] =
          gruposSospechosos.length >= _minimoGruposSospechosos;

      if (gruposSospechosos.isNotEmpty) {
        print(
          '⚠️ ${estudiante['nombre']}: ${gruposSospechosos.length} grupos sospechosos (${estudiante['totalAsistenciasSospechosas']} asistencias marcadas)',
        );
      }
    }

    return estudiantes;
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

    // ✅ NUEVA ESTADÍSTICA: Estudiantes con fraude
    final estudiantesConFraude = estudiantes
        .where((e) => e['tieneFraude'] == true)
        .length;

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

    // ✅ AGREGAR ALERTA DE FRAUDE
    if (estudiantesConFraude > 0) {
      var fraudeCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      );
      fraudeCell.value = TextCellValue(
        '⚠️ Estudiantes con asistencias sospechosas:',
      );
      fraudeCell.cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#E74C3C'),
      );

      var fraudeValueCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
      );
      fraudeValueCell.value = TextCellValue(estudiantesConFraude.toString());
      fraudeValueCell.cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#E74C3C'),
      );
      row++;
    }

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

    // Top 10 estudiantes
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

    _agregarFilaHeader(sheet, row++, ['Nombre', 'Código', 'Total Asistencias']);

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

    final headers = [
      'Nombre',
      'Usuario',
      'DNI',
      'Código',
      'Facultad',
      'Carrera',
      'Ciclo',
      'Grupo',
      'Total Asistencias',
      'Última Asistencia',
      '⚠️ Sospechoso',
    ];

    _agregarFilaHeader(sheet, row++, headers);

    for (var estudiante in estudiantes) {
      final lastScan = (estudiante['lastScan'] as Timestamp?)?.toDate();
      final tieneFraude = estudiante['tieneFraude'] ?? false;

      final datos = [
        estudiante['nombre'],
        '@${estudiante['username']}',
        estudiante['dni'],
        estudiante['codigo'],
        estudiante['facultad'],
        estudiante['carrera'],
        estudiante['ciclo'] ?? 'N/A',
        estudiante['grupo'] ?? 'N/A',
        estudiante['totalScans'].toString(),
        lastScan != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(lastScan)
            : '-',
        tieneFraude ? 'SÍ' : '',
      ];

      for (int i = 0; i < datos.length; i++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row),
        );
        cell.value = TextCellValue(datos[i]);

        // Colorear si es sospechoso
        if (i == 10 && tieneFraude) {
          cell.cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#FADBD8'),
            fontColorHex: ExcelColor.fromHexString('#E74C3C'),
            bold: true,
          );
        }
        // Colorear columna de total asistencias
        else if (i == 8) {
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

    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 15);
    sheet.setColumnWidth(2, 12);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 35);
    sheet.setColumnWidth(5, 35);
    sheet.setColumnWidth(6, 10);
    sheet.setColumnWidth(7, 10);
    sheet.setColumnWidth(8, 18);
    sheet.setColumnWidth(9, 18);
    sheet.setColumnWidth(10, 15);
  }

  // ✅ MODIFICADA: Colorear asistencias sospechosas en rojo
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

      final tieneFraude = estudiante['tieneFraude'] ?? false;
      final headerText = tieneFraude
          ? '⚠️ ESTUDIANTE: ${estudiante['nombre']} (ASISTENCIAS SOSPECHOSAS)'
          : 'ESTUDIANTE: ${estudiante['nombre']}';

      estudianteHeader.value = TextCellValue(headerText);
      estudianteHeader.cellStyle = CellStyle(
        backgroundColorHex: tieneFraude
            ? ExcelColor.fromHexString('#E74C3C')
            : ExcelColor.fromHexString('#4A90E2'),
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
      _agregarFilaSimple(sheet, row++, 'Ciclo:', estudiante['ciclo'] ?? 'N/A');
      _agregarFilaSimple(sheet, row++, 'Grupo:', estudiante['grupo'] ?? 'N/A');
      _agregarFilaSimple(
        sheet,
        row++,
        'Total de asistencias:',
        estudiante['totalScans'].toString(),
      );

      if (tieneFraude) {
        _agregarFilaSimple(
          sheet,
          row++,
          '⚠️ Grupos sospechosos:',
          (estudiante['totalGruposSospechosos'] ?? 0).toString(),
        );
      }

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
        final esSospechoso = scan['esSospechoso'] ?? false;

        final datos = [
          scan['codigoProyecto'] ?? 'Sin código',
          scan['tituloProyecto'] ?? 'Sin título',
          scan['categoria'] ?? 'Sin categoría',
          scan['grupo'] ?? '-',
          timestamp != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp)
              : '-',
        ];

        // ✅ COLOREAR EN ROJO SI ES SOSPECHOSO
        for (int i = 0; i < datos.length; i++) {
          var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row),
          );
          cell.value = TextCellValue(datos[i]);

          if (esSospechoso) {
            cell.cellStyle = CellStyle(
              fontColorHex: ExcelColor.fromHexString('#E74C3C'),
              bold: true,
            );
          }
        }

        row++;
      }

      row += 2;
    }

    sheet.setColumnWidth(0, 15);
    sheet.setColumnWidth(1, 40);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 18);
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

    // Estadísticas por ciclo
    var cicloHeader = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    cicloHeader.value = TextCellValue('ESTADÍSTICAS POR CICLO');
    cicloHeader.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.white,
      bold: true,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
    );
    row += 1;

    final ciclosMap = <String, Map<String, int>>{};
    for (var estudiante in estudiantes) {
      final ciclo = estudiante['ciclo'] ?? 'N/A';
      if (!ciclosMap.containsKey(ciclo)) {
        ciclosMap[ciclo] = {'estudiantes': 0, 'asistencias': 0};
      }
      ciclosMap[ciclo]!['estudiantes'] = ciclosMap[ciclo]!['estudiantes']! + 1;
      ciclosMap[ciclo]!['asistencias'] =
          ciclosMap[ciclo]!['asistencias']! + (estudiante['totalScans'] as int);
    }

    if (ciclosMap.isNotEmpty) {
      _agregarFilaHeader(sheet, row++, [
        'Ciclo',
        'Total Estudiantes',
        'Total Asistencias',
        'Promedio',
      ]);

      final ciclos = ciclosMap.keys.toList()..sort();
      for (var ciclo in ciclos) {
        final estudiantesCount = ciclosMap[ciclo]!['estudiantes']!;
        final asistencias = ciclosMap[ciclo]!['asistencias']!;
        final promedio = estudiantesCount > 0
            ? (asistencias / estudiantesCount).toStringAsFixed(2)
            : '0.00';

        _agregarFilaDatos(sheet, row++, [
          ciclo,
          estudiantesCount.toString(),
          asistencias.toString(),
          promedio,
        ]);
      }
    }

    row += 2;

    // Estadísticas por grupo
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
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
    );
    row += 1;

    final gruposEstudiantesMap = <String, Map<String, int>>{};
    for (var estudiante in estudiantes) {
      final grupo = estudiante['grupo'] ?? 'N/A';
      if (!gruposEstudiantesMap.containsKey(grupo)) {
        gruposEstudiantesMap[grupo] = {'estudiantes': 0, 'asistencias': 0};
      }
      gruposEstudiantesMap[grupo]!['estudiantes'] =
          gruposEstudiantesMap[grupo]!['estudiantes']! + 1;
      gruposEstudiantesMap[grupo]!['asistencias'] =
          gruposEstudiantesMap[grupo]!['asistencias']! +
          (estudiante['totalScans'] as int);
    }

    if (gruposEstudiantesMap.isNotEmpty &&
        !(gruposEstudiantesMap.length == 1 &&
            gruposEstudiantesMap.containsKey('N/A'))) {
      _agregarFilaHeader(sheet, row++, [
        'Grupo',
        'Total Estudiantes',
        'Total Asistencias',
        'Promedio',
      ]);

      final grupos = gruposEstudiantesMap.keys.toList()..sort();
      for (var grupo in grupos) {
        final estudiantesCount = gruposEstudiantesMap[grupo]!['estudiantes']!;
        final asistencias = gruposEstudiantesMap[grupo]!['asistencias']!;
        final promedio = estudiantesCount > 0
            ? (asistencias / estudiantesCount).toStringAsFixed(2)
            : '0.00';

        _agregarFilaDatos(sheet, row++, [
          grupo,
          estudiantesCount.toString(),
          asistencias.toString(),
          promedio,
        ]);
      }
    }

    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 15);
  }

  // ✅ NUEVA HOJA: Reporte de Asistencias Sospechosas
  void _crearHojaAsistenciasSospechosas(
    Excel excel,
    List<Map<String, dynamic>> estudiantes,
  ) {
    final sheet = excel['🚨 Asistencias Sospechosas'];
    int row = 0;

    // Título
    var titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('🚨 REPORTE DE ASISTENCIAS SOSPECHOSAS');
    titleCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#E74C3C'),
      fontColorHex: ExcelColor.white,
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
    );
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('F1'));
    row += 2;

    // Descripción
    var descCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    descCell.value = TextCellValue(
      'Este reporte muestra estudiantes con $_minimoGruposSospechosos o más grupos de asistencias '
      'registradas en un margen de $_umbralMinutos minutos o menos.',
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row),
    );
    row += 2;

    // Filtrar estudiantes con fraude
    final estudiantesConFraude = estudiantes
        .where((e) => e['tieneFraude'] == true)
        .toList();

    if (estudiantesConFraude.isEmpty) {
      var noFraudeCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      );
      noFraudeCell.value = TextCellValue(
        '✅ No se detectaron estudiantes con asistencias sospechosas',
      );
      noFraudeCell.cellStyle = CellStyle(
        fontColorHex: ExcelColor.fromHexString('#27AE60'),
        bold: true,
        fontSize: 13,
      );
      sheet.setColumnWidth(0, 50);
      return;
    }

    // Headers
    _agregarFilaHeader(sheet, row++, [
      'Nombre',
      'Código',
      'DNI',
      'Total Asistencias',
      'Grupos Sospechosos',
      'Ver Detalle',
    ]);

    // Ordenar por más grupos sospechosos
    estudiantesConFraude.sort((a, b) {
      return (b['totalGruposSospechosos'] as int).compareTo(
        a['totalGruposSospechosos'] as int,
      );
    });

    // Datos de estudiantes con fraude
    for (var estudiante in estudiantesConFraude) {
      final datos = [
        estudiante['nombre'],
        estudiante['codigo'],
        estudiante['dni'],
        estudiante['totalScans'].toString(),
        (estudiante['totalGruposSospechosos'] ?? 0).toString(),
        '→ Ver en "Por Estudiante"',
      ];

      for (int i = 0; i < datos.length; i++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row),
        );
        cell.value = TextCellValue(datos[i]);

        // Colorear columna de grupos sospechosos
        if (i == 4) {
          cell.cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#FADBD8'),
            fontColorHex: ExcelColor.fromHexString('#E74C3C'),
            bold: true,
          );
        }
      }
      row++;
    }

    row += 2;

    // Sección de detalle por estudiante
    var detalleHeader = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    detalleHeader.value = TextCellValue('DETALLE DE ASISTENCIAS SOSPECHOSAS');
    detalleHeader.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#E74C3C'),
      fontColorHex: ExcelColor.white,
      bold: true,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row),
    );
    row += 2;

    // Detalle de cada estudiante
    for (var estudiante in estudiantesConFraude) {
      // Nombre del estudiante
      var estudianteCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      );
      estudianteCell.value = TextCellValue(
        '⚠️ ${estudiante['nombre']} (${estudiante['codigo']})',
      );
      estudianteCell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#F8D7DA'),
        fontColorHex: ExcelColor.fromHexString('#721C24'),
        bold: true,
      );
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row),
      );
      row++;

      // Información básica
      _agregarFilaSimple(
        sheet,
        row++,
        'Total de asistencias:',
        estudiante['totalScans'].toString(),
      );
      _agregarFilaSimple(
        sheet,
        row++,
        'Asistencias sospechosas:',
        '${estudiante['totalAsistenciasSospechosas'] ?? 0} de ${estudiante['totalScans']}',
      );
      _agregarFilaSimple(
        sheet,
        row++,
        'Grupos sospechosos detectados:',
        (estudiante['totalGruposSospechosos'] ?? 0).toString(),
      );
      row++;

      // Headers para asistencias
      _agregarFilaHeader(sheet, row++, [
        'Código Proyecto',
        'Título',
        'Categoría',
        'Fecha y Hora',
        'Diferencia',
        '⚠️',
      ]);

      // Mostrar asistencias con detección de grupos
      final scans = estudiante['scans'] as List<dynamic>;
      final gruposSospechosos =
          estudiante['gruposSospechosos'] as List<dynamic>;

      for (int i = 0; i < scans.length; i++) {
        final scan = scans[i];
        final timestamp = (scan['timestamp'] as Timestamp?)?.toDate();
        final esSospechoso = scan['esSospechoso'] ?? false;

        // Calcular diferencia con el anterior
        String diferencia = '-';
        if (i > 0 && timestamp != null) {
          final timestampAnterior = (scans[i - 1]['timestamp'] as Timestamp?)
              ?.toDate();
          if (timestampAnterior != null) {
            final diff = timestamp.difference(timestampAnterior).inMinutes;
            diferencia = '$diff min';
          }
        }

        final datos = [
          scan['codigoProyecto'] ?? 'Sin código',
          scan['tituloProyecto'] ?? 'Sin título',
          scan['categoria'] ?? 'Sin categoría',
          timestamp != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp)
              : '-',
          diferencia,
          esSospechoso ? '⚠️ SOSPECHOSO' : '',
        ];

        for (int j = 0; j < datos.length; j++) {
          var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row),
          );
          cell.value = TextCellValue(datos[j]);

          // Colorear si es sospechoso
          if (esSospechoso) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#FADBD8'),
              fontColorHex: ExcelColor.fromHexString('#E74C3C'),
              bold: j == 5, // Más bold en la columna de advertencia
            );
          }
        }
        row++;
      }

      row += 2;
    }

    // Ajustar anchos
    sheet.setColumnWidth(0, 18);
    sheet.setColumnWidth(1, 40);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 18);
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

  Future<void> _guardarArchivo(
    Excel excel,
    String eventoNombre,
    String facultad,
    String? carrera,
  ) async {
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final nombreEvento = eventoNombre.replaceAll(' ', '_');

      String sufijo = '';
      if (carrera != null && carrera != 'General') {
        sufijo = '_${carrera.replaceAll(' ', '_')}';
      }

      final fileName =
          'Reporte_Asistencias_${nombreEvento}${sufijo}_$timestamp.xlsx';

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
