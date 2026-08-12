import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'reporte_certificados_service.dart';

class ReporteCertificadosExcelService {
  static const _navy = '#0F2044';
  static const _cobalt = '#1A3A6E';
  static const _white = '#FFFFFF';
  static const _gray900 = '#111827';
  static const _rowAlt = '#F5F3FF';

  Future<String?> generarReporte({
    required EscuelaItem escuela,
    required String eventoNombre,
    required int minimoSellos,
    required int metaSellos,
    required ReporteRoles roles,
  }) async {
    try {
      final excel = Excel.createExcel();

      _hojaAsistentes(
          excel, escuela, eventoNombre, minimoSellos, metaSellos,
          roles.asistentes.where((f) => f.sellos >= minimoSellos).toList());
      _hojaPonentes(excel, escuela, eventoNombre, roles.ponentes);
      _hojaJurados(excel, escuela, eventoNombre, roles.jurados);
      _hojaOrganizadores(excel, escuela, eventoNombre, roles.organizadores);

      excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) return null;

      final dir = await getTemporaryDirectory();
      final fecha = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = File('${dir.path}/Reporte_roles_$fecha.xlsx');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('❌ Error generando Excel de roles: $e');
      return null;
    }
  }


  CellStyle get _sTitulo => CellStyle(
        bold: true, fontSize: 14,
        fontColorHex: ExcelColor.fromHexString(_white),
        backgroundColorHex: ExcelColor.fromHexString(_navy),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
  CellStyle get _sMeta => CellStyle(
        fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900),
      );
  CellStyle get _sEnc => CellStyle(
        bold: true, fontSize: 10,
        fontColorHex: ExcelColor.fromHexString(_white),
        backgroundColorHex: ExcelColor.fromHexString(_cobalt),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
  CellStyle get _sTxt => CellStyle(
        fontSize: 10, fontColorHex: ExcelColor.fromHexString(_gray900),
        verticalAlign: VerticalAlign.Center,
      );
  CellStyle get _sTxtAlt => CellStyle(
        fontSize: 10, fontColorHex: ExcelColor.fromHexString(_gray900),
        backgroundColorHex: ExcelColor.fromHexString(_rowAlt),
        verticalAlign: VerticalAlign.Center,
      );
  CellStyle get _sNum => CellStyle(
        fontSize: 10, fontColorHex: ExcelColor.fromHexString(_gray900),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
  CellStyle get _sNumAlt => CellStyle(
        fontSize: 10, fontColorHex: ExcelColor.fromHexString(_gray900),
        backgroundColorHex: ExcelColor.fromHexString(_rowAlt),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
  CellStyle get _sTotal => CellStyle(
        bold: true, fontSize: 10,
        fontColorHex: ExcelColor.fromHexString(_white),
        backgroundColorHex: ExcelColor.fromHexString(_navy),
        horizontalAlign: HorizontalAlign.Center,
      );


  void _hojaAsistentes(
    Excel excel,
    EscuelaItem escuela,
    String eventoNombre,
    int minimoSellos,
    int metaSellos,
    List<CertificadoRow> filas,
  ) {
    final sheet = excel['Asistentes'];
    const lastCol = 6;

    _cel(sheet, 0, 0, '  ASISTENTES QUE RECIBIRÁN CERTIFICADO', _sTitulo);
    _merge(sheet, 0, 0, 0, lastCol);
    sheet.setRowHeight(0, 24);

    _metaFilas(sheet, escuela, eventoNombre, lastCol,
        extra: '  Filtro: mínimo $minimoSellos sello(s)'
            '${metaSellos > 0 ? '  (meta: $metaSellos)' : ''}'
            '   ·   Total: ${filas.length}');

    const fEnc = 7;
    final headers = ['Nro', 'NOMBRE', 'DNI', 'CÓDIGO', 'CICLO', 'GRUPO', 'SELLOS'];
    for (int c = 0; c < headers.length; c++) {
      _cel(sheet, fEnc, c, headers[c], _sEnc);
    }
    sheet.setRowHeight(fEnc, 20);

    int fila = fEnc + 1;
    for (int i = 0; i < filas.length; i++) {
      final r = filas[i];
      final par = i % 2 == 0;
      final sT = par ? _sTxtAlt : _sTxt;
      final sN = par ? _sNumAlt : _sNum;
      _celNum(sheet, fila, 0, i + 1, sN);
      _cel(sheet, fila, 1, r.nombre, sT);
      _cel(sheet, fila, 2, r.dni, sN);
      _cel(sheet, fila, 3, r.codigo, sN);
      _cel(sheet, fila, 4, r.ciclo.isEmpty ? '—' : r.ciclo, sN);
      _cel(sheet, fila, 5, r.grupo.isEmpty ? '—' : r.grupo, sN);
      _celNum(sheet, fila, 6, r.sellos, sN);
      sheet.setRowHeight(fila, 15);
      fila++;
    }

    _cel(sheet, fila, 0, '  TOTAL', _sTotal);
    _merge(sheet, fila, 0, fila, 5);
    _celNum(sheet, fila, 6, filas.length, _sTotal);
    sheet.setRowHeight(fila, 18);

    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 40);
    sheet.setColumnWidth(2, 14);
    sheet.setColumnWidth(3, 16);
    sheet.setColumnWidth(4, 8);
    sheet.setColumnWidth(5, 8);
    sheet.setColumnWidth(6, 10);
  }


  void _hojaPonentes(
    Excel excel,
    EscuelaItem escuela,
    String eventoNombre,
    List<PonenteRow> filas,
  ) {
    final sheet = excel['Ponentes'];
    const lastCol = 6;

    _cel(sheet, 0, 0, '  PONENTES (INTEGRANTES DE PROYECTOS)', _sTitulo);
    _merge(sheet, 0, 0, 0, lastCol);
    sheet.setRowHeight(0, 24);

    _metaFilas(sheet, escuela, eventoNombre, lastCol,
        extra: '  Total: ${filas.length} ponente(s)');

    const fEnc = 7;
    final headers = ['Nro', 'NOMBRE', 'DNI', 'CÓDIGO', 'CICLO', 'GRUPO', 'EVALUADO'];
    for (int c = 0; c < headers.length; c++) {
      _cel(sheet, fEnc, c, headers[c], _sEnc);
    }
    sheet.setRowHeight(fEnc, 20);

    int fila = fEnc + 1;
    for (int i = 0; i < filas.length; i++) {
      final r = filas[i];
      final par = i % 2 == 0;
      final sT = par ? _sTxtAlt : _sTxt;
      final sN = par ? _sNumAlt : _sNum;
      _celNum(sheet, fila, 0, i + 1, sN);
      _cel(sheet, fila, 1, r.nombre, sT);
      _cel(sheet, fila, 2, r.dni, sN);
      _cel(sheet, fila, 3, r.codigo, sN);
      _cel(sheet, fila, 4, r.ciclo.isEmpty ? '—' : r.ciclo, sN);
      _cel(sheet, fila, 5, r.grupo.isEmpty ? '—' : r.grupo, sN);
      _cel(sheet, fila, 6, r.evaluado ? 'Sí' : 'No', sN);
      sheet.setRowHeight(fila, 15);
      fila++;
    }

    _cel(sheet, fila, 0, '  TOTAL', _sTotal);
    _merge(sheet, fila, 0, fila, 5);
    _celNum(sheet, fila, 6, filas.length, _sTotal);
    sheet.setRowHeight(fila, 18);

    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 40);
    sheet.setColumnWidth(2, 14);
    sheet.setColumnWidth(3, 16);
    sheet.setColumnWidth(4, 8);
    sheet.setColumnWidth(5, 8);
    sheet.setColumnWidth(6, 12);
  }


  void _hojaJurados(
    Excel excel,
    EscuelaItem escuela,
    String eventoNombre,
    List<JuradoRow> filas,
  ) {
    final sheet = excel['Jurados'];
    const lastCol = 2;

    _cel(sheet, 0, 0, '  JURADOS EVALUADORES', _sTitulo);
    _merge(sheet, 0, 0, 0, lastCol);
    sheet.setRowHeight(0, 24);

    _metaFilas(sheet, escuela, eventoNombre, lastCol,
        extra: '  Total: ${filas.length} jurado(s)');

    const fEnc = 7;
    final headers = ['Nro', 'NOMBRE COMPLETO', 'PROYECTOS EVALUADOS'];
    for (int c = 0; c < headers.length; c++) {
      _cel(sheet, fEnc, c, headers[c], _sEnc);
    }
    sheet.setRowHeight(fEnc, 20);

    int fila = fEnc + 1;
    for (int i = 0; i < filas.length; i++) {
      final r = filas[i];
      final par = i % 2 == 0;
      final sT = par ? _sTxtAlt : _sTxt;
      final sN = par ? _sNumAlt : _sNum;
      _celNum(sheet, fila, 0, i + 1, sN);
      _cel(sheet, fila, 1, r.nombre, sT);
      _celNum(sheet, fila, 2, r.proyectosEvaluados, sN);
      sheet.setRowHeight(fila, 15);
      fila++;
    }

    _cel(sheet, fila, 0, '  TOTAL', _sTotal);
    _merge(sheet, fila, 0, fila, 1);
    _celNum(sheet, fila, 2, filas.length, _sTotal);
    sheet.setRowHeight(fila, 18);

    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 45);
    sheet.setColumnWidth(2, 22);
  }


  void _hojaOrganizadores(
    Excel excel,
    EscuelaItem escuela,
    String eventoNombre,
    List<OrganizadorRow> filas,
  ) {
    final sheet = excel['Organizadores'];
    const lastCol = 5;

    _cel(sheet, 0, 0, '  ORGANIZADORES (ASISTENTES QR)', _sTitulo);
    _merge(sheet, 0, 0, 0, lastCol);
    sheet.setRowHeight(0, 24);

    _metaFilas(sheet, escuela, eventoNombre, lastCol,
        extra: '  Total: ${filas.length} organizador(es)');

    const fEnc = 7;
    final headers = ['Nro', 'NOMBRE', 'DNI', 'CÓDIGO', 'CICLO', 'GRUPO'];
    for (int c = 0; c < headers.length; c++) {
      _cel(sheet, fEnc, c, headers[c], _sEnc);
    }
    sheet.setRowHeight(fEnc, 20);

    int fila = fEnc + 1;
    for (int i = 0; i < filas.length; i++) {
      final r = filas[i];
      final par = i % 2 == 0;
      final sT = par ? _sTxtAlt : _sTxt;
      final sN = par ? _sNumAlt : _sNum;
      _celNum(sheet, fila, 0, i + 1, sN);
      _cel(sheet, fila, 1, r.nombre, sT);
      _cel(sheet, fila, 2, r.dni, sN);
      _cel(sheet, fila, 3, r.codigo, sN);
      _cel(sheet, fila, 4, r.ciclo.isEmpty ? '—' : r.ciclo, sN);
      _cel(sheet, fila, 5, r.grupo.isEmpty ? '—' : r.grupo, sN);
      sheet.setRowHeight(fila, 15);
      fila++;
    }

    _cel(sheet, fila, 0, '  TOTAL', _sTotal);
    _merge(sheet, fila, 0, fila, 4);
    _celNum(sheet, fila, 5, filas.length, _sTotal);
    sheet.setRowHeight(fila, 18);

    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 40);
    sheet.setColumnWidth(2, 14);
    sheet.setColumnWidth(3, 16);
    sheet.setColumnWidth(4, 8);
    sheet.setColumnWidth(5, 8);
  }


  void _metaFilas(Sheet sheet, EscuelaItem escuela, String eventoNombre,
      int lastCol, {required String extra}) {
    _cel(sheet, 1, 0, '  Filial: ${escuela.filialNombre}', _sMeta);
    _merge(sheet, 1, 0, 1, lastCol);
    _cel(sheet, 2, 0, '  Facultad: ${escuela.facultad}', _sMeta);
    _merge(sheet, 2, 0, 2, lastCol);
    _cel(sheet, 3, 0, '  Escuela: ${escuela.carreraNombre}', _sMeta);
    _merge(sheet, 3, 0, 3, lastCol);
    _cel(sheet, 4, 0, '  Evento: $eventoNombre', _sMeta);
    _merge(sheet, 4, 0, 4, lastCol);
    _cel(sheet, 5, 0, extra, _sMeta);
    _merge(sheet, 5, 0, 5, lastCol);
    for (int r = 1; r <= 5; r++) {
      sheet.setRowHeight(r, 15);
    }
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

  void _merge(Sheet sheet, int r1, int c1, int r2, int c2) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: c1, rowIndex: r1),
      CellIndex.indexByColumnRow(columnIndex: c2, rowIndex: r2),
    );
  }
}