import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import '/login.dart';
import '/shared/logica/gestion_criterios.dart';
import '/roles/jurados/logica/jurado_proyectos_service.dart';
import 'evaluacion_proyecto_screen.dart';
import 'jurado_certificados_tab.dart';

class JuradosScreen extends StatefulWidget {
  const JuradosScreen({super.key});

  @override
  State<JuradosScreen> createState() => _JuradosScreenState();
}

class _JuradosScreenState extends State<JuradosScreen>
    with SingleTickerProviderStateMixin {
  String _userName = '';
  String _userId = '';
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _proyectosPorRubrica = {};
  Map<String, Rubrica> _rubricasMap = {};

  late TabController _tabController;
  int _tabIndex = 0;
  JuradoProyectosService? _service;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (mounted) setState(() => _tabIndex = _tabController.index);
      });
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userName = await PrefsHelper.getUserName();
      final userId = await PrefsHelper.getCurrentUserId();
      final filial = await PrefsHelper.getJuradoFilial();
      final facultad = await PrefsHelper.getJuradoFacultad();

      _service = JuradoProyectosService(
        userId: userId ?? '',
        filial: filial ?? '',
        facultad: facultad ?? '',
      );

      setState(() {
        _userName = userName ?? 'Jurado';
        _userId = userId ?? '';
      });

      if (_userId.isNotEmpty) {
        await _service!.cargarCacheNombres();
        await _cargarProyectosAsignados();
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error en _loadUserData: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarProyectosAsignados() async {
    if (_service == null) return;
    if (mounted) setState(() => _isLoading = true);
    try {
      final result = await _service!.cargarProyectosAsignados();
      if (mounted) {
        setState(() {
          _proyectosPorRubrica = result.proyectosPorRubrica;
          _rubricasMap = result.rubricasMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar proyectos: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            e.toString().contains('FAILED_PRECONDITION') ||
                    e.toString().contains('requires an index')
                ? 'Error de configuración: falta un índice en Firestore. Contacta al administrador.'
                : 'Error al cargar proyectos: $e',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar Sesión',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await PrefsHelper.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _navegarAEvaluacion(Map<String, dynamic> proyecto) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EvaluacionProyectoScreen(
          proyecto: proyecto,
          juradoId: _userId,
          juradoNombre: _userName,
        ),
      ),
    ).then((_) => _cargarProyectosAsignados());
  }

  int get _totalProyectos =>
      _proyectosPorRubrica.values.fold(0, (s, l) => s + l.length);

  int get _totalEvaluados => _proyectosPorRubrica.values.fold(
      0, (s, l) => s + l.where((p) => p['evaluada'] as bool).length);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2F7),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProyectosTab(),
                    JuradoCertificadosTab(
                      juradoId: _userId,
                      juradoNombre: _userName,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final progreso =
        _totalProyectos > 0 ? _totalEvaluados / _totalProyectos : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.gavel, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Panel de Jurado',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              if (_tabIndex == 0)
                Semantics(
                  label: 'Actualizar proyectos',
                  button: true,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      icon: const Icon(Icons.refresh,
                          color: Colors.white, size: 24),
                      onPressed: _isLoading ? null : _cargarProyectosAsignados,
                      tooltip: 'Actualizar proyectos',
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Semantics(
                label: 'Cerrar sesión',
                button: true,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    icon: const Icon(Icons.logout,
                        color: Colors.white, size: 24),
                    onPressed: _logout,
                    tooltip: 'Cerrar Sesión',
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          if (!_isLoading && _totalProyectos > 0 && _tabIndex == 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progreso,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$_totalEvaluados/$_totalProyectos evaluados',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: const Color(0xFF1E3A5F),
          unselectedLabelColor: Colors.white.withValues(alpha: 0.75),
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          unselectedLabelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_outlined, size: 16),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Evaluaciones',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_outlined, size: 16),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Certificados',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProyectosTab() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A5F)),
            ),
            SizedBox(height: 14),
            Text(
              'Cargando proyectos...',
              style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (_proyectosPorRubrica.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined,
                  size: 72, color: Colors.grey[400]),
              const SizedBox(height: 20),
              Text(
                'Sin proyectos asignados',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'El administrador aún no te ha\nasignado proyectos para evaluar.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _cargarProyectosAsignados,
                icon: const Icon(Icons.refresh),
                label: const Text('Volver a intentar'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        ..._proyectosPorRubrica.entries.map((entry) {
          final rubrica = _rubricasMap[entry.key]!;
          return _buildRubricaSection(rubrica, entry.value);
        }),
      ],
    );
  }

  Widget _buildRubricaSection(
      Rubrica rubrica, List<Map<String, dynamic>> proyectos) {
    final evaluados = proyectos.where((p) => p['evaluada'] as bool).toList();
    final pendientes = proyectos
        .where((p) =>
            !(p['evaluada'] as bool) && !(p['bloqueada'] as bool))
        .toList();
    final bloqueados =
        proyectos.where((p) => p['bloqueada'] as bool).toList();
    final progreso =
        proyectos.isNotEmpty ? evaluados.length / proyectos.length : 0.0;
    final completa = progreso == 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.checklist,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rubrica.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${rubrica.totalCriterios} criterios · ${rubrica.puntajeMaximo.toStringAsFixed(1)} pts máx',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _BadgePill(
                      label: '${evaluados.length}/${proyectos.length}',
                      color: completa
                          ? Colors.green
                          : const Color(0xFFE88A00),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progreso,
                    minHeight: 7,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completa ? Colors.green : const Color(0xFFE88A00),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (pendientes.isNotEmpty)
                      _miniTag(
                          '${pendientes.length} pendiente${pendientes.length > 1 ? 's' : ''}',
                          Colors.orange),
                    if (evaluados.isNotEmpty)
                      _miniTag(
                          '${evaluados.length} evaluado${evaluados.length > 1 ? 's' : ''}',
                          Colors.green),
                    if (bloqueados.isNotEmpty)
                      _miniTag(
                          '${bloqueados.length} bloqueado${bloqueados.length > 1 ? 's' : ''}',
                          Colors.red),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (pendientes.isNotEmpty) ...[
                  _seccionLabel(
                      'Pendientes', Icons.pending_actions, Colors.orange),
                  const SizedBox(height: 6),
                  ...pendientes.map((p) => _buildProyectoCard(p)),
                  if (evaluados.isNotEmpty || bloqueados.isNotEmpty)
                    const SizedBox(height: 10),
                ],
                if (evaluados.isNotEmpty) ...[
                  _seccionLabel(
                      'Evaluados', Icons.check_circle, Colors.green),
                  const SizedBox(height: 6),
                  ...evaluados.map((p) => _buildProyectoCard(p)),
                  if (bloqueados.isNotEmpty) const SizedBox(height: 10),
                ],
                if (bloqueados.isNotEmpty) ...[
                  _seccionLabel('Bloqueados', Icons.lock, Colors.red),
                  const SizedBox(height: 6),
                  ...bloqueados.map((p) => _buildProyectoCard(p)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionLabel(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }

  Widget _miniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }

  Widget _buildProyectoCard(Map<String, dynamic> proyecto) {
    final evaluada = proyecto['evaluada'] as bool;
    final bloqueada = proyecto['bloqueada'] as bool;
    final rubrica = proyecto['rubrica'] as Rubrica;

    Color estadoColor;
    IconData estadoIcon;
    String estadoTexto;

    if (bloqueada) {
      estadoColor = Colors.red;
      estadoIcon = Icons.lock;
      estadoTexto = 'Bloqueada';
    } else if (evaluada) {
      estadoColor = Colors.green;
      estadoIcon = Icons.check_circle;
      estadoTexto = 'Evaluada';
    } else {
      estadoColor = const Color(0xFFE88A00);
      estadoIcon = Icons.pending;
      estadoTexto = 'Pendiente';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: estadoColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () => _navegarAEvaluacion(proyecto),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        proyecto['codigo'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: estadoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(estadoIcon, size: 13, color: estadoColor),
                        const SizedBox(width: 4),
                        Text(estadoTexto,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: estadoColor)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right,
                      size: 20, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                proyecto['titulo'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A5F)),
              ),
              const SizedBox(height: 6),
              if ((proyecto['integrantes'] as String).isNotEmpty)
                _infoRow(
                    Icons.people_outline, proyecto['integrantes']),
              if ((proyecto['sala'] as String).isNotEmpty)
                _infoRow(Icons.room_outlined, proyecto['sala']),
              _infoRow(
                  Icons.event_outlined, proyecto['eventoNombre']),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF4FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.checklist,
                              size: 15, color: Color(0xFF1E3A5F)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${rubrica.nombre} · ${rubrica.totalCriterios} criterios',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E3A5F)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (evaluada) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.grade,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            (proyecto['notaTotal'] as double)
                                .toStringAsFixed(2),
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.green),
                          ),
                        ],
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

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final String label;
  final Color color;
  const _BadgePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white)),
    );
  }
}
