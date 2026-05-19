import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import '/login.dart';
import '/admin/logica/gestion_criterios.dart';


// ============================================================================
// JURADOS SCREEN
// ============================================================================

class JuradosScreen extends StatefulWidget {
  const JuradosScreen({super.key});

  @override
  State<JuradosScreen> createState() => _JuradosScreenState();
}

class _JuradosScreenState extends State<JuradosScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RubricasService _rubricasService = RubricasService();
  String _userName = '';
  String _userId = '';
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _proyectosPorRubrica = {};
  Map<String, Rubrica> _rubricasMap = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userName = await PrefsHelper.getUserName();
    final userId = await PrefsHelper.getCurrentUserId();
    setState(() {
      _userName = userName ?? 'Jurado';
      _userId = userId ?? '';
    });
    if (_userId.isNotEmpty) await _cargarProyectosAsignados();
  }

  Future<void> _cargarProyectosAsignados() async {
    setState(() => _isLoading = true);
    try {
      final resultadosBase = await Future.wait([
        _rubricasService.obtenerRubricas(),
        _firestore
            .collectionGroup('evaluaciones')
            .where('juradoId', isEqualTo: _userId)
            .get(),
      ]);

      final todasRubricas = resultadosBase[0] as List<Rubrica>;
      final evaluacionesSnapshot = resultadosBase[1] as QuerySnapshot;
      final Map<String, Rubrica> rubricasMapGlobal = {
        for (var r in todasRubricas) r.id: r,
      };

      final List<DocumentSnapshot> evaluacionesValidas = [];
      final List<Future<void>> eliminaciones = [];

      for (var evalDoc in evaluacionesSnapshot.docs) {
        final data = evalDoc.data() as Map<String, dynamic>;
        final rubricaId = data['rubricaId'] as String?;
        if (rubricaId == null) continue;
        final rubrica = rubricasMapGlobal[rubricaId];
        if (rubrica == null) continue;
        if (!rubrica.juradosAsignados.contains(_userId)) {
          eliminaciones.add(evalDoc.reference.delete());
          continue;
        }
        evaluacionesValidas.add(evalDoc);
      }

      if (eliminaciones.isNotEmpty) Future.wait(eliminaciones);

      final Map<String, Set<String>> proyectosPorEvento = {};
      for (var evalDoc in evaluacionesValidas) {
        final parts = evalDoc.reference.path.split('/');
        if (parts.length < 4) continue;
        proyectosPorEvento.putIfAbsent(parts[1], () => {}).add(parts[3]);
      }

      final eventIds = proyectosPorEvento.keys.toList();
      final futures = <Future>[
        ...eventIds.map((id) => _firestore.collection('events').doc(id).get()),
        ...eventIds.map((eventId) => _firestore
            .collection('events')
            .doc(eventId)
            .collection('proyectos')
            .get()),
      ];

      final resultados = await Future.wait(futures);
      final n = eventIds.length;
      final Map<String, Map<String, dynamic>> eventosData = {};
      final Map<String, Map<String, Map<String, dynamic>>> proyectosData = {};

      for (int i = 0; i < n; i++) {
        final eventoDoc = resultados[i] as DocumentSnapshot;
        eventosData[eventIds[i]] = eventoDoc.exists
            ? eventoDoc.data() as Map<String, dynamic>
            : {};
      }
      for (int i = 0; i < n; i++) {
        final snap = resultados[n + i] as QuerySnapshot;
        proyectosData[eventIds[i]] = {
          for (var doc in snap.docs) doc.id: doc.data() as Map<String, dynamic>,
        };
      }

      final Map<String, List<Map<String, dynamic>>> proyectosPorRubricaTemp = {};
      final Map<String, Rubrica> rubricasTemp = {};

      for (var evalDoc in evaluacionesValidas) {
        final data = evalDoc.data() as Map<String, dynamic>;
        final parts = evalDoc.reference.path.split('/');
        if (parts.length < 4) continue;
        final eventId = parts[1];
        final proyectoId = parts[3];
        final rubricaId = data['rubricaId'] as String;
        final rubrica = rubricasMapGlobal[rubricaId]!;
        final proyectoData = proyectosData[eventId]?[proyectoId];
        if (proyectoData == null) continue;
        final eventoData = eventosData[eventId] ?? {};

        final proyecto = {
          'eventId': eventId,
          'proyectoId': proyectoId,
          'eventoNombre': eventoData['name'] ?? 'Sin nombre',
          'codigo': proyectoData['Código'] ?? 'Sin código',
          'titulo': proyectoData['Título'] ?? 'Sin título',
          'integrantes': proyectoData['Integrantes'] ?? '',
          'sala': proyectoData['Sala'] ?? '',
          'clasificacion': proyectoData['Clasificación'] ?? 'Sin categoría',
          'rubricaId': rubrica.id,
          'rubricaNombre': rubrica.nombre,
          'rubrica': rubrica,
          'evaluada': data['evaluada'] ?? false,
          'bloqueada': data['bloqueada'] ?? false,
          'notaTotal': (data['notaTotal'] ?? 0.0).toDouble(),
          'fechaAsignacion': data['fechaAsignacion'],
        };

        proyectosPorRubricaTemp.putIfAbsent(rubricaId, () => []).add(proyecto);
        rubricasTemp[rubricaId] = rubrica;
      }

      for (var lista in proyectosPorRubricaTemp.values) {
        lista.sort(
            (a, b) => (a['codigo'] as String).compareTo(b['codigo'] as String));
      }

      if (mounted) {
        setState(() {
          _proyectosPorRubrica = proyectosPorRubricaTemp;
          _rubricasMap = rubricasTemp;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error al cargar proyectos: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al cargar proyectos: $e'),
          backgroundColor: Colors.red,
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

  // ─── Totales globales ─────────────────────────────────────────────────────
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
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2F7),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header compacto con progreso inline ──────────────────────────────────
  Widget _buildHeader() {
    final progreso =
        _totalProyectos > 0 ? _totalEvaluados / _totalProyectos : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.gavel, color: Colors.white, size: 22),
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
                        color: Colors.white.withValues(alpha:0.75),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh,
                    color: Colors.white, size: 24),
                onPressed:
                    _isLoading ? null : _cargarProyectosAsignados,
                tooltip: 'Actualizar',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.logout,
                    color: Colors.white, size: 24),
                onPressed: _logout,
                tooltip: 'Cerrar Sesión',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          // Progreso compacto — solo si hay datos
          if (!_isLoading && _totalProyectos > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progreso,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha:0.25),
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
                    color: Colors.white.withValues(alpha:0.85),
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

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFF1E3A5F)),
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
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined,
                  size: 72, color: Colors.grey[400]),
              const SizedBox(height: 20),
              Text(
                'Sin proyectos asignados',
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

  // ─── Sección por rúbrica (protagonista) ───────────────────────────────────
  Widget _buildRubricaSection(
      Rubrica rubrica, List<Map<String, dynamic>> proyectos) {
    final evaluados =
        proyectos.where((p) => p['evaluada'] as bool).toList();
    final pendientes = proyectos
        .where((p) => !(p['evaluada'] as bool) && !(p['bloqueada'] as bool))
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
            color: Colors.black.withValues(alpha:0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera rúbrica
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withValues(alpha:0.05),
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
                            '${rubrica.totalCriterios} criterios · ${rubrica.puntajeMaximo.toStringAsFixed(0)} pts máx',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _BadgePill(
                      label: '${evaluados.length}/${proyectos.length}',
                      color: completa ? Colors.green : const Color(0xFFE88A00),
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
                Row(
                  children: [
                    if (pendientes.isNotEmpty)
                      _miniTag(
                          '${pendientes.length} pendiente${pendientes.length > 1 ? 's' : ''}',
                          Colors.orange),
                    if (pendientes.isNotEmpty && evaluados.isNotEmpty)
                      const SizedBox(width: 6),
                    if (evaluados.isNotEmpty)
                      _miniTag(
                          '${evaluados.length} evaluado${evaluados.length > 1 ? 's' : ''}',
                          Colors.green),
                    if (bloqueados.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _miniTag(
                          '${bloqueados.length} bloqueado${bloqueados.length > 1 ? 's' : ''}',
                          Colors.red),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Lista de proyectos
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (pendientes.isNotEmpty) ...[
                  _seccionLabel('Pendientes', Icons.pending_actions,
                      Colors.orange),
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
        color: color.withValues(alpha:0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }

  // ─── Tarjeta de proyecto ──────────────────────────────────────────────────
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
          color: estadoColor.withValues(alpha:0.25),
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
              // Fila superior: código + estado + flecha
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      proyecto['codigo'],
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: estadoColor.withValues(alpha:0.1),
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
              // Título
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
              // Info rows
              if ((proyecto['integrantes'] as String).isNotEmpty)
                _infoRow(Icons.people_outline, proyecto['integrantes']),
              if ((proyecto['sala'] as String).isNotEmpty)
                _infoRow(Icons.room_outlined, proyecto['sala']),
              _infoRow(Icons.event_outlined, proyecto['eventoNombre']),
              const SizedBox(height: 8),
              // Footer: rúbrica + nota si existe
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
                        color: Colors.green.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.green.withValues(alpha:0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.grade,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            (proyecto['notaTotal'] as double)
                                .toStringAsFixed(1),
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

// ─── Widget auxiliar ─────────────────────────────────────────────────────────

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

// ============================================================================
// EVALUACIÓN SCREEN
// ============================================================================

class EvaluacionProyectoScreen extends StatefulWidget {
  final Map<String, dynamic> proyecto;
  final String juradoId;
  final String juradoNombre;

  const EvaluacionProyectoScreen({
    super.key,
    required this.proyecto,
    required this.juradoId,
    required this.juradoNombre,
  });

  @override
  State<EvaluacionProyectoScreen> createState() =>
      _EvaluacionProyectoScreenState();
}

class _EvaluacionProyectoScreenState
    extends State<EvaluacionProyectoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, double?> _notasSeleccionadas = {};
  bool _isGuardando = false;
  bool _isCargando = true;
  bool _yaEvaluado = false;
  bool _estaBloqueado = false;
  late Rubrica _rubrica;

  @override
  void initState() {
    super.initState();
    _rubrica = widget.proyecto['rubrica'] as Rubrica;
    _cargarNotas();
  }

  Future<void> _cargarNotas() async {
    setState(() => _isCargando = true);
    try {
      final evaluacionDoc = await _firestore
          .collection('events')
          .doc(widget.proyecto['eventId'])
          .collection('proyectos')
          .doc(widget.proyecto['proyectoId'])
          .collection('evaluaciones')
          .doc(widget.juradoId)
          .get();

      if (evaluacionDoc.exists && mounted) {
        final data = evaluacionDoc.data();
        if (data != null) {
          _yaEvaluado = data['evaluada'] ?? false;
          _estaBloqueado = data['bloqueada'] ?? false;
          if (data.containsKey('notas')) {
            final notas = data['notas'] as Map<String, dynamic>;
            for (var e in notas.entries) {
              _notasSeleccionadas[e.key] = (e.value as num).toDouble();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error al cargar notas: $e');
    } finally {
      if (mounted) setState(() => _isCargando = false);
    }
  }

  Future<void> _guardarEvaluacion() async {
    for (var seccion in _rubrica.secciones) {
      for (var criterio in seccion.criterios) {
        if (_notasSeleccionadas[criterio.id] == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Califica todos los criterios en "${seccion.nombre}"'),
            backgroundColor: Colors.orange,
          ));
          return;
        }
      }
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar Evaluación'),
        content: const Text(
            'Una vez guardada no podrás modificar las notas. ¿Confirmas?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F)),
            child: const Text('Guardar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    setState(() => _isGuardando = true);

    try {
      double notaTotal = 0;
      final Map<String, dynamic> notas = {};
      for (var seccion in _rubrica.secciones) {
        for (var criterio in seccion.criterios) {
          final nota = _notasSeleccionadas[criterio.id]!;
          notas[criterio.id] = nota;
          notaTotal += nota;
        }
      }

      await _firestore
          .collection('events')
          .doc(widget.proyecto['eventId'])
          .collection('proyectos')
          .doc(widget.proyecto['proyectoId'])
          .collection('evaluaciones')
          .doc(widget.juradoId)
          .update({
        'notas': notas,
        'notaTotal': notaTotal,
        'evaluada': true,
        'bloqueada': true,
        'fechaEvaluacion': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Evaluación guardada exitosamente'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error al guardar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isGuardando = false);
    }
  }

  int get _totalCriterios => _rubrica.totalCriterios;
  int get _criteriosEvaluados => _notasSeleccionadas.values
      .where((v) => v != null)
      .length;
  double get _notaActual =>
      _notasSeleccionadas.values.fold(0.0, (s, v) => s + (v ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final soloLectura = _yaEvaluado || _estaBloqueado;
    final progresoEval = _totalCriterios > 0
        ? _criteriosEvaluados / _totalCriterios
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 26),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evaluar ${widget.proyecto['codigo']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Text(
                          _rubrica.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha:0.75)),
                        ),
                      ],
                    ),
                  ),
                  if (!soloLectura && !_isGuardando && !_isCargando)
                    TextButton.icon(
                      onPressed: _guardarEvaluacion,
                      icon: const Icon(Icons.save,
                          color: Colors.white, size: 18),
                      label: const Text('Guardar',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
            // Barra de progreso de evaluación (compacta)
            if (!_isCargando)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progresoEval,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha:0.25),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progresoEval == 1.0
                                ? Colors.greenAccent
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$_criteriosEvaluados/$_totalCriterios · ${_notaActual.toStringAsFixed(1)} pts',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha:0.85),
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            // Contenido
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2F7),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: _isCargando
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (soloLectura) _buildEstadoAlert(),
                          _buildInfoProyecto(),
                          const SizedBox(height: 16),
                          ..._rubrica.secciones.map(
                              (s) => _buildSeccion(s, soloLectura)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton:
          (_isCargando || _isGuardando || soloLectura)
              ? null
              : FloatingActionButton.extended(
                  onPressed: _guardarEvaluacion,
                  backgroundColor: const Color(0xFF1E3A5F),
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('Guardar Evaluación',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
    );
  }

  Widget _buildEstadoAlert() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _estaBloqueado
            ? Colors.red.withValues(alpha:0.08)
            : Colors.green.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _estaBloqueado
              ? Colors.red.withValues(alpha:0.3)
              : Colors.green.withValues(alpha:0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(_estaBloqueado ? Icons.lock : Icons.check_circle,
              color: _estaBloqueado ? Colors.red : Colors.green,
              size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _estaBloqueado
                  ? 'Bloqueada por el administrador.'
                  : 'Evaluación completada. Modo solo lectura.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _estaBloqueado ? Colors.red : Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoProyecto() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha:0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.proyecto['titulo'],
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F)),
          ),
          if ((widget.proyecto['integrantes'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            _eRow(Icons.people_outline, widget.proyecto['integrantes']),
          ],
          if ((widget.proyecto['sala'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            _eRow(Icons.room_outlined, widget.proyecto['sala']),
          ],
          const SizedBox(height: 4),
          _eRow(Icons.event_outlined, widget.proyecto['eventoNombre']),
        ],
      ),
    );
  }

  Widget _eRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ),
      ],
    );
  }

  Widget _buildSeccion(SeccionRubrica seccion, bool soloLectura) {
    int criteriosEv = 0;
    double puntajeSeccion = 0;
    for (var c in seccion.criterios) {
      if (_notasSeleccionadas[c.id] != null) {
        criteriosEv++;
        puntajeSeccion += _notasSeleccionadas[c.id]!;
      }
    }
    final seccionCompleta = criteriosEv == seccion.criterios.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: seccionCompleta
              ? Colors.green.withValues(alpha:0.3)
              : Colors.grey.withValues(alpha:0.15),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: !soloLectura || !seccionCompleta,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: seccionCompleta
                  ? Colors.green.withValues(alpha:0.12)
                  : const Color(0xFF1E3A5F).withValues(alpha:0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              seccionCompleta ? Icons.check_circle : Icons.folder_open,
              color: seccionCompleta
                  ? Colors.green
                  : const Color(0xFF1E3A5F),
              size: 20,
            ),
          ),
          title: Text(seccion.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F))),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '$criteriosEv/${seccion.criterios.length} evaluados · ${puntajeSeccion.toStringAsFixed(1)}/${seccion.pesoTotal.toStringAsFixed(0)} pts',
              style:
                  TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ),
          children: seccion.criterios
              .map((c) => _buildCriterio(c, soloLectura))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCriterio(Criterio criterio, bool soloLectura) {
    final nota = _notasSeleccionadas[criterio.id];
    final calificado = nota != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: calificado
            ? Colors.green.withValues(alpha:0.04)
            : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: calificado
              ? Colors.green.withValues(alpha:0.25)
              : Colors.grey.withValues(alpha:0.2),
          width: calificado ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Descripción + máx pts
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  criterio.descripcion,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Máx ${criterio.peso.toStringAsFixed(criterio.peso.truncateToDouble() == criterio.peso ? 0 : 1)} pts',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A5F)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Calificación actual
          if (calificado)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.stars, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    '${nota.toStringAsFixed(nota.truncateToDouble() == nota ? 0 : 1)} pts seleccionados',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                ],
              ),
            )
          else if (!soloLectura)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Selecciona una calificación',
                style: TextStyle(
                    fontSize: 12, color: Colors.orange[700]),
              ),
            ),
          // Selector
          _buildNotaSelector(criterio, nota, soloLectura),
        ],
      ),
    );
  }

  Widget _buildNotaSelector(
      Criterio criterio, double? notaSeleccionada, bool soloLectura) {
    final pesoMaximo = criterio.peso;
    final List<double> opciones = [];
    double v = 0;
    while (v <= pesoMaximo) {
      opciones.add(double.parse(v.toStringAsFixed(1)));
      v += 0.5;
    }
    if (opciones.isEmpty || opciones.last != pesoMaximo) {
      opciones.add(pesoMaximo);
    }

    // Chips si ≤ 10 opciones, Dropdown si son más
    if (opciones.length <= 10) {
      return Wrap(
        spacing: 7,
        runSpacing: 7,
        children: opciones.map((op) {
          final selected = notaSeleccionada == op;
          return GestureDetector(
            onTap: soloLectura
                ? null
                : () => setState(
                    () => _notasSeleccionadas[criterio.id] = op),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF1E3A5F)
                    : soloLectura
                        ? Colors.grey[100]
                        : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF1E3A5F)
                      : soloLectura
                          ? Colors.grey[300]!
                          : const Color(0xFF1E3A5F).withValues(alpha:0.3),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Text(
                op.toStringAsFixed(
                    op.truncateToDouble() == op ? 0 : 1),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? Colors.white
                        : soloLectura
                            ? Colors.grey[500]
                            : const Color(0xFF1E3A5F)),
              ),
            ),
          );
        }).toList(),
      );
    }

    // Dropdown para muchas opciones
    return Container(
      decoration: BoxDecoration(
        color: soloLectura ? Colors.grey[100] : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: notaSeleccionada != null
              ? const Color(0xFF1E3A5F)
              : Colors.grey.withValues(alpha:0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          value: notaSeleccionada,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('Elegir calificación',
                style:
                    TextStyle(fontSize: 14, color: Colors.grey[500])),
          ),
          icon: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.arrow_drop_down,
                color: Color(0xFF1E3A5F)),
          ),
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          menuMaxHeight: 360,
          items: opciones.map((op) {
            return DropdownMenuItem<double>(
              value: op,
              enabled: !soloLectura,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                child: Text(
                  '${op.toStringAsFixed(op.truncateToDouble() == op ? 0 : 1)} pts',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: notaSeleccionada == op
                          ? const Color(0xFF1E3A5F)
                          : Colors.grey[700]),
                ),
              ),
            );
          }).toList(),
          onChanged: soloLectura
              ? null
              : (val) {
                  if (val != null) {
                    setState(() => _notasSeleccionadas[criterio.id] = val);
                  }
                },
        ),
      ),
    );
  }
}