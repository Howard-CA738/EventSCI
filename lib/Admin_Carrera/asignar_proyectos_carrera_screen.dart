import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import '/admin/logica/gestion_criterios.dart';

/// Versión de AsignarProyectos para Admin de Carrera.
/// Carga filial/facultad/carrera automáticamente desde la sesión.
class AsignarProyectosCarreraScreen extends StatefulWidget {
  const AsignarProyectosCarreraScreen({super.key});

  @override
  State<AsignarProyectosCarreraScreen> createState() =>
      _AsignarProyectosCarreraScreenState();
}

class _AsignarProyectosCarreraScreenState
    extends State<AsignarProyectosCarreraScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RubricasService _rubricasService = RubricasService();

  // ── Datos de sesión (se cargan al inicio) ────────────────────────────────
  String? _filialId;
  String? _filialNombre;
  String? _facultad;
  String? _carreraId;
  String? _carreraNombre;

  // ── Selección paso a paso ────────────────────────────────────────────────
  String? _eventoSeleccionado;
  Map<String, dynamic>? _eventoData;
  String? _juradoSeleccionado;
  Map<String, dynamic>? _juradoData;

  List<Rubrica> _rubricasDelJurado = [];
  Rubrica? _rubricaSeleccionada;

  List<Map<String, dynamic>> _eventosDisponibles = [];
  List<Map<String, dynamic>> _juradosDisponibles = [];
  List<Map<String, dynamic>> _proyectosDisponibles = [];
  Map<String, List<Map<String, dynamic>>> _proyectosPorCategoria = {};
  Set<String> _proyectosSeleccionados = {};

  bool _isLoadingSession = true;
  bool _isLoadingEventos = false;
  bool _isLoadingJurados = false;
  bool _isLoadingProyectos = false;
  bool _isAsignando = false;

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  // ── Carga sesión igual que CrearEventosCarreraScreen ────────────────────
  Future<void> _loadSessionData() async {
    setState(() => _isLoadingSession = true);
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData != null) {
        _filialId = adminData['filial'];
        _filialNombre = adminData['filialNombre'];
        _facultad = adminData['facultad'];
        _carreraId = adminData['carreraId'] ?? adminData['carrera'];
        _carreraNombre = adminData['carrera'];
      }
    } catch (e) {
      debugPrint('Error cargando sesión: $e');
      _showSnackBar('Error al cargar datos de la sesión', isError: true);
    } finally {
      setState(() => _isLoadingSession = false);
    }

    if (_filialId != null) await _cargarEventos();
  }

  // ── Carga eventos filtrados por carrera de la sesión ─────────────────────
  Future<void> _cargarEventos() async {
    setState(() => _isLoadingEventos = true);
    try {
      final snap = await _firestore
          .collection('events')
          .where('filialId', isEqualTo: _filialId)
          .where('facultad', isEqualTo: _facultad)
          .where('carreraId', isEqualTo: _carreraId)
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _eventosDisponibles = snap.docs.map((doc) {
            final d = doc.data();
            return {
              'id': doc.id,
              'name': d['name'] ?? 'Sin nombre',
              'filialId': d['filialId'] ?? '',
              'filialNombre': d['filialNombre'] ?? '',
              'facultad': d['facultad'] ?? '',
              'carreraId': d['carreraId'] ?? '',
              'carreraNombre': d['carreraNombre'] ?? '',
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error cargando eventos: $e');
    } finally {
      if (mounted) setState(() => _isLoadingEventos = false);
    }
  }

  Future<void> _onEventoChanged(String? eventoId) async {
    if (eventoId == null) return;
    final eventoData = _eventosDisponibles.firstWhere((e) => e['id'] == eventoId);

    setState(() {
      _eventoSeleccionado = eventoId;
      _eventoData = eventoData;
      _juradoSeleccionado = null;
      _juradoData = null;
      _rubricasDelJurado = [];
      _rubricaSeleccionada = null;
      _proyectosSeleccionados.clear();
      _proyectosDisponibles.clear();
      _proyectosPorCategoria.clear();
      _juradosDisponibles = [];
    });

    await _cargarJuradosParaEvento();
  }

  Future<void> _cargarJuradosParaEvento() async {
    if (_eventoData == null) return;
    setState(() => _isLoadingJurados = true);

    try {
      final jurados = await _rubricasService.obtenerJurados(
        filial: _eventoData!['filialId'],
        facultad: _eventoData!['facultad'],
        carrera: (_eventoData!['carreraNombre'] as String).isNotEmpty
            ? _eventoData!['carreraNombre']
            : null,
      );
      if (mounted) {
        setState(() => _juradosDisponibles = jurados);
        if (jurados.isEmpty) {
          _showSnackBar(
            'No hay jurados disponibles para esta carrera',
            isError: false,
            isWarning: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Error cargando jurados: $e');
    } finally {
      if (mounted) setState(() => _isLoadingJurados = false);
    }
  }

  Future<void> _onJuradoChanged(String? juradoId) async {
    if (juradoId == null) return;
    setState(() {
      _juradoSeleccionado = juradoId;
      _juradoData = _juradosDisponibles.firstWhere((j) => j['id'] == juradoId);
      _rubricasDelJurado = [];
      _rubricaSeleccionada = null;
      _proyectosSeleccionados.clear();
      _proyectosDisponibles.clear();
      _proyectosPorCategoria.clear();
    });
    await _cargarRubricasDelJurado(juradoId);
  }

  Future<void> _cargarRubricasDelJurado(String juradoId) async {
    try {
      final todasRubricas = await _rubricasService.obtenerRubricas();
      final rubricasJurado =
          todasRubricas.where((r) => r.juradosAsignados.contains(juradoId)).toList();

      if (rubricasJurado.isEmpty) {
        _showSnackBar('Este jurado no tiene rúbricas asignadas.',
            isError: false, isWarning: true);
        return;
      }

      final eventoFilial = _eventoData!['filialId'];
      final eventoFacultad = _eventoData!['facultad'];
      final eventoCarrera = _eventoData!['carreraNombre'];

      final rubricasCompatibles = rubricasJurado.where((r) {
        if (r.filial != eventoFilial) return false;
        if (r.facultad.trim().toLowerCase() !=
            eventoFacultad.trim().toLowerCase()) return false;
        if (r.carrera != null && r.carrera!.isNotEmpty) {
          return eventoCarrera.trim().toLowerCase() ==
              r.carrera!.trim().toLowerCase();
        }
        return true;
      }).toList();

      if (rubricasCompatibles.isEmpty) {
        _showSnackBar(
          'El jurado no tiene rúbricas compatibles con este evento',
          isError: false,
          isWarning: true,
        );
        return;
      }

      if (mounted) {
        setState(() {
          _rubricasDelJurado = rubricasCompatibles;
          if (rubricasCompatibles.length == 1) {
            _rubricaSeleccionada = rubricasCompatibles.first;
            _cargarProyectosConRubrica(_rubricaSeleccionada!);
          }
        });
      }
    } catch (e) {
      _showSnackBar('Error al cargar rúbricas: $e', isError: true);
    }
  }

  Future<void> _onRubricaChanged(String? rubricaId) async {
    if (rubricaId == null) return;
    final rubrica = _rubricasDelJurado.firstWhere((r) => r.id == rubricaId);
    setState(() {
      _rubricaSeleccionada = rubrica;
      _proyectosSeleccionados.clear();
      _proyectosDisponibles.clear();
      _proyectosPorCategoria.clear();
    });
    await _cargarProyectosConRubrica(rubrica);
  }

  Future<void> _cargarProyectosConRubrica(Rubrica rubrica) async {
    if (_eventoSeleccionado == null || _juradoSeleccionado == null) return;
    setState(() => _isLoadingProyectos = true);

    try {
      final juradoDoc =
          await _firestore.collection('users').doc(_juradoSeleccionado).get();
      List<String> categoriasJurado = [];
      if (juradoDoc.exists) {
        final d = juradoDoc.data();
        if (d != null && d.containsKey('categorias')) {
          categoriasJurado = List<String>.from(d['categorias'] ?? []);
        }
      }

      if (categoriasJurado.isEmpty) {
        _showSnackBar('Este jurado no tiene categorías asignadas',
            isError: false, isWarning: true);
        if (mounted) setState(() => _isLoadingProyectos = false);
        return;
      }

      final proyectosSnap = await _firestore
          .collection('events')
          .doc(_eventoSeleccionado)
          .collection('proyectos')
          .get();

      final evaluacionesSnap = await _firestore
          .collectionGroup('evaluaciones')
          .where('juradoId', isEqualTo: _juradoSeleccionado)
          .where('rubricaId', isEqualTo: rubrica.id)
          .get();

      final proyectosAsignados = <String>{};
      for (var doc in evaluacionesSnap.docs) {
        final parts = doc.reference.path.split('/');
        if (parts.length >= 4) proyectosAsignados.add(parts[3]);
      }

      final Map<String, Map<String, dynamic>> proyectosMap = {};
      for (var doc in proyectosSnap.docs) {
        final d = doc.data();
        final codigo = d['Código'] ?? '';
        final clasificacion = d['Clasificación'] ?? 'Sin categoría';
        if (codigo.isEmpty || !categoriasJurado.contains(clasificacion)) continue;

        if (!proyectosMap.containsKey(codigo)) {
          proyectosMap[codigo] = {
            'id': doc.id,
            'eventId': _eventoSeleccionado,
            'codigo': codigo,
            'titulo': d['Título'] ?? '',
            'integrantes': d['Integrantes'] ?? '',
            'sala': d['Sala'] ?? '',
            'clasificacion': clasificacion,
            'yaAsignado': proyectosAsignados.contains(doc.id),
          };
        }
      }

      final proyectosList = proyectosMap.values.toList()
        ..sort((a, b) =>
            (a['codigo'] as String).compareTo(b['codigo'] as String));

      final Map<String, List<Map<String, dynamic>>> grupos = {};
      for (final p in proyectosList) {
        final cat = p['clasificacion'] as String;
        grupos.putIfAbsent(cat, () => []).add(p);
      }

      if (mounted) {
        _proyectosSeleccionados.clear();
        for (var p in proyectosList) {
          if (p['yaAsignado'] == true) {
            _proyectosSeleccionados.add(p['codigo'] as String);
          }
        }
        setState(() {
          _proyectosDisponibles = proyectosList;
          _proyectosPorCategoria = grupos;
          _isLoadingProyectos = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando proyectos: $e');
      if (mounted) setState(() => _isLoadingProyectos = false);
      _showSnackBar('Error al cargar proyectos: $e', isError: true);
    }
  }

  Future<void> _asignarProyectos() async {
    if (_proyectosSeleccionados.isEmpty) {
      _showSnackBar('Selecciona al menos un proyecto', isWarning: true);
      return;
    }
    if (_rubricaSeleccionada == null) {
      _showSnackBar('Selecciona una rúbrica', isWarning: true);
      return;
    }

    final proyectosAEliminar = _proyectosDisponibles
        .where((p) =>
            !_proyectosSeleccionados.contains(p['codigo']) &&
            p['yaAsignado'] == true)
        .length;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Asignación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Asignar ${_proyectosSeleccionados.length} proyecto(s) a ${_juradoData!['nombre']}?',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.assignment, color: Colors.blue.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rúbrica: ${_rubricaSeleccionada!.nombre}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (proyectosAEliminar > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$proyectosAEliminar asignación(es) se eliminarán',
                        style: TextStyle(fontSize: 12, color: Colors.red[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
            ),
            child: const Text('Asignar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    setState(() => _isAsignando = true);

    try {
      final batch = _firestore.batch();
      int asignados = 0, actualizados = 0, eliminados = 0;

      for (var p in _proyectosDisponibles) {
        final codigo = p['codigo'] as String;
        final yaAsignado = p['yaAsignado'] as bool;
        final seleccionado = _proyectosSeleccionados.contains(codigo);

        final docRef = _firestore
            .collection('events')
            .doc(p['eventId'])
            .collection('proyectos')
            .doc(p['id'])
            .collection('evaluaciones')
            .doc(_juradoSeleccionado);

        if (yaAsignado && !seleccionado) {
          batch.delete(docRef);
          eliminados++;
        } else if (yaAsignado && seleccionado) {
          batch.update(docRef, {
            'rubricaId': _rubricaSeleccionada!.id,
            'rubricaNombre': _rubricaSeleccionada!.nombre,
            'fechaActualizacion': FieldValue.serverTimestamp(),
          });
          actualizados++;
        } else if (!yaAsignado && seleccionado) {
          batch.set(docRef, {
            'juradoId': _juradoSeleccionado,
            'juradoNombre': _juradoData!['nombre'],
            'rubricaId': _rubricaSeleccionada!.id,
            'rubricaNombre': _rubricaSeleccionada!.nombre,
            'filialId': _rubricaSeleccionada!.filial,
            'facultad': _rubricaSeleccionada!.facultad,
            'carreraNombre': _rubricaSeleccionada!.carrera,
            'evaluada': false,
            'bloqueada': false,
            'notaTotal': 0.0,
            'fechaAsignacion': FieldValue.serverTimestamp(),
          });
          asignados++;
        }
      }

      await batch.commit();

      if (mounted) {
        final partes = <String>[];
        if (asignados > 0) partes.add('$asignados nuevo(s)');
        if (actualizados > 0) partes.add('$actualizados actualizado(s)');
        if (eliminados > 0) partes.add('$eliminados eliminado(s)');
        _showSnackBar(partes.isEmpty ? 'Sin cambios' : partes.join(' + '));
        await _cargarProyectosConRubrica(_rubricaSeleccionada!);
      }
    } catch (e) {
      _showSnackBar('Error al asignar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isAsignando = false);
    }
  }

  void _showSnackBar(String msg,
      {bool isError = false, bool isWarning = false}) {
    final color = isError
        ? const Color(0xFFE53935)
        : isWarning
            ? Colors.orange
            : const Color(0xFF43A047);
    final icon = isError
        ? Icons.error_outline
        : isWarning
            ? Icons.warning_amber
            : Icons.check_circle_outline;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _getColorForCategory(int index) {
    const colors = [
      Color(0xFF2196F3),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
      Color(0xFF9C27B0),
      Color(0xFFF44336),
      Color(0xFF009688),
      Color(0xFF3F51B5),
      Color(0xFFE91E63),
    ];
    return colors[index % colors.length];
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF2),
      appBar: AppBar(
        title: const Text('Asignar Proyectos',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoadingSession
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E3A5F)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tarjeta de contexto de sesión
                  _buildContextCard(),
                  const SizedBox(height: 20),

                  // Paso 1: Evento
                  _buildEventoCard(),

                  // Paso 2: Jurado
                  if (_eventoSeleccionado != null) ...[
                    const SizedBox(height: 16),
                    _buildJuradoCard(),
                  ],

                  // Paso 3: Rúbrica
                  if (_rubricasDelJurado.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildRubricasCard(),
                  ],

                  // Paso 4: Proyectos
                  if (_rubricaSeleccionada != null) ...[
                    const SizedBox(height: 16),
                    _buildProyectosCard(),
                    const SizedBox(height: 20),
                    _buildBotonAsignar(),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildContextCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _carreraNombre ?? '—',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(_facultad ?? '—',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    Text(_filialNombre ?? '—',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30),
            ),
            child: const Text('Tu carrera',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildEventoCard() {
    return _buildStepCard(
      stepNumber: '1',
      title: 'Seleccionar Evento',
      color: const Color(0xFF4CAF50),
      icon: Icons.event,
      child: _isLoadingEventos
          ? const Center(child: CircularProgressIndicator())
          : DropdownButtonFormField<String>(
              value: _eventoSeleccionado,
              isExpanded: true,
              decoration: _inputDecoration('Evento', Icons.event_note),
              items: _eventosDisponibles
                  .map((e) => DropdownMenuItem(
                        value: e['id'] as String,
                        child: Text(e['name'] as String,
                            style: const TextStyle(fontSize: 14)),
                      ))
                  .toList(),
              onChanged:
                  _eventosDisponibles.isEmpty ? null : _onEventoChanged,
            ),
    );
  }

  Widget _buildJuradoCard() {
    return _buildStepCard(
      stepNumber: '2',
      title: 'Seleccionar Jurado',
      color: const Color(0xFFFF9800),
      icon: Icons.person,
      child: _isLoadingJurados
          ? const Center(child: CircularProgressIndicator())
          : DropdownButtonFormField<String>(
              value: _juradoSeleccionado,
              isExpanded: true,
              decoration: _inputDecoration('Jurado', Icons.badge),
              items: _juradosDisponibles
                  .map((j) => DropdownMenuItem(
                        value: j['id'] as String,
                        child: Text(j['nombre'] as String,
                            style: const TextStyle(fontSize: 14)),
                      ))
                  .toList(),
              onChanged:
                  _juradosDisponibles.isEmpty ? null : _onJuradoChanged,
            ),
    );
  }

  Widget _buildRubricasCard() {
    return _buildStepCard(
      stepNumber: '3',
      title: _rubricasDelJurado.length > 1
          ? 'Seleccionar Rúbrica (${_rubricasDelJurado.length})'
          : 'Rúbrica del Jurado',
      color: const Color(0xFF9C27B0),
      icon: Icons.checklist,
      child: _rubricasDelJurado.length == 1
          ? Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green[700], size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _rubricasDelJurado.first.nombre,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[900]),
                        ),
                        Text(
                          '${_rubricasDelJurado.first.totalCriterios} criterios · ${_rubricasDelJurado.first.puntajeMaximo.toStringAsFixed(0)} pts',
                          style: TextStyle(
                              fontSize: 12, color: Colors.green[800]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : DropdownButtonFormField<String>(
              value: _rubricaSeleccionada?.id,
              isExpanded: true,
              decoration: _inputDecoration('Rúbrica', Icons.assignment),
              items: _rubricasDelJurado
                  .map((r) => DropdownMenuItem(
                        value: r.id,
                        child: Text(r.nombre,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _onRubricaChanged,
            ),
    );
  }

  Widget _buildProyectosCard() {
    return _buildStepCard(
      stepNumber: '4',
      title: 'Seleccionar Proyectos',
      color: const Color(0xFF2196F3),
      icon: Icons.folder_open,
      trailing: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${_proyectosSeleccionados.length} seleccionados',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2196F3)),
        ),
      ),
      child: _isLoadingProyectos
          ? const Center(
              child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ))
          : _proyectosPorCategoria.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.folder_open,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('No hay proyectos disponibles',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 14)),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _proyectosPorCategoria.keys.length,
                  itemBuilder: (context, index) {
                    final categoria =
                        _proyectosPorCategoria.keys.elementAt(index);
                    final proyectos = _proyectosPorCategoria[categoria]!;
                    return _buildCategoryCard(categoria, proyectos, index);
                  },
                ),
    );
  }

  Widget _buildCategoryCard(
      String categoria, List<Map<String, dynamic>> proyectos, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _getColorForCategory(index).withOpacity(0.3), width: 2),
      ),
      child: Theme(
        data:
            Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _getColorForCategory(index),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${proyectos.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ),
          title: Text(categoria,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF2C3E50))),
          subtitle: Text('${proyectos.length} proyecto(s)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          children: proyectos.map(_buildProyectoItem).toList(),
        ),
      ),
    );
  }

  Widget _buildProyectoItem(Map<String, dynamic> proyecto) {
    final codigo = proyecto['codigo'] as String;
    final yaAsignado = proyecto['yaAsignado'] as bool;
    final isSelected = _proyectosSeleccionados.contains(codigo);

    return Card(
      margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      color: yaAsignado
          ? Colors.amber.shade50
          : isSelected
              ? Colors.blue.shade50
              : const Color(0xFFF8F9FA),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (val) {
          setState(() {
            if (val == true) {
              _proyectosSeleccionados.add(codigo);
            } else {
              _proyectosSeleccionados.remove(codigo);
            }
          });
        },
        title: Row(
          children: [
            Expanded(
              child: Text(
                proyecto['titulo'] as String,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: yaAsignado
                        ? Colors.amber[900]
                        : const Color(0xFF2C3E50)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (yaAsignado)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Ya asignado',
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.qr_code, size: 11, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(codigo,
                  style: TextStyle(fontSize: 11, color: Colors.grey[700])),
            ],
          ),
        ),
        activeColor: const Color(0xFF1E3A5F),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildBotonAsignar() {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isAsignando || _proyectosSeleccionados.isEmpty
            ? null
            : _asignarProyectos,
        icon: _isAsignando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_circle),
        label: Text(
          _isAsignando
              ? 'Asignando...'
              : 'Asignar ${_proyectosSeleccionados.length} Proyecto(s)',
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: _proyectosSeleccionados.isNotEmpty ? 4 : 0,
        ),
      ),
    );
  }

  // ── Helpers de UI ────────────────────────────────────────────────────────

  Widget _buildStepCard({
    required String stepNumber,
    required String title,
    required Color color,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Card(
      elevation: 3,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text(stepNumber,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F))),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
    );
  }
}