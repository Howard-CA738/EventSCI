import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/logica/gestion_criterios.dart';
import '/admin/logica/filiales_service.dart';

// Archivo: lib/admin/interfaz/evaluaciones.dart

class EvaluacionesScreen extends StatefulWidget {
  const EvaluacionesScreen({super.key});

  @override
  State<EvaluacionesScreen> createState() => _EvaluacionesScreenState();
}

class _EvaluacionesScreenState extends State<EvaluacionesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RubricasService _rubricasService = RubricasService();
  final FilialesService _filialesService = FilialesService();

  // ═══════════════════════════════════════════════════════════════
  // ✅ ESTRUCTURA DE FILIALES DESDE FIREBASE
  // ═══════════════════════════════════════════════════════════════
  Map<String, dynamic> _estructuraFiliales = {};
  List<String> _filiales = [];
  List<String> _facultadesDisponibles = [];
  List<Map<String, dynamic>> _carrerasDisponibles = [];
  bool _isLoadingFiliales = true;

  // FILTROS
  String? _filialSeleccionada;
  String? _facultadSeleccionada;
  String? _carreraSeleccionada;

  // DATOS
  String? _eventoSeleccionado;
  Map<String, dynamic>? _eventoData;
  List<Map<String, dynamic>> _eventosDisponibles = [];
  List<Map<String, dynamic>> _eventosFiltrados = [];
  List<Map<String, dynamic>> _evaluaciones = [];
  Map<String, Rubrica> _rubricasCache = {};

  // ESTADOS
  bool _isLoadingEventos = false;
  bool _isLoadingEvaluaciones = false;

  @override
  void initState() {
    super.initState();
    _loadFiliales();
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ CARGAR ESTRUCTURA DE FILIALES
  // ═══════════════════════════════════════════════════════════════
  Future<void> _loadFiliales() async {
    setState(() {
      _isLoadingFiliales = true;
    });

    try {
      // Inicializar si es necesario
      await _filialesService.inicializarSiEsNecesario();

      // Obtener estructura completa (con caché de 24h)
      _estructuraFiliales = await _filialesService.getEstructuraCompleta();

      // Obtener lista de filiales
      _filiales = _estructuraFiliales.keys.toList();

      print('✅ Filiales cargadas: $_filiales');

      // Cargar eventos después de cargar filiales
      await _cargarEventos();
    } catch (e) {
      print('❌ Error cargando filiales: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando filiales: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isLoadingFiliales = false;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ ACTUALIZAR FACULTADES SEGÚN FILIAL
  // ═══════════════════════════════════════════════════════════════
  void _onFilialChanged(String? filial) {
    setState(() {
      _filialSeleccionada = filial;
      _facultadSeleccionada = null;
      _carreraSeleccionada = null;
      _eventoSeleccionado = null;
      _eventoData = null;
      _evaluaciones.clear();
      _facultadesDisponibles = [];
      _carrerasDisponibles = [];

      if (filial != null && _estructuraFiliales.containsKey(filial)) {
        final filialData = _estructuraFiliales[filial];
        final facultades = filialData['facultades'] as Map<String, dynamic>?;

        if (facultades != null) {
          _facultadesDisponibles = facultades.keys.toList();
        }
      }

      _filtrarEventos();
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ ACTUALIZAR CARRERAS SEGÚN FACULTAD
  // ═══════════════════════════════════════════════════════════════
  void _onFacultadChanged(String? facultad) {
    setState(() {
      _facultadSeleccionada = facultad;
      _carreraSeleccionada = null;
      _eventoSeleccionado = null;
      _eventoData = null;
      _evaluaciones.clear();
      _carrerasDisponibles = [];

      if (_filialSeleccionada != null &&
          facultad != null &&
          _estructuraFiliales.containsKey(_filialSeleccionada)) {
        final filialData = _estructuraFiliales[_filialSeleccionada!];
        final facultades = filialData['facultades'] as Map<String, dynamic>?;

        if (facultades != null && facultades.containsKey(facultad)) {
          final facultadData = facultades[facultad];
          _carrerasDisponibles = List<Map<String, dynamic>>.from(
            facultadData['carreras'] ?? [],
          );
        }
      }

      _filtrarEventos();
    });
  }

  void _onCarreraChanged(String? carrera) {
    setState(() {
      _carreraSeleccionada = carrera;
      _eventoSeleccionado = null;
      _eventoData = null;
      _evaluaciones.clear();
      _filtrarEventos();
    });
  }

  void _filtrarEventos() {
    if (_filialSeleccionada == null || _facultadSeleccionada == null) {
      setState(() => _eventosFiltrados = []);
      return;
    }

    final nombreSede = _filialesService.getNombreFilial(_filialSeleccionada!);

    List<Map<String, dynamic>> filtrados = _eventosDisponibles.where((evento) {
      // Filtrar por sede
      final sedeMatch = evento['sede'] == nombreSede;
      if (!sedeMatch) return false;

      // Filtrar por facultad
      final facultadMatch = evento['facultad'] == _facultadSeleccionada;
      if (!facultadMatch) return false;

      // Filtrar por carrera si está seleccionada
      if (_carreraSeleccionada != null) {
        return evento['carrera'] == _carreraSeleccionada;
      }

      return true;
    }).toList();

    setState(() => _eventosFiltrados = filtrados);
  }

  Future<void> _cargarEventos() async {
    setState(() {
      _isLoadingEventos = true;
      _eventosDisponibles = [];
    });

    try {
      final eventosSnapshot = await _firestore
          .collection('events')
          .orderBy('createdAt', descending: true)
          .get();

      final eventos = eventosSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Sin nombre',
          'sede': data['sede'] ?? '',
          'facultad': data['facultad'] ?? '',
          'carrera': data['carrera'] ?? 'General',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _eventosDisponibles = eventos;
          _isLoadingEventos = false;
        });
      }
    } catch (e) {
      print('Error al cargar eventos: $e');
      if (mounted) {
        setState(() => _isLoadingEventos = false);
      }
    }
  }

  Future<void> _onEventoChanged(String? eventoId) async {
    if (eventoId == null) return;

    final eventoData = _eventosFiltrados.firstWhere((e) => e['id'] == eventoId);

    setState(() {
      _eventoSeleccionado = eventoId;
      _eventoData = eventoData;
      _evaluaciones.clear();
    });

    await _cargarEvaluaciones();
  }

  // OPTIMIZACIÓN: Carga paralela y eficiente
  Future<void> _cargarEvaluaciones() async {
    if (_eventoSeleccionado == null) return;

    setState(() => _isLoadingEvaluaciones = true);

    try {
      print('🔍 Cargando evaluaciones del evento: $_eventoSeleccionado');

      // 1. Cargar rúbricas en paralelo
      final rubricasFuture = _rubricasService.obtenerRubricas();

      // 2. Obtener proyectos del evento
      final proyectosSnapshot = await _firestore
          .collection('events')
          .doc(_eventoSeleccionado)
          .collection('proyectos')
          .get();

      print('📦 ${proyectosSnapshot.docs.length} proyectos en el evento');

      if (proyectosSnapshot.docs.isEmpty) {
        print('⚠️ No hay proyectos en este evento');
        if (mounted) {
          setState(() {
            _evaluaciones = [];
            _isLoadingEvaluaciones = false;
          });
        }
        return;
      }

      // 3. Esperar rúbricas
      final todasRubricas = await rubricasFuture;
      _rubricasCache = {for (var r in todasRubricas) r.id: r};

      final List<Map<String, dynamic>> evaluacionesList = [];

      // 4. Obtener evaluaciones en batch usando Future.wait (OPTIMIZADO)
      final futures = proyectosSnapshot.docs.map((proyectoDoc) async {
        try {
          final proyectoData = proyectoDoc.data();
          final evaluacionesSnapshot = await _firestore
              .collection('events')
              .doc(_eventoSeleccionado)
              .collection('proyectos')
              .doc(proyectoDoc.id)
              .collection('evaluaciones')
              .get();

          return evaluacionesSnapshot.docs.map((evaluacionDoc) {
            final evaluacionData = evaluacionDoc.data();

            // FIX: Conversión segura de Map<dynamic, dynamic> a Map<String, dynamic>
            final notasRaw = evaluacionData['notas'];
            final Map<String, dynamic> notas = {};
            if (notasRaw != null && notasRaw is Map) {
              notasRaw.forEach((key, value) {
                notas[key.toString()] = value;
              });
            }

            final rubricaId = evaluacionData['rubricaId'] as String?;
            Rubrica? rubrica;
            if (rubricaId != null && _rubricasCache.containsKey(rubricaId)) {
              rubrica = _rubricasCache[rubricaId];
            }

            return {
              'proyectoId': proyectoDoc.id,
              'codigo': proyectoData['Código'] ?? 'Sin código',
              'titulo': proyectoData['Título'] ?? 'Sin título',
              'integrantes': proyectoData['Integrantes'] ?? '',
              'sala': proyectoData['Sala'] ?? '',
              'clasificacion': proyectoData['Clasificación'] ?? 'Sin categoría',
              'juradoId': evaluacionDoc.id,
              'juradoNombre': evaluacionData['juradoNombre'] ?? 'Jurado',
              'rubricaId': rubricaId,
              'rubricaNombre': evaluacionData['rubricaNombre'] ?? 'Sin rúbrica',
              'rubrica': rubrica,
              'evaluada': evaluacionData['evaluada'] ?? false,
              'bloqueada': evaluacionData['bloqueada'] ?? false,
              'notaTotal': (evaluacionData['notaTotal'] ?? 0.0).toDouble(),
              'notas': notas,
              'fechaAsignacion': evaluacionData['fechaAsignacion'],
              'fechaEvaluacion': evaluacionData['fechaEvaluacion'],
            };
          }).toList();
        } catch (e) {
          print('❌ Error procesando proyecto ${proyectoDoc.id}: $e');
          return <Map<String, dynamic>>[];
        }
      }).toList();

      // 5. Esperar todas las evaluaciones en paralelo (MUCHO MÁS RÁPIDO)
      final resultados = await Future.wait(futures);

      // 6. Aplanar la lista de listas
      for (var lista in resultados) {
        evaluacionesList.addAll(lista);
      }

      print('📝 ${evaluacionesList.length} evaluaciones encontradas');

      // Ordenar por código de proyecto
      evaluacionesList.sort((a, b) => a['codigo'].compareTo(b['codigo']));

      print('✅ ${evaluacionesList.length} evaluaciones cargadas');

      if (mounted) {
        setState(() {
          _evaluaciones = evaluacionesList;
          _isLoadingEvaluaciones = false;
        });
      }
    } catch (e) {
      print('❌ Error al cargar evaluaciones: $e');
      if (mounted) {
        setState(() => _isLoadingEvaluaciones = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar evaluaciones: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleBloqueo(Map<String, dynamic> evaluacion) async {
    final bloqueada = evaluacion['bloqueada'] as bool;
    final nuevoEstado = !bloqueada;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          nuevoEstado ? 'Bloquear Evaluación' : 'Desbloquear Evaluación',
        ),
        content: Text(
          nuevoEstado
              ? '¿Deseas bloquear esta evaluación? El jurado no podrá modificarla.'
              : '¿Deseas desbloquear esta evaluación? El jurado podrá modificarla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: nuevoEstado ? Colors.red : Colors.green,
            ),
            child: Text(nuevoEstado ? 'Bloquear' : 'Desbloquear'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _firestore
          .collection('events')
          .doc(_eventoSeleccionado)
          .collection('proyectos')
          .doc(evaluacion['proyectoId'])
          .collection('evaluaciones')
          .doc(evaluacion['juradoId'])
          .update({'bloqueada': nuevoEstado});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nuevoEstado
                  ? '✅ Evaluación bloqueada'
                  : '✅ Evaluación desbloqueada',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarEvaluaciones();
      }
    } catch (e) {
      print('Error al cambiar bloqueo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _verDetalleEvaluacion(Map<String, dynamic> evaluacion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDetalleEvaluacion(evaluacion),
    );
  }

  Widget _buildDetalleEvaluacion(Map<String, dynamic> evaluacion) {
    final rubrica = evaluacion['rubrica'] as Rubrica?;
    final notas = evaluacion['notas'] as Map<String, dynamic>;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evaluación de ${evaluacion['codigo']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Jurado: ${evaluacion['juradoNombre']}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),

              const Divider(height: 24),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Info del proyecto
                    _buildInfoCard(evaluacion),

                    const SizedBox(height: 16),

                    // Nota total
                    _buildNotaTotalCard(evaluacion),

                    const SizedBox(height: 16),

                    // Criterios evaluados
                    if (rubrica != null) ...[
                      const Text(
                        'Criterios Evaluados',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...rubrica.secciones.map((seccion) {
                        return _buildSeccionDetalle(seccion, notas);
                      }).toList(),
                    ] else
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No se encontró la rúbrica asociada',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> evaluacion) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              evaluacion['titulo'],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            if (evaluacion['integrantes'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.people, evaluacion['integrantes']),
            ],
            if (evaluacion['sala'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildInfoRow(Icons.room, evaluacion['sala']),
            ],
            const SizedBox(height: 6),
            _buildInfoRow(
              Icons.category,
              'Categoría: ${evaluacion['clasificacion']}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotaTotalCard(Map<String, dynamic> evaluacion) {
    final evaluada = evaluacion['evaluada'] as bool;
    final notaTotal = evaluacion['notaTotal'] as double;

    return Card(
      elevation: 2,
      color: evaluada ? Colors.green.shade50 : Colors.orange.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: evaluada ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    notaTotal.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'pts',
                    style: TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    evaluada ? 'Evaluación Completa' : 'Evaluación Pendiente',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: evaluada ? Colors.green[900] : Colors.orange[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    evaluacion['rubricaNombre'],
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionDetalle(
    SeccionRubrica seccion,
    Map<String, dynamic> notas,
  ) {
    double puntajeSeccion = 0;
    int criteriosEvaluados = 0;

    for (var criterio in seccion.criterios) {
      if (notas.containsKey(criterio.id)) {
        puntajeSeccion += (notas[criterio.id] as num).toDouble();
        criteriosEvaluados++;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.folder_open,
              color: Color(0xFF1E3A5F),
              size: 20,
            ),
          ),
          title: Text(
            seccion.nombre,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
          subtitle: Text(
            '$criteriosEvaluados/${seccion.criterios.length} criterios • ${puntajeSeccion.toStringAsFixed(1)}/${seccion.pesoTotal.toStringAsFixed(0)} pts',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          children: seccion.criterios.map((criterio) {
            final nota = notas[criterio.id];
            return _buildCriterioDetalle(criterio, nota);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCriterioDetalle(Criterio criterio, dynamic nota) {
    final tieneNota = nota != null;
    final notaDouble = tieneNota ? (nota as num).toDouble() : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tieneNota ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tieneNota
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  criterio.descripcion,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Máximo: ${criterio.peso.toStringAsFixed(1)} pts',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tieneNota ? Colors.green : Colors.grey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tieneNota ? notaDouble.toStringAsFixed(1) : '-',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ver Evaluaciones',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (_eventoSeleccionado != null)
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: _isLoadingEvaluaciones
                          ? null
                          : _cargarEvaluaciones,
                      tooltip: 'Actualizar',
                    ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _isLoadingFiliales
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: Color(0xFF1E3A5F),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Cargando filiales...',
                              style: TextStyle(
                                color: Color(0xFF1E3A5F),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // PASO 1: Filtros
                              _buildFiltrosCard(),

                              // PASO 2: Selector de Evento
                              if (_filialSeleccionada != null &&
                                  _facultadSeleccionada != null) ...[
                                const SizedBox(height: 16),
                                _buildEventoCard(),
                              ],

                              // Resumen de evaluaciones
                              if (_eventoSeleccionado != null &&
                                  !_isLoadingEvaluaciones) ...[
                                const SizedBox(height: 16),
                                _buildResumenCard(),
                              ],

                              // Lista de evaluaciones
                              if (_eventoSeleccionado != null) ...[
                                const SizedBox(height: 16),
                                _buildEvaluacionesCard(),
                              ],

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltrosCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF2C5F7C)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.filter_list,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '1. Filtrar por Filial, Facultad y Carrera',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ✅ Filtro Filial
            DropdownButtonFormField<String>(
              value: _filialSeleccionada,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Filial (Sede)',
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _filiales.map((filial) {
                final nombre = _filialesService.getNombreFilial(filial);
                final ubicacion = _filialesService.getUbicacionFilial(filial);
                return DropdownMenuItem(
                  value: filial,
                  child: Text(
                    '$nombre - $ubicacion',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _onFilialChanged,
            ),

            // ✅ Filtro Facultad
            if (_filialSeleccionada != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _facultadSeleccionada,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Facultad',
                  prefixIcon: const Icon(Icons.school),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _facultadesDisponibles.map((facultad) {
                  return DropdownMenuItem(
                    value: facultad,
                    child: Text(
                      facultad,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _onFacultadChanged,
              ),
            ],

            // ✅ Filtro Carrera
            if (_facultadSeleccionada != null &&
                _carrerasDisponibles.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _carreraSeleccionada,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Carrera (Opcional)',
                  prefixIcon: const Icon(Icons.menu_book),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _carrerasDisponibles.map((carrera) {
                  return DropdownMenuItem<String>(
                    value: carrera['nombre'] as String,
                    child: Text(
                      carrera['nombre'] as String,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _onCarreraChanged,
              ),
            ],

            // Info de eventos disponibles
            if (_filialSeleccionada != null &&
                _facultadSeleccionada != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_eventosFiltrados.length} evento(s) disponible(s)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventoCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.event, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '2. Seleccionar Evento',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _eventoSeleccionado,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Evento',
                prefixIcon: const Icon(Icons.event_note),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _eventosFiltrados.map((evento) {
                return DropdownMenuItem(
                  value: evento['id'] as String,
                  child: Text(
                    evento['name'] as String,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _eventosFiltrados.isEmpty ? null : _onEventoChanged,
            ),
            if (_eventoData != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: Colors.green[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_eventoData!['name']}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResumenCard() {
    final totalEvaluaciones = _evaluaciones.length;
    final evaluadas = _evaluaciones.where((e) => e['evaluada'] as bool).length;
    final pendientes = totalEvaluaciones - evaluadas;
    final bloqueadas = _evaluaciones
        .where((e) => e['bloqueada'] as bool)
        .length;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF2C5F7C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  'Resumen de Evaluaciones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildEstadisticaItem(
                    'Total',
                    totalEvaluaciones.toString(),
                    Icons.assignment,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEstadisticaItem(
                    'Evaluadas',
                    evaluadas.toString(),
                    Icons.check_circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildEstadisticaItem(
                    'Pendientes',
                    pendientes.toString(),
                    Icons.pending,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEstadisticaItem(
                    'Bloqueadas',
                    bloqueadas.toString(),
                    Icons.lock,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadisticaItem(String label, String valor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluacionesCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.assessment,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Lista de Evaluaciones',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingEvaluaciones)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Cargando evaluaciones...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_evaluaciones.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay evaluaciones en este evento',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Las evaluaciones aparecerán cuando se asignen proyectos a los jurados',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _evaluaciones.length,
                itemBuilder: (context, index) {
                  return _buildEvaluacionItem(_evaluaciones[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluacionItem(Map<String, dynamic> evaluacion) {
    final evaluada = evaluacion['evaluada'] as bool;
    final bloqueada = evaluacion['bloqueada'] as bool;

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
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: estadoColor.withOpacity(0.3), width: 2),
      ),
      child: InkWell(
        onTap: () => _verDetalleEvaluacion(evaluacion),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FIX: Row con overflow - usar Flexible/Expanded
              Row(
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        evaluacion['codigo'],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: estadoColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(estadoIcon, size: 14, color: estadoColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              estadoTexto,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: estadoColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                evaluacion['titulo'],
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              _buildInfoRowSmall(
                Icons.person,
                'Jurado: ${evaluacion['juradoNombre']}',
              ),
              const SizedBox(height: 4),
              _buildInfoRowSmall(Icons.checklist, evaluacion['rubricaNombre']),
              if (evaluacion['integrantes'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                _buildInfoRowSmall(Icons.people, evaluacion['integrantes']),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (evaluada)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.grade,
                              color: Colors.green,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Nota: ${evaluacion['notaTotal'].toStringAsFixed(1)} pts',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (evaluada && !bloqueada) const SizedBox(width: 8),
                  if (!bloqueada)
                    IconButton(
                      onPressed: () => _toggleBloqueo(evaluacion),
                      icon: const Icon(Icons.lock_open, color: Colors.grey),
                      tooltip: 'Bloquear evaluación',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                  if (bloqueada)
                    IconButton(
                      onPressed: () => _toggleBloqueo(evaluacion),
                      icon: const Icon(Icons.lock, color: Colors.red),
                      tooltip: 'Desbloquear evaluación',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRowSmall(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
