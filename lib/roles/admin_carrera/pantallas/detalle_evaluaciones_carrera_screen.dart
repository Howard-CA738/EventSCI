import 'package:flutter/material.dart';
import '/shared/logica/gestion_criterios.dart';
import '/roles/admin_carrera/logica/evaluaciones_carrera_excel.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../logica/detalle_evaluaciones_carrera_service.dart';
import 'editar_notas_screen.dart';
import 'widgets/detalle_evaluaciones_widgets.dart';

class DetalleEvaluacionesCarreraScreen extends StatefulWidget {
  final String eventoId;
  final String eventoNombre;
  final List<Map<String, dynamic>> evaluaciones;
  final String filialNombre;
  final String facultad;
  final String carrera;

  const DetalleEvaluacionesCarreraScreen({
    super.key,
    required this.eventoId,
    required this.eventoNombre,
    required this.evaluaciones,
    required this.filialNombre,
    required this.facultad,
    required this.carrera,
  });

  @override
  State<DetalleEvaluacionesCarreraScreen> createState() =>
      _DetalleEvaluacionesCarreraScreenState();
}

class _DetalleEvaluacionesCarreraScreenState
    extends State<DetalleEvaluacionesCarreraScreen>
    with TickerProviderStateMixin {
  final _service = DetalleEvaluacionesCarreraService();
  final EvaluacionesCarreraExcelService _excelService =
      EvaluacionesCarreraExcelService();
  bool _isGeneratingExcel = false;
  late TabController _tabController;
  late List<Map<String, dynamic>> _evaluaciones;
  late AnimationController _headerAnim;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _evaluaciones = List<Map<String, dynamic>>.from(widget.evaluaciones);
    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerAnim.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerAnim.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _pendientes =>
      _evaluaciones.where((e) => !(e['evaluada'] as bool)).toList();

  List<Map<String, dynamic>> get _evaluadas =>
      _evaluaciones.where((e) => e['evaluada'] as bool).toList();

  Future<void> _toggleBloqueo(Map<String, dynamic> evaluacion) async {
    final bloqueada = evaluacion['bloqueada'] as bool;
    final nuevoEstado = !bloqueada;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: nuevoEstado ? 'Bloquear evaluación' : 'Desbloquear evaluación',
        message: nuevoEstado
            ? 'El jurado no podrá modificar esta evaluación una vez bloqueada.'
            : 'El jurado podrá volver a calificar este proyecto.',
        confirmLabel: nuevoEstado ? 'Bloquear' : 'Desbloquear',
        confirmColor: nuevoEstado ? DColores.danger : DColores.success,
        icon: nuevoEstado ? Icons.lock_rounded : Icons.lock_open_rounded,
      ),
    );

    if (confirmar != true) return;

    try {
      await _service.toggleBloqueo(
        eventoId: widget.eventoId,
        proyectoId: evaluacion['proyectoId'] as String,
        juradoId: evaluacion['juradoId'] as String,
        nuevoEstado: nuevoEstado,
      );

      setState(() {
        final idx = _evaluaciones.indexWhere(
          (e) =>
              e['proyectoId'] == evaluacion['proyectoId'] &&
              e['juradoId'] == evaluacion['juradoId'],
        );
        if (idx != -1) {
          _evaluaciones[idx]['bloqueada'] = nuevoEstado;
          if (!nuevoEstado) _evaluaciones[idx]['evaluada'] = false;
        }
      });

      _showSnack(
        nuevoEstado ? 'Evaluación bloqueada' : 'Evaluación desbloqueada',
        nuevoEstado ? DColores.danger : DColores.success,
        nuevoEstado ? Icons.lock_rounded : Icons.lock_open_rounded,
      );
    } catch (e) {
      _showSnack('Error: $e', DColores.danger, Icons.error_outline_rounded);
    }
  }

  void _verDetalle(Map<String, dynamic> evaluacion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DetalleBottomSheet(evaluacion: evaluacion),
    );
  }

  Future<void> _exportarExcel() async {
    if (_evaluaciones.isEmpty) return;

    if (!mounted) return;
    setState(() => _isGeneratingExcel = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: DColores.purple),
            const SizedBox(height: 20),
            const Text(
              'Generando reporte Excel...',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '${_evaluaciones.length} evaluaciones',
              style: const TextStyle(fontSize: 12, color: DColores.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    try {
      final ruta = await _excelService.generarReporteEvaluaciones(
        evaluaciones: _evaluaciones,
        eventoNombre: widget.eventoNombre,
        filialNombre: widget.filialNombre,
        facultad: widget.facultad,
        carrera: widget.carrera,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isGeneratingExcel = false);

      if (ruta == null) {
        _showSnack(
            'Error al generar el reporte', DColores.danger, Icons.error_outline_rounded);
        return;
      }

      _mostrarOpcionesArchivo(ruta);
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isGeneratingExcel = false);
        _showSnack('Error: $e', DColores.danger, Icons.error_outline_rounded);
      }
    }
  }

  void _mostrarOpcionesArchivo(String ruta) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DColores.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: DColores.success, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Reporte generado',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const Text(
          '¿Qué deseas hacer con el archivo Excel?',
          style: TextStyle(fontSize: 14, color: DColores.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final result = await OpenFilex.open(ruta);
                if (result.type != ResultType.done && mounted) {
                  _showSnack(
                    'No se encontró app para abrir Excel. Prueba compartirlo.',
                    DColores.warning,
                    Icons.warning_rounded,
                  );
                }
              },
              icon: const Icon(Icons.open_in_new, size: 20),
              label: const Text('Abrir archivo',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: DColores.navy,
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
                  [XFile(ruta)],
                  subject:
                      'Reporte de Evaluaciones – ${widget.eventoNombre}',
                );
              },
              icon: const Icon(Icons.share, size: 20),
              label: const Text('Compartir',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: DColores.navy,
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: DColores.navy, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editarNotas(Map<String, dynamic> evaluacion) async {
    final rubrica = evaluacion['rubrica'] as Rubrica?;
    if (rubrica == null) {
      _showSnack(
          'No se encontró la rúbrica', DColores.danger, Icons.error_outline_rounded);
      return;
    }

    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditarNotasScreen(
          eventoId: widget.eventoId,
          evaluacion: evaluacion,
          rubrica: rubrica,
        ),
      ),
    );

    if (resultado != null) {
      setState(() {
        final idx = _evaluaciones.indexWhere(
          (e) =>
              e['proyectoId'] == evaluacion['proyectoId'] &&
              e['juradoId'] == evaluacion['juradoId'],
        );
        if (idx != -1) {
          _evaluaciones[idx]['notas'] = resultado['notas'];
          _evaluaciones[idx]['notaTotal'] = resultado['notaTotal'];
        }
      });
    }
  }

  void _showSnack(String msg, Color color, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DColores.navy,
      body: SafeArea(
        child: Column(
          children: [
            FadeTransition(
              opacity: _headerFade,
              child: _buildHeader(),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildStatsRow(),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildTabBar(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: DColores.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLista(_pendientes, esPendiente: true),
                      _buildLista(_evaluadas, esPendiente: false),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Evaluaciones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.eventoNombre,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Exportar Excel',
            child: GestureDetector(
              onTap: _isGeneratingExcel ? null : _exportarExcel,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                decoration: BoxDecoration(
                  color: _isGeneratingExcel
                      ? Colors.white.withValues(alpha: 0.08)
                      : DColores.success.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isGeneratingExcel
                        ? Colors.white.withValues(alpha: 0.15)
                        : DColores.success.withValues(alpha: 0.5),
                  ),
                ),
                child: _isGeneratingExcel
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.file_download_rounded,
                              color: Colors.white, size: 17),
                          SizedBox(width: 5),
                          Text(
                            'Excel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final total = _evaluaciones.length;
    final pct = total > 0 ? (_evaluadas.length / total) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          _statPill('Total', total, Colors.white),
          _dividerV(),
          _statPill('Pendientes', _pendientes.length, DColores.warning),
          _dividerV(),
          _statPill('Evaluadas', _evaluadas.length, DColores.success),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor:
                        Colors.white.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      pct == 1.0 ? DColores.success : DColores.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, int valor, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            valor.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerV() {
    return Container(
      height: 28,
      width: 1,
      color: Colors.white.withValues(alpha: 0.15),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: DColores.navy,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        tabs: [
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pending_actions_rounded, size: 15),
                  const SizedBox(width: 5),
                  Text('Pendientes (${_pendientes.length})'),
                ],
              ),
            ),
          ),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 15),
                  const SizedBox(width: 5),
                  Text('Evaluadas (${_evaluadas.length})'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista(List<Map<String, dynamic>> lista,
      {required bool esPendiente}) {
    if (lista.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: esPendiente
                              ? DColores.warningLight
                              : DColores.successLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          esPendiente
                              ? Icons.pending_actions_rounded
                              : Icons.assignment_turned_in_rounded,
                          size: 40,
                          color: esPendiente ? DColores.warning : DColores.success,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        esPendiente
                            ? 'Sin evaluaciones pendientes'
                            : 'Sin evaluaciones completadas',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: DColores.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        esPendiente
                            ? 'Todos los jurados han evaluado'
                            : 'Aún no hay evaluaciones completadas',
                        style: const TextStyle(
                          fontSize: 13,
                          color: DColores.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + index * 60),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (ctx, v, child) => Transform.translate(
            offset: Offset(0, 20 * (1 - v)),
            child: Opacity(opacity: v, child: child),
          ),
          child: EvaluacionCard(
            evaluacion: lista[index],
            esPendiente: esPendiente,
            onVerDetalle: () => _verDetalle(lista[index]),
            onEditar: () => _editarNotas(lista[index]),
            onToggleBloqueo: () => _toggleBloqueo(lista[index]),
          ),
        );
      },
    );
  }
}
