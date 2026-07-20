import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'reporte_usuarios_service.dart';

class UsuariosExcelService {
  static const _navy = '#0F2044';
  static const _cobalt = '#1A3A6E';
  static const _purple = '#7C3AED';
  static const _purpleSoft = '#F5F3FF';
  static const _white = '#FFFFFF';
  static const _gray900 = '#111827';
  static const _gray700 = '#374151';
  static const _gray100 = '#F3F4F6';

  Future<String?> generarReporte({
    required List<FilialResumen> resumen,
  }) async {
    try {
      final excel = Excel.createExcel();
      _crearHojaResumen(excel, resumen);
      excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) return null;

      final dir = await getTemporaryDirectory();
      final fecha = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = File('${dir.path}/Reporte_eventos_$fecha.xlsx');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('❌ Error generando Excel de reporte: $e');
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // HOJA: RESUMEN por evento (Filial → Facultad → Carrera → Evento)
  // Columnas: FILIAL | FACULTAD | CARRERA | EVENTO | PERÍODO |
  //           MATRICULADOS | INSCRITOS | ASISTIERON | % ASIST/INSCR
  // ───────────────────────────────────────────────────────────────────────
  void _crearHojaResumen(Excel excel, List<FilialResumen> resumen) {
    final sheet = excel['Resumen'];

    final sTitulo = CellStyle(
      bold: true, fontSize: 15,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sSubtitulo = CellStyle(
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#A78BFA'),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sSep =
        CellStyle(backgroundColorHex: ExcelColor.fromHexString(_purple));
    final sMetaLabel = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray700),
      backgroundColorHex: ExcelColor.fromHexString(_gray100),
    );
    final sMetaValue = CellStyle(
      fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900),
    );
    final sEnc = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_cobalt),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final sFilialBand = CellStyle(
      bold: true, fontSize: 10,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      verticalAlign: VerticalAlign.Center,
    );
    final sDato = CellStyle(
      fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900),
      verticalAlign: VerticalAlign.Center,
    );
    final sDatoP = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_purpleSoft),
      fontColorHex: ExcelColor.fromHexString(_gray900),
      verticalAlign: VerticalAlign.Center,
    );
    final sNum = CellStyle(
      fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sNumP = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_purpleSoft),
      fontColorHex: ExcelColor.fromHexString(_gray900),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sSubtotal = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_cobalt),
      fontColorHex: ExcelColor.fromHexString(_white),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sTotGen = CellStyle(
      bold: true, fontSize: 11,
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      fontColorHex: ExcelColor.fromHexString(_white),
      horizontalAlign: HorizontalAlign.Center,
    );

    const lastCol = 8; // 0..8 → 9 columnas

    _cel(sheet, 0, 0, '  REPORTE DE EVENTOS POR CARRERA', sTitulo);
    _cel(sheet, 1, 0,
        '  Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
        sSubtitulo);
    for (int c = 0; c <= lastCol; c++) {
      _cel(sheet, 2, c, '', sSep);
    }
    sheet.setRowHeight(2, 4);

    // Totales generales
    int totalEventos = 0;
    int totalPagaron = 0;
    int totalAsistieron = 0;
    int totalMatriculados = 0;
    for (final f in resumen) {
      totalEventos += f.totalEventos;
      totalMatriculados += f.totalMatriculados;
      for (final fa in f.facultades) {
        for (final c in fa.carreras) {
          totalPagaron += c.totalPagaron;
          totalAsistieron += c.totalAsistieron;
        }
      }
    }

    final metas = [
      ['  TOTAL DE EVENTOS', '$totalEventos'],
      ['  MATRICULADOS (suma por carrera)', '$totalMatriculados'],
      ['  INSCRITOS (pagaron)', '$totalPagaron'],
      ['  ASISTIERON', '$totalAsistieron'],
    ];
    for (int i = 0; i < metas.length; i++) {
      _cel(sheet, i + 3, 0, metas[i][0], sMetaLabel);
      _cel(sheet, i + 3, 1, '  ${metas[i][1]}', sMetaValue);
      _merge(sheet, i + 3, 1, i + 3, lastCol);
      sheet.setRowHeight(i + 3, 16);
    }
    sheet.setRowHeight(7, 8);

    const fEnc = 8;
    final headers = [
      'FILIAL', 'FACULTAD', 'CARRERA', 'EVENTO', 'PERÍODO',
      'MATRI-\nCULADOS', 'INSCRITOS\n(pagaron)', 'ASIS-\nTIERON',
      '% ASIST/\nINSCR.',
    ];
    for (int c = 0; c < headers.length; c++) {
      _cel(sheet, fEnc, c, headers[c], sEnc);
    }
    sheet.setRowHeight(fEnc, 30);

    int fila = fEnc + 1;
    int idx = 0;
    for (final f in resumen) {
      // Banda de filial
      _cel(sheet, fila, 0, '  ${f.filialNombre}', sFilialBand);
      _merge(sheet, fila, 0, fila, lastCol);
      sheet.setRowHeight(fila, 18);
      fila++;

      int filialPago = 0;
      int filialAsis = 0;

      for (final fac in f.facultades) {
        for (final car in fac.carreras) {
          for (final ev in car.eventos) {
            final par = idx % 2 == 0;
            final sTxt = par ? sDatoP : sDato;
            final sN = par ? sNumP : sNum;

            _cel(sheet, fila, 0, f.filialNombre, sTxt);
            _cel(sheet, fila, 1, fac.nombre, sTxt);
            _cel(sheet, fila, 2, car.carrera, sTxt);
            _cel(sheet, fila, 3, ev.eventName, sTxt);
            _cel(sheet, fila, 4, ev.periodoNombre, sTxt);
            _celNum(sheet, fila, 5, ev.matriculados, sN);
            _celNum(sheet, fila, 6, ev.pagaron, sN);
            _celNum(sheet, fila, 7, ev.asistieron, sN);
            _cel(sheet, fila, 8,
                '${ev.pctAsistioVsPago.toStringAsFixed(0)}%', sN);

            sheet.setRowHeight(fila, 15);
            filialPago += ev.pagaron;
            filialAsis += ev.asistieron;
            fila++;
            idx++;
          }
        }
      }

      // Subtotal de la filial
      _cel(sheet, fila, 0, '  Subtotal ${f.filialNombre}', sSubtotal);
      _merge(sheet, fila, 0, fila, 5);
      _celNum(sheet, fila, 6, filialPago, sSubtotal);
      _celNum(sheet, fila, 7, filialAsis, sSubtotal);
      _cel(sheet, fila, 8,
          filialPago == 0
              ? '—'
              : '${(filialAsis / filialPago * 100).toStringAsFixed(0)}%',
          sSubtotal);
      sheet.setRowHeight(fila, 16);
      fila++;
    }

    // Total general
    _cel(sheet, fila, 0, '  TOTAL GENERAL', sTotGen);
    _merge(sheet, fila, 0, fila, 5);
    _celNum(sheet, fila, 6, totalPagaron, sTotGen);
    _celNum(sheet, fila, 7, totalAsistieron, sTotGen);
    _cel(sheet, fila, 8,
        totalPagaron == 0
            ? '—'
            : '${(totalAsistieron / totalPagaron * 100).toStringAsFixed(0)}%',
        sTotGen);
    sheet.setRowHeight(fila, 22);

    _merge(sheet, 0, 0, 0, lastCol);
    _merge(sheet, 1, 0, 1, lastCol);

    sheet.setColumnWidth(0, 16);
    sheet.setColumnWidth(1, 30);
    sheet.setColumnWidth(2, 30);
    sheet.setColumnWidth(3, 34);
    sheet.setColumnWidth(4, 16);
    sheet.setColumnWidth(5, 12);
    sheet.setColumnWidth(6, 12);
    sheet.setColumnWidth(7, 11);
    sheet.setColumnWidth(8, 11);
    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 20);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
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

  void _merge(Sheet sheet, int r1, int c1, int r2, int c2) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: c1, rowIndex: r1),
      CellIndex.indexByColumnRow(columnIndex: c2, rowIndex: r2),
    );
  }
}