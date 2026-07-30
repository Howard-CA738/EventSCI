import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class ParticipantesCarreraExcelService {
  static const _navy      = '#0F2044';
  static const _cobalt    = '#1A3A6E';
  static const _blue      = '#2563EB';
  static const _blueSoft  = '#DBEAFE';
  static const _gray900   = '#111827';
  static const _gray700   = '#374151';
  static const _gray400   = '#9CA3AF';
  static const _gray100   = '#F3F4F6';
  static const _white     = '#FFFFFF';
  static const _gold       = '#D97706';
  static const _goldBg     = '#FFFBEB';
  static const _silverBg   = '#F8FAFC';
  static const _silverText = '#475569';
  static const _bronzeBg   = '#FFF7ED';
  static const _bronzeText = '#92400E';
  static const _tealDark  = '#0F766E';
  static const _tealLight = '#CCFBF1';
  static const _tealBg    = '#F0FDFA';

  Future<String?> generarReporteParticipantes({
    required Map<String, List<Map<String, dynamic>>> participantesPorCategoria,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    String? carrera,
    double escalaBase = 20.0,
  }) async {
    try {
      final excel = Excel.createExcel();

      final List<Map<String, dynamic>> todos = [];
      for (final entry in participantesPorCategoria.entries) {
        for (int i = 0; i < entry.value.length; i++) {
          todos.add({
            ...entry.value[i],
            '_categoria': entry.key,
            '_posicionEnCategoria': i,
          });
        }
      }

      _crearHojaResumenCategorias(
        excel: excel,
        participantesPorCategoria: participantesPorCategoria,
        eventoNombre: eventoNombre,
        filialNombre: filialNombre,
        facultad: facultad,
        carrera: carrera,
        escalaBase: escalaBase,
      );

      _crearHojaListaCompleta(
        excel: excel,
        todos: todos,
        eventoNombre: eventoNombre,
        filialNombre: filialNombre,
        facultad: facultad,
        carrera: carrera,
        escalaBase: escalaBase,
      );

      _crearHojaPodio(
        excel: excel,
        participantesPorCategoria: participantesPorCategoria,
        eventoNombre: eventoNombre,
        escalaBase: escalaBase,
      );

      excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) return null;

      final dir = await getTemporaryDirectory();
      final fecha = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final nombreArchivo = 'Participantes_${_sanitizar(eventoNombre)}_$fecha.xlsx';
      final file = File('${dir.path}/$nombreArchivo');
      await file.writeAsBytes(bytes);

      return file.path;
    } catch (e) {
      debugPrint('❌ Error generando Excel de participantes: $e');
      return null;
    }
  }






  void _crearHojaResumenCategorias({
    required Excel excel,
    required Map<String, List<Map<String, dynamic>>> participantesPorCategoria,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    String? carrera,
    double escalaBase = 20.0,
  }) {
    final sheet = excel['Resumen por Categoría'];

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
      backgroundColorHex: ExcelColor.fromHexString(_white),
    );
    final sEncCategoria = CellStyle(
      bold: true, fontSize: 10,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_cobalt),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final sEncCol = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_blue),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final sOro = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_goldBg),
      fontColorHex: ExcelColor.fromHexString(_gold),
    );
    final sOroC = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_goldBg),
      fontColorHex: ExcelColor.fromHexString(_gold),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sPlata = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_silverBg),
      fontColorHex: ExcelColor.fromHexString(_silverText),
    );
    final sPlataC = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_silverBg),
      fontColorHex: ExcelColor.fromHexString(_silverText),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sBronce = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_bronzeBg),
      fontColorHex: ExcelColor.fromHexString(_bronzeText),
    );
    final sBronceC = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_bronzeBg),
      fontColorHex: ExcelColor.fromHexString(_bronzeText),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sDatoIzq = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray900),
      horizontalAlign: HorizontalAlign.Left,
    );
    final sDatoC = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray900),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sDatoIzqP = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_blueSoft),
      fontColorHex: ExcelColor.fromHexString(_gray900),
    );
    final sDatoCPar = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_blueSoft),
      fontColorHex: ExcelColor.fromHexString(_gray900),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sDatoPromedio = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray900),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sDatoPromedioP = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_blueSoft),
      fontColorHex: ExcelColor.fromHexString(_gray900),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sSinEval = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray400),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sStatLabel = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_tealDark),
      backgroundColorHex: ExcelColor.fromHexString(_tealBg),
    );
    final sStatVal = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_tealLight),
      fontColorHex: ExcelColor.fromHexString(_tealDark),
      horizontalAlign: HorizontalAlign.Center,
    );


    _cel(sheet, 0, 0, '  REPORTE DE PARTICIPANTES', sTitulo);
    _cel(sheet, 1, 0, '  ${eventoNombre.toUpperCase()}', sSubtitulo);
    for (int c = 0; c <= 7; c++) _cel(sheet, 2, c, '', sSeparador);
    sheet.setRowHeight(2, 4);

    _merge(sheet, 0, 0, 0, 7);
    _merge(sheet, 1, 0, 1, 7);


    final fechaGen = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final totalProyectos = participantesPorCategoria.values.fold(0, (s, l) => s + l.length);
    final totalEvaluados = participantesPorCategoria.values
        .expand((l) => l)
        .where((p) => p['tieneEvaluaciones'] == true)
        .length;

    final metas = [
      ['  FILIAL', filialNombre],
      ['  FACULTAD', facultad],
      ['  CARRERA', carrera ?? 'Todas'],
      ['  TOTAL PROYECTOS', '$totalProyectos'],
      ['  EVALUADOS', '$totalEvaluados de $totalProyectos'],
      ['  GENERADO', fechaGen],
    ];
    for (int i = 0; i < metas.length; i++) {
      _cel(sheet, i + 3, 0, metas[i][0], sMetaLabel);
      _cel(sheet, i + 3, 1, '  ${metas[i][1]}', sMetaValue);
      _merge(sheet, i + 3, 1, i + 3, 7);
      sheet.setRowHeight(i + 3, 16);
    }
    sheet.setRowHeight(9, 8);


    const fEnc = 10;
    final encabezados = [
      'CATEGORÍA', 'POS', 'CÓDIGO', 'TÍTULO DEL PROYECTO',
      'INTEGRANTES', 'SALA',
      'PROMEDIO/${escalaBase.toStringAsFixed(0)}', 'JURADOS EVALUADORES',
    ];
    for (int c = 0; c < encabezados.length; c++) {
      _cel(sheet, fEnc, c, encabezados[c], sEncCol);
    }
    sheet.setRowHeight(fEnc, 28);


    int fila = fEnc + 1;
    int filaGlobal = 0;

    for (final entry in participantesPorCategoria.entries) {
      final categoria = entry.key;
      final proyectos = entry.value;

      _cel(sheet, fila, 0, '  $categoria', sEncCategoria);
      _merge(sheet, fila, 0, fila, 7);
      sheet.setRowHeight(fila, 22);
      fila++;

      for (int i = 0; i < proyectos.length; i++) {
        final p = proyectos[i];
        final tieneEval      = p['tieneEvaluaciones'] == true;
        final promedio       = (p['promedio']  as num?)?.toDouble() ?? 0.0;
        final nombresJurados = _sv(p['nombresJurados']);
        final par = filaGlobal % 2 == 0;

        final CellStyle sFila;
        final CellStyle sFilaC;
        final CellStyle sFilaPromedio;
        final String puestoStr;

        if (!tieneEval) {
          sFila         = par ? sDatoIzqP : sDatoIzq;
          sFilaC        = par ? sDatoCPar : sDatoC;
          sFilaPromedio = sSinEval;
          puestoStr     = '—';
        } else if (i == 0) {
          sFila = sOro;    sFilaC = sOroC;    sFilaPromedio = sOroC;    puestoStr = '🥇 1°';
        } else if (i == 1) {
          sFila = sPlata;  sFilaC = sPlataC;  sFilaPromedio = sPlataC;  puestoStr = '🥈 2°';
        } else if (i == 2) {
          sFila = sBronce; sFilaC = sBronceC; sFilaPromedio = sBronceC; puestoStr = '🥉 3°';
        } else {
          sFila         = par ? sDatoIzqP : sDatoIzq;
          sFilaC        = par ? sDatoCPar : sDatoC;
          sFilaPromedio = par ? sDatoPromedioP : sDatoPromedio;
          puestoStr     = '${i + 1}°';
        }

        _cel(sheet, fila, 0, '', sFilaC);
        _cel(sheet, fila, 1, puestoStr, sFilaC);
        _cel(sheet, fila, 2, _sv(p['codigo']), sFilaC);
        _cel(sheet, fila, 3, _sv(p['titulo']), sFila);
        _cel(sheet, fila, 4, _sv(p['integrantes']), sFila);
        _cel(sheet, fila, 5, _sv(p['sala']), sFilaC);

        if (tieneEval) {
          _celDouble(sheet, fila, 6, promedio, sFilaPromedio);
          _cel(sheet, fila, 7, nombresJurados == '—' ? '' : nombresJurados, sFila);
        } else {
          _cel(sheet, fila, 6, 'S/E', sSinEval);
          _cel(sheet, fila, 7, '',    sSinEval);
        }

        sheet.setRowHeight(fila, 18);
        fila++;
        filaGlobal++;
      }


      final conEval = proyectos.where((p) => p['tieneEvaluaciones'] == true).toList();
      if (conEval.isNotEmpty) {
        final promedios = conEval.map((p) => (p['promedio'] as num).toDouble()).toList();
        final avgCat = promedios.reduce((a, b) => a + b) / promedios.length;

        _cel(sheet, fila, 0,
            '  ∑  ${conEval.length} evaluados / ${proyectos.length} total',
            sStatLabel);
        _merge(sheet, fila, 0, fila, 5);
        _cel(sheet, fila, 6, avgCat.toStringAsFixed(2), sStatVal);
        _cel(sheet, fila, 7, '', sStatVal);
        sheet.setRowHeight(fila, 18);
        fila++;
      }

      sheet.setRowHeight(fila, 6);
      fila++;
    }


    sheet.setColumnWidth(0, 24);
    sheet.setColumnWidth(1, 9);
    sheet.setColumnWidth(2, 12);
    sheet.setColumnWidth(3, 40);
    sheet.setColumnWidth(4, 30);
    sheet.setColumnWidth(5, 7);
    sheet.setColumnWidth(6, 11);
    sheet.setColumnWidth(7, 40);

    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 22);
  }






  void _crearHojaListaCompleta({
    required Excel excel,
    required List<Map<String, dynamic>> todos,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    String? carrera,
    double escalaBase = 20.0,
  }) {
    final sheet = excel['Lista Completa'];

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
    final sEncPromedio = CellStyle(
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
    final sPromedioNormal = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray900),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sPromedioNormalP = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_blueSoft),
      fontColorHex: ExcelColor.fromHexString(_gray900),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sSinEval = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray400),
      horizontalAlign: HorizontalAlign.Center,
    );


    _cel(sheet, 0, 0, '  LISTA COMPLETA DE PROYECTOS', sTitulo);
    _cel(sheet, 1, 0, '  ${eventoNombre.toUpperCase()}', sSubtitulo);
    for (int c = 0; c <= 7; c++) _cel(sheet, 2, c, '', sSeparador);
    sheet.setRowHeight(2, 4);

    _merge(sheet, 0, 0, 0, 7);
    _merge(sheet, 1, 0, 1, 7);


    final fechaGen = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final totalEval = todos.where((p) => p['tieneEvaluaciones'] == true).length;
    final metas = [
      ['  FILIAL', filialNombre],
      ['  FACULTAD', facultad],
      ['  CARRERA', carrera ?? 'Todas'],
      ['  TOTAL PROYECTOS', '${todos.length}'],
      ['  EVALUADOS', '$totalEval de ${todos.length}'],
      ['  GENERADO', fechaGen],
    ];
    for (int i = 0; i < metas.length; i++) {
      _cel(sheet, i + 3, 0, metas[i][0], sMetaLabel);
      _cel(sheet, i + 3, 1, '  ${metas[i][1]}', sMetaValue);
      _merge(sheet, i + 3, 1, i + 3, 7);
      sheet.setRowHeight(i + 3, 16);
    }
    sheet.setRowHeight(9, 8);


    const fEnc = 10;
    final encabezados = [
      'N°', 'CÓDIGO', 'TÍTULO DEL PROYECTO',
      'CATEGORÍA', 'INTEGRANTES',
      'SALA', 'PROMEDIO/${escalaBase.toStringAsFixed(0)}', 'JURADOS EVALUADORES',
    ];
    for (int c = 0; c < encabezados.length; c++) {
      _cel(sheet, fEnc, c, encabezados[c], c == 6 ? sEncPromedio : sEnc);
    }
    sheet.setRowHeight(fEnc, 28);


    for (int i = 0; i < todos.length; i++) {
      final p = todos[i];
      final fila = fEnc + 1 + i;
      final par = i % 2 == 0;
      final tieneEval      = p['tieneEvaluaciones'] == true;
      final promedio       = (p['promedio'] as num?)?.toDouble() ?? 0.0;
      final nombresJurados = _sv(p['nombresJurados']);

      final sI = par ? sIzqP : sIzq;
      final sC = par ? sCenP : sCen;
      final sProm = par ? sPromedioNormalP : sPromedioNormal;

      _cel(sheet, fila, 0, '${i + 1}', sC);
      _cel(sheet, fila, 1, _sv(p['codigo']), sC);
      _cel(sheet, fila, 2, _sv(p['titulo']), sI);
      _cel(sheet, fila, 3, _sv(p['_categoria'] ?? p['clasificacion']), sC);
      _cel(sheet, fila, 4, _sv(p['integrantes']), sI);
      _cel(sheet, fila, 5, _sv(p['sala']), sC);

      if (tieneEval) {
        _celDouble(sheet, fila, 6, promedio, sProm);
        _cel(sheet, fila, 7, nombresJurados == '—' ? '' : nombresJurados, sI);
      } else {
        _cel(sheet, fila, 6, 'S/E', sSinEval);
        _cel(sheet, fila, 7, '',    sSinEval);
      }

      sheet.setRowHeight(fila, 18);
    }


    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 12);
    sheet.setColumnWidth(2, 40);
    sheet.setColumnWidth(3, 22);
    sheet.setColumnWidth(4, 30);
    sheet.setColumnWidth(5, 7);
    sheet.setColumnWidth(6, 11);
    sheet.setColumnWidth(7, 40);

    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 22);
  }




  void _crearHojaPodio({
    required Excel excel,
    required Map<String, List<Map<String, dynamic>>> participantesPorCategoria,
    required String eventoNombre,
    double escalaBase = 20.0,
  }) {
    final sheet = excel['Podio por Categoría'];

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
    final sEncCat = CellStyle(
      bold: true, fontSize: 11,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final sOroEnc = CellStyle(
      bold: true, fontSize: 10,
      backgroundColorHex: ExcelColor.fromHexString('#F59E0B'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sPlataEnc = CellStyle(
      bold: true, fontSize: 10,
      backgroundColorHex: ExcelColor.fromHexString('#64748B'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sBronceEnc = CellStyle(
      bold: true, fontSize: 10,
      backgroundColorHex: ExcelColor.fromHexString('#B45309'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sLabel = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray700),
      backgroundColorHex: ExcelColor.fromHexString(_gray100),
    );
    final sOroVal = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_goldBg),
      fontColorHex: ExcelColor.fromHexString(_gold),
      textWrapping: TextWrapping.WrapText,
    );
    final sPlataVal = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_silverBg),
      fontColorHex: ExcelColor.fromHexString(_silverText),
      textWrapping: TextWrapping.WrapText,
    );
    final sBronceVal = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_bronzeBg),
      fontColorHex: ExcelColor.fromHexString(_bronzeText),
      textWrapping: TextWrapping.WrapText,
    );
    final sOroNota = CellStyle(
      bold: true, fontSize: 18,
      backgroundColorHex: ExcelColor.fromHexString('#FDE68A'),
      fontColorHex: ExcelColor.fromHexString(_gold),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sPlaNota = CellStyle(
      bold: true, fontSize: 18,
      backgroundColorHex: ExcelColor.fromHexString('#E2E8F0'),
      fontColorHex: ExcelColor.fromHexString('#475569'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sBroNota = CellStyle(
      bold: true, fontSize: 18,
      backgroundColorHex: ExcelColor.fromHexString('#FED7AA'),
      fontColorHex: ExcelColor.fromHexString(_bronzeText),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );


    _cel(sheet, 0, 0, '  PODIO DE GANADORES POR CATEGORÍA', sTitulo);
    _cel(sheet, 1, 0, '  ${eventoNombre.toUpperCase()}', sSubtitulo);
    for (int c = 0; c <= 6; c++) _cel(sheet, 2, c, '', sSeparador);
    sheet.setRowHeight(2, 4);
    _merge(sheet, 0, 0, 0, 6);
    _merge(sheet, 1, 0, 1, 6);
    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 22);
    sheet.setRowHeight(3, 10);

    int fila = 4;

    for (final entry in participantesPorCategoria.entries) {
      final categoria = entry.key;
      final proyectos = entry.value
          .where((p) => p['tieneEvaluaciones'] == true)
          .toList();

      if (proyectos.isEmpty) continue;

      _cel(sheet, fila, 0, '  $categoria', sEncCat);
      _merge(sheet, fila, 0, fila, 6);
      sheet.setRowHeight(fila, 26);
      fila++;

      _cel(sheet, fila, 0, '', sLabel);
      final encStyles = [sOroEnc, sPlataEnc, sBronceEnc];
      final encLabels = ['🥇  1er Lugar', '🥈  2do Lugar', '🥉  3er Lugar'];
      for (int col = 0; col < 3; col++) {
        if (col < proyectos.length) {
          _cel(sheet, fila, 1 + col * 2, encLabels[col], encStyles[col]);
          _merge(sheet, fila, 1 + col * 2, fila, 1 + col * 2 + 1);
        }
      }
      sheet.setRowHeight(fila, 24);
      fila++;

      final fields = [
        {'label': 'Título',       'key': 'titulo'},
        {'label': 'Código',       'key': 'codigo'},
        {'label': 'Integrantes',  'key': 'integrantes'},
        {'label': 'Jurados',      'key': 'nombresJurados'},
        {'label': 'Prom./${escalaBase.toStringAsFixed(0)}', 'key': 'promedio'},
      ];

      final valStyles  = [sOroVal,  sPlataVal,  sBronceVal];
      final notaStyles = [sOroNota, sPlaNota, sBroNota];

      for (final field in fields) {
        final isNota = field['key'] == 'promedio';
        _cel(sheet, fila, 0, '  ${field['label']}', sLabel);

        for (int col = 0; col < 3; col++) {
          if (col >= proyectos.length) continue;
          final p    = proyectos[col];
          final sVal = isNota ? notaStyles[col] : valStyles[col];
          final val  = field['key'] == 'promedio'
              ? (p['promedio'] as num?)?.toDouble().toStringAsFixed(2) ?? '—'
              : _sv(p[field['key']]);

          _cel(sheet, fila, 1 + col * 2, val, sVal);
          _merge(sheet, fila, 1 + col * 2, fila, 1 + col * 2 + 1);
        }

        sheet.setRowHeight(fila, isNota ? 36 : 20);
        fila++;
      }

      sheet.setRowHeight(fila, 12);
      fila++;
    }


    sheet.setColumnWidth(0, 14);
    sheet.setColumnWidth(1, 22);
    sheet.setColumnWidth(2, 22);
    sheet.setColumnWidth(3, 22);
    sheet.setColumnWidth(4, 22);
    sheet.setColumnWidth(5, 22);
    sheet.setColumnWidth(6, 22);
  }




  void _cel(Sheet sheet, int row, int col, String value, CellStyle style) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(value);
    cell.cellStyle = style;
  }

  void _celDouble(Sheet sheet, int row, int col, double value, CellStyle style) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = DoubleCellValue(double.parse(value.toStringAsFixed(2)));
    cell.cellStyle = style;
  }

  void _merge(Sheet sheet, int r1, int c1, int r2, int c2) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: c1, rowIndex: r1),
      CellIndex.indexByColumnRow(columnIndex: c2, rowIndex: r2),
    );
  }

  String _sv(dynamic v, [String fb = '—']) {
    if (v == null) return fb;
    final s = v.toString().trim();
    return s.isEmpty ? fb : s;
  }

  String _sanitizar(String texto) {
    final s = texto.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').replaceAll(' ', '_');
    return s.substring(0, s.length > 40 ? 40 : s.length);
  }
}