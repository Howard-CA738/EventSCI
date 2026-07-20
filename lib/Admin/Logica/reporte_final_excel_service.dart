import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'reporte_final_service.dart';

class ReporteFinalExcelService {
  static const _navy = '#0F2044';
  static const _cobalt = '#1A3A6E';
  static const _white = '#FFFFFF';
  static const _gray900 = '#111827';
  static const _grayEmpty = '#F9FAFB';
  static const _rowAlt = '#F5F3FF';

  Future<String?> generarReporte({
    required List<EventoFinalRow> filas,
  }) async {
    try {
      final excel = Excel.createExcel();
      _crearHoja(excel, filas);
      excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) return null;

      final dir = await getTemporaryDirectory();
      final fecha = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = File('${dir.path}/Reporte_final_$fecha.xlsx');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('❌ Error generando Reporte Final: $e');
      return null;
    }
  }

  void _crearHoja(Excel excel, List<EventoFinalRow> filas) {
    final sheet = excel['Reporte Final'];

    // Estilos
    final sTitulo = CellStyle(
      bold: true, fontSize: 14,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sEnc = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_cobalt),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final sTxt = CellStyle(
      fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900),
      verticalAlign: VerticalAlign.Center,
    );
    final sTxtAlt = CellStyle(
      fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900),
      backgroundColorHex: ExcelColor.fromHexString(_rowAlt),
      verticalAlign: VerticalAlign.Center,
    );
    final sNum = CellStyle(
      fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sNumAlt = CellStyle(
      fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900),
      backgroundColorHex: ExcelColor.fromHexString(_rowAlt),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sVacio = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_grayEmpty),
    );
    final sTotal = CellStyle(
      bold: true, fontSize: 10,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Encabezados (orden EXACTO de tu plantilla + columna FILIAL agregada)
    final headers = <String>[
      'Nro',
      'FILIAL',
      'FACULTAD',
      'EP NOMBRE CORTO',
      'ESCUELA PROFESIONAL',
      'NOMBRE DEL EVENTO CIENTÍFICO\n(Jornada científica de estudiantes)',
      'FECHA EN LA QUE DESARROLLARÁ EL EVENTO CIENTÍFICO',
      'NOMBRE DEL PONENTE MAGISTRAL',
      'N° ESTUDIANTES MATRICULADOS',
      'ESTUDIANTES INSCRITOS PRONOSTICADOS EN EL EVENTO CIENTÍFICO',
      'PONENCIAS ORALES DE ESTUDIANTES',
      'PONENCIAS POSTER DE ESTUDIANTES',
      'N° DE DOCENTES QUE ARTICULAN LA INVEST. FORMATIVA',
      'N° DE DOCENTES JURADOS EVALUADORES',
      'NRO DE CATEGORÍAS QUE PREMIARÁ',
      'CANTIDAD DE PREMIOS PRONOSTICADOS',
      'META SUMISIÓN DE ARTÍCULOS A REVISTAS NIVEL SCIELO ó LATINDEX',
      'META SUMISIÓN DE ARTÍCULOS A REVISTAS SCOPUS O WOS',
      'N° DOCENTES RENACYT',
      'LINK DE ONEDRIVE (FOTOS DEL EVENTO)',
    ];
    final lastCol = headers.length - 1; // 19

    // Índices de columnas que SÍ se llenan
   // Índices de columnas que SÍ se llenan
const colNro = 0,
    colFilial = 1,
    colFacultad = 2,
    colEpCorto = 3,
    colEscuela = 4,
    colEvento = 5,
    colFecha = 6,
    colMatric = 8,
    colInscritos = 9,
    colOrales = 10,      // ← nuevo
    colPoster = 11,      // ← nuevo
    colJurados = 13;

// Columnas que quedan vacías
const vacias = {7, 12, 14, 15, 16, 17, 18, 19};  // ← se quitan 10 y 11

    // Título
    _cel(sheet, 0, 0, '  REPORTE FINAL DE EVENTOS CIENTÍFICOS', sTitulo);
    _merge(sheet, 0, 0, 0, lastCol);
    sheet.setRowHeight(0, 26);

    // Encabezados
    const fEnc = 1;
    for (int c = 0; c < headers.length; c++) {
      _cel(sheet, fEnc, c, headers[c], sEnc);
    }
    sheet.setRowHeight(fEnc, 56);

    // Filas de datos
    int fila = fEnc + 1;
    int totMatric = 0, totInscritos = 0, totJurados = 0;

    for (int i = 0; i < filas.length; i++) {
      final r = filas[i];
      final par = i % 2 == 0;
      final sT = par ? sTxtAlt : sTxt;
      final sN = par ? sNumAlt : sNum;

_celNum(sheet, fila, colNro, r.nro, sN);
_cel(sheet, fila, colFilial, r.filial, sT);
_cel(sheet, fila, colFacultad, r.facultadCorta, sT);
_cel(sheet, fila, colEpCorto, r.epNombreCorto, sT);
_cel(sheet, fila, colEscuela, r.escuelaProfesional, sT);
_cel(sheet, fila, colEvento, r.nombreEvento, sT);
_cel(sheet, fila, colFecha, r.fechaEvento, sN);
_celNum(sheet, fila, colMatric, r.matriculados, sN);
_celNum(sheet, fila, colInscritos, r.inscritos, sN);
_celNum(sheet, fila, colOrales, r.ponenciasOrales, sN);   // ← nuevo
_celNum(sheet, fila, colPoster, r.ponenciasPoster, sN);   // ← nuevo
_celNum(sheet, fila, colJurados, r.juradosEvaluadores, sN);

      // Pintar las columnas vacías
      for (final c in vacias) {
        _cel(sheet, fila, c, '', sVacio);
      }

      totMatric += r.matriculados;
      totInscritos += r.inscritos;
      totJurados += r.juradosEvaluadores;
      sheet.setRowHeight(fila, 16);
      fila++;
    }

    // Fila TOTALES
    _cel(sheet, fila, 0, '  TOTALES', sTotal);
    _merge(sheet, fila, 0, fila, colEscuela);
    for (int c = colEscuela + 1; c <= lastCol; c++) {
      if (c == colMatric) {
        _celNum(sheet, fila, c, totMatric, sTotal);
      } else if (c == colInscritos) {
        _celNum(sheet, fila, c, totInscritos, sTotal);
      } else if (c == colJurados) {
        _celNum(sheet, fila, c, totJurados, sTotal);
      } else {
        _cel(sheet, fila, c, '', sTotal);
      }
    }
    sheet.setRowHeight(fila, 20);

    // Anchos
    final anchos = <int, double>{
      0: 6, 1: 14, 2: 12, 3: 18, 4: 30, 5: 34, 6: 18, 7: 22, 8: 13, 9: 16,
      10: 14, 11: 14, 12: 18, 13: 16, 14: 14, 15: 14, 16: 22, 17: 22, 18: 14,
      19: 22,
    };
    anchos.forEach((c, w) => sheet.setColumnWidth(c, w));
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