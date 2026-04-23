import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import '/login.dart';
import '/admin/logica/gestion_criterios.dart';

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
  List<Map<String, dynamic>> _proyectosAsignados = [];
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

    if (_userId.isNotEmpty) {
      await _cargarProyectosAsignados();
    }
  }

  // ============================================================================
  // ✅ OPTIMIZADO: Todo en paralelo con Future.wait
  // ============================================================================
  Future<void> _cargarProyectosAsignados() async {
    setState(() => _isLoading = true);

    try {
      // ── 1. Lanzar rúbricas y evaluaciones EN PARALELO ─────────────────────
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

      // ── 2. Filtrar evaluaciones válidas ───────────────────────────────────
      // Separar las que hay que eliminar (huérfanas) de las válidas
      final List<DocumentSnapshot> evaluacionesValidas = [];
      final List<Future<void>> eliminaciones = [];

      for (var evalDoc in evaluacionesSnapshot.docs) {
        final data = evalDoc.data() as Map<String, dynamic>;
        final rubricaId = data['rubricaId'] as String?;
        if (rubricaId == null) continue;

        final rubrica = rubricasMapGlobal[rubricaId];
        if (rubrica == null) continue;

        // Si el jurado ya no está asignado → eliminar en paralelo
        if (!rubrica.juradosAsignados.contains(_userId)) {
          eliminaciones.add(evalDoc.reference.delete());
          continue;
        }

        evaluacionesValidas.add(evalDoc);
      }

      // Eliminar huérfanas sin esperar (fire & forget)
      if (eliminaciones.isNotEmpty) Future.wait(eliminaciones);

      // ── 3. Extraer IDs únicos de eventos y proyectos ──────────────────────
      final Map<String, Set<String>> proyectosPorEvento = {};
      for (var evalDoc in evaluacionesValidas) {
        final parts = evalDoc.reference.path.split('/');
        if (parts.length < 4) continue;
        final eventId = parts[1];
        final proyectoId = parts[3];
        proyectosPorEvento.putIfAbsent(eventId, () => {}).add(proyectoId);
      }

      // ── 4. Cargar eventos y proyectos EN PARALELO ─────────────────────────
      final eventIds = proyectosPorEvento.keys.toList();

      // Traer todos los eventos y todos los proyectos necesarios en paralelo
      final futures = <Future>[];

      // Eventos
      futures.addAll(
        eventIds.map((id) => _firestore.collection('events').doc(id).get()),
      );

      // Proyectos (una query por evento)
      futures.addAll(
        eventIds.map(
          (eventId) => _firestore
              .collection('events')
              .doc(eventId)
              .collection('proyectos')
              .get(),
        ),
      );

      final resultados = await Future.wait(futures);

      // Separar resultados: primeras N son eventos, siguientes N son proyectos
      final n = eventIds.length;
      final Map<String, Map<String, dynamic>> eventosData = {};
      final Map<String, Map<String, Map<String, dynamic>>> proyectosData = {};

      for (int i = 0; i < n; i++) {
        final eventoDoc = resultados[i] as DocumentSnapshot;
        final data = eventoDoc.exists
            ? eventoDoc.data() as Map<String, dynamic>
            : <String, dynamic>{};
        eventosData[eventIds[i]] = data;
      }

      for (int i = 0; i < n; i++) {
        final snap = resultados[n + i] as QuerySnapshot;
        proyectosData[eventIds[i]] = {
          for (var doc in snap.docs)
            doc.id: doc.data() as Map<String, dynamic>,
        };
      }

      // ── 5. Construir mapa de proyectos por rúbrica ────────────────────────
      final Map<String, List<Map<String, dynamic>>> proyectosPorRubricaTemp =
          {};
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

      // Ordenar proyectos por código dentro de cada rúbrica
      for (var lista in proyectosPorRubricaTemp.values) {
        lista.sort((a, b) =>
            (a['codigo'] as String).compareTo(b['codigo'] as String));
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar proyectos: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await PrefsHelper.logout();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.gavel, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Panel de Jurado',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _userName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
                    onPressed: _isLoading ? null : _cargarProyectosAsignados,
                    tooltip: 'Actualizar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white, size: 28),
                    onPressed: _logout,
                    tooltip: 'Cerrar Sesión',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
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

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A5F)),
            ),
            SizedBox(height: 16),
            Text(
              'Cargando proyectos asignados...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
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
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.assignment_outlined,
                    size: 80, color: Colors.grey[400]),
              ),
              const SizedBox(height: 24),
              Text(
                'No tienes proyectos asignados',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Los proyectos aparecerán aquí cuando\nel administrador te los asigne',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    int totalProyectos = 0;
    int totalEvaluados = 0;
    int totalBloqueados = 0;

    _proyectosPorRubrica.forEach((_, proyectos) {
      totalProyectos += proyectos.length;
      totalEvaluados += proyectos.where((p) => p['evaluada'] as bool).length;
      totalBloqueados += proyectos.where((p) => p['bloqueada'] as bool).length;
    });
    final totalPendientes = totalProyectos - totalEvaluados - totalBloqueados;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEstadisticasCardGlobal(
            totalProyectos,
            totalPendientes,
            totalEvaluados,
            totalBloqueados,
          ),
          const SizedBox(height: 16),
          ..._proyectosPorRubrica.entries.map((entry) {
            final rubricaId = entry.key;
            final proyectos = entry.value;
            final rubrica = _rubricasMap[rubricaId]!;
            return _buildRubricaSection(rubrica, proyectos);
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEstadisticasCardGlobal(
    int total,
    int pendientes,
    int evaluados,
    int bloqueados,
  ) {
    final progreso = total > 0 ? evaluados / total : 0.0;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2C5F7C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tu Progreso Total',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(progreso * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_proyectosPorRubrica.length} ${_proyectosPorRubrica.length == 1 ? 'rúbrica asignada' : 'rúbricas asignadas'}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildEstadistica(
                      'Total', total.toString(), Icons.assignment)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildEstadistica(
                      'Pendientes', pendientes.toString(), Icons.pending)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildEstadistica(
                      'Evaluados', evaluados.toString(), Icons.check_circle)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRubricaSection(
      Rubrica rubrica, List<Map<String, dynamic>> proyectos) {
    final pendientes = proyectos
        .where((p) => !(p['evaluada'] as bool) && !(p['bloqueada'] as bool))
        .toList();
    final evaluados =
        proyectos.where((p) => p['evaluada'] as bool).toList();
    final bloqueados =
        proyectos.where((p) => p['bloqueada'] as bool).toList();
    final progreso =
        proyectos.isNotEmpty ? evaluados.length / proyectos.length : 0.0;

    return Card(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E3A5F).withOpacity(0.1),
                  const Color(0xFF2C5F7C).withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.checklist,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rubrica.nombre,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${rubrica.totalCriterios} criterios • ${rubrica.puntajeMaximo.toStringAsFixed(0)} pts máx',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: progreso == 1.0 ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${evaluados.length}/${proyectos.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progreso,
                    minHeight: 6,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progreso == 1.0 ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (pendientes.isNotEmpty) ...[
                  _buildMiniSeccionHeader(
                      'Pendientes', pendientes.length, Colors.orange,
                      Icons.pending_actions),
                  const SizedBox(height: 8),
                  ...pendientes.map((p) => _buildProyectoCard(p)),
                  const SizedBox(height: 16),
                ],
                if (evaluados.isNotEmpty) ...[
                  _buildMiniSeccionHeader(
                      'Evaluados', evaluados.length, Colors.green,
                      Icons.check_circle),
                  const SizedBox(height: 8),
                  ...evaluados.map((p) => _buildProyectoCard(p)),
                  const SizedBox(height: 16),
                ],
                if (bloqueados.isNotEmpty) ...[
                  _buildMiniSeccionHeader(
                      'Bloqueados', bloqueados.length, Colors.red, Icons.lock),
                  const SizedBox(height: 8),
                  ...bloqueados.map((p) => _buildProyectoCard(p)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSeccionHeader(
      String titulo, int cantidad, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(titulo,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(cantidad.toString(),
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ),
      ],
    );
  }

  Widget _buildEstadistica(String label, String valor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(valor,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withOpacity(0.8))),
        ],
      ),
    );
  }

  Widget _buildProyectoCard(Map<String, dynamic> proyecto) {
    final rubrica = proyecto['rubrica'] as Rubrica;
    final evaluada = proyecto['evaluada'] as bool;
    final bloqueada = proyecto['bloqueada'] as bool;

    Color estadoColor = Colors.orange;
    IconData estadoIcon = Icons.pending;
    String estadoTexto = 'Pendiente';

    if (bloqueada) {
      estadoColor = Colors.red;
      estadoIcon = Icons.lock;
      estadoTexto = 'Bloqueada';
    } else if (evaluada) {
      estadoColor = Colors.green;
      estadoIcon = Icons.check_circle;
      estadoTexto = 'Evaluada';
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: estadoColor.withOpacity(0.3), width: 2),
      ),
      child: InkWell(
        onTap: () => _navegarAEvaluacion(proyecto),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      proyecto['codigo'],
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(estadoIcon, size: 16, color: estadoColor),
                        const SizedBox(width: 4),
                        Text(estadoTexto,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: estadoColor)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios,
                      size: 18, color: Color(0xFF64748B)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                proyecto['titulo'],
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              if (proyecto['integrantes'].toString().isNotEmpty)
                _buildInfoRow(Icons.people, proyecto['integrantes']),
              if (proyecto['sala'].toString().isNotEmpty)
                _buildInfoRow(Icons.room, proyecto['sala']),
              _buildInfoRow(
                  Icons.event, 'Evento: ${proyecto['eventoNombre']}'),
              _buildInfoRow(Icons.category,
                  'Categoría: ${proyecto['clasificacion']}'),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF1E3A5F).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.checklist,
                              color: Color(0xFF1E3A5F), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${rubrica.nombre}\n${rubrica.totalSecciones} secciones • ${rubrica.totalCriterios} criterios',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E3A5F)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (evaluada) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.grade,
                              color: Colors.green, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            proyecto['notaTotal'].toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 16,
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PANTALLA DE EVALUACIÓN CON RÚBRICAS
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
            for (var entry in notas.entries) {
              _notasSeleccionadas[entry.key] = (entry.value as num).toDouble();
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
                'Debes calificar todos los criterios en "${seccion.nombre}"'),
            backgroundColor: Colors.orange,
          ));
          return;
        }
      }
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar Evaluación'),
        content: const Text(
            'Una vez guardada, no podrás modificar las notas. ¿Estás seguro?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F)),
            child: const Text('Guardar'),
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
        'bloqueada': true, // ← AUTO-BLOQUEO AL GUARDAR
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

  @override
  Widget build(BuildContext context) {
    final soloLectura = _yaEvaluado || _estaBloqueado;

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evaluar ${widget.proyecto['codigo']}',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Text(
                          _rubrica.nombre,
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                  if (!soloLectura && !_isGuardando && !_isCargando)
                    IconButton(
                      icon: const Icon(Icons.save,
                          color: Colors.white, size: 28),
                      onPressed: _guardarEvaluacion,
                      tooltip: 'Guardar Evaluación',
                    ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _isCargando
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          if (soloLectura) _buildEstadoAlert(),
                          _buildInfoProyecto(),
                          const SizedBox(height: 20),
                          _buildResumenRubrica(),
                          const SizedBox(height: 20),
                          ..._rubrica.secciones
                              .map((s) => _buildSeccion(s, soloLectura)),
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
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
    );
  }

  Widget _buildEstadoAlert() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _estaBloqueado
            ? Colors.red.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _estaBloqueado
              ? Colors.red.withOpacity(0.3)
              : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(_estaBloqueado ? Icons.lock : Icons.check_circle,
              color: _estaBloqueado ? Colors.red : Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _estaBloqueado
                  ? 'Evaluación bloqueada por el administrador'
                  : 'Evaluación completada. Solo lectura.',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _estaBloqueado ? Colors.red : Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoProyecto() {
    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.proyecto['titulo'],
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F)),
            ),
            if (widget.proyecto['integrantes'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.people, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(widget.proyecto['integrantes'],
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[700]))),
              ]),
            ],
            if (widget.proyecto['sala'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.room, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(widget.proyecto['sala'],
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey[700])),
              ]),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.event, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(widget.proyecto['eventoNombre'],
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenRubrica() {
    final notasIngresadas = _notasSeleccionadas.length;
    final totalCriterios = _rubrica.totalCriterios;
    final progreso =
        totalCriterios > 0 ? notasIngresadas / totalCriterios : 0.0;

    double notaActual = 0;
    for (var nota in _notasSeleccionadas.values) {
      if (nota != null) notaActual += nota;
    }

    return Card(
      elevation: 2,
      color: Colors.blue.shade50,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.analytics_outlined, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text('Progreso de Evaluación',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900)),
            ]),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Criterios evaluados',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      Text('$notasIngresadas / $totalCriterios',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Puntaje actual',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      Text(
                          '${notaActual.toStringAsFixed(1)} / ${_rubrica.puntajeMaximo.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                    progreso == 1.0 ? Colors.green : Colors.blue),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              progreso == 1.0
                  ? '¡Evaluación completa! Puedes guardar.'
                  : 'Completa todos los criterios para guardar',
              style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color:
                      progreso == 1.0 ? Colors.green : Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccion(SeccionRubrica seccion, bool soloLectura) {
    int criteriosEvaluados = 0;
    double puntajeSeccion = 0;

    for (var criterio in seccion.criterios) {
      if (_notasSeleccionadas[criterio.id] != null) {
        criteriosEvaluados++;
        puntajeSeccion += _notasSeleccionadas[criterio.id]!;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data:
            Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.folder_open,
                color: Color(0xFF1E3A5F), size: 24),
          ),
          title: Text(seccion.nombre,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F))),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                  '${seccion.criterios.length} criterios • ${seccion.pesoTotal.toStringAsFixed(0)} pts máx',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[600])),
              if (criteriosEvaluados > 0) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(
                    criteriosEvaluados == seccion.criterios.length
                        ? Icons.check_circle
                        : Icons.pending,
                    size: 14,
                    color: criteriosEvaluados == seccion.criterios.length
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$criteriosEvaluados/${seccion.criterios.length} evaluados • ${puntajeSeccion.toStringAsFixed(1)} pts',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: criteriosEvaluados == seccion.criterios.length
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ]),
              ],
            ],
          ),
          children:
              seccion.criterios.map((c) => _buildCriterio(c, soloLectura)).toList(),
        ),
      ),
    );
  }

  Widget _buildCriterio(Criterio criterio, bool soloLectura) {
    final notaSeleccionada = _notasSeleccionadas[criterio.id];
    final pesoMaximo = criterio.peso;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notaSeleccionada != null
            ? Colors.green.withOpacity(0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notaSeleccionada != null
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
          width: notaSeleccionada != null ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(criterio.descripcion,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Máx: ${pesoMaximo.toStringAsFixed(1)} pts',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A5F))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (notaSeleccionada != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.stars, size: 18, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                    'Calificación: ${notaSeleccionada.toStringAsFixed(1)} pts',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.pending, size: 16, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text('Selecciona una calificación',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700])),
              ]),
            ),
          _buildNotaSelector(criterio, notaSeleccionada, soloLectura),
        ],
      ),
    );
  }

  Widget _buildNotaSelector(
      Criterio criterio, double? notaSeleccionada, bool soloLectura) {
    final pesoMaximo = criterio.peso;
    final List<double> opciones = [];
    double valor = 0;
    while (valor <= pesoMaximo) {
      opciones.add(valor);
      valor += 0.5;
    }
    if (opciones.last != pesoMaximo) opciones.add(pesoMaximo);

    return opciones.length > 10
        ? _buildDropdownSelector(
            criterio, opciones, notaSeleccionada, soloLectura)
        : _buildChipsSelector(
            criterio, opciones, notaSeleccionada, soloLectura);
  }

  Widget _buildChipsSelector(Criterio criterio, List<double> opciones,
      double? notaSeleccionada, bool soloLectura) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: opciones.map((nota) {
        final isSelected = notaSeleccionada == nota;
        return InkWell(
          onTap: soloLectura
              ? null
              : () => setState(
                  () => _notasSeleccionadas[criterio.id] = nota),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1E3A5F)
                  : soloLectura
                      ? Colors.grey[200]
                      : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1E3A5F)
                    : soloLectura
                        ? Colors.grey[300]!
                        : const Color(0xFF1E3A5F).withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: const Color(0xFF1E3A5F).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.check_circle,
                        color: Colors.white, size: 16),
                  ),
                Text(
                  nota.toStringAsFixed(
                      nota.truncateToDouble() == nota ? 0 : 1),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : soloLectura
                              ? Colors.grey[600]
                              : const Color(0xFF1E3A5F)),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropdownSelector(Criterio criterio, List<double> opciones,
      double? notaSeleccionada, bool soloLectura) {
    return Container(
      decoration: BoxDecoration(
        color: soloLectura ? Colors.grey[200] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notaSeleccionada != null
              ? const Color(0xFF1E3A5F)
              : const Color(0xFF1E3A5F).withOpacity(0.3),
          width: notaSeleccionada != null ? 2 : 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          value: notaSeleccionada,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Icon(Icons.arrow_drop_down_circle,
                  color: Colors.grey[600], size: 20),
              const SizedBox(width: 12),
              Text('Toca para elegir la calificación',
                  style:
                      TextStyle(fontSize: 14, color: Colors.grey[600])),
            ]),
          ),
          icon: const Padding(
            padding: EdgeInsets.only(right: 12),
            child:
                Icon(Icons.arrow_drop_down, color: Color(0xFF1E3A5F)),
          ),
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          elevation: 8,
          menuMaxHeight: 400,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A5F)),
          items: opciones.map((nota) {
            return DropdownMenuItem<double>(
              value: nota,
              enabled: !soloLectura,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(children: [
                  Container(
                    width: 50,
                    height: 40,
                    decoration: BoxDecoration(
                      color: notaSeleccionada == nota
                          ? const Color(0xFF1E3A5F)
                          : const Color(0xFF1E3A5F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        nota.toStringAsFixed(
                            nota.truncateToDouble() == nota ? 0 : 1),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: notaSeleccionada == nota
                                ? Colors.white
                                : const Color(0xFF1E3A5F)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('pts',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600])),
                  if (notaSeleccionada == nota) ...[
                    const Spacer(),
                    const Icon(Icons.check_circle,
                        color: Color(0xFF1E3A5F), size: 20),
                  ],
                ]),
              ),
            );
          }).toList(),
          onChanged: soloLectura
              ? null
              : (value) {
                  if (value != null) {
                    setState(
                        () => _notasSeleccionadas[criterio.id] = value);
                  }
                },
          selectedItemBuilder: (context) {
            return opciones.map((nota) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.check_circle,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    nota.toStringAsFixed(
                        nota.truncateToDouble() == nota ? 0 : 1),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F)),
                  ),
                  const SizedBox(width: 8),
                  Text('puntos',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[600])),
                ]),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}