import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class EvaluacionesCarreraExcelService {

  static const _navy        = '#0F2044';
  static const _cobalt      = '#1A3A6E';
  static const _purple      = '#7C3AED';
  static const _purpleSoft  = '#F5F3FF';
  static const _white       = '#FFFFFF';
  static const _gray900     = '#111827';
  static const _gray700     = '#374151';
  static const _gray100     = '#F3F4F6';

  Future<String?> generarReporteEvaluaciones({
    required List<Map<String, dynamic>> evaluaciones,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    String? carrera,
  }) async {
    try {
      final excel = Excel.createExcel();

      _crearHojaResumenProyectos(
        excel: excel,
        evaluaciones: evaluaciones,
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
      final nombreArchivo =
          'Evaluaciones_${_sanitizar(eventoNombre)}_$fecha.xlsx';
      final file = File('${dir.path}/$nombreArchivo');
      await file.writeAsBytes(bytes);

      return file.path;
    } catch (e) {
      debugPrint('❌ Error generando Excel de evaluaciones: $e');
      return null;
    }
  }

  void _crearHojaResumenProyectos({
    required Excel excel,
    required List<Map<String, dynamic>> evaluaciones,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    String? carrera,
  }) {
    final sheet = excel['Resumen por Proyecto'];

    final sTitulo = CellStyle(
      bold: true, fontSize: 15,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sSubtitulo = CellStyle(
      bold: false, fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#A78BFA'),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sSep = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_purple),
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
    final sEncDim = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_cobalt),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final sEncVal = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_purple),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final sDatoCen = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray900),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sDatoCenP = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_purpleSoft),
      fontColorHex: ExcelColor.fromHexString(_gray900),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sWrap = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray900),
      verticalAlign: VerticalAlign.Top,
      textWrapping: TextWrapping.WrapText,
    );
    final sWrapP = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_purpleSoft),
      fontColorHex: ExcelColor.fromHexString(_gray900),
      verticalAlign: VerticalAlign.Top,
      textWrapping: TextWrapping.WrapText,
    );

    final sCodCen = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray700),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Top,
      textWrapping: TextWrapping.WrapText,
    );
    final sCodCenP = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_purpleSoft),
      fontColorHex: ExcelColor.fromHexString(_gray700),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Top,
      textWrapping: TextWrapping.WrapText,
    );
    final sTotGen = CellStyle(
      bold: true, fontSize: 10,
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      fontColorHex: ExcelColor.fromHexString(_white),
      horizontalAlign: HorizontalAlign.Center,
    );

    _cel(sheet, 0, 0, '  REPORTE DE EVALUACIONES POR PROYECTO', sTitulo);
    _cel(sheet, 1, 0, '  ${eventoNombre.toUpperCase()}', sSubtitulo);
    const lastCol = 6;
    for (int c = 0; c <= lastCol; c++) _cel(sheet, 2, c, '', sSep);
    sheet.setRowHeight(2, 4);

    final fechaGen = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final evaluadas = evaluaciones.where((e) => e['evaluada'] == true).length;
    final metas = [
      ['  FILIAL', filialNombre],
      ['  FACULTAD', facultad],
      ['  CARRERA', carrera ?? 'Todas'],
      ['  TOTAL EVALUACIONES', '${evaluaciones.length}'],
      ['  EVALUACIONES COMPLETAS', '$evaluadas'],
      ['  GENERADO', fechaGen],
    ];
    for (int i = 0; i < metas.length; i++) {
      _cel(sheet, i + 3, 0, metas[i][0], sMetaLabel);
      _cel(sheet, i + 3, 1, '  ${metas[i][1]}', sMetaValue);
      _merge(sheet, i + 3, 1, i + 3, lastCol);
      sheet.setRowHeight(i + 3, 16);
    }
    sheet.setRowHeight(9, 8);

    final Map<String, List<Map<String, dynamic>>> porProyecto = {};
    for (final ev in evaluaciones) {
      final key = ev['proyectoId']?.toString() ?? 'sin_id';
      porProyecto.putIfAbsent(key, () => []).add(ev);
    }

    const fEnc = 10;
    _cel(sheet, fEnc, 0, 'N°', sEncDim);
    _cel(sheet, fEnc, 1, 'CÓDIGO', sEncDim);
    _cel(sheet, fEnc, 2, 'TÍTULO', sEncDim);
    _cel(sheet, fEnc, 3, 'ESTUDIANTE', sEncDim);
    _cel(sheet, fEnc, 4, 'CÓDIGO\nESTUDIANTE', sEncDim);
    _cel(sheet, fEnc, 5, 'JURADOS', sEncVal);
    _cel(sheet, fEnc, 6, 'NOTA\nFINAL', sEncDim);
    sheet.setRowHeight(fEnc, 32);

    int idx = 0;
    double sumaPromedios = 0;
    for (final entry in porProyecto.entries) {
      final evs = entry.value;
      final fila = fEnc + 1 + idx;
      final par = idx % 2 == 0;
      final sCen  = par ? sDatoCenP : sDatoCen;
      final sLeft = par ? sWrapP   : sWrap;
      final sCod  = par ? sCodCenP  : sCodCen;

      final codigo = evs.first['codigo']?.toString() ?? '—';
      final titulo = evs.first['titulo']?.toString() ?? 'Sin título';


      List<String> nombres = (evs.first['integrantesNombres']?.toString() ?? '')
          .split('\n').where((s) => s.trim().isNotEmpty).toList();
      List<String> codigos = (evs.first['integrantesCodigos']?.toString() ?? '')
          .split('\n').where((s) => s.trim().isNotEmpty).toList();


      if (codigos.isEmpty) {
        final crudo = evs.first['integrantes'];
        if (crudo is List) {
          codigos = crudo.map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty).toList();
        } else {
          codigos = (crudo?.toString() ?? '')
              .split(RegExp(r'[,\n]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }

      if (nombres.isEmpty) nombres = List<String>.from(codigos);

      final nombresTexto = nombres.isEmpty ? '—' : nombres.join('\n');
      final codigosTexto = codigos.isEmpty ? '—' : codigos.join('\n');

      final evaluadasList = evs.where((e) => e['evaluada'] == true).toList();
      final nombresJurados = evaluadasList
          .map((e) => e['juradoNombre']?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .join('\n');

      double promedio = 0;
      if (evaluadasList.isNotEmpty) {
        promedio = evaluadasList.fold<double>(
              0, (s, e) => s + ((e['notaTotal'] as num?)?.toDouble() ?? 0)) /
            evaluadasList.length;
      }
      sumaPromedios += promedio;

      _celNum(sheet, fila, 0, idx + 1, sCen);
      _cel(sheet, fila, 1, codigo, sCen);
      _cel(sheet, fila, 2, titulo, sLeft);
      _cel(sheet, fila, 3, nombresTexto, sLeft);
      _cel(sheet, fila, 4, codigosTexto, sCod);
      _cel(sheet, fila, 5, nombresJurados.isEmpty ? '—' : nombresJurados, sLeft);
      _celDec(sheet, fila, 6, promedio, sCen);


      final nomLineas = nombres.isEmpty ? 1 : nombres.length;
      final codLineas = codigos.isEmpty ? 1 : codigos.length;
      final jurLineas =
          nombresJurados.isEmpty ? 1 : nombresJurados.split('\n').length;
      int tituloLineas = (titulo.length / 30).ceil();
      if (tituloLineas < 1) tituloLineas = 1;
      if (tituloLineas > 6) tituloLineas = 6;

      int maxLineas = nomLineas;
      if (codLineas > maxLineas) maxLineas = codLineas;
      if (jurLineas > maxLineas) maxLineas = jurLineas;
      if (tituloLineas > maxLineas) maxLineas = tituloLineas;

      final altura = (maxLineas * 13.0 + 8).clamp(18.0, 260.0).toDouble();
      sheet.setRowHeight(fila, altura);
      idx++;
    }

    final fTot = fEnc + 1 + idx;
    _cel(sheet, fTot, 0,
        '  PROMEDIO GENERAL: ${porProyecto.isEmpty ? 0 : (sumaPromedios / porProyecto.length).toStringAsFixed(2)} pts',
        sTotGen);
    _merge(sheet, fTot, 0, fTot, lastCol);
    sheet.setRowHeight(fTot, 22);

    _merge(sheet, 0, 0, 0, lastCol);
    _merge(sheet, 1, 0, 1, lastCol);

    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 12);
    sheet.setColumnWidth(2, 32);
    sheet.setColumnWidth(3, 30);
    sheet.setColumnWidth(4, 16);
    sheet.setColumnWidth(5, 24);
    sheet.setColumnWidth(6, 11);
    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 22);
  }

  void _cel(Sheet sheet, int row, int col, String value, CellStyle style) {
    final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(value);
    cell.cellStyle = style;
  }

  void _celNum(Sheet sheet, int row, int col, int value, CellStyle style) {
    final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = IntCellValue(value);
    cell.cellStyle = style;
  }

  void _celDec(Sheet sheet, int row, int col, double value, CellStyle style) {
    final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(value.toStringAsFixed(2));
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
    return s.substring(0, s.length > 40 ? 40 : s.length);
  }
}