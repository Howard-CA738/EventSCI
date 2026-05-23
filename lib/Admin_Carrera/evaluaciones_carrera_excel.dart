import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class EvaluacionesCarreraExcelService {

  // ═══════════════════════════════════════════════════════════════════════════
  // PALETA DE COLORES
  // ═══════════════════════════════════════════════════════════════════════════
  static const _navy        = '#0F2044';
  static const _cobalt      = '#1A3A6E';
  static const _purple      = '#7C3AED';
  static const _purpleLight = '#EDE9FE';
  static const _purpleSoft  = '#F5F3FF';
  static const _white       = '#FFFFFF';
  static const _gray900     = '#111827';
  static const _gray700     = '#374151';
  static const _gray400     = '#9CA3AF';
  static const _gray100     = '#F3F4F6';
  static const _greenDark   = '#166534';
  static const _greenLight  = '#DCFCE7';
  static const _yellowDark  = '#854D0E';
  static const _yellowLight = '#FEF9C3';
  static const _redDark     = '#991B1B';
  static const _redLight    = '#FEE2E2';
  static const _blueDark    = '#1E40AF';
  static const _blueLight   = '#DBEAFE';

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

      _crearHojaDetalleEvaluaciones(
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

  // ═══════════════════════════════════════════════════════════════════════════
  // HOJA 1 — Resumen por Proyecto (nota promedio por proyecto)
  // ═══════════════════════════════════════════════════════════════════════════
  void _crearHojaResumenProyectos({
    required Excel excel,
    required List<Map<String, dynamic>> evaluaciones,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    String? carrera,
  }) {
    final sheet = excel['Resumen por Proyecto'];

    // ── Estilos ───────────────────────────────────────────────────────────────
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
    final sEncGreen = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString('#059669'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sDatoIzq = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray900),
    );
    final sDatoIzqP = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_purpleSoft),
      fontColorHex: ExcelColor.fromHexString(_gray900),
    );
    final sDatoCen = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray900),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sDatoCenP = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_purpleSoft),
      fontColorHex: ExcelColor.fromHexString(_gray900),
      horizontalAlign: HorizontalAlign.Center,
    );
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
    final sBloq = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_redLight),
      fontColorHex: ExcelColor.fromHexString(_redDark),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sTotGen = CellStyle(
      bold: true, fontSize: 10,
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      fontColorHex: ExcelColor.fromHexString(_white),
      horizontalAlign: HorizontalAlign.Center,
    );

    // ── Banner ────────────────────────────────────────────────────────────────
    _cel(sheet, 0, 0, '  REPORTE DE EVALUACIONES POR PROYECTO', sTitulo);
    _cel(sheet, 1, 0, '  ${eventoNombre.toUpperCase()}', sSubtitulo);
    const lastCol = 6;
    for (int c = 0; c <= lastCol; c++) _cel(sheet, 2, c, '', sSep);
    sheet.setRowHeight(2, 4);

    // ── Metadatos ─────────────────────────────────────────────────────────────
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

    // ── Agrupar por proyecto ──────────────────────────────────────────────────
    final Map<String, List<Map<String, dynamic>>> porProyecto = {};
    for (final ev in evaluaciones) {
      final key = ev['proyectoId']?.toString() ?? 'sin_id';
      porProyecto.putIfAbsent(key, () => []).add(ev);
    }

    // Nota máxima posible (tomada de la primera rúbrica disponible)
    double notaMax = 20;
    for (final ev in evaluaciones) {
      final r = ev['rubrica'];
      if (r != null && r.puntajeMaximo != null) {
        notaMax = (r.puntajeMaximo as num).toDouble();
        break;
      }
    }

    // ── Encabezados (fila 10) ─────────────────────────────────────────────────
    const fEnc = 10;
    _cel(sheet, fEnc, 0, 'N°', sEncDim);
    _cel(sheet, fEnc, 1, 'CÓDIGO', sEncDim);
    _cel(sheet, fEnc, 2, 'TÍTULO', sEncDim);
    _cel(sheet, fEnc, 3, 'JURADOS\nEVALUADOS', sEncVal);
    _cel(sheet, fEnc, 4, 'NOTA\nPROMEDIO', sEncGreen);
    _cel(sheet, fEnc, 5, 'NOTA\nMÁXIMA', sEncVal);
    _cel(sheet, fEnc, 6, 'ESTADO', sEncVal);
    sheet.setRowHeight(fEnc, 30);

    int idx = 0;
    double sumaPromedios = 0;
    for (final entry in porProyecto.entries) {
      final evs = entry.value;
      final fila = fEnc + 1 + idx;
      final par = idx % 2 == 0;
      final sI = par ? sDatoIzqP : sDatoIzq;
      final sC = par ? sDatoCenP : sDatoCen;

      final codigo = evs.first['codigo']?.toString() ?? '—';
      final titulo = evs.first['titulo']?.toString() ?? 'Sin título';
      final evaluadasList = evs.where((e) => e['evaluada'] == true).toList();
      final juradosEval = evaluadasList.length;
      final total = evs.length;

      double promedio = 0;
      if (evaluadasList.isNotEmpty) {
        promedio = evaluadasList.fold<double>(
              0, (s, e) => s + ((e['notaTotal'] as num?)?.toDouble() ?? 0)) /
            evaluadasList.length;
      }
      sumaPromedios += promedio;

      final notaMaxEv = evaluadasList.isEmpty
          ? 0.0
          : evaluadasList.map((e) => (e['notaTotal'] as num?)?.toDouble() ?? 0.0)
              .reduce((a, b) => a > b ? a : b);

      final bloqueadas = evs.where((e) => e['bloqueada'] == true).length;
      final estado = bloqueadas > 0
          ? '🔒 $bloqueadas bloqueada(s)'
          : (juradosEval == total ? '✅ Completo' : '⏳ $juradosEval/$total');

      final ratio = notaMax > 0 ? promedio / notaMax : 0.0;
      final sBadge = bloqueadas > 0
          ? sBloq
          : ratio >= 0.75
              ? sBadgeAlto
              : ratio >= 0.5
                  ? sBadgeMedio
                  : promedio > 0
                      ? sBadgeBajo
                      : sC;

      _celNum(sheet, fila, 0, idx + 1, sC);
      _cel(sheet, fila, 1, codigo, sC);
      _cel(sheet, fila, 2, titulo, sI);
      _celNum(sheet, fila, 3, juradosEval, sC);
      _celDec(sheet, fila, 4, promedio, sBadge);
      _celDec(sheet, fila, 5, notaMaxEv, sC);
      _cel(sheet, fila, 6, estado, sC);
      sheet.setRowHeight(fila, 18);
      idx++;
    }

    // ── Fila resumen ──────────────────────────────────────────────────────────
    final fTot = fEnc + 1 + idx;
    _cel(sheet, fTot, 0,
        '  PROMEDIO GENERAL: ${porProyecto.isEmpty ? 0 : (sumaPromedios / porProyecto.length).toStringAsFixed(2)} pts',
        sTotGen);
    _merge(sheet, fTot, 0, fTot, lastCol);
    sheet.setRowHeight(fTot, 22);

    // ── Merges banner ─────────────────────────────────────────────────────────
    _merge(sheet, 0, 0, 0, lastCol);
    _merge(sheet, 1, 0, 1, lastCol);

    // ── Anchos ────────────────────────────────────────────────────────────────
    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 12);
    sheet.setColumnWidth(2, 38);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 12);
    sheet.setColumnWidth(5, 12);
    sheet.setColumnWidth(6, 18);
    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 22);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOJA 2 — Detalle de Evaluaciones (una fila por evaluación)
  // ═══════════════════════════════════════════════════════════════════════════
  void _crearHojaDetalleEvaluaciones({
    required Excel excel,
    required List<Map<String, dynamic>> evaluaciones,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    String? carrera,
  }) {
    final sheet = excel['Detalle de Evaluaciones'];

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
      fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900),
    );
    final sEnc = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_purple),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final sEncGreen = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString('#059669'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sIzq  = CellStyle(fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900));
    final sCen  = CellStyle(fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900), horizontalAlign: HorizontalAlign.Center);
    final sIzqP = CellStyle(fontSize: 9, backgroundColorHex: ExcelColor.fromHexString(_purpleSoft), fontColorHex: ExcelColor.fromHexString(_gray900));
    final sCenP = CellStyle(fontSize: 9, backgroundColorHex: ExcelColor.fromHexString(_purpleSoft), fontColorHex: ExcelColor.fromHexString(_gray900), horizontalAlign: HorizontalAlign.Center);
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
    final sBloq = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_redLight),
      fontColorHex: ExcelColor.fromHexString(_redDark),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sPend = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_yellowLight),
      fontColorHex: ExcelColor.fromHexString(_yellowDark),
      horizontalAlign: HorizontalAlign.Center,
    );

    // ── Recopilar criterios únicos para columnas dinámicas ────────────────────
    final List<Map<String, String>> criteriosUnicos = [];
    final Set<String> idsVistos = {};
    for (final ev in evaluaciones) {
      final r = ev['rubrica'];
      if (r == null) continue;
      for (final sec in r.secciones) {
        for (final crit in sec.criterios) {
          if (!idsVistos.contains(crit.id)) {
            idsVistos.add(crit.id);
            criteriosUnicos.add({
              'id': crit.id,
              'descripcion': crit.descripcion,
              'seccion': sec.nombre,
              'peso': crit.peso.toStringAsFixed(1),
            });
          }
        }
      }
    }

    const colsBase = 7; // N°, Código, Título, Jurado, Rúbrica, Nota Total, Estado
    final lastCol = colsBase - 1 + criteriosUnicos.length;

    // ── Banner ────────────────────────────────────────────────────────────────
    _cel(sheet, 0, 0, '  DETALLE DE EVALUACIONES', sTitulo);
    _cel(sheet, 1, 0, '  ${eventoNombre.toUpperCase()}', sSubtitulo);
    for (int c = 0; c <= lastCol; c++) _cel(sheet, 2, c, '', sSep);
    sheet.setRowHeight(2, 4);

    // ── Metadatos ─────────────────────────────────────────────────────────────
    final fechaGen = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final metas = [
      ['  FILIAL', filialNombre],
      ['  FACULTAD', facultad],
      ['  CARRERA', carrera ?? 'Todas'],
      ['  TOTAL EVALUACIONES', '${evaluaciones.length}'],
      ['  GENERADO', fechaGen],
    ];
    for (int i = 0; i < metas.length; i++) {
      _cel(sheet, i + 3, 0, metas[i][0], sMetaLabel);
      _cel(sheet, i + 3, 1, '  ${metas[i][1]}', sMetaValue);
      _merge(sheet, i + 3, 1, i + 3, lastCol);
      sheet.setRowHeight(i + 3, 16);
    }
    sheet.setRowHeight(8, 8);

    // ── Encabezados (fila 9) ──────────────────────────────────────────────────
    const fEnc = 9;
    _cel(sheet, fEnc, 0, 'N°', sEnc);
    _cel(sheet, fEnc, 1, 'CÓDIGO', sEnc);
    _cel(sheet, fEnc, 2, 'TÍTULO', sEnc);
    _cel(sheet, fEnc, 3, 'JURADO', sEnc);
    _cel(sheet, fEnc, 4, 'RÚBRICA', sEnc);
    _cel(sheet, fEnc, 5, 'NOTA\nTOTAL', sEncGreen);
    _cel(sheet, fEnc, 6, 'ESTADO', sEnc);
    for (int c = 0; c < criteriosUnicos.length; c++) {
      final crit = criteriosUnicos[c];
      _cel(
        sheet, fEnc, colsBase + c,
        '${crit['seccion']}\n${crit['descripcion']}\n(Máx: ${crit['peso']})',
        sEnc,
      );
    }
    sheet.setRowHeight(fEnc, 40);

    // ── Nota máxima ───────────────────────────────────────────────────────────
    double notaMax = 20;
    for (final ev in evaluaciones) {
      final r = ev['rubrica'];
      if (r != null) { notaMax = (r.puntajeMaximo as num).toDouble(); break; }
    }

    // ── Filas de datos ────────────────────────────────────────────────────────
    for (int i = 0; i < evaluaciones.length; i++) {
      final ev = evaluaciones[i];
      final fila = fEnc + 1 + i;
      final par = i % 2 == 0;
      final sI = par ? sIzqP : sIzq;
      final sC = par ? sCenP : sCen;

      final evaluada = ev['evaluada'] == true;
      final bloqueada = ev['bloqueada'] == true;
      final notaTotal = (ev['notaTotal'] as num?)?.toDouble() ?? 0.0;
      final notas = ev['notas'] as Map<String, dynamic>? ?? {};
      final rubricaNombre = ev['rubricaNombre']?.toString() ?? '—';

      final ratio = notaMax > 0 ? notaTotal / notaMax : 0.0;
      final CellStyle sBadgeNota;
      if (bloqueada) {
        sBadgeNota = sBloq;
      } else if (!evaluada) {
        sBadgeNota = sPend;
      } else if (ratio >= 0.75) {
        sBadgeNota = sBadgeAlto;
      } else if (ratio >= 0.5) {
        sBadgeNota = sBadgeMedio;
      } else {
        sBadgeNota = sBadgeBajo;
      }

      final estado = bloqueada
          ? '🔒 Bloqueada'
          : evaluada
              ? '✅ Evaluada'
              : '⏳ Pendiente';

      _celNum(sheet, fila, 0, i + 1, sC);
      _cel(sheet, fila, 1, ev['codigo']?.toString() ?? '—', sC);
      _cel(sheet, fila, 2, ev['titulo']?.toString() ?? 'Sin título', sI);
      _cel(sheet, fila, 3, ev['juradoNombre']?.toString() ?? '—', sI);
      _cel(sheet, fila, 4, rubricaNombre, sI);
      _celDec(sheet, fila, 5, notaTotal, sBadgeNota);
      _cel(sheet, fila, 6, estado, sC);

      for (int c = 0; c < criteriosUnicos.length; c++) {
        final critId = criteriosUnicos[c]['id']!;
        final nota = notas[critId];
        if (nota != null) {
          _celDec(sheet, fila, colsBase + c,
              (nota as num).toDouble(), par ? sCenP : sCen);
        } else {
          _cel(sheet, fila, colsBase + c, '—', sC);
        }
      }
      sheet.setRowHeight(fila, 18);
    }

    // ── Merges banner ─────────────────────────────────────────────────────────
    _merge(sheet, 0, 0, 0, lastCol);
    _merge(sheet, 1, 0, 1, lastCol);

    // ── Anchos ────────────────────────────────────────────────────────────────
    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 12);
    sheet.setColumnWidth(2, 36);
    sheet.setColumnWidth(3, 22);
    sheet.setColumnWidth(4, 18);
    sheet.setColumnWidth(5, 12);
    sheet.setColumnWidth(6, 14);
    for (int c = 0; c < criteriosUnicos.length; c++) {
      sheet.setColumnWidth(colsBase + c, 18);
    }
    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 22);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════════════
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
    return s.substring(0, s.length > 40 ? 40 : s.length);
  }
}