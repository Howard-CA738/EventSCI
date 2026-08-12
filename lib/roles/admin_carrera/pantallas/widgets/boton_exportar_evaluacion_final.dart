import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../datos/eval_final_config.dart';
import '../../datos/nota_final_item.dart';
import '../../logica/reporte_evaluacion_final_excel_service.dart';

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
  late Animation<double> _scaleAnim;

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
        notas: widget.notas,
        config: widget.config,
        eventoNombre: widget.eventoNombre,
        filialNombre: widget.filialNombre,
        facultad: widget.facultad,
        carrera: widget.carrera,
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
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
                  subject: 'Reporte Evaluación Final — ${widget.eventoNombre}',
                );
              },
              icon: const Icon(Icons.share, size: 20),
              label: const Text('Compartir',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F2342),
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: Color(0xFF0F2342), width: 1.5),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                              valueColor: AlwaysStoppedAnimation(Colors.white),
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
                        color: habilitado ? Colors.white : Colors.grey.shade500,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (habilitado) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${widget.notas.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
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
