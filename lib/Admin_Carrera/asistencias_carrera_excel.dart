import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class AsistenciasCarreraExcelService {

  static const _navy       = '#0F2044';
  static const _blue       = '#2563EB';
  static const _blueSoft   = '#DBEAFE';
  static const _white      = '#FFFFFF';
  static const _gray900    = '#111827';
  static const _gray700    = '#374151';
  static const _gray100    = '#F3F4F6';
  static const _greenDark  = '#166534';
  static const _greenLight = '#DCFCE7';
  static const _yellowDark = '#854D0E';
  static const _yellowLight = '#FEF9C3';
  static const _redDark    = '#991B1B';
  static const _redLight   = '#FEE2E2';

  Future<String?> generarReporteAsistencias({
    required List<Map<String, dynamic>> estudiantes,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    String? carrera,
  }) async {
    try {
      final excel = Excel.createExcel();

      final Map<String, Map<String, dynamic>> vistos = {};

      for (final e in estudiantes) {
        final key = _idEstudiante(e);

        if (!vistos.containsKey(key)) {
          vistos[key] = Map<String, dynamic>.from(e);
          vistos[key]!['scans'] = List<Map<String, dynamic>>.from(
            (e['scans'] as List<dynamic>? ?? []).map((s) => Map<String, dynamic>.from(s as Map)),
          );
        } else {
          final scansPrevios = vistos[key]!['scans'] as List<Map<String, dynamic>>;
          final scansNuevos = (e['scans'] as List<dynamic>? ?? [])
              .map((s) => Map<String, dynamic>.from(s as Map))
              .toList();

          final idsExistentes = scansPrevios.map((s) => s['id']).toSet();
          for (final scan in scansNuevos) {
            if (!idsExistentes.contains(scan['id'])) {
              scansPrevios.add(scan);
            }
          }

          vistos[key]!['totalScans'] = scansPrevios.length;

          final lastA = vistos[key]!['lastScan'];
          final lastB = e['lastScan'];
          if (lastA == null) {
            vistos[key]!['lastScan'] = lastB;
          } else if (lastB != null && (lastB as dynamic).compareTo(lastA) > 0) {
            vistos[key]!['lastScan'] = lastB;
          }
        }
      }

      final estudiantesLimpios = vistos.values.toList()
        ..sort((a, b) {
          final ca = _parseCiclo(a['ciclo']);
          final cb = _parseCiclo(b['ciclo']);
          if (ca != cb) return ca.compareTo(cb);
          final ga = _parseGrupo(a['grupo']);
          final gb = _parseGrupo(b['grupo']);
          if (ga != gb) return ga.compareTo(gb);
          return ((a['nombre'] as String?) ?? '')
              .compareTo((b['nombre'] as String?) ?? '');
        });

      debugPrint('✅ Estudiantes únicos para Excel: ${estudiantesLimpios.length}');

      _crearHojaListaAsistencias(
        excel: excel,
        estudiantes: estudiantesLimpios,
        eventoNombre: eventoNombre,
        filialNombre: filialNombre,
        facultad: facultad,
        carrera: carrera,
      );

      excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) return null;

      final dir = await getTemporaryDirectory();
      final fecha = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final nombreArchivo = 'Asistencias_${_sanitizar(eventoNombre)}_$fecha.xlsx';
      final file = File('${dir.path}/$nombreArchivo');
      await file.writeAsBytes(bytes);

      return file.path;
    } catch (e) {
      debugPrint('❌ Error generando Excel: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOJA — Lista de Asistencias
  // ═══════════════════════════════════════════════════════════════════════════
  void _crearHojaListaAsistencias({
    required Excel excel,
    required List<Map<String, dynamic>> estudiantes,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    String? carrera,
  }) {
    final sheet = excel['Lista de Asistencias'];

    final sTitulo = CellStyle(
      bold: true, fontSize: 15,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sSubtitulo = CellStyle(
      bold: false, fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#93C5FD'),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sSeparador = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_blue),
    );
    final sMetaLabel = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray700),
      backgroundColorHex: ExcelColor.fromHexString(_gray100),
    );
    final sMetaValue = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray900),
    );

    final sEnc = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_blue),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final sEncAsistencias = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString('#059669'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final sIzq  = CellStyle(fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900));
    final sCen  = CellStyle(fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900), horizontalAlign: HorizontalAlign.Center);
    final sIzqP = CellStyle(fontSize: 9, backgroundColorHex: ExcelColor.fromHexString(_blueSoft), fontColorHex: ExcelColor.fromHexString(_gray900));
    final sCenP = CellStyle(fontSize: 9, backgroundColorHex: ExcelColor.fromHexString(_blueSoft), fontColorHex: ExcelColor.fromHexString(_gray900), horizontalAlign: HorizontalAlign.Center);

    final sBadgeAlto = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_greenLight),
      fontColorHex: ExcelColor.fromHexString(_greenDark),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sBadgeMedio = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_yellowLight),
      fontColorHex: ExcelColor.fromHexString(_yellowDark),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sBadgeBajo = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_redLight),
      fontColorHex: ExcelColor.fromHexString(_redDark),
      horizontalAlign: HorizontalAlign.Center,
    );

    // ── Banner ────────────────────────────────────────────────────────────────
    _cel(sheet, 0, 0, '  LISTA DE ASISTENCIAS', sTitulo);
    _cel(sheet, 1, 0, '  ${eventoNombre.toUpperCase()}', sSubtitulo);
    for (int c = 0; c <= 6; c++) _cel(sheet, 2, c, '', sSeparador);
    sheet.setRowHeight(2, 4);

    // ── Metadatos ─────────────────────────────────────────────────────────────
    final fechaGen = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final totalGlobal = estudiantes.fold<int>(
        0, (s, e) => s + ((e['totalScans'] as int?) ?? 0));
    final metas = [
      ['  FILIAL', filialNombre],
      ['  FACULTAD', facultad],
      ['  CARRERA', carrera ?? 'Todas'],
      ['  TOTAL ESTUDIANTES', '${estudiantes.length}'],
      ['  ASISTENCIAS REGISTRADAS', '$totalGlobal'],
      ['  GENERADO', fechaGen],
    ];
    for (int i = 0; i < metas.length; i++) {
      _cel(sheet, i + 3, 0, metas[i][0], sMetaLabel);
      _cel(sheet, i + 3, 1, '  ${metas[i][1]}', sMetaValue);
      _merge(sheet, i + 3, 1, i + 3, 6);
      sheet.setRowHeight(i + 3, 16);
    }
    sheet.setRowHeight(9, 8);

    // ── Encabezados tabla (fila 10) ───────────────────────────────────────────
    // Columnas: N° | NOMBRE | CÓDIGO | CICLO | GRUPO | N° ASISTENCIAS | ÚLTIMA ASISTENCIA
    const fEnc = 10;
    const encabezados = [
      'N°', 'NOMBRE COMPLETO', 'CÓDIGO',
      'CICLO', 'GRUPO', 'N° ASISTENCIAS', 'ÚLTIMA ASISTENCIA',
    ];
    for (int c = 0; c < encabezados.length; c++) {
      _cel(sheet, fEnc, c, encabezados[c], c == 5 ? sEncAsistencias : sEnc);
    }
    sheet.setRowHeight(fEnc, 28);

    final maxScans = estudiantes.isEmpty
        ? 1
        : estudiantes
            .map((e) => (e['totalScans'] as int?) ?? 0)
            .reduce((a, b) => a > b ? a : b)
            .clamp(1, 99999);

    // ── Filas de datos ────────────────────────────────────────────────────────
    for (int i = 0; i < estudiantes.length; i++) {
      final e = estudiantes[i];
      final fila = fEnc + 1 + i;
      final par = i % 2 == 0;

      final sI = par ? sIzqP : sIzq;
      final sC = par ? sCenP : sCen;

      String ultimaAsistencia = '—';
      final lastScan = e['lastScan'];
      if (lastScan != null) {
        try {
          final dt = lastScan.toDate() as DateTime;
          ultimaAsistencia = DateFormat('dd/MM/yyyy HH:mm').format(dt);
        } catch (_) {}
      }

      final totalScans = (e['totalScans'] as int?) ?? 0;
      final ratio = totalScans / maxScans;
      final sBadge = ratio >= 0.66
          ? sBadgeAlto
          : ratio >= 0.33
              ? sBadgeMedio
              : sBadgeBajo;

      _cel(sheet, fila, 0, '${i + 1}', sC);
      _cel(sheet, fila, 1, e['nombre'] ?? '', sI);
      _cel(sheet, fila, 2, e['codigo'] ?? '', sC);
      _cel(sheet, fila, 3, e['ciclo'] ?? 'N/A', sC);
      _cel(sheet, fila, 4, e['grupo'] ?? 'N/A', sC);
      _celNum(sheet, fila, 5, totalScans, sBadge);
      _cel(sheet, fila, 6, ultimaAsistencia, sC);
      sheet.setRowHeight(fila, 18);
    }

    // ── Merges banner ─────────────────────────────────────────────────────────
    _merge(sheet, 0, 0, 0, 6);
    _merge(sheet, 1, 0, 1, 6);

    // ── Anchos ────────────────────────────────────────────────────────────────
    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 34);
    sheet.setColumnWidth(2, 14);
    sheet.setColumnWidth(3, 8);
    sheet.setColumnWidth(4, 10);
    sheet.setColumnWidth(5, 15);
    sheet.setColumnWidth(6, 22);

    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 22);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helpers internos
  // ═══════════════════════════════════════════════════════════════════════════
  void _cel(Sheet sheet, int row, int col, String value, CellStyle style) {
    final cell =
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(value);
    cell.cellStyle = style;
  }

  void _celNum(Sheet sheet, int row, int col, int value, CellStyle style) {
    final cell =
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = IntCellValue(value);
    cell.cellStyle = style;
  }

  void _merge(Sheet sheet, int r1, int c1, int r2, int c2) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: c1, rowIndex: r1),
      CellIndex.indexByColumnRow(columnIndex: c2, rowIndex: r2),
    );
  }

  String _idEstudiante(Map<String, dynamic> e) {
    final codigo = (e['codigo'] as String?) ?? '';
    if (codigo.isNotEmpty) return codigo;
    final dni = (e['dni'] as String?) ?? '';
    if (dni.isNotEmpty) return dni;
    return (e['nombre'] as String?) ?? 'unknown';
  }

  int _parseCiclo(String? ciclo) {
    if (ciclo == null || ciclo.isEmpty || ciclo == 'N/A') return 999;
    try {
      final m = RegExp(r'\d+').firstMatch(ciclo);
      if (m != null) return int.parse(m.group(0)!);
    } catch (_) {}
    return 999;
  }

  int _parseGrupo(String? grupo) {
    if (grupo == null || grupo.isEmpty || grupo == 'N/A') return 9999;
    final g = grupo.toLowerCase();
    if (g.contains('único') || g.contains('unico')) return 9998;
    try {
      final m = RegExp(r'\d+').firstMatch(grupo);
      if (m != null) return int.parse(m.group(0)!);
    } catch (_) {}
    return 9999;
  }

  String _sanitizar(String texto) {
    final s =
        texto.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').replaceAll(' ', '_');
    return s.substring(0, s.length > 40 ? 40 : s.length);
  }
}