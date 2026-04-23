import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AsistenciasExcel {
  /// Genera y descarga un reporte de asistencias en formato Excel
  static Future<void> generarReporteExcel({
    required List<Map<String, dynamic>> estudiantes,
    required Map<String, List<Map<String, dynamic>>> asistenciasPorEstudiante,
    required String facultad,
    required String carrera,
    String? cicloFiltro,
    String? grupoFiltro,
    String? terminoBusqueda,
  }) async {
    final excel = Excel.createExcel();

    _crearHojaCompleta(
      excel,
      estudiantes,
      asistenciasPorEstudiante,
      facultad,
      carrera,
      cicloFiltro,
      grupoFiltro,
      terminoBusqueda,
    );

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    await _guardarArchivo(excel, facultad, carrera, cicloFiltro, grupoFiltro);
  }

  // ── Método principal (orquestador) ────────────────────────────────────────

  static void _crearHojaCompleta(
    Excel excel,
    List<Map<String, dynamic>> estudiantes,
    Map<String, List<Map<String, dynamic>>> asistenciasPorEstudiante,
    String facultad,
    String carrera,
    String? cicloFiltro,
    String? grupoFiltro,
    String? terminoBusqueda,
  ) {
    final sheet = excel['Reporte de Asistencias'];

    _escribirEncabezado(sheet, facultad, carrera);
    final headerRow = _escribirFiltros(sheet, cicloFiltro, grupoFiltro, terminoBusqueda);
    _escribirColumnas(sheet, headerRow);

    int currentRow = headerRow + 1;
    int contador = 1;

    for (var estudiante in estudiantes) {
      final asistencias = asistenciasPorEstudiante[estudiante['id']] ?? [];
      currentRow = _escribirFilaEstudiante(
        sheet, estudiante, asistencias, currentRow, contador,
      );
      contador++;
    }

    _escribirResumen(sheet, currentRow + 1, estudiantes, asistenciasPorEstudiante);
    _ajustarColumnas(sheet);
  }

  // ── Encabezado principal ──────────────────────────────────────────────────

  static void _escribirEncabezado(Sheet sheet, String facultad, String carrera) {
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('L1'));
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue(
      'REPORTE DE ASISTENCIAS - $facultad - $carrera',
    );
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#1976D2'),
      fontColorHex: ExcelColor.white,
    );

    final fechaCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2),
    );
    fechaCell.value = TextCellValue(
      'Fecha de generación: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
    );
    fechaCell.cellStyle = CellStyle(fontSize: 11, italic: true);
  }

  // ── Fila de filtros ───────────────────────────────────────────────────────

  /// Escribe los filtros aplicados y retorna el índice de la fila de encabezados.
  static int _escribirFiltros(
    Sheet sheet,
    String? cicloFiltro,
    String? grupoFiltro,
    String? terminoBusqueda,
  ) {
    final hayFiltros = cicloFiltro != null ||
        grupoFiltro != null ||
        (terminoBusqueda != null && terminoBusqueda.isNotEmpty);

    if (!hayFiltros) return 3;

    final filtros = [
      if (cicloFiltro != null) 'Ciclo $cicloFiltro',
      if (grupoFiltro != null) 'Grupo $grupoFiltro',
      if (terminoBusqueda != null && terminoBusqueda.isNotEmpty)
        'Búsqueda: "$terminoBusqueda"',
    ];

    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3),
    );
    cell.value = TextCellValue('FILTROS APLICADOS: ${filtros.join(' | ')}');
    cell.cellStyle = CellStyle(
      fontSize: 11,
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#D32F2F'),
    );

    return 4;
  }

  // ── Encabezados de columna ────────────────────────────────────────────────

  static const _headers = [
    'N°',
    'Estudiante',
    'DNI',
    'Código Univ.',
    'Ciclo',
    'Grupo',
    'Evento',
    'Categoría',
    'Código Proyecto',
    'Título de Investigación',
    'Fecha Asistencia',
    'Total Asistencias',
  ];

  static void _escribirColumnas(Sheet sheet, int headerRow) {
    for (var i = 0; i < _headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRow),
      );
      cell.value = TextCellValue(_headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#2196F3'),
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }
  }

  // ── Filas de datos ────────────────────────────────────────────────────────

  /// Escribe todas las filas de un estudiante y retorna la siguiente fila libre.
  static int _escribirFilaEstudiante(
    Sheet sheet,
    Map<String, dynamic> estudiante,
    List<Map<String, dynamic>> asistencias,
    int currentRow,
    int contador,
  ) {
    if (asistencias.isEmpty) {
      _escribirSinAsistencias(sheet, estudiante, currentRow, contador);
      return currentRow + 1;
    }

    for (var i = 0; i < asistencias.length; i++) {
      _escribirAsistencia(
        sheet,
        estudiante,
        asistencias[i],
        asistencias.length,
        currentRow,
        contador,
        esPrimeraFila: i == 0,
      );
      currentRow++;
    }
    return currentRow;
  }

  static void _escribirSinAsistencias(
    Sheet sheet,
    Map<String, dynamic> estudiante,
    int row,
    int contador,
  ) {
    _aplicarDatosBasicos(sheet, estudiante, row, contador);

    final msgCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
    );
    msgCell.value = TextCellValue('Sin asistencias registradas');
    msgCell.cellStyle = CellStyle(
      italic: true,
      fontColorHex: ExcelColor.fromHexString('#757575'),
    );

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row),
    );

    final bgGris = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'),
    );
    for (var col = 0; col < _headers.length; col++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
          .cellStyle = bgGris;
    }
  }

  static void _escribirAsistencia(
    Sheet sheet,
    Map<String, dynamic> estudiante,
    Map<String, dynamic> asistencia,
    int totalAsistencias,
    int row,
    int contador, {
    required bool esPrimeraFila,
  }) {
    final bgAzul = ExcelColor.fromHexString('#E3F2FD');

    if (esPrimeraFila) {
      _aplicarDatosBasicos(sheet, estudiante, row, contador);
    } else {
      for (var col = 0; col <= 5; col++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
            .cellStyle = CellStyle(backgroundColorHex: bgAzul);
      }
    }

    _escribirCamposAsistencia(sheet, asistencia, row);

    final totalCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row),
    );
    if (esPrimeraFila) {
      totalCell.value = IntCellValue(totalAsistencias);
      totalCell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: bgAzul,
        horizontalAlign: HorizontalAlign.Center,
      );
    } else {
      totalCell.cellStyle = CellStyle(backgroundColorHex: bgAzul);
    }
  }

  /// Escribe los campos específicos de cada registro de asistencia (cols 6–10).
  static void _escribirCamposAsistencia(
    Sheet sheet,
    Map<String, dynamic> asistencia,
    int row,
  ) {
    final timestamp = (asistencia['timestamp'] as Timestamp?)?.toDate();

    _setCell(sheet, 6, row, asistencia['eventName'] ?? 'Sin nombre');
    _setCell(
      sheet, 7, row,
      asistencia['categoria'] ?? asistencia['tipoInvestigacion'] ?? 'Sin categoría',
    );
    _setCell(sheet, 8, row, asistencia['codigoProyecto']?.toString() ?? '-');

    final tituloCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row),
    );
    tituloCell.value = TextCellValue(
      asistencia['tituloProyecto']?.toString() ?? '-',
    );
    tituloCell.cellStyle = CellStyle(textWrapping: TextWrapping.WrapText);

    _setCell(
      sheet, 10, row,
      timestamp != null
          ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp)
          : '-',
    );
  }

  /// Escribe N°, nombre, DNI, código universitario, ciclo y grupo con fondo azul claro.
  static void _aplicarDatosBasicos(
    Sheet sheet,
    Map<String, dynamic> estudiante,
    int row,
    int contador,
  ) {
    final bgAzul = ExcelColor.fromHexString('#E3F2FD');
    final datos = <dynamic>[
      contador,
      estudiante['name'] ?? 'Sin nombre',
      estudiante['dni']?.toString() ?? '-',
      estudiante['codigoUniversitario']?.toString() ?? '-',
      estudiante['ciclo']?.toString() ?? '-',
      estudiante['grupo']?.toString() ?? '-',
    ];

    for (var col = 0; col < datos.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      );
      final val = datos[col];
      cell.value = val is int ? IntCellValue(val) : TextCellValue(val as String);
      cell.cellStyle = CellStyle(
        backgroundColorHex: bgAzul,
        bold: col == 1,
        horizontalAlign:
            col >= 4 ? HorizontalAlign.Center : HorizontalAlign.Left,
      );
    }
  }

  // ── Fila de resumen ───────────────────────────────────────────────────────

  static void _escribirResumen(
    Sheet sheet,
    int row,
    List<Map<String, dynamic>> estudiantes,
    Map<String, List<Map<String, dynamic>>> asistenciasPorEstudiante,
  ) {
    var totalAsistencias = 0;
    var estudiantesConAsistencias = 0;
    for (var est in estudiantes) {
      final lista = asistenciasPorEstudiante[est['id']] ?? [];
      totalAsistencias += lista.length;
      if (lista.isNotEmpty) estudiantesConAsistencias++;
    }

    _fusionarYEscribir(
      sheet, row, 0, 1, 'RESUMEN:',
      CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#FFC107'),
        horizontalAlign: HorizontalAlign.Center,
        fontSize: 12,
      ),
    );

    final bgAmarillo = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
      bold: true,
    );

    _fusionarYEscribir(
      sheet, row, 2, 4,
      'Total Estudiantes: ${estudiantes.length}',
      bgAmarillo,
    );
    _fusionarYEscribir(
      sheet, row, 5, 7,
      'Con asistencias: $estudiantesConAsistencias',
      bgAmarillo,
    );
    _fusionarYEscribir(
      sheet, row, 8, 11,
      'Total Asistencias: $totalAsistencias',
      CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      ),
    );
  }

  // ── Ajuste de columnas ────────────────────────────────────────────────────

  static void _ajustarColumnas(Sheet sheet) {
    const anchos = <double>[
      8,  // N°
      30, // Estudiante
      12, // DNI
      15, // Código Univ.
      8,  // Ciclo
      8,  // Grupo
      40, // Evento
      20, // Categoría
      18, // Código Proyecto
      50, // Título de Investigación
      18, // Fecha Asistencia
      18, // Total Asistencias
    ];
    for (var i = 0; i < anchos.length; i++) {
      sheet.setColumnWidth(i, anchos[i]);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static void _setCell(Sheet sheet, int col, int row, String value) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        .value = TextCellValue(value);
  }

  static void _fusionarYEscribir(
    Sheet sheet,
    int row,
    int colStart,
    int colEnd,
    String texto,
    CellStyle style,
  ) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: colStart, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: colEnd, rowIndex: row),
    );
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: colStart, rowIndex: row),
    );
    cell.value = TextCellValue(texto);
    cell.cellStyle = style;
  }

  // ── Guardado en disco ─────────────────────────────────────────────────────

  static Future<void> _guardarArchivo(
    Excel excel,
    String facultad,
    String carrera,
    String? cicloFiltro,
    String? grupoFiltro,
  ) async {
    try {
      if (Platform.isAndroid) {
        await _solicitarPermisosAndroid();
      }

      final filePath = await _construirRutaArchivo(
        carrera, cicloFiltro, grupoFiltro,
      );
      final fileBytes = excel.save();

      if (fileBytes == null) {
        throw Exception('Error al generar el archivo Excel');
      }

      await File(filePath).writeAsBytes(fileBytes);
      print('✅ Archivo guardado exitosamente en: $filePath');
    } catch (e) {
      print('❌ Error al guardar archivo: $e');
      rethrow;
    }
  }

  static Future<void> _solicitarPermisosAndroid() async {
    var storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) return;

    storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) return;

    var manageStatus = await Permission.manageExternalStorage.status;
    if (!manageStatus.isGranted) {
      manageStatus = await Permission.manageExternalStorage.request();
    }

    if (!manageStatus.isGranted) {
      if (manageStatus.isPermanentlyDenied) await openAppSettings();
      throw Exception(
        'Se requieren permisos de almacenamiento para guardar el archivo Excel.',
      );
    }
  }

  static Future<String> _construirRutaArchivo(
    String carrera,
    String? cicloFiltro,
    String? grupoFiltro,
  ) async {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final nombreCarrera = carrera.replaceAll(' ', '_');

    var sufijo = '';
    if (cicloFiltro != null) sufijo += '_C$cicloFiltro';
    if (grupoFiltro != null) sufijo += '_G$grupoFiltro';

    final fileName = 'Asistencias_$nombreCarrera${sufijo}_$timestamp.xlsx';
    final directory = await _obtenerDirectorio();

    return '${directory.path}/$fileName';
  }

  static Future<Directory> _obtenerDirectorio() async {
    if (Platform.isIOS) {
      return getApplicationDocumentsDirectory();
    }

    // Android: preferir Downloads
    final downloads = Directory('/storage/emulated/0/Download');
    if (await downloads.exists()) return downloads;

    final documents = Directory('/storage/emulated/0/Documents');
    if (await documents.exists()) return documents;

    try {
      await documents.create(recursive: true);
      return documents;
    } catch (e) {
      throw Exception('No se pudo crear el directorio para guardar el archivo');
    }
  }
}