import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class AsistenciasCarreraExcelService {

  // ═══════════════════════════════════════════════════════════════════════════
  // PALETA DE COLORES — Sistema de diseño unificado
  // ═══════════════════════════════════════════════════════════════════════════
  static const _navy       = '#0F2044';
  static const _cobalt     = '#1A3A6E';
  static const _blue       = '#2563EB';
  static const _blueSoft   = '#DBEAFE';
  static const _blueText   = '#1E40AF';
  static const _white      = '#FFFFFF';
  static const _gray900    = '#111827';
  static const _gray700    = '#374151';
  static const _gray400    = '#9CA3AF';
  static const _gray100    = '#F3F4F6';
  static const _greenDark  = '#166534';
  static const _greenLight = '#DCFCE7';
  static const _yellowDark = '#854D0E';
  static const _yellowLight = '#FEF9C3';
  static const _redDark    = '#991B1B';
  static const _redLight   = '#FEE2E2';
  static const _tealDark   = '#0F766E';
  static const _tealLight  = '#CCFBF1';
  static const _tealBg     = '#F0FDFA';

  Future<String?> generarReporteAsistencias({
    required List<Map<String, dynamic>> estudiantes,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    String? carrera,
  }) async {
    try {
      final excel = Excel.createExcel();

      // Deduplicar por código > DNI > nombre
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

      _crearHojaResumenCategorias(
        excel: excel,
        estudiantes: estudiantesLimpios,
        eventoNombre: eventoNombre,
        filialNombre: filialNombre,
        facultad: facultad,
        carrera: carrera,
      );

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
  // HOJA 1 — Resumen por Categoría (tabla cruzada ciclo × categoría)
  // ═══════════════════════════════════════════════════════════════════════════
  void _crearHojaResumenCategorias({
    required Excel excel,
    required List<Map<String, dynamic>> estudiantes,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    String? carrera,
  }) {
    final sheet = excel['Resumen por Categoría'];

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

    // Encabezados de columna de la tabla cruzada
    final sEncDim = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_cobalt),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final sEncCat = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_blue),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final sEncTotal = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString('#059669'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );

    // Celdas de datos de la tabla cruzada
    final sDimLabel = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_blueText),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sDimLabelP = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_blueSoft),
      fontColorHex: ExcelColor.fromHexString(_blueText),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sDatoN = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray900),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sDatoP = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_blueSoft),
      fontColorHex: ExcelColor.fromHexString(_gray900),
      horizontalAlign: HorizontalAlign.Center,
    );

    // Total por fila — verde suave
    final sTotFila = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_greenLight),
      fontColorHex: ExcelColor.fromHexString(_greenDark),
      horizontalAlign: HorizontalAlign.Center,
    );
    // Total por columna — azul suave
    final sTotCol = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_blueSoft),
      fontColorHex: ExcelColor.fromHexString(_blueText),
      horizontalAlign: HorizontalAlign.Center,
    );
    // Total general — navy sólido
    final sTotGen = CellStyle(
      bold: true, fontSize: 10,
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      fontColorHex: ExcelColor.fromHexString(_white),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // ── Banner ────────────────────────────────────────────────────────────────
    _cel(sheet, 0, 0, '  REPORTE DE ASISTENCIAS POR CATEGORÍA', sTitulo);
    _cel(sheet, 1, 0, '  ${eventoNombre.toUpperCase()}', sSubtitulo);
    // Separador decorativo (línea delgada azul)
    // Se aplica dinámicamente después de conocer el lastCol
    sheet.setRowHeight(2, 4);

    // ── Metadatos ─────────────────────────────────────────────────────────────
    final fechaGen = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final metas = [
      ['  FILIAL', filialNombre],
      ['  FACULTAD', facultad],
      ['  CARRERA', carrera ?? 'Todas'],
      ['  TOTAL ESTUDIANTES', '${estudiantes.length}'],
      ['  GENERADO', fechaGen],
    ];
    for (int i = 0; i < metas.length; i++) {
      _cel(sheet, i + 3, 0, metas[i][0], sMetaLabel);
      _cel(sheet, i + 3, 1, '  ${metas[i][1]}', sMetaValue);
      sheet.setRowHeight(i + 3, 16);
    }
    sheet.setRowHeight(8, 8); // espacio antes de la tabla

    // ── Recopilar categorías únicas ───────────────────────────────────────────
    final categoriasSet = <String>{};
    for (final e in estudiantes) {
      for (final s in (e['scans'] as List<dynamic>? ?? [])) {
        final cat = (s['categoria'] as String?)?.trim() ?? 'Sin categoría';
        if (cat.isNotEmpty) categoriasSet.add(cat);
      }
    }
    final categorias = categoriasSet.toList()..sort();

    // ── Construir tabla cruzada ───────────────────────────────────────────────
    final Map<String, Map<String, Set<String>>> tabla = {};
    final Map<String, Map<String, String>> grupoInfo = {};

    for (final e in estudiantes) {
      final ciclo = (e['ciclo'] as String?) ?? 'N/A';
      final grupo = (e['grupo'] as String?) ?? 'N/A';
      final key = '$ciclo||$grupo';
      final sid = _idEstudiante(e);

      tabla.putIfAbsent(key, () => {});
      grupoInfo[key] = {'ciclo': ciclo, 'grupo': grupo};

      for (final s in (e['scans'] as List<dynamic>? ?? [])) {
        final cat = (s['categoria'] as String?)?.trim() ?? 'Sin categoría';
        tabla[key]!.putIfAbsent(cat, () => <String>{}).add(sid);
      }
    }

    final grupoKeys = tabla.keys.toList()
      ..sort((a, b) {
        final ia = grupoInfo[a]!;
        final ib = grupoInfo[b]!;
        final ca = _parseCiclo(ia['ciclo']);
        final cb = _parseCiclo(ib['ciclo']);
        if (ca != cb) return ca.compareTo(cb);
        return _parseGrupo(ia['grupo']).compareTo(_parseGrupo(ib['grupo']));
      });

    final lastCol = categorias.length + 2;

    // Separador — ahora que conocemos lastCol
    for (int c = 0; c <= lastCol; c++) {
      _cel(sheet, 2, c, '', sSeparador);
    }

    // ── Merges metadatos ──────────────────────────────────────────────────────
    _merge(sheet, 0, 0, 0, lastCol);
    _merge(sheet, 1, 0, 1, lastCol);
    for (int i = 0; i < metas.length; i++) {
      _merge(sheet, i + 3, 1, i + 3, lastCol);
    }

    // ── Encabezados tabla (fila 9) ────────────────────────────────────────────
    const fEnc = 9;
    _cel(sheet, fEnc, 0, 'CICLO', sEncDim);
    _cel(sheet, fEnc, 1, 'GRUPO', sEncDim);
    for (int c = 0; c < categorias.length; c++) {
      _cel(sheet, fEnc, c + 2, categorias[c].toUpperCase(), sEncCat);
    }
    _cel(sheet, fEnc, lastCol, 'TOTAL', sEncTotal);
    sheet.setRowHeight(fEnc, 28);

    // ── Filas de datos ────────────────────────────────────────────────────────
    final Map<String, int> totPorCat = {};
    int totGeneral = 0;

    for (int i = 0; i < grupoKeys.length; i++) {
      final key = grupoKeys[i];
      final info = grupoInfo[key]!;
      final catMap = tabla[key]!;
      final fila = fEnc + 1 + i;
      final par = i % 2 == 0;

      _cel(sheet, fila, 0, info['ciclo']!, par ? sDimLabelP : sDimLabel);
      _cel(sheet, fila, 1, info['grupo']!, par ? sDimLabelP : sDimLabel);

      final estudiantesUnicos = <String>{};
      for (int c = 0; c < categorias.length; c++) {
        final cat = categorias[c];
        final set = catMap[cat] ?? {};
        _celNum(sheet, fila, c + 2, set.length, par ? sDatoP : sDatoN);
        totPorCat[cat] = (totPorCat[cat] ?? 0) + set.length;
        estudiantesUnicos.addAll(set);
      }

      final totFila = estudiantesUnicos.length;
      totGeneral += totFila;
      _celNum(sheet, fila, lastCol, totFila, sTotFila);
      sheet.setRowHeight(fila, 18);
    }

    // ── Fila de totales ───────────────────────────────────────────────────────
    final fTot = fEnc + 1 + grupoKeys.length;
    _cel(sheet, fTot, 0, 'TOTAL', sTotGen);
    _cel(sheet, fTot, 1, '', sTotGen);
    _merge(sheet, fTot, 0, fTot, 1);
    for (int c = 0; c < categorias.length; c++) {
      _celNum(sheet, fTot, c + 2, totPorCat[categorias[c]] ?? 0, sTotCol);
    }
    _celNum(sheet, fTot, lastCol, totGeneral, sTotGen);
    sheet.setRowHeight(fTot, 24);

    // ── Anchos ────────────────────────────────────────────────────────────────
    sheet.setColumnWidth(0, 10);
    sheet.setColumnWidth(1, 12);
    for (int c = 0; c < categorias.length; c++) {
      sheet.setColumnWidth(c + 2, 20);
    }
    sheet.setColumnWidth(lastCol, 14);

    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 22);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOJA 2 — Lista de Asistencias
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

    // Encabezados de columna
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

    // Filas alternas
    final sIzq  = CellStyle(fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900));
    final sCen  = CellStyle(fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900), horizontalAlign: HorizontalAlign.Center);
    final sIzqP = CellStyle(fontSize: 9, backgroundColorHex: ExcelColor.fromHexString(_blueSoft), fontColorHex: ExcelColor.fromHexString(_gray900));
    final sCenP = CellStyle(fontSize: 9, backgroundColorHex: ExcelColor.fromHexString(_blueSoft), fontColorHex: ExcelColor.fromHexString(_gray900), horizontalAlign: HorizontalAlign.Center);

    // Badges de nivel de asistencia
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

    // Fila de estadísticas al final — teal
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

    // ── Banner ────────────────────────────────────────────────────────────────
    _cel(sheet, 0, 0, '  LISTA DE ASISTENCIAS', sTitulo);
    _cel(sheet, 1, 0, '  ${eventoNombre.toUpperCase()}', sSubtitulo);
    for (int c = 0; c <= 7; c++) _cel(sheet, 2, c, '', sSeparador);
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
      _merge(sheet, i + 3, 1, i + 3, 7);
      sheet.setRowHeight(i + 3, 16);
    }
    sheet.setRowHeight(9, 8); // espacio antes de la tabla

    // ── Encabezados tabla (fila 10) ───────────────────────────────────────────
    const fEnc = 10;
    const encabezados = [
      'N°', 'NOMBRE COMPLETO', 'DNI', 'CÓDIGO',
      'CICLO', 'GRUPO', 'N° ASISTENCIAS', 'ÚLTIMA ASISTENCIA',
    ];
    for (int c = 0; c < encabezados.length; c++) {
      _cel(sheet, fEnc, c, encabezados[c], c == 6 ? sEncAsistencias : sEnc);
    }
    sheet.setRowHeight(fEnc, 28);

    // Máximo para badge relativo
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
      _cel(sheet, fila, 2, e['dni'] ?? '', sC);
      _cel(sheet, fila, 3, e['codigo'] ?? '', sC);
      _cel(sheet, fila, 4, e['ciclo'] ?? 'N/A', sC);
      _cel(sheet, fila, 5, e['grupo'] ?? 'N/A', sC);
      _celNum(sheet, fila, 6, totalScans, sBadge);
      _cel(sheet, fila, 7, ultimaAsistencia, sC);
      sheet.setRowHeight(fila, 18);
    }

    // ── Fila de totales / estadísticas ────────────────────────────────────────
    if (estudiantes.isNotEmpty) {
      final fTot = fEnc + 1 + estudiantes.length;
      final scansLista =
          estudiantes.map((e) => (e['totalScans'] as int?) ?? 0).toList();
      final promedio = totalGlobal / estudiantes.length;
      final maxS = scansLista.reduce((a, b) => a > b ? a : b);
      final minS = scansLista.reduce((a, b) => a < b ? a : b);

      _cel(sheet, fTot, 0,
          '  ∑  ${estudiantes.length} estudiantes — Total asistencias: $totalGlobal',
          sStatLabel);
      _merge(sheet, fTot, 0, fTot, 5);
      _cel(sheet, fTot, 6,
          'Prom: ${promedio.toStringAsFixed(1)}  Máx: $maxS  Mín: $minS',
          sStatVal);
      _merge(sheet, fTot, 6, fTot, 7);
      sheet.setRowHeight(fTot, 20);
    }

    // ── Merges banner ─────────────────────────────────────────────────────────
    _merge(sheet, 0, 0, 0, 7);
    _merge(sheet, 1, 0, 1, 7);

    // ── Anchos ────────────────────────────────────────────────────────────────
    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 34);
    sheet.setColumnWidth(2, 13);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(4, 8);
    sheet.setColumnWidth(5, 10);
    sheet.setColumnWidth(6, 15);
    sheet.setColumnWidth(7, 22);

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
    if (grupo == null || grupo.isEmpty || grupo == 'N/A') return 999;
    final g = grupo.toLowerCase();
    if (g.contains('único') || g.contains('unico')) return 0;
    try {
      final m = RegExp(r'\d+').firstMatch(grupo);
      if (m != null) return int.parse(m.group(0)!);
    } catch (_) {}
    return 999;
  }

  String _sanitizar(String texto) {
    final s =
        texto.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').replaceAll(' ', '_');
    return s.substring(0, s.length > 40 ? 40 : s.length);
  }
}