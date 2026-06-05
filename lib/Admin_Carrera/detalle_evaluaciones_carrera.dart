import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/logica/gestion_criterios.dart';
import 'evaluaciones_carrera_excel.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class _T {
  static const navy = Color(0xFF0F2342);
  static const accent = Color(0xFF3B82F6);
  static const accentLight = Color(0xFFDBEAFE);
  static const success = Color(0xFF059669);
  static const successLight = Color(0xFFD1FAE5);
  static const warning = Color(0xFFD97706);
  static const warningLight = Color(0xFFFEF3C7);
  static const danger = Color(0xFFDC2626);
  static const dangerLight = Color(0xFFFEE2E2);
  static const purple = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFFEDE9FE);
  static const surface = Color(0xFFF8FAFC);
  static const card = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const borderMed = Color(0xFFCBD5E1);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textTertiary = Color(0xFF94A3B8);
  static const divider = Color(0xFFF1F5F9);
}

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
      builder: (context) => _ConfirmDialog(
        title: nuevoEstado ? 'Bloquear evaluación' : 'Desbloquear evaluación',
        message: nuevoEstado
            ? 'El jurado no podrá modificar esta evaluación una vez bloqueada.'
            : 'El jurado podrá volver a calificar este proyecto.',
        confirmLabel: nuevoEstado ? 'Bloquear' : 'Desbloquear',
        confirmColor: nuevoEstado ? _T.danger : _T.success,
        icon: nuevoEstado ? Icons.lock_rounded : Icons.lock_open_rounded,
      ),
    );

    if (confirmar != true) return;

    try {
      await _firestore
          .collection('events')
          .doc(widget.eventoId)
          .collection('proyectos')
          .doc(evaluacion['proyectoId'])
          .collection('evaluaciones')
          .doc(evaluacion['juradoId'])
          .update({
        'bloqueada': nuevoEstado,
        if (!nuevoEstado) 'evaluada': false,
      });

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
        nuevoEstado ? _T.danger : _T.success,
        nuevoEstado ? Icons.lock_rounded : Icons.lock_open_rounded,
      );
    } catch (e) {
      _showSnack('Error: $e', _T.danger, Icons.error_outline_rounded);
    }
  }

  void _verDetalle(Map<String, dynamic> evaluacion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleBottomSheet(evaluacion: evaluacion),
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
            const CircularProgressIndicator(color: _T.purple),
            const SizedBox(height: 20),
            const Text(
              'Generando reporte Excel...',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '${_evaluaciones.length} evaluaciones',
              style: const TextStyle(fontSize: 12, color: _T.textSecondary),
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
            'Error al generar el reporte', _T.danger, Icons.error_outline_rounded);
        return;
      }

      _mostrarOpcionesArchivo(ruta);
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isGeneratingExcel = false);
        _showSnack('Error: $e', _T.danger, Icons.error_outline_rounded);
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
                color: _T.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: _T.success, size: 22),
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
          style: TextStyle(fontSize: 14, color: _T.textSecondary),
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
                    _T.warning,
                    Icons.warning_rounded,
                  );
                }
              },
              icon: const Icon(Icons.open_in_new, size: 20),
              label: const Text('Abrir archivo',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _T.navy,
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
                foregroundColor: _T.navy,
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: _T.navy, width: 1.5),
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
          'No se encontró la rúbrica', _T.danger, Icons.error_outline_rounded);
      return;
    }

    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _EditarNotasScreen(
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
      backgroundColor: _T.navy,
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
                  color: _T.surface,
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
                      : _T.success.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isGeneratingExcel
                        ? Colors.white.withValues(alpha: 0.15)
                        : _T.success.withValues(alpha: 0.5),
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
          _statPill('Pendientes', _pendientes.length, _T.warning),
          _dividerV(),
          _statPill('Evaluadas', _evaluadas.length, _T.success),
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
                      pct == 1.0 ? _T.success : _T.accent,
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
        labelColor: _T.navy,
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
                              ? _T.warningLight
                              : _T.successLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          esPendiente
                              ? Icons.pending_actions_rounded
                              : Icons.assignment_turned_in_rounded,
                          size: 40,
                          color: esPendiente ? _T.warning : _T.success,
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
                          color: _T.textPrimary,
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
                          color: _T.textTertiary,
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
          child: _EvaluacionCard(
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

class _EvaluacionCard extends StatelessWidget {
  final Map<String, dynamic> evaluacion;
  final bool esPendiente;
  final VoidCallback onVerDetalle;
  final VoidCallback onEditar;
  final VoidCallback onToggleBloqueo;

  const _EvaluacionCard({
    required this.evaluacion,
    required this.esPendiente,
    required this.onVerDetalle,
    required this.onEditar,
    required this.onToggleBloqueo,
  });

  @override
  Widget build(BuildContext context) {
    final bloqueada = evaluacion['bloqueada'] as bool;
    final notaTotal = (evaluacion['notaTotal'] as num).toDouble();
    final integrantes = evaluacion['integrantes']?.toString() ?? '';
    final rubricaNombre = evaluacion['rubricaNombre']?.toString() ?? '';

    final Color estadoColor;
    final IconData estadoIcon;
    final String estadoLabel;
    if (bloqueada) {
      estadoColor = _T.danger;
      estadoIcon = Icons.lock_rounded;
      estadoLabel = 'Bloqueada';
    } else if (esPendiente) {
      estadoColor = _T.warning;
      estadoIcon = Icons.hourglass_top_rounded;
      estadoLabel = 'Pendiente';
    } else {
      estadoColor = _T.success;
      estadoIcon = Icons.check_circle_rounded;
      estadoLabel = 'Evaluada';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: esPendiente ? _T.warningLight : _T.successLight,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 100),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _T.navy,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      evaluacion['codigo']?.toString() ?? '—',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: estadoColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: estadoColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(estadoIcon, size: 11, color: estadoColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              estadoLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: estadoColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!esPendiente) ...[
                    Container(
                      constraints: const BoxConstraints(maxWidth: 90),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: _T.successLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${notaTotal.toStringAsFixed(1)} pts',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _T.success,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Semantics(
                    button: true,
                    label: bloqueada
                        ? 'Desbloquear evaluación'
                        : 'Bloquear evaluación',
                    child: GestureDetector(
                      onTap: onToggleBloqueo,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bloqueada
                              ? _T.dangerLight
                              : _T.border.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          bloqueada
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          size: 18,
                          color: bloqueada ? _T.danger : _T.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                evaluacion['titulo']?.toString() ?? 'Sin título',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _T.textPrimary,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              _MetaRow(
                icon: Icons.person_rounded,
                text: evaluacion['juradoNombre']?.toString() ?? '—',
              ),
              const SizedBox(height: 4),
              if (rubricaNombre.isNotEmpty) ...[
                _MetaRow(
                  icon: Icons.checklist_rounded,
                  text: rubricaNombre,
                ),
                const SizedBox(height: 4),
              ],
              if (integrantes.isNotEmpty)
                _MetaRow(
                  icon: Icons.group_rounded,
                  text: integrantes,
                ),
              const SizedBox(height: 14),
              Container(height: 1, color: _T.divider),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Ver detalle',
                      icon: Icons.visibility_rounded,
                      onTap: onVerDetalle,
                      style: _ActionStyle.outlined,
                    ),
                  ),
                  if (!esPendiente) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        label: 'Editar nota',
                        icon: Icons.edit_rounded,
                        onTap: onEditar,
                        style: _ActionStyle.purple,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ActionStyle { outlined, purple }

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final _ActionStyle style;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final isOutlined = style == _ActionStyle.outlined;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: isOutlined ? Colors.transparent : _T.purple,
            borderRadius: BorderRadius.circular(10),
            border: isOutlined ? Border.all(color: _T.borderMed) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isOutlined ? _T.textSecondary : Colors.white,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOutlined ? _T.textSecondary : Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: _T.textTertiary),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: _T.textSecondary,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final IconData icon;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: confirmColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: confirmColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _T.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: _T.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: _T.border),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        color: _T.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      minimumSize: const Size(0, 44),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetalleBottomSheet extends StatelessWidget {
  final Map<String, dynamic> evaluacion;

  const _DetalleBottomSheet({required this.evaluacion});

  @override
  Widget build(BuildContext context) {
    final rubrica = evaluacion['rubrica'] as Rubrica?;
    final notas = evaluacion['notas'] as Map<String, dynamic>;
    final evaluada = evaluacion['evaluada'] as bool;
    final notaTotal = (evaluacion['notaTotal'] as num).toDouble();

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _T.card,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _T.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 90),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _T.navy,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  evaluacion['codigo']?.toString() ?? '—',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Jurado: ${evaluacion['juradoNombre'] ?? '—'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _T.textTertiary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            evaluacion['titulo']?.toString() ?? 'Sin título',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _T.textPrimary,
                              height: 1.3,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      constraints: const BoxConstraints(minWidth: 64),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: evaluada ? _T.successLight : _T.warningLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            notaTotal.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: evaluada ? _T.success : _T.warning,
                            ),
                          ),
                          Text(
                            'pts',
                            style: TextStyle(
                              fontSize: 10,
                              color: evaluada ? _T.success : _T.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: _T.divider),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 20),
                    if (rubrica != null) ...[
                      const Text(
                        'Criterios evaluados',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _T.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...rubrica.secciones.map(
                        (s) => _SeccionDetalleWidget(
                          seccion: s,
                          notas: notas,
                        ),
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _T.warningLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: _T.warning, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No se encontró la rúbrica asociada.',
                                style: TextStyle(
                                    color: _T.warning,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard() {
    final sala = evaluacion['sala']?.toString() ?? '';
    final integrantes = evaluacion['integrantes']?.toString() ?? '';
    final clasificacion = evaluacion['clasificacion']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _T.accentLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información del proyecto',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _T.accent,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          if (integrantes.isNotEmpty)
            _infoRow(Icons.group_rounded, 'Integrantes', integrantes),
          if (sala.isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoRow(Icons.room_rounded, 'Sala', sala),
          ],
          if (clasificacion.isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoRow(Icons.category_rounded, 'Categoría', clasificacion),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: _T.accent),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _T.textPrimary,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                      fontSize: 12, color: _T.textSecondary),
                ),
              ],
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SeccionDetalleWidget extends StatelessWidget {
  final SeccionRubrica seccion;
  final Map<String, dynamic> notas;

  const _SeccionDetalleWidget({
    required this.seccion,
    required this.notas,
  });

  @override
  Widget build(BuildContext context) {
    double puntaje = 0;
    int evaluados = 0;
    for (var c in seccion.criterios) {
      if (notas.containsKey(c.id)) {
        puntaje += (notas[c.id] as num).toDouble();
        evaluados++;
      }
    }
    final completo = evaluados == seccion.criterios.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: completo ? _T.successLight : _T.warningLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              completo
                  ? Icons.folder_special_rounded
                  : Icons.folder_open_rounded,
              color: completo ? _T.success : _T.warning,
              size: 18,
            ),
          ),
          title: Text(
            seccion.nombre,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _T.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '$evaluados/${seccion.criterios.length} criterios  ·  ${puntaje.toStringAsFixed(1)} / ${seccion.pesoTotal.toStringAsFixed(0)} pts',
            style: const TextStyle(fontSize: 11, color: _T.textTertiary),
          ),
          children: seccion.criterios.map((c) {
            final nota = notas[c.id];
            final tiene = nota != null;
            final notaVal = tiene ? (nota as num).toDouble() : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tiene
                    ? _T.successLight.withValues(alpha: 0.5)
                    : _T.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: tiene
                      ? _T.success.withValues(alpha: 0.3)
                      : _T.border,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.descripcion,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _T.textPrimary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Máx: ${c.peso.toStringAsFixed(1)} pts',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _T.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    constraints: const BoxConstraints(minWidth: 44),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: tiene ? _T.success : _T.textTertiary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tiene ? notaVal.toStringAsFixed(1) : '—',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _EditarNotasScreen extends StatefulWidget {
  final String eventoId;
  final Map<String, dynamic> evaluacion;
  final Rubrica rubrica;

  const _EditarNotasScreen({
    required this.eventoId,
    required this.evaluacion,
    required this.rubrica,
  });

  @override
  State<_EditarNotasScreen> createState() => _EditarNotasScreenState();
}

class _EditarNotasScreenState extends State<_EditarNotasScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Map<String, double?> _notasEditadas;
  bool _isGuardando = false;

  @override
  void initState() {
    super.initState();
    final notasActuales =
        widget.evaluacion['notas'] as Map<String, dynamic>;
    _notasEditadas = {};
    for (var seccion in widget.rubrica.secciones) {
      for (var criterio in seccion.criterios) {
        final nota = notasActuales[criterio.id];
        _notasEditadas[criterio.id] =
            nota != null ? (nota as num).toDouble() : null;
      }
    }
  }

  double get _notaTotalActual {
    double total = 0;
    for (var nota in _notasEditadas.values) {
      if (nota != null) total += nota;
    }
    return total;
  }

  int get _criteriosCompletos =>
      _notasEditadas.values.where((n) => n != null).length;

  int get _totalCriterios => _notasEditadas.length;

  double get _progreso =>
      _totalCriterios > 0 ? _criteriosCompletos / _totalCriterios : 0.0;

  Future<void> _guardarCambios() async {
    for (var seccion in widget.rubrica.secciones) {
      for (var criterio in seccion.criterios) {
        if (_notasEditadas[criterio.id] == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Faltan criterios en "${seccion.nombre}"',
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: _T.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ));
          return;
        }
      }
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: 'Guardar cambios',
        message:
            'La nota total será ${_notaTotalActual.toStringAsFixed(1)} pts.\n¿Confirmas los cambios?',
        confirmLabel: 'Guardar',
        confirmColor: _T.purple,
        icon: Icons.save_rounded,
      ),
    );

    if (confirmar != true) return;

    setState(() => _isGuardando = true);

    try {
      final Map<String, dynamic> notasGuardar = {
        for (var e in _notasEditadas.entries) e.key: e.value!,
      };

      await _firestore
          .collection('events')
          .doc(widget.eventoId)
          .collection('proyectos')
          .doc(widget.evaluacion['proyectoId'])
          .collection('evaluaciones')
          .doc(widget.evaluacion['juradoId'])
          .update({
        'notas': notasGuardar,
        'notaTotal': _notaTotalActual,
        'editadoPorAdmin': true,
        'fechaEdicionAdmin': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Notas actualizadas correctamente',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            backgroundColor: _T.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context, {
          'notas': notasGuardar,
          'notaTotal': _notaTotalActual,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error al guardar: $e',
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: _T.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGuardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.navy,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.12),
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
                        Text(
                          'Editar · ${widget.evaluacion['codigo'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.rubrica.nombre,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Colors.white.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_isGuardando)
                    Semantics(
                      button: true,
                      label: 'Guardar cambios',
                      child: GestureDetector(
                        onTap: _guardarCambios,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          constraints: const BoxConstraints(
                              minWidth: 44, minHeight: 44),
                          decoration: BoxDecoration(
                            color: _T.purple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.save_rounded,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Guardar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
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
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: _T.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: _isGuardando
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: _T.purple),
                            SizedBox(height: 16),
                            Text('Guardando cambios...',
                                style: TextStyle(
                                    color: _T.textSecondary,
                                    fontSize: 14)),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                        child: ListView(
                          padding:
                              const EdgeInsets.fromLTRB(16, 20, 16, 100),
                          children: [
                            _buildProgresoCard(),
                            const SizedBox(height: 16),
                            ...widget.rubrica.secciones
                                .map((s) => _buildSeccionEditable(s)),
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

  Widget _buildProgresoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _T.purpleLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _T.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_note_rounded,
                    color: _T.purple, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Progreso de edición',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _T.purple,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _progresoStat(
                  'Criterios',
                  '$_criteriosCompletos / $_totalCriterios',
                  _T.purple,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: _T.purple.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _progresoStat(
                  'Nota total',
                  '${_notaTotalActual.toStringAsFixed(1)} / ${widget.rubrica.puntajeMaximo.toStringAsFixed(0)}',
                  _T.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progreso,
              minHeight: 7,
              backgroundColor: _T.purple.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                _progreso == 1.0 ? _T.success : _T.purple,
              ),
            ),
          ),
          if (_progreso == 1.0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: _T.success, size: 14),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Todos los criterios completados',
                    style: TextStyle(
                      fontSize: 11,
                      color: _T.success,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _progresoStat(String label, String valor, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: _T.textTertiary)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionEditable(SeccionRubrica seccion) {
    double puntajeSeccion = 0;
    int evaluados = 0;
    for (var c in seccion.criterios) {
      final n = _notasEditadas[c.id];
      if (n != null) {
        puntajeSeccion += n;
        evaluados++;
      }
    }
    final completo = evaluados == seccion.criterios.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: completo ? _T.successLight : _T.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: completo ? _T.successLight : _T.warningLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              completo
                  ? Icons.check_circle_rounded
                  : Icons.pending_rounded,
              color: completo ? _T.success : _T.warning,
              size: 18,
            ),
          ),
          title: Text(
            seccion.nombre,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _T.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '$evaluados/${seccion.criterios.length} criterios  ·  ${puntajeSeccion.toStringAsFixed(1)} / ${seccion.pesoTotal.toStringAsFixed(0)} pts',
            style: const TextStyle(fontSize: 11, color: _T.textTertiary),
          ),
          children: seccion.criterios
              .map((c) => _buildCriterioEditable(c))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCriterioEditable(Criterio criterio) {
    final notaSeleccionada = _notasEditadas[criterio.id];
    final pesoMaximo = criterio.peso;

    final List<double> opciones = [];
    double valor = 0;
    while (valor <= pesoMaximo + 0.001) {
      opciones.add(double.parse(valor.toStringAsFixed(1)));
      valor += 0.5;
    }
    if (opciones.isEmpty ||
        (opciones.last - pesoMaximo).abs() > 0.001) {
      opciones.add(pesoMaximo);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: notaSeleccionada != null
            ? _T.successLight.withValues(alpha: 0.4)
            : _T.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notaSeleccionada != null
              ? _T.success.withValues(alpha: 0.4)
              : _T.border,
          width: notaSeleccionada != null ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  criterio.descripcion,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _T.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _T.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Máx ${pesoMaximo.toStringAsFixed(1)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _T.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: notaSeleccionada != null
                  ? _T.success.withValues(alpha: 0.1)
                  : _T.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  notaSeleccionada != null
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 13,
                  color: notaSeleccionada != null
                      ? _T.success
                      : _T.warning,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    notaSeleccionada != null
                        ? 'Nota: ${notaSeleccionada.toStringAsFixed(1)} pts'
                        : 'Sin calificar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: notaSeleccionada != null
                          ? _T.success
                          : _T.warning,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          opciones.length <= 10
              ? _buildChips(criterio, opciones, notaSeleccionada)
              : _buildDropdown(criterio, opciones, notaSeleccionada),
        ],
      ),
    );
  }

  Widget _buildChips(Criterio criterio, List<double> opciones,
      double? notaSeleccionada) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: opciones.map((nota) {
        final sel = notaSeleccionada == nota;
        return Semantics(
          button: true,
          selected: sel,
          label: 'Nota ${nota.toStringAsFixed(1)}',
          child: GestureDetector(
            onTap: () =>
                setState(() => _notasEditadas[criterio.id] = nota),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? _T.purple : _T.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: sel ? _T.purple : _T.borderMed,
                  width: sel ? 1.5 : 1,
                ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: _T.purple.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Text(
                nota.toStringAsFixed(
                    nota.truncateToDouble() == nota ? 0 : 1),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : _T.purple,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropdown(Criterio criterio, List<double> opciones,
      double? notaSeleccionada) {
    return Container(
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: notaSeleccionada != null ? _T.purple : _T.borderMed,
          width: notaSeleccionada != null ? 1.5 : 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          value: notaSeleccionada,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          hint: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Selecciona una nota',
              style: TextStyle(fontSize: 13, color: _T.textTertiary),
            ),
          ),
          icon: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.keyboard_arrow_down_rounded,
                color: _T.purple, size: 22),
          ),
          items: opciones.map((nota) {
            return DropdownMenuItem<double>(
              value: nota,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  nota.toStringAsFixed(
                      nota.truncateToDouble() == nota ? 0 : 1),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _T.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _notasEditadas[criterio.id] = v);
            }
          },
        ),
      ),
    );
  }
}