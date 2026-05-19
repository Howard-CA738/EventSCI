import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

// Archivo: lib/admin/interfaz/participantes_carrera_excel.dart

class ParticipantesCarreraExcelService {
  // ═══════════════════════════════════════════════════════════════════════════
  // PALETA DE COLORES — Sistema de diseño unificado
  // Inspirado en reportes de Notion / Linear / Looker Studio
  // ═══════════════════════════════════════════════════════════════════════════

  // Azules corporativos (encabezados principales)
  static const _navy      = '#0F2044'; // Azul muy oscuro — título principal
  static const _cobalt    = '#1A3A6E'; // Azul corporativo — subtítulos
  static const _blue      = '#2563EB'; // Azul brillante — encabezados de columna
  static const _blueSoft  = '#DBEAFE'; // Azul muy claro — filas pares
  static const _blueText  = '#1E40AF'; // Texto azul oscuro

  // Neutros / texto
  static const _gray900   = '#111827'; // Texto principal oscuro
  static const _gray700   = '#374151'; // Texto secundario
  static const _gray400   = '#9CA3AF'; // Texto deshabilitado / S/E
  static const _gray100   = '#F3F4F6'; // Fondo filas alternas
  static const _white     = '#FFFFFF';

  // Semáforo de rendimiento
  static const _greenDark  = '#166534';
  static const _greenLight = '#DCFCE7';
  static const _yellowDark = '#854D0E';
  static const _yellowLight = '#FEF9C3';
  static const _redDark    = '#991B1B';
  static const _redLight   = '#FEE2E2';

  // Podio
  static const _gold       = '#D97706'; // Texto dorado
  static const _goldBg     = '#FFFBEB'; // Fondo dorado suave
  static const _goldAccent = '#FDE68A'; // Borde/acento dorado
  static const _silverBg   = '#F8FAFC';
  static const _silverText = '#475569';
  static const _bronzeBg   = '#FFF7ED';
  static const _bronzeText = '#92400E';

  // Estadísticas
  static const _tealDark  = '#0F766E';
  static const _tealLight = '#CCFBF1';
  static const _tealBg    = '#F0FDFA';

  /// Genera el reporte Excel de participantes de un evento.
  Future<String?> generarReporteParticipantes({
    required Map<String, List<Map<String, dynamic>>> participantesPorCategoria,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    String? carrera,
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

      debugPrint('✅ Proyectos para Excel: ${todos.length}');

      _crearHojaResumenCategorias(
        excel: excel,
        participantesPorCategoria: participantesPorCategoria,
        eventoNombre: eventoNombre,
        filialNombre: filialNombre,
        facultad: facultad,
        carrera: carrera,
      );

      _crearHojaListaCompleta(
        excel: excel,
        todos: todos,
        eventoNombre: eventoNombre,
        filialNombre: filialNombre,
        facultad: facultad,
        carrera: carrera,
      );

      _crearHojaPodio(
        excel: excel,
        participantesPorCategoria: participantesPorCategoria,
        eventoNombre: eventoNombre,
      );

      excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) return null;

      final dir = await getTemporaryDirectory();
      final fecha = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final nombreArchivo =
          'Participantes_${_sanitizar(eventoNombre)}_$fecha.xlsx';
      final file = File('${dir.path}/$nombreArchivo');
      await file.writeAsBytes(bytes);

      return file.path;
    } catch (e) {
      debugPrint('❌ Error generando Excel de participantes: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOJA 1 — Resumen por Categoría
  // ═══════════════════════════════════════════════════════════════════════════
  void _crearHojaResumenCategorias({
    required Excel excel,
    required Map<String, List<Map<String, dynamic>>> participantesPorCategoria,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    String? carrera,
  }) {
    final sheet = excel['Resumen por Categoría'];

    // ── Estilos ───────────────────────────────────────────────────────────────

    // Banner principal — Fondo navy, texto blanco, fuente grande
    final sTitulo = CellStyle(
      bold: true,
      fontSize: 15,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Subtítulo del evento — Cobalt, texto blanco, tamaño medio
    final sSubtitulo = CellStyle(
      bold: false,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#93C5FD'), // Azul claro pastel
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Fila de separación debajo del banner
    final sSeparador = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_blue),
    );

    // Metadatos — Etiqueta
    final sMetaLabel = CellStyle(
      bold: true,
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray700),
      backgroundColorHex: ExcelColor.fromHexString(_gray100),
    );

    // Metadatos — Valor
    final sMetaValue = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray900),
      backgroundColorHex: ExcelColor.fromHexString(_white),
    );

    // Encabezado de sección categoría (span completo)
    final sEncCategoria = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_cobalt),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );

    // Encabezados de columna — Azul brillante, compacto
    final sEncCol = CellStyle(
      bold: true,
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_blue),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );

    // Filas — Podio oro
    final sOro = CellStyle(
      bold: true,
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_goldBg),
      fontColorHex: ExcelColor.fromHexString(_gold),
    );
    final sOroC = CellStyle(
      bold: true,
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_goldBg),
      fontColorHex: ExcelColor.fromHexString(_gold),
      horizontalAlign: HorizontalAlign.Center,
    );

    // Filas — Podio plata
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

    // Filas — Podio bronce
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

    // Filas normales — alternas blanco / gris muy claro
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

    // Nota numérica destacada (promedio, max, min)
    final sNota = CellStyle(
      bold: true,
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_blueText),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sNotaPar = CellStyle(
      bold: true,
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_blueSoft),
      fontColorHex: ExcelColor.fromHexString(_blueText),
      horizontalAlign: HorizontalAlign.Center,
    );

    // Sin evaluación
    final sSinEval = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray400),
      horizontalAlign: HorizontalAlign.Center,
    );

    // Fila estadísticas — Teal suave
    final sStatLabel = CellStyle(
      bold: true,
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_tealDark),
      backgroundColorHex: ExcelColor.fromHexString(_tealBg),
    );
    final sStatVal = CellStyle(
      bold: true,
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_tealLight),
      fontColorHex: ExcelColor.fromHexString(_tealDark),
      horizontalAlign: HorizontalAlign.Center,
    );

    // ── Fila 0-1: Banner ──────────────────────────────────────────────────────
    _cel(sheet, 0, 0, '  REPORTE DE PARTICIPANTES', sTitulo);
    _cel(sheet, 1, 0, '  ${eventoNombre.toUpperCase()}', sSubtitulo);

    // Fila 2: separador de color sólido (altura pequeña = línea decorativa)
    for (int c = 0; c <= 10; c++) {
      _cel(sheet, 2, c, '', sSeparador);
    }
    sheet.setRowHeight(2, 4);

    // ── Filas 3-8: Metadatos en 2 columnas ───────────────────────────────────
    final fechaGen = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final totalProyectos =
        participantesPorCategoria.values.fold(0, (s, l) => s + l.length);
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
      _merge(sheet, i + 3, 1, i + 3, 10);
      sheet.setRowHeight(i + 3, 16);
    }

    // Fila en blanco de separación antes de la tabla
    sheet.setRowHeight(9, 8);

    // ── Encabezados de tabla (fila 10) ────────────────────────────────────────
    const fEnc = 10;
    final encabezados = [
      'CATEGORÍA', 'POS', 'CÓDIGO', 'TÍTULO DEL PROYECTO',
      'INTEGRANTES', 'ASESOR', 'SALA',
      'PROMEDIO', 'MÁX', 'MÍN', 'JURADOS',
    ];
    for (int c = 0; c < encabezados.length; c++) {
      _cel(sheet, fEnc, c, encabezados[c], sEncCol);
    }
    sheet.setRowHeight(fEnc, 28);

    // ── Filas de datos ────────────────────────────────────────────────────────
    int fila = fEnc + 1;
    int filaGlobal = 0; // Para alternar colores independiente de categorías

    for (final entry in participantesPorCategoria.entries) {
      final categoria = entry.key;
      final proyectos = entry.value;

      // Encabezado de sección por categoría
      _cel(sheet, fila, 0, '  $categoria', sEncCategoria);
      _merge(sheet, fila, 0, fila, 10);
      sheet.setRowHeight(fila, 22);
      fila++;

      for (int i = 0; i < proyectos.length; i++) {
        final p = proyectos[i];
        final tieneEval = p['tieneEvaluaciones'] == true;
        final promedio = (p['promedio'] as num?)?.toDouble() ?? 0.0;
        final notaMax = (p['notaMax'] as num?)?.toDouble() ?? 0.0;
        final notaMin = (p['notaMin'] as num?)?.toDouble() ?? 0.0;
        final jurados = (p['cantidadJurados'] as int?) ?? 0;
        final par = filaGlobal % 2 == 0;

        // Determinar estilo de fila y etiqueta de posición
        final CellStyle sFila;
        final CellStyle sFilaC;
        final CellStyle sFilaNota;
        final String puestoStr;

        if (!tieneEval) {
          sFila  = par ? sDatoIzqP : sDatoIzq;
          sFilaC = par ? sDatoCPar : sDatoC;
          sFilaNota = sSinEval;
          puestoStr = '—';
        } else if (i == 0) {
          sFila = sOro; sFilaC = sOroC; sFilaNota = sOroC;
          puestoStr = '🥇 1°';
        } else if (i == 1) {
          sFila = sPlata; sFilaC = sPlataC; sFilaNota = sPlataC;
          puestoStr = '🥈 2°';
        } else if (i == 2) {
          sFila = sBronce; sFilaC = sBronceC; sFilaNota = sBronceC;
          puestoStr = '🥉 3°';
        } else {
          sFila  = par ? sDatoIzqP : sDatoIzq;
          sFilaC = par ? sDatoCPar : sDatoC;
          sFilaNota = par ? sNotaPar : sNota;
          puestoStr = '${i + 1}°';
        }

        _cel(sheet, fila, 0, '', sFilaC); // Categoría vacía (ya mostrada en header)
        _cel(sheet, fila, 1, puestoStr, sFilaC);
        _cel(sheet, fila, 2, _sv(p['codigo']), sFilaC);
        _cel(sheet, fila, 3, _sv(p['titulo']), sFila);
        _cel(sheet, fila, 4, _sv(p['integrantes']), sFila);
        _cel(sheet, fila, 5, _sv(p['asesor']), sFila);
        _cel(sheet, fila, 6, _sv(p['sala']), sFilaC);

        if (tieneEval) {
          _celDouble(sheet, fila, 7, promedio, sFilaNota);
          _celDouble(sheet, fila, 8, notaMax, sFilaNota);
          _celDouble(sheet, fila, 9, notaMin, sFilaNota);
          _celNum(sheet, fila, 10, jurados, sFilaNota);
        } else {
          _cel(sheet, fila, 7, 'S/E', sSinEval);
          _cel(sheet, fila, 8, 'S/E', sSinEval);
          _cel(sheet, fila, 9, 'S/E', sSinEval);
          _cel(sheet, fila, 10, '—', sSinEval);
        }

        sheet.setRowHeight(fila, 18);
        fila++;
        filaGlobal++;
      }

      // Fila estadísticas de la categoría
      final conEval =
          proyectos.where((p) => p['tieneEvaluaciones'] == true).toList();
      if (conEval.isNotEmpty) {
        final promedios =
            conEval.map((p) => (p['promedio'] as num).toDouble()).toList();
        final maxCat = promedios.reduce((a, b) => a > b ? a : b);
        final minCat = promedios.reduce((a, b) => a < b ? a : b);
        final avgCat = promedios.reduce((a, b) => a + b) / promedios.length;

        _cel(sheet, fila, 0,
            '  ∑  ${conEval.length} evaluados / ${proyectos.length} total',
            sStatLabel);
        _merge(sheet, fila, 0, fila, 6);
        _cel(sheet, fila, 7, avgCat.toStringAsFixed(2), sStatVal);
        _cel(sheet, fila, 8, maxCat.toStringAsFixed(2), sStatVal);
        _cel(sheet, fila, 9, minCat.toStringAsFixed(2), sStatVal);
        _cel(sheet, fila, 10, '', sStatVal);
        sheet.setRowHeight(fila, 18);
        fila++;
      }

      // Separador visual entre categorías
      sheet.setRowHeight(fila, 6);
      fila++;
    }

    // ── Merges banner y metadatos ─────────────────────────────────────────────
    _merge(sheet, 0, 0, 0, 10);
    _merge(sheet, 1, 0, 1, 10);
    for (int c = 0; c <= 10; c++) {} // separador ya puesto celda a celda

    // ── Anchos de columna ─────────────────────────────────────────────────────
    sheet.setColumnWidth(0, 24);
    sheet.setColumnWidth(1, 9);
    sheet.setColumnWidth(2, 12);
    sheet.setColumnWidth(3, 40);
    sheet.setColumnWidth(4, 30);
    sheet.setColumnWidth(5, 22);
    sheet.setColumnWidth(6, 7);
    sheet.setColumnWidth(7, 11);
    sheet.setColumnWidth(8, 9);
    sheet.setColumnWidth(9, 9);
    sheet.setColumnWidth(10, 9);

    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 22);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOJA 2 — Lista Completa de Proyectos
  // ═══════════════════════════════════════════════════════════════════════════
  void _crearHojaListaCompleta({
    required Excel excel,
    required List<Map<String, dynamic>> todos,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    String? carrera,
  }) {
    final sheet = excel['Lista Completa'];

    // ── Estilos ───────────────────────────────────────────────────────────────
    final sTitulo = CellStyle(
      bold: true,
      fontSize: 15,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sSubtitulo = CellStyle(
      bold: false,
      fontSize: 11,
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
    // Columna Promedio con acento verde
    final sEncPromedio = CellStyle(
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

    // Badges de rendimiento
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
    final sBadgeEstado = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_greenLight),
      fontColorHex: ExcelColor.fromHexString(_greenDark),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sSinEval = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray400),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sSinEvalEstado = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_gray100),
      fontColorHex: ExcelColor.fromHexString(_gray400),
      horizontalAlign: HorizontalAlign.Center,
    );

    // ── Banner ────────────────────────────────────────────────────────────────
    _cel(sheet, 0, 0, '  LISTA COMPLETA DE PROYECTOS', sTitulo);
    _cel(sheet, 1, 0, '  ${eventoNombre.toUpperCase()}', sSubtitulo);
    for (int c = 0; c <= 9; c++) _cel(sheet, 2, c, '', sSeparador);
    sheet.setRowHeight(2, 4);

    // ── Metadatos ─────────────────────────────────────────────────────────────
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
      _merge(sheet, i + 3, 1, i + 3, 9);
      sheet.setRowHeight(i + 3, 16);
    }
    sheet.setRowHeight(9, 8);

    // ── Encabezados de tabla ──────────────────────────────────────────────────
    const fEnc = 10;
    const encabezados = [
      'N°', 'CÓDIGO', 'TÍTULO DEL PROYECTO',
      'CATEGORÍA', 'INTEGRANTES', 'ASESOR',
      'SALA', 'PROMEDIO', 'JURADOS', 'ESTADO',
    ];
    for (int c = 0; c < encabezados.length; c++) {
      _cel(sheet, fEnc, c, encabezados[c], c == 7 ? sEncPromedio : sEnc);
    }
    sheet.setRowHeight(fEnc, 28);

    // Nota máxima para badge relativo
    final maxPromedio = todos.isEmpty
        ? 1.0
        : todos
            .where((p) => p['tieneEvaluaciones'] == true)
            .map((p) => (p['promedio'] as num?)?.toDouble() ?? 0.0)
            .fold(0.0, (a, b) => a > b ? a : b)
            .clamp(0.1, 999.0);

    // ── Filas de datos ────────────────────────────────────────────────────────
    for (int i = 0; i < todos.length; i++) {
      final p = todos[i];
      final fila = fEnc + 1 + i;
      final par = i % 2 == 0;
      final tieneEval = p['tieneEvaluaciones'] == true;
      final promedio = (p['promedio'] as num?)?.toDouble() ?? 0.0;
      final jurados = (p['cantidadJurados'] as int?) ?? 0;

      final sI = par ? sIzqP : sIzq;
      final sC = par ? sCenP : sCen;

      _cel(sheet, fila, 0, '${i + 1}', sC);
      _cel(sheet, fila, 1, _sv(p['codigo']), sC);
      _cel(sheet, fila, 2, _sv(p['titulo']), sI);
      _cel(sheet, fila, 3, _sv(p['_categoria'] ?? p['clasificacion']), sC);
      _cel(sheet, fila, 4, _sv(p['integrantes']), sI);
      _cel(sheet, fila, 5, _sv(p['asesor']), sI);
      _cel(sheet, fila, 6, _sv(p['sala']), sC);

      if (tieneEval) {
        final ratio = promedio / maxPromedio;
        final sBadge = ratio >= 0.66 ? sBadgeAlto
            : ratio >= 0.33 ? sBadgeMedio
            : sBadgeBajo;
        _celDouble(sheet, fila, 7, promedio, sBadge);
        _celNum(sheet, fila, 8, jurados, sC);
        _cel(sheet, fila, 9, '✓ Evaluado', sBadgeEstado);
      } else {
        _cel(sheet, fila, 7, 'S/E', sSinEval);
        _cel(sheet, fila, 8, '—', sSinEval);
        _cel(sheet, fila, 9, 'Pendiente', sSinEvalEstado);
      }

      sheet.setRowHeight(fila, 18);
    }

    // ── Merges ────────────────────────────────────────────────────────────────
    _merge(sheet, 0, 0, 0, 9);
    _merge(sheet, 1, 0, 1, 9);

    // ── Anchos ────────────────────────────────────────────────────────────────
    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 12);
    sheet.setColumnWidth(2, 40);
    sheet.setColumnWidth(3, 22);
    sheet.setColumnWidth(4, 30);
    sheet.setColumnWidth(5, 22);
    sheet.setColumnWidth(6, 7);
    sheet.setColumnWidth(7, 11);
    sheet.setColumnWidth(8, 9);
    sheet.setColumnWidth(9, 13);

    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 22);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOJA 3 — Podio por Categoría
  // ═══════════════════════════════════════════════════════════════════════════
  void _crearHojaPodio({
    required Excel excel,
    required Map<String, List<Map<String, dynamic>>> participantesPorCategoria,
    required String eventoNombre,
  }) {
    final sheet = excel['Podio por Categoría'];

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

    // Sección de categoría — navy completo
    final sEncCat = CellStyle(
      bold: true, fontSize: 11,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    // Encabezados de cada lugar
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

    // Label de campo (izquierda, gris suave)
    final sLabel = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray700),
      backgroundColorHex: ExcelColor.fromHexString(_gray100),
    );

    // Valores por lugar
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

    // Nota grande del podio
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

    // ── Banner ────────────────────────────────────────────────────────────────
    _cel(sheet, 0, 0, '  PODIO DE GANADORES POR CATEGORÍA', sTitulo);
    _cel(sheet, 1, 0, '  ${eventoNombre.toUpperCase()}', sSubtitulo);
    for (int c = 0; c <= 6; c++) _cel(sheet, 2, c, '', sSeparador);
    sheet.setRowHeight(2, 4);
    _merge(sheet, 0, 0, 0, 6);
    _merge(sheet, 1, 0, 1, 6);

    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 22);

    // Fila de separación extra antes del contenido
    sheet.setRowHeight(3, 10);
    int fila = 4;

    for (final entry in participantesPorCategoria.entries) {
      final categoria = entry.key;
      final proyectos =
          entry.value.where((p) => p['tieneEvaluaciones'] == true).toList();

      if (proyectos.isEmpty) continue;

      // ── Encabezado de categoría ───────────────────────────────────────────
      _cel(sheet, fila, 0, '  $categoria', sEncCat);
      _merge(sheet, fila, 0, fila, 6);
      sheet.setRowHeight(fila, 26);
      fila++;

      // ── Encabezados de los 3 lugares ──────────────────────────────────────
      // Layout: col 0 = etiqueta, col 1-2 = 1er lugar, col 3-4 = 2do, col 5-6 = 3ro
      _cel(sheet, fila, 0, '', sLabel); // celda vacía en col de labels
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

      // ── Filas de detalle ──────────────────────────────────────────────────
      final fields = [
        {'label': 'Título', 'key': 'titulo'},
        {'label': 'Código', 'key': 'codigo'},
        {'label': 'Integrantes', 'key': 'integrantes'},
        {'label': 'Asesor', 'key': 'asesor'},
        {'label': 'Promedio', 'key': 'promedio'},
      ];

      final valStyles = [sOroVal, sPlataVal, sBronceVal];
      final notaStyles = [sOroNota, sPlaNota, sBroNota];

      for (final field in fields) {
        final isNota = field['key'] == 'promedio';

        // Label de la fila
        _cel(sheet, fila, 0, '  ${field['label']}', sLabel);

        for (int col = 0; col < 3; col++) {
          if (col >= proyectos.length) continue;
          final p = proyectos[col];
          final sVal = isNota ? notaStyles[col] : valStyles[col];

          String val;
          if (field['key'] == 'promedio') {
            val = (p['promedio'] as num?)?.toDouble().toStringAsFixed(2) ?? '—';
          } else {
            val = _sv(p[field['key']]);
          }

          _cel(sheet, fila, 1 + col * 2, val, sVal);
          _merge(sheet, fila, 1 + col * 2, fila, 1 + col * 2 + 1);
        }

        sheet.setRowHeight(fila, isNota ? 36 : 20);
        fila++;
      }

      // Separador visual entre categorías
      sheet.setRowHeight(fila, 12);
      fila++;
    }

    // ── Anchos ────────────────────────────────────────────────────────────────
    sheet.setColumnWidth(0, 14); // col de etiquetas
    sheet.setColumnWidth(1, 22); // 1er lugar col A
    sheet.setColumnWidth(2, 22); // 1er lugar col B
    sheet.setColumnWidth(3, 22); // 2do lugar col A
    sheet.setColumnWidth(4, 22); // 2do lugar col B
    sheet.setColumnWidth(5, 22); // 3er lugar col A
    sheet.setColumnWidth(6, 22); // 3er lugar col B
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helpers internos
  // ═══════════════════════════════════════════════════════════════════════════
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

  void _celDouble(
      Sheet sheet, int row, int col, double value, CellStyle style) {
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

  String _sv(dynamic v, [String fb = '—']) {
    if (v == null) return fb;
    final s = v.toString().trim();
    return s.isEmpty ? fb : s;
  }

  String _sanitizar(String texto) {
    final s =
        texto.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').replaceAll(' ', '_');
    return s.substring(0, s.length > 40 ? 40 : s.length);
  }
}