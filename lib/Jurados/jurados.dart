import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import '/login.dart';
import '/admin/logica/gestion_criterios.dart';
import '/resolver_nombres_service.dart';

class JuradosScreen extends StatefulWidget {
  const JuradosScreen({super.key});

  @override
  State<JuradosScreen> createState() => _JuradosScreenState();
}

class _JuradosScreenState extends State<JuradosScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _resolverNombres = ResolverNombresService();
  final RubricasService _rubricasService = RubricasService();

  String _userName = '';
  String _userId = '';
  String _juradoFilial = '';
  String _juradoFacultad = '';
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _proyectosPorRubrica = {};
  Map<String, Rubrica> _rubricasMap = {};

  String _resolverCampoString(dynamic valor) {
    if (valor == null) return '';
    if (valor is List) return valor.map((e) => e.toString()).join(', ');
    return valor.toString();
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userName = await PrefsHelper.getUserName();
    final userId = await PrefsHelper.getCurrentUserId();
    final filial = await PrefsHelper.getJuradoFilial();
    final facultad = await PrefsHelper.getJuradoFacultad();

    setState(() {
      _userName = userName ?? 'Jurado';
      _userId = userId ?? '';
      _juradoFilial = filial ?? '';
      _juradoFacultad = facultad ?? '';
    });

    if (_userId.isNotEmpty) {
      // FIX M6: cargar proyectos primero (crítico para el usuario),
      // la cache de nombres se carga en paralelo en background.
      await Future.wait([
        _cargarProyectosAsignados(),
        _cargarCacheNombres(),
      ]);
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // FIX M1/2.2: reescrito para no depender del formato del ID del documento.
  // Ahora carga la cache a partir de los datos reales del jurado en Firestore.
  Future<void> _cargarCacheNombres() async {
    try {
      if (_juradoFilial.isEmpty) return;
      // Obtener el documento del jurado actual para saber su carrera
      final juradoDoc =
          await FirebaseFirestore.instance.collection('users').doc(_userId).get();
      if (!juradoDoc.exists) return;

      final data = juradoDoc.data();
      final filialNombre = data?['filialNombre'] as String? ?? _juradoFilial;
      final carrera = data?['carrera'] as String? ?? '';

      if (carrera.isNotEmpty) {
        await _resolverNombres.cargarEstudiantes(
          filialNombre: filialNombre,
          carrera: carrera,
        );
      }
    } catch (e) {
      debugPrint('Error cargando cache nombres jurado: $e');
    }
  }

  // FIX C1: método completamente restaurado con la lógica real de carga.
  // FIX C3: requiere índice compuesto en Firestore (ver documentación adjunta).
  Future<void> _cargarProyectosAsignados() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      // 1. Construir la query de evaluaciones asignadas a este jurado
      Query evaluacionesQuery = FirebaseFirestore.instance
          .collectionGroup('evaluaciones')
          .where('juradoId', isEqualTo: _userId);

      // Filtros adicionales para reducir el scope (requieren índice compuesto)
      if (_juradoFilial.isNotEmpty) {
        evaluacionesQuery =
            evaluacionesQuery.where('filialId', isEqualTo: _juradoFilial);
      }
      if (_juradoFacultad.isNotEmpty) {
        evaluacionesQuery =
            evaluacionesQuery.where('facultad', isEqualTo: _juradoFacultad);
      }

      // 2. Ejecutar rúbricas y evaluaciones en paralelo
      final resultados = await Future.wait([
        _rubricasService.obtenerRubricas(),
        evaluacionesQuery.get(),
      ]);

      final todasRubricas = resultados[0] as List<Rubrica>;
      final evaluacionesSnapshot = resultados[1] as QuerySnapshot;

      // 3. Construir mapa rubricaId → Rubrica para acceso rápido
      final Map<String, Rubrica> rubricasById = {
        for (final r in todasRubricas) r.id: r,
      };

      // 4. Rúbricas donde este jurado está asignado
      final rubricasAsignadas = todasRubricas
          .where((r) => r.juradosAsignados.contains(_userId))
          .toList();

      final Map<String, List<Map<String, dynamic>>> proyectosPorRubrica = {};
      final Map<String, Rubrica> rubricasMapFinal = {};

      for (final rubrica in rubricasAsignadas) {
        proyectosPorRubrica[rubrica.id] = [];
        rubricasMapFinal[rubrica.id] = rubrica;
      }

      // 5. Procesar cada documento de evaluación encontrado
      // Obtener los datos de los proyectos en paralelo para mejor rendimiento
      final List<Future<void>> tareas = [];

      for (final evalDoc in evaluacionesSnapshot.docs) {
        tareas.add(_procesarEvaluacion(
          evalDoc: evalDoc,
          rubricasById: rubricasById,
          rubricasMapFinal: rubricasMapFinal,
          proyectosPorRubrica: proyectosPorRubrica,
        ));
      }

      await Future.wait(tareas);

      // 6. Eliminar rúbricas que no tienen proyectos asignados en este evento
      proyectosPorRubrica.removeWhere((k, v) => v.isEmpty);
      rubricasMapFinal
          .removeWhere((k, _) => !proyectosPorRubrica.containsKey(k));

      if (mounted) {
        setState(() {
          _proyectosPorRubrica = proyectosPorRubrica;
          _rubricasMap = rubricasMapFinal;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error al cargar proyectos: $e');
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

  // Helper para procesar una evaluación individual
  Future<void> _procesarEvaluacion({
    required QueryDocumentSnapshot evalDoc,
    required Map<String, Rubrica> rubricasById,
    required Map<String, Rubrica> rubricasMapFinal,
    required Map<String, List<Map<String, dynamic>>> proyectosPorRubrica,
  }) async {
    try {
      final evalData = evalDoc.data() as Map<String, dynamic>;
      final rubricaId = evalData['rubricaId'] as String?;

      // Solo procesar si la evaluación tiene rubricaId y pertenece a una rúbrica asignada
      if (rubricaId == null || !rubricasMapFinal.containsKey(rubricaId)) {
        // Fallback: intentar encontrar la rúbrica por juradosAsignados si no hay rubricaId
        // (evaluaciones legacy sin el campo rubricaId)
        Rubrica? rubricaEncontrada;
        for (final r in rubricasMapFinal.values) {
          if (r.juradosAsignados.contains(_userId)) {
            rubricaEncontrada = r;
            break;
          }
        }
        if (rubricaEncontrada == null) return;
      }

      final rubricaFinal = rubricaId != null && rubricasMapFinal.containsKey(rubricaId)
          ? rubricasMapFinal[rubricaId]!
          : rubricasMapFinal.values.first;

      // Obtener referencia al proyecto padre
      final proyectoRef = evalDoc.reference.parent.parent;
      if (proyectoRef == null) return;

      final proyectoSnap = await proyectoRef.get();
      if (!proyectoSnap.exists) return;

      final proyectoData = proyectoSnap.data() as Map<String, dynamic>;
      final eventoId = proyectoRef.parent.parent?.id ?? '';

      // Resolver nombres de integrantes
      final integrantesRaw = proyectoData['integrantes'] ??
          proyectoData['Integrantes'];
      final integrantes = _resolverCampoString(integrantesRaw);

      final salaRaw =
          proyectoData['Sala'] ?? proyectoData['sala'] ?? '';
      final titulo =
          proyectoData['Título'] ?? proyectoData['titulo'] ?? '';
      final codigo =
          proyectoData['Código'] ?? proyectoData['codigo'] ?? '';

      final entrada = {
        'proyectoId': proyectoRef.id,
        'eventId': eventoId,
        'codigo': _resolverCampoString(codigo),
        'titulo': _resolverCampoString(titulo),
        'integrantes': integrantes,
        'sala': _resolverCampoString(salaRaw),
        'eventoNombre': _resolverCampoString(
            evalData['eventoNombre'] ?? proyectoData['eventoNombre'] ?? ''),
        'evaluada': evalData['evaluada'] ?? false,
        'bloqueada': evalData['bloqueada'] ?? false,
        'notaTotal': (evalData['notaTotal'] ?? 0.0).toDouble(),
        'rubrica': rubricaFinal,
      };

      proyectosPorRubrica[rubricaFinal.id]?.add(entrada);
    } catch (e) {
      debugPrint('Error procesando evaluación ${evalDoc.id}: $e');
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
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
                onPressed: _isLoading ? null : _cargarProyectosAsignados,
                tooltip: 'Actualizar',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white, size: 24),
                onPressed: _logout,
                tooltip: 'Cerrar Sesión',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
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

  Widget _buildContent() {
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
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined, size: 72, color: Colors.grey[400]),
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
              const SizedBox(height: 24),
              // Botón de recarga manual
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
                      color:
                          completa ? Colors.green : const Color(0xFFE88A00),
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
                fontSize: 12, fontWeight: FontWeight.bold, color: color)),
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
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
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
                  Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
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
                _infoRow(Icons.people_outline, proyecto['integrantes']),
              if ((proyecto['sala'] as String).isNotEmpty)
                _infoRow(Icons.room_outlined, proyecto['sala']),
              _infoRow(Icons.event_outlined, proyecto['eventoNombre']),
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

// ============================================================================
// BADGE PILL
// ============================================================================
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
// BOTÓN DE NOTA RÁPIDA
// ============================================================================
class _BotonNota extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final bool soloLectura;
  final VoidCallback onTap;

  const _BotonNota({
    required this.label,
    required this.seleccionado,
    required this.soloLectura,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: soloLectura ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: seleccionado
              ? const Color(0xFF1E3A5F)
              : const Color(0xFFEEF4FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: seleccionado
                ? const Color(0xFF1E3A5F)
                : const Color(0xFF1E3A5F).withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: seleccionado ? Colors.white : const Color(0xFF1E3A5F),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PANTALLA DE EVALUACIÓN DE PROYECTO
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
  final Map<String, TextEditingController> _controllers = {};
  bool _isGuardando = false;
  bool _isCargando = true;
  bool _yaEvaluado = false;
  bool _estaBloqueado = false;
  // FIX C5: flag para prevenir doble guardado por tap rápido
  bool _guardadoEnProceso = false;
  late Rubrica _rubrica;

  @override
  void initState() {
    super.initState();
    _rubrica = widget.proyecto['rubrica'] as Rubrica;
    _cargarNotas();
  }

  @override
  void dispose() {
    // FIX m5: liberar todos los controllers creados dinámicamente
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
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
    // FIX C5: prevenir doble guardado
    if (_guardadoEnProceso || _isGuardando) return;

    // FIX M5: verificar bloqueo actual antes de guardar
    // Re-leer el documento para verificar que no fue bloqueado por el admin
    // mientras el jurado tenía la pantalla abierta
    try {
      final docActual = await _firestore
          .collection('events')
          .doc(widget.proyecto['eventId'])
          .collection('proyectos')
          .doc(widget.proyecto['proyectoId'])
          .collection('evaluaciones')
          .doc(widget.juradoId)
          .get();

      if (docActual.exists) {
        final dataActual = docActual.data();
        if (dataActual != null &&
            (dataActual['bloqueada'] == true ||
                dataActual['evaluada'] == true)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Esta evaluación ya fue bloqueada o guardada. No se puede modificar.'),
              backgroundColor: Colors.orange,
            ));
            setState(() {
              _estaBloqueado = true;
              _yaEvaluado = true;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error verificando estado actual: $e');
      // Si falla la verificación, continuar con el guardado normal
    }

    // Validar que la rúbrica tenga criterios
    if (_rubrica.totalCriterios == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Esta rúbrica no tiene criterios configurados'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Validar que todos los criterios estén calificados
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

    // FIX C5: activar el flag de debounce
    _guardadoEnProceso = true;
    setState(() => _isGuardando = true);

    try {
      double notaTotal = 0;
      final Map<String, dynamic> notas = {};

      for (var seccion in _rubrica.secciones) {
        for (var criterio in seccion.criterios) {
          // Clamp para garantizar que ninguna nota supere su peso máximo
          final nota = (_notasSeleccionadas[criterio.id]!)
              .clamp(0.0, criterio.peso);
          notas[criterio.id] = nota;
          notaTotal += nota;
        }
      }

      // Clamp final sobre notaTotal para evitar desbordamientos de punto flotante
      notaTotal = notaTotal.clamp(0.0, _rubrica.puntajeMaximo);

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
        'puntajeMaximo': _rubrica.puntajeMaximo,
        // FIX C4: guardar rubricaId para que la limpieza de evaluaciones funcione
        'rubricaId': _rubrica.id,
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
      if (mounted) {
        setState(() {
          _isGuardando = false;
          // FIX C5: resetear el flag al terminar (éxito o error)
          _guardadoEnProceso = false;
        });
      }
    }
  }

  int get _totalCriterios => _rubrica.totalCriterios;
  int get _criteriosEvaluados =>
      _notasSeleccionadas.values.where((v) => v != null).length;
  double get _notaActual =>
      _notasSeleccionadas.values.fold(0.0, (s, v) => s + (v ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final soloLectura = _estaBloqueado || _yaEvaluado;
    final progresoEval =
        _totalCriterios > 0 ? _criteriosEvaluados / _totalCriterios : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
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
                              color: Colors.white.withValues(alpha: 0.75)),
                        ),
                      ],
                    ),
                  ),
                  // Botón guardar en AppBar solo si no es solo lectura
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
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.25),
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
                      '$_criteriosEvaluados/$_totalCriterios · ${_notaActual.toStringAsFixed(2)} / ${_rubrica.puntajeMaximo.toStringAsFixed(2)} pts',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
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
                          ..._rubrica.secciones
                              .map((s) => _buildSeccion(s, soloLectura)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      // FIX C5: FAB también protegido con _guardadoEnProceso
      floatingActionButton:
          (_isCargando || _isGuardando || soloLectura || _guardadoEnProceso)
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
            ? Colors.red.withValues(alpha: 0.08)
            : Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _estaBloqueado
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(_estaBloqueado ? Icons.lock : Icons.check_circle,
              color: _estaBloqueado ? Colors.red : Colors.green, size: 20),
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
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
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
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.15),
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
                  ? Colors.green.withValues(alpha: 0.12)
                  : const Color(0xFF1E3A5F).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              seccionCompleta ? Icons.check_circle : Icons.folder_open,
              color: seccionCompleta ? Colors.green : const Color(0xFF1E3A5F),
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
              '$criteriosEv/${seccion.criterios.length} evaluados · ${puntajeSeccion.toStringAsFixed(2)}/${seccion.pesoTotal.toStringAsFixed(2)} pts',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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
            ? Colors.green.withValues(alpha: 0.04)
            : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: calificado
              ? Colors.green.withValues(alpha: 0.25)
              : Colors.grey.withValues(alpha: 0.2),
          width: calificado ? 1.5 : 1,
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
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Máx ${criterio.peso.toStringAsFixed(2)} pts',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A5F)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (calificado)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.stars, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    '${nota.toStringAsFixed(2)} pts seleccionados',
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
                'Ingresa una calificación (0 – ${criterio.peso.toStringAsFixed(2)} pts)',
                style: TextStyle(fontSize: 12, color: Colors.orange[700]),
              ),
            ),
          _buildNotaSelector(criterio, nota, soloLectura),
        ],
      ),
    );
  }

  Widget _buildNotaSelector(
      Criterio criterio, double? notaSeleccionada, bool soloLectura) {
    final pesoMaximo = criterio.peso;

    // FIX m5: los controllers se crean una sola vez por criterio
    final controller = _controllers.putIfAbsent(
      criterio.id,
      () => TextEditingController(),
    );

    // Sincronizar solo si el valor numérico es realmente distinto
    // para no interrumpir la escritura del jurado
    if (notaSeleccionada != null) {
      final valorActualEnCampo = double.tryParse(controller.text);
      final difiere = valorActualEnCampo == null ||
          (notaSeleccionada - valorActualEnCampo).abs() >= 0.001;
      if (difiere) {
        final texto = notaSeleccionada.toStringAsFixed(2);
        controller.value = TextEditingValue(
          text: texto,
          selection:
              TextSelection.fromPosition(TextPosition(offset: texto.length)),
        );
      }
    } else if (controller.text.isNotEmpty && soloLectura) {
      // En solo lectura, limpiar si no hay nota
      controller.clear();
    }

    // Botones rápidos: 0%, 25%, 50%, 75%, 100% del máximo del criterio
    final botones = [0.0, 0.25, 0.50, 0.75, 1.0].map((pct) {
      final valor = double.parse((pesoMaximo * pct).toStringAsFixed(2));
      final seleccionado = notaSeleccionada != null &&
          (notaSeleccionada - valor).abs() < 0.001;
      return _BotonNota(
        label: valor.toStringAsFixed(2),
        seleccionado: seleccionado,
        soloLectura: soloLectura,
        onTap: () {
          setState(() => _notasSeleccionadas[criterio.id] = valor);
        },
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Campo de texto libre
        TextFormField(
          controller: controller,
          enabled: !soloLectura,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            hintText: 'Ej: ${(pesoMaximo * 0.75).toStringAsFixed(2)}',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            suffixText: '/ ${pesoMaximo.toStringAsFixed(2)} pts',
            suffixStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3A5F)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: const Color(0xFF1E3A5F).withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFF1E3A5F), width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            filled: true,
            fillColor: soloLectura ? Colors.grey[100] : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
          onChanged: (val) {
            final parsed = double.tryParse(val);
            if (parsed == null) {
              setState(() => _notasSeleccionadas[criterio.id] = null);
              return;
            }
            final clamped = parsed.clamp(0.0, pesoMaximo);
            setState(() => _notasSeleccionadas[criterio.id] = clamped);
            if (parsed > pesoMaximo) {
              final corregido = pesoMaximo.toStringAsFixed(2);
              controller.value = TextEditingValue(
                text: corregido,
                selection: TextSelection.fromPosition(
                    TextPosition(offset: corregido.length)),
              );
            }
          },
        ),

        const SizedBox(height: 8),

        // Botones rápidos
        if (!soloLectura)
          Row(
            children: [
              const Text('Rápido:',
                  style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: botones,
                ),
              ),
            ],
          ),

        // Barra de progreso
        if (notaSeleccionada != null && pesoMaximo > 0) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (notaSeleccionada / pesoMaximo).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                notaSeleccionada / pesoMaximo >= 0.8
                    ? Colors.green
                    : notaSeleccionada / pesoMaximo >= 0.5
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(notaSeleccionada / pesoMaximo * 100).toStringAsFixed(1)}% del máximo',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }
}