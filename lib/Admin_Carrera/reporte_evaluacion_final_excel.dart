import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODELOS
// ═══════════════════════════════════════════════════════════════════════════

class EvalFinalConfig {
  final double pctAsistNoSel;
  final double pctDocenteNoSel;
  final bool   incluirDocenteNoSel;
  final String modalidad;
  final double pctAsistSel;
  final double pctJuradoSel;
  final double pctAsistSelMixta;
  final double pctJuradoSelMixta;
  final double pctDocenteSelMixta;

  const EvalFinalConfig({
    this.pctAsistNoSel       = 100,
    this.pctDocenteNoSel     = 0,
    this.incluirDocenteNoSel = false,
    this.modalidad           = 'jurado',
    this.pctAsistSel         = 40,
    this.pctJuradoSel        = 60,
    this.pctAsistSelMixta    = 30,
    this.pctJuradoSelMixta   = 50,
    this.pctDocenteSelMixta  = 20,
  });
}

class NotaFinalItem {
  final String studentId;
  final String nombre;
  final String codigo;
  final String ciclo;
  final String grupo;
  final bool   seleccionado;
  final String proyectoCodigo;
  final double notaAsist;
  final double notaJurado;
  final double notaDocente;
  final double notaFinal;

  const NotaFinalItem({
    required this.studentId,
    required this.nombre,
    required this.codigo,
    required this.ciclo,
    required this.grupo,
    required this.seleccionado,
    required this.proyectoCodigo,
    required this.notaAsist,
    required this.notaJurado,
    required this.notaDocente,
    required this.notaFinal,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SERVICIO PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════

class ReporteEvaluacionFinalExcelService {

  // ── Paleta ─────────────────────────────────────────────────────────────────
  static const _cobalt    = '#1A3A6E';
  static const _teal      = '#0F9D58';
  static const _tealLight = '#D7F5E6';
  static const _tealDark  = '#065F46';
  static const _purple    = '#7C3AED';
  static const _blue      = '#2563EB';
  static const _orange    = '#D97706';
  static const _gray900   = '#111827';
  static const _gray700   = '#374151';
  static const _gray100   = '#F3F4F6';
  static const _white     = '#FFFFFF';
  static const _surface   = '#F8FAFC';

  // ── Punto de entrada ───────────────────────────────────────────────────────
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

      // Orden: ciclo → grupo (numérico) → grupo único al final → nombre
      final seleccionados = notas.where((n) => n.seleccionado).toList()
        ..sort(_ordenCicloGrupo);
      final noSeleccionados = notas.where((n) => !n.seleccionado).toList()
        ..sort(_ordenCicloGrupo);

      _crearHoja(
        excel:       excel,
        nombreHoja:  'SELECCIONADOS',
        notas:       seleccionados,
        config:      config,
        eventoNombre: eventoNombre,
        filialNombre: filialNombre,
        facultad:    facultad,
        carrera:     carrera,
        mostrarJurado: true,
        mostrarDocente: config.modalidad == 'mixta',
        bannerColor: _purple,
      );

      _crearHoja(
        excel:       excel,
        nombreHoja:  'NO SELECCIONADOS',
        notas:       noSeleccionados,
        config:      config,
        eventoNombre: eventoNombre,
        filialNombre: filialNombre,
        facultad:    facultad,
        carrera:     carrera,
        mostrarJurado: false,
        mostrarDocente: config.incluirDocenteNoSel,
        bannerColor: _cobalt,
      );

      excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) return null;

      final dir = await getTemporaryDirectory();
      final fecha = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

      // Nombre del archivo: prioriza el evento; si está vacío usa carrera;
      // si todo falla, un nombre genérico.
      final base = eventoNombre.trim().isNotEmpty
          ? eventoNombre
          : (carrera.trim().isNotEmpty ? carrera : 'Reporte');

      final file = File('${dir.path}/EvalFinal_${_sanitizar(base)}_$fecha.xlsx');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e, st) {
      debugPrint('❌ Error generando Excel: $e\n$st');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOJA GENÉRICA (usada tanto para SELECCIONADOS como NO SELECCIONADOS)
  // ═══════════════════════════════════════════════════════════════════════════
  void _crearHoja({
    required Excel  excel,
    required String nombreHoja,
    required List<NotaFinalItem> notas,
    required EvalFinalConfig config,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    required String carrera,
    required bool   mostrarJurado,
    required bool   mostrarDocente,
    required String bannerColor,
  }) {
    final sheet = excel[nombreHoja];

    // ── Estilos base ──────────────────────────────────────────────────────────
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

    // Calcular lastCol dinámico:
    // Columnas fijas: N°(0), NOMBRE(1), CÓDIGO(2), CICLO(3), GRUPO(4) = 5 cols
    // + N1(5) siempre
    // + N2(6) si mostrarJurado
    // + N3   si mostrarDocente
    // + NOTA FINAL al final
    int lastCol = 5; // N1
    if (mostrarJurado)  lastCol++; // N2
    if (mostrarDocente) lastCol++; // N3
    // NOTA FINAL
    final colNotaFinal = lastCol;
    lastCol = colNotaFinal; // ya está en su lugar

    // ── Banner ────────────────────────────────────────────────────────────────
    _cel(sheet, 0, 0, '  $nombreHoja — EVALUACIÓN FINAL', sTitulo);
    _cel(sheet, 1, 0, '  ${eventoNombre.toUpperCase()}', sSubtitulo);
    for (int c = 0; c <= lastCol; c++) _cel(sheet, 2, c, '', sSep);
    _merge(sheet, 0, 0, 0, lastCol);
    _merge(sheet, 1, 0, 1, lastCol);
    sheet.setRowHeight(0, 36);
    sheet.setRowHeight(1, 24);
    sheet.setRowHeight(2, 4);

    // ── Metadatos (sin PONDERACIÓN) ───────────────────────────────────────────
    final fechaGen = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final metas = [
      ['  FILIAL',    filialNombre],
      ['  FACULTAD',  facultad],
      ['  CARRERA',   carrera],
      ['  GENERADO',  fechaGen],
    ];
    for (int i = 0; i < metas.length; i++) {
      _cel(sheet, i + 3, 0, metas[i][0], sMetaLbl);
      _cel(sheet, i + 3, 1, '  ${metas[i][1]}', sMetaVal);
      _merge(sheet, i + 3, 1, i + 3, lastCol);
      sheet.setRowHeight(i + 3, 16);
    }
    sheet.setRowHeight(7, 8);

    // ── Encabezados ───────────────────────────────────────────────────────────
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
    // NOTA FINAL: mismo color que encabezados base (cobalt), sin semáforo
    final sEncFinal = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_cobalt),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    const fEnc = 8;
    int col = 0;
    _cel(sheet, fEnc, col++, 'N°',              sEncBase);
    _cel(sheet, fEnc, col++, 'NOMBRE COMPLETO', sEncBase);
    _cel(sheet, fEnc, col++, 'CÓDIGO UNIV.',    sEncBase);
    _cel(sheet, fEnc, col++, 'CICLO',           sEncBase);
    _cel(sheet, fEnc, col++, 'GRUPO',           sEncBase);
    _cel(sheet, fEnc, col++, 'N1 – ASIST.',     sEncN1);
    if (mostrarJurado)  _cel(sheet, fEnc, col++, 'N2 – JURADO',   sEncN2);
    if (mostrarDocente) _cel(sheet, fEnc, col++, 'N3 – DOCENTE',  sEncN3);
    _cel(sheet, fEnc, col,   'NOTA FINAL',      sEncFinal);
    sheet.setRowHeight(fEnc, 28);

    // ── Estilos de filas de datos ─────────────────────────────────────────────
    final sIzq  = CellStyle(fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900));
    final sCen  = CellStyle(fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900),
        horizontalAlign: HorizontalAlign.Center);
    final sIzqP = CellStyle(fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900),
        backgroundColorHex: ExcelColor.fromHexString(_surface));
    final sCenP = CellStyle(fontSize: 9, fontColorHex: ExcelColor.fromHexString(_gray900),
        backgroundColorHex: ExcelColor.fromHexString(_surface),
        horizontalAlign: HorizontalAlign.Center);

    // NOTA FINAL: estilo neutro igual que las demás celdas centradas
    // (sin color de semáforo — solo bold para destacar)
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

    // ── Filas de datos ────────────────────────────────────────────────────────
    for (int i = 0; i < notas.length; i++) {
      final n    = notas[i];
      final fila = fEnc + 1 + i;
      final par  = i % 2 == 0;
      final sI   = par ? sIzqP : sIzq;
      final sC   = par ? sCenP : sCen;
      final sNF  = par ? sNotaFinalP : sNotaFinalN;

      int c2 = 0;
      _celNum(sheet, fila, c2++, i + 1,    sC);
      _cel(sheet, fila,    c2++, n.nombre, sI);
      _cel(sheet, fila,    c2++, n.codigo, sC);
      _cel(sheet, fila,    c2++, n.ciclo,  sC);
      _cel(sheet, fila,    c2++, n.grupo,  sC);
      _celDec(sheet, fila, c2++, n.notaAsist,  sC);
      if (mostrarJurado)  _celDec(sheet, fila, c2++, n.notaJurado,  sC);
      if (mostrarDocente) _celDec(sheet, fila, c2++, n.notaDocente, sC);
      _celDec(sheet, fila, c2, n.notaFinal, sNF);
      sheet.setRowHeight(fila, 18);
    }

    // ── Fila de estadísticas ──────────────────────────────────────────────────
    if (notas.isNotEmpty) {
      final fTot = fEnc + 1 + notas.length;
      final prom = notas.map((n) => n.notaFinal).reduce((a, b) => a + b) / notas.length;
      final maxN = notas.map((n) => n.notaFinal).reduce((a, b) => a > b ? a : b);
      final minN = notas.map((n) => n.notaFinal).reduce((a, b) => a < b ? a : b);
      final aprobados = notas.where((n) => n.notaFinal >= 11).length;

      final sStat = CellStyle(
        bold: true, fontSize: 9,
        backgroundColorHex: ExcelColor.fromHexString(_tealLight),
        fontColorHex: ExcelColor.fromHexString(_tealDark),
      );
      _cel(sheet, fTot, 0,
          '  ${notas.length} estudiantes  —  Aprobados: $aprobados  '
          '|  Promedio: ${prom.toStringAsFixed(2)}  '
          '|  Máx: ${maxN.toStringAsFixed(2)}  '
          '|  Mín: ${minN.toStringAsFixed(2)}',
          sStat);
      _merge(sheet, fTot, 0, fTot, lastCol);
      sheet.setRowHeight(fTot, 20);
    }

    // ── Anchos ────────────────────────────────────────────────────────────────
    sheet.setColumnWidth(0,  5);   // N°
    sheet.setColumnWidth(1,  34);  // Nombre
    sheet.setColumnWidth(2,  16);  // Código
    sheet.setColumnWidth(3,  8);   // Ciclo
    sheet.setColumnWidth(4,  10);  // Grupo
    int wCol = 5;
    sheet.setColumnWidth(wCol++, 14); // N1
    if (mostrarJurado)  sheet.setColumnWidth(wCol++, 14); // N2
    if (mostrarDocente) sheet.setColumnWidth(wCol++, 14); // N3
    sheet.setColumnWidth(wCol, 14);   // Nota final
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS DE ORDEN (ciclo → grupo → único al final → nombre)
  // ═══════════════════════════════════════════════════════════════════════════
  int _ciclo(String c) {
    if (c.trim().isEmpty || c == 'N/A') return 999;
    final m = RegExp(r'\d+').firstMatch(c);
    return m != null ? int.parse(m.group(0)!) : 999;
  }

  int _grupo(String g) {
    final s = g.toLowerCase().trim();
    if (s.isEmpty || s == 'n/a') return 9999;
    if (s.contains('único') || s.contains('unico')) return 9998; // único al final
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

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS DE CELDAS
  // ═══════════════════════════════════════════════════════════════════════════
  void _cel(Sheet sheet, int row, int col, String value, CellStyle style) {
    final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value     = TextCellValue(value);
    cell.cellStyle = style;
  }

  void _celNum(Sheet sheet, int row, int col, int value, CellStyle style) {
    final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value     = IntCellValue(value);
    cell.cellStyle = style;
  }

  void _celDec(Sheet sheet, int row, int col, double value, CellStyle style) {
    final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value     = DoubleCellValue(double.parse(value.toStringAsFixed(2)));
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

// ═══════════════════════════════════════════════════════════════════════════
// BOTÓN DE EXPORTAR
// ═══════════════════════════════════════════════════════════════════════════
class BotonExportarEvaluacionFinal extends StatefulWidget {
  final List<NotaFinalItem> notas;
  final EvalFinalConfig config;
  final String eventoNombre;
  final String filialNombre;
  final String facultad;
  final String carrera;
  final void Function(String path)? onExportado;

  const BotonExportarEvaluacionFinal({
    super.key,
    required this.notas,
    required this.config,
    required this.eventoNombre,
    required this.filialNombre,
    required this.facultad,
    required this.carrera,
    this.onExportado,
  });

  @override
  State<BotonExportarEvaluacionFinal> createState() =>
      _BotonExportarEvaluacionFinalState();
}

class _BotonExportarEvaluacionFinalState
    extends State<BotonExportarEvaluacionFinal>
    with SingleTickerProviderStateMixin {
  bool _exportando = false;
  late AnimationController _pulse;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _exportar() async {
    if (_exportando || widget.notas.isEmpty) return;
    setState(() => _exportando = true);
    _pulse.repeat(reverse: true);

    try {
      final service = ReporteEvaluacionFinalExcelService();
      final path = await service.generarReporte(
        notas:        widget.notas,
        config:       widget.config,
        eventoNombre: widget.eventoNombre,
        filialNombre: widget.filialNombre,
        facultad:     widget.facultad,
        carrera:      widget.carrera,
      );

      if (!mounted) return;

      if (path != null) {
        widget.onExportado?.call(path);
        _mostrarOpcionesArchivo(path);
      } else {
        _mostrarError('No se pudo generar el archivo Excel.');
      }
    } catch (e) {
      if (mounted) _mostrarError('Error: $e');
    } finally {
      _pulse.stop();
      _pulse.reset();
      if (mounted) setState(() => _exportando = false);
    }
  }

  void _mostrarOpcionesArchivo(String path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle,
                  color: Color(0xFF059669), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Reporte generado',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const Text('¿Qué deseas hacer con el archivo Excel?',
            style: TextStyle(fontSize: 14, color: Colors.black54)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final result = await OpenFilex.open(path);
                if (result.type != ResultType.done && mounted) {
                  _mostrarError(
                      'No se encontró una app para abrir Excel. Prueba compartirlo.');
                }
              },
              icon: const Icon(Icons.open_in_new, size: 20),
              label: const Text('Abrir archivo',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2342),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await Share.shareXFiles(
                  [XFile(path)],
                  subject:
                      'Reporte Evaluación Final — ${widget.eventoNombre}',
                );
              },
              icon: const Icon(Icons.share, size: 20),
              label: const Text('Compartir',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F2342),
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(
                    color: Color(0xFF0F2342), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final habilitado = widget.notas.isNotEmpty && !_exportando;

    return ScaleTransition(
      scale: _scaleAnim,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          gradient: habilitado
              ? const LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF0F9D58)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: habilitado ? null : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(14),
          boxShadow: habilitado
              ? [
                  BoxShadow(
                    color: const Color(0xFF059669).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: habilitado ? _exportar : null,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _exportando
                        ? const SizedBox(
                            key: ValueKey('loading'),
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(
                            key: ValueKey('icon'),
                            Icons.file_download_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _exportando ? 'Generando Excel...' : 'Exportar Excel',
                      key: ValueKey(_exportando),
                      style: TextStyle(
                        color: habilitado
                            ? Colors.white
                            : Colors.grey.shade500,
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (habilitado) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${widget.notas.length}',
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}