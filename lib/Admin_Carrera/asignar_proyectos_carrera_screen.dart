import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import '/admin/logica/gestion_criterios.dart';

class AsignarProyectosCarreraScreen extends StatefulWidget {
  const AsignarProyectosCarreraScreen({super.key});

  @override
  State<AsignarProyectosCarreraScreen> createState() =>
      _AsignarProyectosCarreraScreenState();
}

class _AsignarProyectosCarreraScreenState
    extends State<AsignarProyectosCarreraScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RubricasService _rubricasService = RubricasService();

  String? _filialId;
  String? _filialNombre;
  String? _facultad;
  String? _carreraId;
  String? _carreraNombre;

  String? _eventoSeleccionado;
  Map<String, dynamic>? _eventoData;
  String? _juradoSeleccionado;
  Map<String, dynamic>? _juradoData;

  List<Rubrica> _rubricasDelJurado = [];
  Rubrica? _rubricaSeleccionada;

  List<Map<String, dynamic>> _juradosDisponibles = [];
  List<Map<String, dynamic>> _proyectosDisponibles = [];
  Map<String, List<Map<String, dynamic>>> _proyectosPorCategoria = {};
  // FIX L37: referencia nunca se reasigna → final
  final Set<String> _proyectosSeleccionados = {};

  bool _isLoadingSession = true;
  bool _isLoadingJurados = false;
  bool _isLoadingProyectos = false;
  bool _isAsignando = false;
  bool _modoEdicion = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const _categoryColors = [
    Color(0xFF3B6FD4),
    Color(0xFF2E9E6E),
    Color(0xFFD4863B),
    Color(0xFF8B4DC7),
    Color(0xFFD4453B),
    Color(0xFF2B9EA8),
    Color(0xFF4B63D4),
    Color(0xFFD44B87),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadSessionData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    if (mounted) setState(() => _isLoadingSession = true);
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData != null) {
        _filialId      = adminData['filial'];
        _filialNombre  = adminData['filialNombre'];
        _facultad      = adminData['facultad'];
        _carreraId     = adminData['carreraId'] ?? adminData['carrera'];
        _carreraNombre = adminData['carrera'];
      } else {
        _showSnackBar('No se encontraron datos de sesión', isError: true);
      }
    } catch (e) {
      debugPrint('Error cargando sesión: $e');
      _showSnackBar('Error al cargar datos de la sesión', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoadingSession = false);
        // FIX L98: TickerFuture no necesita await; unawaited() silencia el warning
        unawaited(_fadeController.forward());
      }
    }
  }

  Stream<QuerySnapshot> _buildEventsQuery() {
    return _firestore
        .collection('events')
        .where('filialId',  isEqualTo: _filialId)
        .where('facultad',  isEqualTo: _facultad)
        .where('carreraId', isEqualTo: _carreraId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _onEventoSelected(
      String eventoId, Map<String, dynamic> eventoData) async {
    eventoData['id'] = eventoId;
    setState(() {
      _eventoSeleccionado = eventoId;
      _eventoData         = eventoData;
      _juradoSeleccionado = null;
      _juradoData         = null;
      _rubricasDelJurado  = [];
      _rubricaSeleccionada = null;
      _proyectosSeleccionados.clear();
      _proyectosDisponibles.clear();
      _proyectosPorCategoria.clear();
      _juradosDisponibles = [];
      _modoEdicion        = false;
    });
    await _cargarJuradosParaEvento();
  }

  void _deseleccionarEvento() {
    setState(() {
      _eventoSeleccionado  = null;
      _eventoData          = null;
      _juradoSeleccionado  = null;
      _juradoData          = null;
      _rubricasDelJurado   = [];
      _rubricaSeleccionada = null;
      _proyectosSeleccionados.clear();
      _proyectosDisponibles.clear();
      _proyectosPorCategoria.clear();
      _juradosDisponibles  = [];
      _modoEdicion         = false;
    });
  }

  Future<void> _cargarJuradosParaEvento() async {
    if (_eventoData == null) return;
    if (mounted) setState(() => _isLoadingJurados = true);
    try {
      final jurados = await _rubricasService.obtenerJurados(
        filial:   _eventoData!['filialId'] as String?,
        facultad: _eventoData!['facultad'] as String?,
        carrera:  (_eventoData!['carreraNombre'] as String).isNotEmpty
            ? _eventoData!['carreraNombre'] as String?
            : null,
      );
      if (mounted) {
        setState(() => _juradosDisponibles = jurados);
        if (jurados.isEmpty) {
          _showSnackBar(
            'No hay jurados disponibles para esta carrera',
            isWarning: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Error cargando jurados: $e');
      if (mounted) _showSnackBar('Error al cargar jurados', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingJurados = false);
    }
  }

  Future<void> _onJuradoChanged(String? juradoId) async {
    if (juradoId == null) return;
    setState(() {
      _juradoSeleccionado  = juradoId;
      _juradoData          = _juradosDisponibles.firstWhere((j) => j['id'] == juradoId);
      _rubricasDelJurado   = [];
      _rubricaSeleccionada = null;
      _proyectosSeleccionados.clear();
      _proyectosDisponibles.clear();
      _proyectosPorCategoria.clear();
      _modoEdicion         = false;
    });
    await _cargarRubricasDelJurado(juradoId);
  }

  Future<void> _cargarRubricasDelJurado(String juradoId) async {
    try {
      final todasRubricas    = await _rubricasService.obtenerRubricas();
      final rubricasJurado   = todasRubricas
          .where((r) => r.juradosAsignados.contains(juradoId))
          .toList();

      if (rubricasJurado.isEmpty) {
        if (mounted) {
          _showSnackBar('Este jurado no tiene rúbricas asignadas.',
              isWarning: true);
        }
        return;
      }

      final eventoFilial   = _eventoData!['filialId'] as String?;
      final eventoFacultad = _eventoData!['facultad'] as String? ?? '';
      final eventoCarrera  = _eventoData!['carreraNombre'] as String? ?? '';

      final rubricasCompatibles = rubricasJurado.where((r) {
        if (r.filial != eventoFilial) return false;
        if (r.facultad.trim().toLowerCase() !=
            eventoFacultad.trim().toLowerCase()) return false;
        if (eventoCarrera.isNotEmpty) {
          if (r.carrera == null || r.carrera!.trim().isEmpty) return false;
          return r.carrera!.trim().toLowerCase() ==
              eventoCarrera.trim().toLowerCase();
        }
        return true;
      }).toList();

      if (rubricasCompatibles.isEmpty) {
        if (mounted) {
          _showSnackBar(
            'El jurado no tiene rúbricas compatibles con este evento',
            isWarning: true,
          );
        }
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
      if (mounted) _showSnackBar('Error al cargar rúbricas: $e', isError: true);
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
      _modoEdicion = false;
    });
    await _cargarProyectosConRubrica(rubrica);
  }

  Future<void> _cargarProyectosConRubrica(Rubrica rubrica) async {
    if (_eventoSeleccionado == null || _juradoSeleccionado == null) return;
    if (mounted) setState(() => _isLoadingProyectos = true);

    try {
      final resultados = await Future.wait([
        _firestore.collection('users').doc(_juradoSeleccionado).get(),
        _firestore
            .collection('events')
            .doc(_eventoSeleccionado)
            .collection('proyectos')
            .get(),
        _firestore
            .collectionGroup('evaluaciones')
            .where('juradoId',  isEqualTo: _juradoSeleccionado)
            .where('rubricaId', isEqualTo: rubrica.id)
            .get(),
      ]);

      final juradoDoc        = resultados[0] as DocumentSnapshot;
      final proyectosSnap    = resultados[1] as QuerySnapshot;
      final evaluacionesSnap = resultados[2] as QuerySnapshot;

      List<String> categoriasJurado = [];
      if (juradoDoc.exists) {
        // FIX L885: data() puede ser null → null-check antes del cast
        final rawData = juradoDoc.data();
        if (rawData != null) {
          final d = rawData as Map<String, dynamic>;
          if (d.containsKey('categorias')) {
            categoriasJurado = List<String>.from(d['categorias'] as List? ?? []);
          }
        }
      }

      if (categoriasJurado.isEmpty) {
        if (mounted) {
          _showSnackBar('Este jurado no tiene categorías asignadas',
              isWarning: true);
          setState(() => _isLoadingProyectos = false);
        }
        return;
      }

      final proyectosAsignados = <String>{};
      // FIX L300: var → final
      for (final doc in evaluacionesSnap.docs) {
        final parts = doc.reference.path.split('/');
        if (parts.length >= 4) proyectosAsignados.add(parts[3]);
      }

      final Map<String, Map<String, dynamic>> proyectosMap = {};
      // FIX L306: var → final; FIX L307: null-check en data()
      for (final doc in proyectosSnap.docs) {
        final rawDoc = doc.data();
        if (rawDoc == null) continue;
        final d             = rawDoc as Map<String, dynamic>;
        // FIX L318: cast explícito desde dynamic
        final codigo        = (d['Código']        as String?) ?? '';
        final clasificacion = (d['Clasificación'] as String?) ?? 'Sin categoría';

        if (!categoriasJurado.contains(clasificacion)) continue;

        proyectosMap[doc.id] = {
          'id':            doc.id,
          'eventId':       _eventoSeleccionado,
          'codigo':        codigo.isEmpty ? '(sin código)' : codigo,
          'titulo':        (d['Título']      as String?) ?? '',
          'integrantes':   (d['Integrantes'] as String?) ?? '',
          'sala':          (d['Sala']        as String?) ?? '',
          'clasificacion': clasificacion,
          'yaAsignado':    proyectosAsignados.contains(doc.id),
        };
      }

      final proyectosList = proyectosMap.values.toList()
        ..sort((a, b) =>
            (a['titulo'] as String).compareTo(b['titulo'] as String));

      final Map<String, List<Map<String, dynamic>>> grupos = {};
      // FIX L339: var → final
      for (final p in proyectosList) {
        final cat = p['clasificacion'] as String;
        grupos.putIfAbsent(cat, () => []).add(p);
      }

      if (mounted) {
        _proyectosSeleccionados.clear();
        // FIX L569 (equivalente): var → final
        for (final p in proyectosList) {
          if (p['yaAsignado'] == true) {
            _proyectosSeleccionados.add(p['id'] as String);
          }
        }
        setState(() {
          _proyectosDisponibles  = proyectosList;
          _proyectosPorCategoria = grupos;
          _isLoadingProyectos    = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando proyectos: $e');
      if (mounted) {
        setState(() => _isLoadingProyectos = false);
        _showSnackBar('Error al cargar proyectos: $e', isError: true);
      }
    }
  }

  Future<void> _asignarProyectos() async {
    if (_proyectosSeleccionados.isEmpty && !_modoEdicion) {
      _showSnackBar('Selecciona al menos un proyecto', isWarning: true);
      return;
    }
    if (_rubricaSeleccionada == null) {
      _showSnackBar('Selecciona una rúbrica', isWarning: true);
      return;
    }

    final proyectosAEliminar = _proyectosDisponibles
        .where((p) =>
            !_proyectosSeleccionados.contains(p['id']) &&
            p['yaAsignado'] == true)
        .length;

    final confirmar = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (_modoEdicion
                              ? const Color(0xFF2E9E6E)
                              : const Color(0xFF1E3A5F))
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _modoEdicion
                          ? Icons.edit_note
                          : Icons.assignment_turned_in,
                      color: _modoEdicion
                          ? const Color(0xFF2E9E6E)
                          : const Color(0xFF1E3A5F),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _modoEdicion
                          ? 'Confirmar cambios'
                          : 'Confirmar asignación',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _modoEdicion
                    ? _proyectosSeleccionados.isEmpty
                        ? '¿Quitar TODOS los proyectos asignados a ${_juradoData!['nombre']}?'
                        : '¿Guardar los cambios de proyectos para ${_juradoData!['nombre']}?'
                    : '¿Asignar ${_proyectosSeleccionados.length} proyecto(s) a ${_juradoData!['nombre']}?',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF475569),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F5FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD9F5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.checklist_rounded,
                        color: Color(0xFF3B6FD4), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _rubricaSeleccionada!.nombre,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (proyectosAEliminar > 0) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFFFEC5C5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.delete_sweep_rounded,
                          color: Color(0xFFD4453B), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$proyectosAEliminar asignación(es) se eliminarán',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFD4453B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                              color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Color(0xFF64748B),
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
                        backgroundColor: _modoEdicion
                            ? const Color(0xFF2E9E6E)
                            : const Color(0xFF1E3A5F),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _modoEdicion ? 'Guardar' : 'Asignar',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmar != true) return;
    if (mounted) setState(() => _isAsignando = true);

    try {
      final batch = _firestore.batch();
      int asignados = 0, actualizados = 0, eliminados = 0;

      for (final p in _proyectosDisponibles) {
        final id           = p['id']         as String;
        final yaAsignado   = p['yaAsignado'] as bool;
        final seleccionado = _proyectosSeleccionados.contains(id);

        final docRef = _firestore
            .collection('events')
            .doc(p['eventId'] as String?)
            .collection('proyectos')
            .doc(p['id'] as String?)
            .collection('evaluaciones')
            .doc(_juradoSeleccionado);

        if (yaAsignado && !seleccionado) {
          batch.delete(docRef);
          eliminados++;
        } else if (yaAsignado && seleccionado) {
          batch.update(docRef, {
            'rubricaId':           _rubricaSeleccionada!.id,
            'rubricaNombre':       _rubricaSeleccionada!.nombre,
            'fechaActualizacion':  FieldValue.serverTimestamp(),
          });
          actualizados++;
        } else if (!yaAsignado && seleccionado) {
          batch.set(docRef, {
            'juradoId':      _juradoSeleccionado,
            'juradoNombre':  _juradoData!['nombre'],
            'rubricaId':     _rubricaSeleccionada!.id,
            'rubricaNombre': _rubricaSeleccionada!.nombre,
            'filialId':      _rubricaSeleccionada!.filial,
            'facultad':      _rubricaSeleccionada!.facultad,
            'carreraNombre': _rubricaSeleccionada!.carrera,
            'evaluada':      false,
            'bloqueada':     false,
            'notaTotal':     0.0,
            'fechaAsignacion': FieldValue.serverTimestamp(),
          });
          asignados++;
        }
      }

      await batch.commit();

      if (mounted) {
        final partes = <String>[];
        if (asignados   > 0) partes.add('$asignados nuevo(s)');
        if (actualizados > 0) partes.add('$actualizados actualizado(s)');
        if (eliminados  > 0) partes.add('$eliminados eliminado(s)');
        _showSnackBar(partes.isEmpty ? 'Sin cambios' : partes.join(' · '));
        setState(() => _modoEdicion = false);
        await _cargarProyectosConRubrica(_rubricaSeleccionada!);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error al asignar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isAsignando = false);
    }
  }

  void _showSnackBar(String msg,
      {bool isError = false, bool isWarning = false}) {
    if (!mounted) return;
    final color = isError
        ? const Color(0xFFD4453B)
        : isWarning
            ? const Color(0xFFD4863B)
            : const Color(0xFF2E9E6E);
    final icon = isError
        ? Icons.error_outline_rounded
        : isWarning
            ? Icons.warning_amber_rounded
            : Icons.check_circle_outline_rounded;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 6,
      ),
    );
  }

  Color _getColorForCategory(int index) =>
      _categoryColors[index % _categoryColors.length];

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate().toLocal();
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F7),
      appBar: AppBar(
        title: const Text(
          'Asignar Proyectos',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: _eventoSeleccionado != null
            ? Semantics(
                label: 'Cambiar evento',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18),
                  onPressed: _deseleccionarEvento,
                  tooltip: 'Cambiar evento',
                ),
              )
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      body: _isLoadingSession
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1E3A5F),
                strokeWidth: 2.5,
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildContextCard(),
                    const SizedBox(height: 16),
                    if (_eventoSeleccionado == null)
                      _buildEventosList()
                    else ...[
                      _buildEventoSeleccionadoCard(),
                      const SizedBox(height: 14),
                      _buildJuradoCard(),
                      if (_rubricasDelJurado.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildRubricasCard(),
                      ],
                      if (_rubricaSeleccionada != null) ...[
                        const SizedBox(height: 14),
                        _buildProyectosCard(),
                        const SizedBox(height: 16),
                        _buildBotonAsignar(),
                      ],
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildContextCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2D5480)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.school_rounded,
                color: Colors.white, size: 24),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _facultad ?? '—',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _filialNombre ?? '—',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withOpacity(0.25)),
            ),
            child: const Text(
              'Tu carrera',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventosList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildEventsQuery(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: CircularProgressIndicator(
                color: Color(0xFF1E3A5F),
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error al cargar los eventos. Verifica tu conexión.');
        }

        final events = snapshot.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Seleccionar Evento',
              count: events.length,
              hint: 'Toca un evento para asignar proyectos',
            ),
            const SizedBox(height: 12),
            if (events.isEmpty)
              _buildNoEventsState()
            else
              ...events.map((event) {
                final data = event.data() as Map<String, dynamic>;
                return _buildEventCard(
                  event.id,
                  data,
                  key: ValueKey(event.id),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A5F),
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF1E3A5F),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 15, color: Colors.blue[700]),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hint,
                  style:
                      TextStyle(fontSize: 12, color: Colors.blue[700]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(String eventId, Map<String, dynamic> data,
      {Key? key}) {
    final name    = data['name'] as String? ?? '';
    final periodo = data['periodoNombre'] as String? ?? '';
    final displayName = name.isNotEmpty ? name : 'Sin nombre';
    final initial = displayName[0].toUpperCase();

    return Semantics(
      label: 'Evento: $displayName',
      button: true,
      child: GestureDetector(
        key: key,
        onTap: () => _onEventoSelected(
            eventId, Map<String, dynamic>.from(data)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8EDF5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2E5A8D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1E3A5F),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (periodo.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded,
                              size: 11, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              periodo,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (data['createdAt'] != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 11, color: Colors.blue[400]),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(
                                data['createdAt'] as Timestamp),
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[400]),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F5FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF1E3A5F),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventoSeleccionadoCard() {
    final name    = _eventoData?['name'] as String? ?? 'Sin nombre';
    final periodo = _eventoData?['periodoNombre'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF2E9E6E), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E9E6E).withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF2E9E6E).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_available_rounded,
                color: Color(0xFF2E9E6E), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF2E9E6E), size: 12),
                    const SizedBox(width: 4),
                    const Text(
                      'Evento seleccionado',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF2E9E6E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E3A5F),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (periodo.isNotEmpty)
                  Text(
                    periodo,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Semantics(
            label: 'Cambiar evento seleccionado',
            button: true,
            child: TextButton.icon(
              onPressed: _deseleccionarEvento,
              icon: const Icon(Icons.swap_horiz_rounded,
                  size: 15, color: Color(0xFF1E3A5F)),
              label: const Text(
                'Cambiar',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1E3A5F),
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                minimumSize: const Size(44, 44),
                backgroundColor:
                    const Color(0xFF1E3A5F).withOpacity(0.07),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJuradoCard() {
    final nombreSeleccionado = _juradoData?['nombre'] as String?;

    return _buildStepCard(
      stepNumber: '2',
      title: 'Seleccionar Jurado',
      stepColor: const Color(0xFFD4863B),
      icon: Icons.person_rounded,
      child: _isLoadingJurados
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFFD4863B)),
              ),
            )
          : _juradosDisponibles.isEmpty
              ? _buildNoJuradosState()
              : Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _juradoSeleccionado != null
                          ? const Color(0xFFFFF7ED)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _juradoSeleccionado != null
                            ? const Color(0xFFD4863B)
                            : const Color(0xFFE2E8F0),
                        width: _juradoSeleccionado != null ? 1.5 : 1,
                      ),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      collapsedShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      leading: _juradoSeleccionado != null
                          ? Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFD4863B),
                                    Color(0xFFE8A458)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  (nombreSeleccionado ?? '?')[0]
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4863B)
                                    .withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.badge_rounded,
                                  color: Color(0xFFD4863B), size: 18),
                            ),
                      title: Text(
                        nombreSeleccionado ??
                            'Selecciona un jurado',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _juradoSeleccionado != null
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _juradoSeleccionado != null
                              ? const Color(0xFF92400E)
                              : const Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: _juradoSeleccionado != null
                          ? const Text(
                              'Toca para cambiar',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFD4863B)),
                            )
                          : null,
                      iconColor: const Color(0xFFD4863B),
                      collapsedIconColor: const Color(0xFF94A3B8),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      children: _juradosDisponibles
                          .map((j) => _buildJuradoItem(j))
                          .toList(),
                    ),
                  ),
                ),
    );
  }

  Widget _buildNoJuradosState() {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        children: [
          Icon(Icons.person_off_rounded,
              color: Color(0xFFD4863B), size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No hay jurados disponibles para esta carrera',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJuradoItem(Map<String, dynamic> jurado) {
    final id         = jurado['id']     as String;
    final nombre     = jurado['nombre'] as String? ?? '—';
    // FIX L213: cast explícito desde dynamic antes de List.from
    final categorias = List<dynamic>.from(
        jurado['categorias'] as List<dynamic>? ?? <dynamic>[]);
    final isSelected = _juradoSeleccionado == id;
    final inicial    = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    final chipsCategorias = categorias.take(3).map<Widget>((cat) {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD4863B).withOpacity(0.15)
              : const Color(0xFF1E3A5F).withOpacity(0.07),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          // FIX L1037: cast explícito a Object antes de toString()
          (cat as Object).toString(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? const Color(0xFF92400E)
                : const Color(0xFF475569),
          ),
        ),
      );
    }).toList();

    if (categorias.length > 3) {
      chipsCategorias.add(
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '+${categorias.length - 3}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: 'Jurado: $nombre',
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () => _onJuradoChanged(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFFF7ED)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFD4863B)
                  : const Color(0xFFE8EDF5),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color:
                          const Color(0xFFD4863B).withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [
                            Color(0xFFD4863B),
                            Color(0xFFE8A458)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFF64748B),
                            Color(0xFF94A3B8)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    inicial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isSelected
                            ? const Color(0xFF92400E)
                            : const Color(0xFF1E3A5F),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (categorias.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: chipsCategorias,
                      ),
                    ] else
                      Text(
                        'Sin categorías asignadas',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400]),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFD4863B)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFD4863B)
                        : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                  shape: BoxShape.circle,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRubricasCard() {
    return _buildStepCard(
      stepNumber: '3',
      title: _rubricasDelJurado.length > 1
          ? 'Seleccionar Rúbrica (${_rubricasDelJurado.length})'
          : 'Rúbrica del Jurado',
      stepColor: const Color(0xFF8B4DC7),
      icon: Icons.checklist_rounded,
      child: _rubricasDelJurado.length == 1
          ? Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FBF6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF9FD9BB), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E9E6E).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF2E9E6E), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _rubricasDelJurado.first.nombre,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A5C3E),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_rubricasDelJurado.first.totalCriterios} criterios · ${_rubricasDelJurado.first.puntajeMaximo.toStringAsFixed(0)} pts máx.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2E9E6E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : DropdownButtonFormField<String>(
              initialValue: _rubricaSeleccionada?.id,
              isExpanded: true,
              decoration: _inputDecoration(
                  'Selecciona una rúbrica', Icons.assignment_rounded),
              items: _rubricasDelJurado
                  .map((r) => DropdownMenuItem(
                        value: r.id,
                        child: Text(
                          r.nombre,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
      stepColor: const Color(0xFF3B6FD4),
      icon: Icons.folder_open_rounded,
      trailing: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF3B6FD4).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${_proyectosSeleccionados.length} sel.',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF3B6FD4),
          ),
        ),
      ),
      child: _isLoadingProyectos
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child:
                    CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : _proyectosPorCategoria.isEmpty
              ? _buildEmptyProyectos()
              : Column(
                  children: List.generate(
                    _proyectosPorCategoria.keys.length,
                    (index) {
                      final categoria = _proyectosPorCategoria.keys
                          .elementAt(index);
                      final proyectos =
                          _proyectosPorCategoria[categoria]!;
                      return _buildCategoryCard(
                          categoria, proyectos, index);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyProyectos() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.folder_off_rounded,
              size: 44, color: Colors.grey[350]),
          const SizedBox(height: 10),
          Text(
            'No hay proyectos disponibles',
            style:
                TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    String categoria,
    List<Map<String, dynamic>> proyectos,
    int index,
  ) {
    final color = _getColorForCategory(index);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: color.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context)
            .copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${proyectos.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          title: Text(
            categoria,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF1E3A5F),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${proyectos.length} proyecto(s)',
            style: TextStyle(
                fontSize: 11, color: Colors.grey[500]),
          ),
          childrenPadding:
              const EdgeInsets.fromLTRB(10, 0, 10, 10),
          // FIX L1159: pasar key explícito para evitar dynamic implícito
          children: proyectos
              .map((p) => _buildProyectoItem(p, key: ValueKey(p['id'] as String)))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildProyectoItem(Map<String, dynamic> proyecto,
      {Key? key}) {
    final id          = proyecto['id']         as String;
    final codigo      = proyecto['codigo']     as String;
    final yaAsignado  = proyecto['yaAsignado'] as bool;
    final isSelected  = _proyectosSeleccionados.contains(id);
    final interactivo = _modoEdicion || !yaAsignado;

    Color cardBg;
    Color? textColor;
    Color borderColor = Colors.transparent;

    if (!_modoEdicion && yaAsignado) {
      cardBg      = const Color(0xFFFFFBEB);
      textColor   = const Color(0xFF92400E);
      borderColor = Colors.transparent;
    } else if (_modoEdicion && yaAsignado && isSelected) {
      cardBg      = const Color(0xFFF0FBF6);
      textColor   = const Color(0xFF1A5C3E);
      borderColor = const Color(0xFF2E9E6E);
    } else if (_modoEdicion && yaAsignado && !isSelected) {
      cardBg      = const Color(0xFFFFF5F5);
      textColor   = const Color(0xFF9B1C1C);
      borderColor = const Color(0xFFD4453B);
    } else if (!yaAsignado && isSelected) {
      cardBg      = const Color(0xFFF0F5FF);
      textColor   = const Color(0xFF1E3A5F);
      borderColor = const Color(0xFF3B6FD4);
    } else {
      cardBg      = const Color(0xFFF8FAFC);
      textColor   = const Color(0xFF334155);
      borderColor = Colors.transparent;
    }

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: interactivo
            ? (val) {
                setState(() {
                  if (val == true) {
                    _proyectosSeleccionados.add(id);
                  } else {
                    _proyectosSeleccionados.remove(id);
                  }
                });
              }
            : null,
        title: Row(
          children: [
            Expanded(
              child: Text(
                proyecto['titulo'] as String,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            if (yaAsignado && !_modoEdicion)
              _buildStatusChip(
                  'Asignado', const Color(0xFFD4863B)),
            if (yaAsignado && _modoEdicion)
              _buildStatusChip(
                isSelected ? 'Mantener' : 'Quitar',
                isSelected
                    ? const Color(0xFF2E9E6E)
                    : const Color(0xFFD4453B),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            children: [
              Icon(Icons.qr_code_rounded,
                  size: 11, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                codigo,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        activeColor: const Color(0xFF1E3A5F),
        checkColor: Colors.white,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildBotonAsignar() {
    final tieneAsignados =
        _proyectosDisponibles.any((p) => p['yaAsignado'] == true);

    return Column(
      children: [
        if (_modoEdicion)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFFDE68A), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note_rounded,
                    color: Color(0xFFD4863B), size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Modo edición: marca o desmarca proyectos y guarda los cambios.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: 'Cancelar modo edición',
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _modoEdicion = false;
                        _proyectosSeleccionados.clear();
                        // FIX L1931: var → final
                        for (final p in _proyectosDisponibles) {
                          if (p['yaAsignado'] == true) {
                            _proyectosSeleccionados
                                .add(p['id'] as String);
                          }
                        }
                      });
                    },
                    child: Container(
                      constraints: const BoxConstraints(
                          minWidth: 44, minHeight: 44),
                      alignment: Alignment.center,
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFD4453B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (tieneAsignados && !_modoEdicion)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            width: double.infinity,
            height: 50,
            child: Semantics(
              label: 'Editar proyectos asignados',
              button: true,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _modoEdicion = true);
                  _showSnackBar(
                    'Modo edición activo. Modifica los proyectos y guarda.',
                    isWarning: true,
                  );
                },
                icon: const Icon(Icons.edit_rounded,
                    size: 17, color: Color(0xFF1E3A5F)),
                label: const Text(
                  'Editar proyectos asignados',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: Color(0xFF1E3A5F), width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),

        if (_modoEdicion || !tieneAsignados)
          SizedBox(
            height: 52,
            width: double.infinity,
            child: Semantics(
              label: _modoEdicion
                  ? 'Guardar cambios'
                  : 'Asignar ${_proyectosSeleccionados.length} proyectos',
              button: true,
              child: ElevatedButton.icon(
                onPressed: _isAsignando || (_proyectosSeleccionados.isEmpty && !_modoEdicion)
                    ? null
                    : _asignarProyectos,
                icon: _isAsignando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white),
                      )
                    : Icon(
                        _modoEdicion
                            ? Icons.save_rounded
                            : Icons.check_circle_rounded,
                        size: 20,
                      ),
                label: Text(
                  _isAsignando
                      ? 'Guardando...'
                      : _modoEdicion
                          ? 'Guardar cambios'
                          : 'Asignar ${_proyectosSeleccionados.length} Proyecto(s)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _modoEdicion
                      ? const Color(0xFF2E9E6E)
                      : const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(0xFFCBD5E1),
                  disabledForegroundColor: Colors.white70,
                  elevation:
                      _proyectosSeleccionados.isNotEmpty ? 4 : 0,
                  shadowColor: (_modoEdicion
                          ? const Color(0xFF2E9E6E)
                          : const Color(0xFF1E3A5F))
                      .withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoEventsState() {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF7ED),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              size: 36,
              color: Color(0xFFD4863B),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay eventos disponibles',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay eventos registrados para esta carrera.\nCrea uno en Gestión de Eventos.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF5F5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                size: 36, color: Color(0xFFD4453B)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Error al cargar eventos',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFFD4453B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style:
                TextStyle(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required String title,
    required Color stepColor,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: stepColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      stepNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A5F),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 13,
        color: Color(0xFF64748B),
      ),
      prefixIcon:
          Icon(icon, color: const Color(0xFF1E3A5F), size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
            color: Color(0xFF1E3A5F), width: 1.5),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 14),
    );
  }
}