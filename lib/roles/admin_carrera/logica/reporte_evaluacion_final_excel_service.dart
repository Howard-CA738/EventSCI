import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../datos/eval_final_config.dart';
import '../datos/nota_final_item.dart';

class ReporteEvaluacionFinalExcelService {
  static const _cobalt = '#1A3A6E';
  static const _teal = '#0F9D58';
  static const _tealLight = '#D7F5E6';
  static const _tealDark = '#065F46';
  static const _purple = '#7C3AED';
  static const _blue = '#2563EB';
  static const _orange = '#D97706';
  static const _gray900 = '#111827';
  static const _gray700 = '#374151';
  static const _gray100 = '#F3F4F6';
  static const _white = '#FFFFFF';
  static const _surface = '#F8FAFC';

  Future<String?> generarReporte({
    required List<NotaFinalItem> notas,
    required EvalFinalConfig config,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    required String carrera,
  }) async {
    try {
      final excel = Excel.createExcel();

      final seleccionados = notas.where((n) => n.seleccionado).toList()
        ..sort(_ordenCicloGrupo);
      final noSeleccionados = notas.where((n) => !n.seleccionado).toList()
        ..sort(_ordenCicloGrupo);

      _crearHoja(
        excel: excel,
        nombreHoja: 'SELECCIONADOS',
        notas: seleccionados,
        config: config,
        eventoNombre: eventoNombre,
        filialNombre: filialNombre,
        facultad: facultad,
        carrera: carrera,
        mostrarJurado: true,
        mostrarDocente: config.modalidad == 'mixta',
        bannerColor: _purple,
      );

      _crearHoja(
        excel: excel,
        nombreHoja: 'NO SELECCIONADOS',
        notas: noSeleccionados,
        config: config,
        eventoNombre: eventoNombre,
        filialNombre: filialNombre,
        facultad: facultad,
        carrera: carrera,
        mostrarJurado: false,
        mostrarDocente: config.incluirDocenteNoSel,
        bannerColor: _cobalt,
      );

      excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) return null;

      final dir = await getTemporaryDirectory();
      final fecha = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

      final base = eventoNombre.trim().isNotEmpty
          ? eventoNombre
          : (carrera.trim().isNotEmpty ? carrera : 'Reporte');

      final file =
          File('${dir.path}/EvalFinal_${_sanitizar(base)}_$fecha.xlsx');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e, st) {
      debugPrint('❌ Error generando Excel: $e\n$st');
      return null;
    }
  }

  void _crearHoja({
    required Excel excel,
    required String nombreHoja,
    required List<NotaFinalItem> notas,
    required EvalFinalConfig config,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    required String carrera,
    required bool mostrarJurado,
    required bool mostrarDocente,
    required String bannerColor,
  }) {
    final sheet = excel[nombreHoja];

    final sTitulo = CellStyle(
      bold: true, fontSize: 15,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(bannerColor),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sSubtitulo = CellStyle(
      bold: false, fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#93C5FD'),
      backgroundColorHex: ExcelColor.fromHexString(bannerColor),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sSep = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_teal),
    );
    final sMetaLbl = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray700),
      backgroundColorHex: ExcelColor.fromHexString(_gray100),
    );
    final sMetaVal = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray900),
    );

    int lastCol = 5;
    if (mostrarJurado) lastCol++;
    if (mostrarDocente) lastCol++;

    final colNotaFinal = lastCol;
    lastCol = colNotaFinal;

    _cel(sheet, 0, 0, '  $nombreHoja — EVALUACIÓN FINAL', sTitulo);
    _cel(sheet, 1, 0, '  ${eventoNombre.toUpperCase()}', sSubtitulo);
    for (int c = 0; c <= lastCol; c++) _cel(sheet, 2, c, '', sSep);
    _merge(sheet, 0, 0, 0, lastCol);
    _merge(sheet, 1, 0, 1, lastCol);
    sheet.setRowHeight(0, 36);
    sheet.setRowHeight(1, 24);
    sheet.setRowHeight(2, 4);

    final fechaGen = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final metas = [
      ['  FILIAL', filialNombre],
      ['  FACULTAD', facultad],
      ['  CARRERA', carrera],
      ['  GENERADO', fechaGen],
    ];
    for (int i = 0; i < metas.length; i++) {
      _cel(sheet, i + 3, 0, metas[i][0], sMetaLbl);
      _cel(sheet, i + 3, 1, '  ${metas[i][1]}', sMetaVal);
      _merge(sheet, i + 3, 1, i + 3, lastCol);
      sheet.setRowHeight(i + 3, 16);
    }
    sheet.setRowHeight(7, 8);

    final sEncBase = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_cobalt),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final sEncN1 = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_blue),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sEncN2 = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_purple),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sEncN3 = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_orange),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final sEncFinal = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_cobalt),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    const fEnc = 8;
    int col = 0;
    _cel(sheet, fEnc, col++, 'N°', sEncBase);
    _cel(sheet, fEnc, col++, 'NOMBRE COMPLETO', sEncBase);
    _cel(sheet, fEnc, col++, 'CÓDIGO UNIV.', sEncBase);
    _cel(sheet, fEnc, col++, 'CICLO', sEncBase);
    _cel(sheet, fEnc, col++, 'GRUPO', sEncBase);
    _cel(sheet, fEnc, col++, 'N1 – ASIST.', sEncN1);
    if (mostrarJurado) _cel(sheet, fEnc, col++, 'N2 – JURADO', sEncN2);
    if (mostrarDocente) _cel(sheet, fEnc, col++, 'N3 – DOCENTE', sEncN3);
    _cel(sheet, fEnc, col, 'NOTA FINAL', sEncFinal);
    sheet.setRowHeight(fEnc, 28);

    final sIzq =
        CellStyle(fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900));
    final sCen = CellStyle(
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString(_gray900),
        horizontalAlign: HorizontalAlign.Center);
    final sIzqP = CellStyle(
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString(_gray900),
        backgroundColorHex: ExcelColor.fromHexString(_surface));
    final sCenP = CellStyle(
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString(_gray900),
        backgroundColorHex: ExcelColor.fromHexString(_surface),
        horizontalAlign: HorizontalAlign.Center);

    final sNotaFinalN = CellStyle(
      bold: true, fontSize: 11,
      fontColorHex: ExcelColor.fromHexString(_cobalt),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sNotaFinalP = CellStyle(
      bold: true, fontSize: 11,
      fontColorHex: ExcelColor.fromHexString(_cobalt),
      backgroundColorHex: ExcelColor.fromHexString(_surface),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    for (int i = 0; i < notas.length; i++) {
      final n = notas[i];
      final fila = fEnc + 1 + i;
      final par = i % 2 == 0;
      final sI = par ? sIzqP : sIzq;
      final sC = par ? sCenP : sCen;
      final sNF = par ? sNotaFinalP : sNotaFinalN;

      int c2 = 0;
      _celNum(sheet, fila, c2++, i + 1, sC);
      _cel(sheet, fila, c2++, n.nombre, sI);
      _cel(sheet, fila, c2++, n.codigo, sC);
      _cel(sheet, fila, c2++, n.ciclo, sC);
      _cel(sheet, fila, c2++, n.grupo, sC);
      _celDec(sheet, fila, c2++, n.notaAsist, sC);
      if (mostrarJurado) _celDec(sheet, fila, c2++, n.notaJurado, sC);
      if (mostrarDocente) _celDec(sheet, fila, c2++, n.notaDocente, sC);
      _celDec(sheet, fila, c2, n.notaFinal, sNF);
      sheet.setRowHeight(fila, 18);
    }

    if (notas.isNotEmpty) {
      final fTot = fEnc + 1 + notas.length;
      final prom =
          notas.map((n) => n.notaFinal).reduce((a, b) => a + b) / notas.length;
      final maxN = notas.map((n) => n.notaFinal).reduce((a, b) => a > b ? a : b);
      final minN = notas.map((n) => n.notaFinal).reduce((a, b) => a < b ? a : b);
      final aprobados = notas.where((n) => n.notaFinal >= 11).length;

      final sStat = CellStyle(
        bold: true, fontSize: 9,
        backgroundColorHex: ExcelColor.fromHexString(_tealLight),
        fontColorHex: ExcelColor.fromHexString(_tealDark),
      );
      _cel(
          sheet,
          fTot,
          0,
          '  ${notas.length} estudiantes  —  Aprobados: $aprobados  '
          '|  Promedio: ${prom.toStringAsFixed(2)}  '
          '|  Máx: ${maxN.toStringAsFixed(2)}  '
          '|  Mín: ${minN.toStringAsFixed(2)}',
          sStat);
      _merge(sheet, fTot, 0, fTot, lastCol);
      sheet.setRowHeight(fTot, 20);
    }

    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 34);
    sheet.setColumnWidth(2, 16);
    sheet.setColumnWidth(3, 8);
    sheet.setColumnWidth(4, 10);
    int wCol = 5;
    sheet.setColumnWidth(wCol++, 14);
    if (mostrarJurado) sheet.setColumnWidth(wCol++, 14);
    if (mostrarDocente) sheet.setColumnWidth(wCol++, 14);
    sheet.setColumnWidth(wCol, 14);
  }

  int _ciclo(String c) {
    if (c.trim().isEmpty || c == 'N/A') return 999;
    final m = RegExp(r'\d+').firstMatch(c);
    return m != null ? int.parse(m.group(0)!) : 999;
  }

  int _grupo(String g) {
    final s = g.toLowerCase().trim();
    if (s.isEmpty || s == 'n/a') return 9999;
    if (s.contains('único') || s.contains('unico')) return 9998;
    final m = RegExp(r'\d+').firstMatch(g);
    return m != null ? int.parse(m.group(0)!) : 9999;
  }

  int _ordenCicloGrupo(NotaFinalItem a, NotaFinalItem b) {
    final ca = _ciclo(a.ciclo), cb = _ciclo(b.ciclo);
    if (ca != cb) return ca.compareTo(cb);
    final ga = _grupo(a.grupo), gb = _grupo(b.grupo);
    if (ga != gb) return ga.compareTo(gb);
    return a.nombre.compareTo(b.nombre);
  }

  void _cel(Sheet sheet, int row, int col, String value, CellStyle style) {
    final cell = sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(value);
    cell.cellStyle = style;
  }

  void _celNum(Sheet sheet, int row, int col, int value, CellStyle style) {
    final cell = sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = IntCellValue(value);
    cell.cellStyle = style;
  }

  void _celDec(Sheet sheet, int row, int col, double value, CellStyle style) {
    final cell = sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = DoubleCellValue(double.parse(value.toStringAsFixed(2)));
    cell.cellStyle = style;
  }

  void _merge(Sheet sheet, int r1, int c1, int r2, int c2) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: c1, rowIndex: r1),
      CellIndex.indexByColumnRow(columnIndex: c2, rowIndex: r2),
    );
  }

  String _sanitizar(String texto) {
    final s = texto
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(' ', '_');
    if (s.trim().isEmpty) return 'Reporte';
    return s.substring(0, s.length > 30 ? 30 : s.length);
  }
}
