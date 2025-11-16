import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'crear_jurados.dart';
import 'gestion_criterios.dart';

class AsignarProyectosScreen extends StatefulWidget {
  const AsignarProyectosScreen({super.key});

  @override
  State<AsignarProyectosScreen> createState() => _AsignarProyectosScreenState();
}

class _AsignarProyectosScreenState extends State<AsignarProyectosScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RubricasService _rubricasService = RubricasService();

  // Estructura de facultades y carreras (igual que en EventosService)
  final Map<String, List<String>> facultadesCarreras = {
    'Universidad Peruana Unión': [],
    'Facultad de Ciencias Empresariales': [
      'Administración',
      'Contabilidad',
      'Gestión Tributaria y Aduanera',
    ],
    'Facultad de Ciencias Humanas y Educación': [
      'Educación, Especialidad Inicial y Puericultura',
      'Educación, Especialidad Primaria y Pedagogía Terapéutica',
      'Educación, Especialidad Inglés y Español',
    ],
    'Facultad de Ciencias de la Salud': [
      'Enfermería',
      'Nutrición Humana',
      'Psicología',
    ],
    'Facultad de Ingeniería y Arquitectura': [
      'Ingeniería Civil',
      'Arquitectura y Urbanismo',
      'Ingeniería Ambiental',
      'Ingeniería de Industrias Alimentarias',
      'Ingeniería de Sistemas',
    ],
  };

  // FILTROS PRINCIPALES
  String? _facultadSeleccionada;
  String? _carreraSeleccionada;
  List<String> _carrerasDisponibles = [];

  // Selección
  String? _eventoSeleccionado;
  Map<String, dynamic>? _eventoData;
  String? _juradoSeleccionado;
  Map<String, dynamic>? _juradoData;
  Rubrica? _rubricaAsignada;

  // Listas dinámicas
  List<Map<String, dynamic>> _eventosDisponibles = [];
  List<Map<String, dynamic>> _eventosFiltrados = [];
  List<Map<String, dynamic>> _juradosDisponibles = [];
  List<Map<String, dynamic>> _proyectosDisponibles = [];
  Map<String, List<Map<String, dynamic>>> _proyectosPorCategoria = {};
  Set<String> _proyectosSeleccionados = {};

  bool _isLoadingEventos = false;
  bool _isLoadingJurados = false;
  bool _isLoadingProyectos = false;
  bool _isAsignando = false;

  @override
  void initState() {
    super.initState();
    _cargarEventos();
  }

  bool _requiereCarrera(String? facultad) {
    if (facultad == null) return false;
    return facultad != 'Universidad Peruana Unión';
  }

  void _onFacultadChanged(String? facultad) {
    setState(() {
      _facultadSeleccionada = facultad;
      _carreraSeleccionada = null;
      _eventoSeleccionado = null;
      _eventoData = null;
      _juradoSeleccionado = null;
      _juradoData = null;
      _rubricaAsignada = null;
      _proyectosSeleccionados.clear();
      _proyectosDisponibles.clear();
      _proyectosPorCategoria.clear();
      _juradosDisponibles.clear();

      if (facultad != null) {
        _carrerasDisponibles = facultadesCarreras[facultad] ?? [];
        _filtrarEventos();
      } else {
        _carrerasDisponibles = [];
        _eventosFiltrados = [];
      }
    });
  }

  void _onCarreraChanged(String? carrera) {
    setState(() {
      _carreraSeleccionada = carrera;
      _eventoSeleccionado = null;
      _eventoData = null;
      _juradoSeleccionado = null;
      _juradoData = null;
      _rubricaAsignada = null;
      _proyectosSeleccionados.clear();
      _proyectosDisponibles.clear();
      _proyectosPorCategoria.clear();
      _juradosDisponibles.clear();

      _filtrarEventos();
    });
  }

  void _filtrarEventos() {
    if (_facultadSeleccionada == null) {
      setState(() => _eventosFiltrados = []);
      return;
    }

    List<Map<String, dynamic>> filtrados = _eventosDisponibles.where((evento) {
      final facultadMatch = evento['facultad'] == _facultadSeleccionada;

      if (_facultadSeleccionada == 'Universidad Peruana Unión') {
        return facultadMatch;
      }

      if (_carreraSeleccionada != null) {
        return facultadMatch && evento['carrera'] == _carreraSeleccionada;
      }

      return facultadMatch;
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
      _juradoSeleccionado = null;
      _juradoData = null;
      _rubricaAsignada = null;
      _proyectosSeleccionados.clear();
      _proyectosDisponibles.clear();
      _proyectosPorCategoria.clear();
      _juradosDisponibles.clear();
    });

    await _cargarJuradosParaEvento();
  }

  Future<void> _cargarJuradosParaEvento() async {
    if (_eventoData == null) return;

    setState(() {
      _isLoadingJurados = true;
      _juradosDisponibles = [];
    });

    try {
      final facultadEvento = _eventoData!['facultad'];
      final carreraEvento = _eventoData!['carrera'];

      print('🔍 Buscando jurados para:');
      print('   Facultad: $facultadEvento');
      print('   Carrera: $carreraEvento');

      final jurados = await _rubricasService.obtenerJurados(
        facultad: facultadEvento,
        carrera: carreraEvento != 'General' ? carreraEvento : null,
      );

      if (mounted) {
        setState(() {
          _juradosDisponibles = jurados;
          _isLoadingJurados = false;
        });

        if (jurados.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                carreraEvento != 'General'
                    ? 'No hay jurados disponibles para $facultadEvento - $carreraEvento'
                    : 'No hay jurados disponibles para $facultadEvento',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error al cargar jurados: $e');
      if (mounted) {
        setState(() => _isLoadingJurados = false);
      }
    }
  }

  Future<void> _onJuradoChanged(String? juradoId) async {
    if (juradoId == null) return;

    setState(() {
      _juradoSeleccionado = juradoId;
      _juradoData = _juradosDisponibles.firstWhere((j) => j['id'] == juradoId);
      _proyectosSeleccionados.clear();
      _proyectosDisponibles.clear();
      _proyectosPorCategoria.clear();
      _rubricaAsignada = null;
    });

    await _cargarRubricaYProyectos(juradoId);
  }

  Future<void> _cargarRubricaYProyectos(String juradoId) async {
    if (_eventoSeleccionado == null) return;

    setState(() => _isLoadingProyectos = true);

    try {
      // 1. Buscar rúbrica del jurado
      final todasRubricas = await _rubricasService.obtenerRubricas();
      final rubricasJurado = todasRubricas
          .where((r) => r.juradosAsignados.contains(juradoId))
          .toList();

      if (rubricasJurado.isEmpty) {
        if (mounted) {
          setState(() => _isLoadingProyectos = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este jurado no tiene rúbricas asignadas.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final rubrica = rubricasJurado.first;

      // 2. Verificar compatibilidad evento-rúbrica
      final eventoFacultad = _eventoData!['facultad'];
      final eventoCarrera = _eventoData!['carrera'];

      final facultadMatch =
          eventoFacultad.trim().toLowerCase() ==
          rubrica.facultad.trim().toLowerCase();

      if (!facultadMatch) {
        if (mounted) {
          setState(() => _isLoadingProyectos = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ El evento es de "$eventoFacultad" pero la rúbrica del jurado es para "${rubrica.facultad}"',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (rubrica.carrera != null && rubrica.carrera != 'General') {
        final carreraMatch =
            eventoCarrera.trim().toLowerCase() ==
            rubrica.carrera!.trim().toLowerCase();

        if (!carreraMatch) {
          if (mounted) {
            setState(() => _isLoadingProyectos = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '⚠️ El evento es de "$eventoCarrera" pero la rúbrica es para "${rubrica.carrera}"',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      }

      // 3. Cargar proyectos del evento
      print('📦 Cargando proyectos del evento...');

      final proyectosSnapshot = await _firestore
          .collection('events')
          .doc(_eventoSeleccionado)
          .collection('proyectos')
          .get();

      print('✅ ${proyectosSnapshot.docs.length} proyectos encontrados');

      // 4. Cargar evaluaciones del jurado
      final evaluacionesSnapshot = await _firestore
          .collectionGroup('evaluaciones')
          .where('juradoId', isEqualTo: juradoId)
          .get();

      final proyectosAsignados = <String>{};
      for (var doc in evaluacionesSnapshot.docs) {
        final path = doc.reference.path;
        final parts = path.split('/');
        if (parts.length >= 4) {
          final proyectoId = parts[3];
          proyectosAsignados.add(proyectoId);
        }
      }

      print('🔒 ${proyectosAsignados.length} proyectos ya asignados');

      // 5. Construir lista de proyectos
      final Map<String, Map<String, dynamic>> proyectosMap = {};

      for (var proyectoDoc in proyectosSnapshot.docs) {
        final data = proyectoDoc.data();
        final codigo = data['Código'] ?? '';

        if (codigo.isEmpty) continue;

        final yaAsignado = proyectosAsignados.contains(proyectoDoc.id);

        if (!proyectosMap.containsKey(codigo)) {
          proyectosMap[codigo] = {
            'id': proyectoDoc.id,
            'eventId': _eventoSeleccionado,
            'codigo': codigo,
            'titulo': data['Título'] ?? '',
            'integrantes': data['Integrantes'] ?? '',
            'sala': data['Sala'] ?? '',
            'clasificacion': data['Clasificación'] ?? 'Sin categoría',
            'facultad': eventoFacultad,
            'carrera': eventoCarrera,
            'yaAsignado': yaAsignado,
          };
        }
      }

      // 6. Agrupar proyectos por categoría
      final proyectosList = proyectosMap.values.toList()
        ..sort(
          (a, b) => (a['codigo'] as String).compareTo(b['codigo'] as String),
        );

      final Map<String, List<Map<String, dynamic>>> grupos = {};
      for (final proyecto in proyectosList) {
        final categoria = proyecto['clasificacion'] as String;
        if (!grupos.containsKey(categoria)) {
          grupos[categoria] = [];
        }
        grupos[categoria]!.add(proyecto);
      }

      if (mounted) {
        setState(() {
          _rubricaAsignada = rubrica;
          _proyectosDisponibles = proyectosList;
          _proyectosPorCategoria = grupos;
          _isLoadingProyectos = false;
        });

        print(
          '✅ ${_proyectosDisponibles.length} proyectos listos para asignar',
        );
        print('📂 ${_proyectosPorCategoria.length} categorías encontradas');
      }
    } catch (e) {
      print('❌ Error: $e');
      if (mounted) {
        setState(() => _isLoadingProyectos = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar proyectos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _asignarProyectos() async {
    if (_proyectosSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar al menos un proyecto'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Asignación'),
        content: Text(
          '¿Deseas asignar ${_proyectosSeleccionados.length} proyecto(s) a ${_juradoData!['nombre']} para evaluar con la rúbrica "${_rubricaAsignada!.nombre}"?',
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
            child: const Text('Asignar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isAsignando = true);

    try {
      final batch = _firestore.batch();
      int asignados = 0;

      for (var proyecto in _proyectosDisponibles) {
        if (_proyectosSeleccionados.contains(proyecto['codigo'])) {
          final docRef = _firestore
              .collection('events')
              .doc(proyecto['eventId'])
              .collection('proyectos')
              .doc(proyecto['id'])
              .collection('evaluaciones')
              .doc(_juradoSeleccionado);

          batch.set(docRef, {
            'juradoId': _juradoSeleccionado,
            'juradoNombre': _juradoData!['nombre'],
            'rubricaId': _rubricaAsignada!.id,
            'rubricaNombre': _rubricaAsignada!.nombre,
            'facultad': _rubricaAsignada!.facultad,
            'carrera': _rubricaAsignada!.carrera,
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
        setState(() => _isAsignando = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $asignados proyecto(s) asignado(s) correctamente'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        await _cargarRubricaYProyectos(_juradoSeleccionado!);
        setState(() => _proyectosSeleccionados.clear());
      }
    } catch (e) {
      print('Error al asignar proyectos: $e');
      if (mounted) {
        setState(() => _isAsignando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al asignar proyectos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getColorForCategory(int index) {
    final colors = [
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFFF44336),
      const Color(0xFF009688),
      const Color(0xFFFFEB3B),
      const Color(0xFF3F51B5),
    ];
    return colors[index % colors.length];
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
                      'Asignar Proyectos a Jurados',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.people,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CrearJuradosScreen(),
                        ),
                      );
                    },
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
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PASO 1: Filtros de Facultad y Carrera
                        _buildFiltrosCard(),

                        // PASO 2: Selector de Evento
                        if (_facultadSeleccionada != null &&
                            (!_requiereCarrera(_facultadSeleccionada) ||
                                _carreraSeleccionada != null)) ...[
                          const SizedBox(height: 16),
                          _buildEventoCard(),
                        ],

                        // PASO 3: Selector de Jurado
                        if (_eventoSeleccionado != null) ...[
                          const SizedBox(height: 16),
                          _buildJuradoCard(),
                        ],

                        // Info Rúbrica
                        if (_rubricaAsignada != null) ...[
                          const SizedBox(height: 16),
                          _buildRubricaCard(),
                        ],

                        // Lista de Proyectos por Categoría
                        if (_juradoSeleccionado != null) ...[
                          const SizedBox(height: 16),
                          _buildProyectosPorCategoriaCard(),
                        ],

                        const SizedBox(height: 24),

                        // Botón Asignar
                        if (_juradoSeleccionado != null) _buildBotonAsignar(),

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
                const Text(
                  '1. Filtrar por Facultad y Carrera',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filtro Facultad
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
              items: facultadesCarreras.keys.map((facultad) {
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

            // Filtro Carrera (solo si requiere)
            if (_facultadSeleccionada != null &&
                _requiereCarrera(_facultadSeleccionada)) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _carreraSeleccionada,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Carrera',
                  prefixIcon: const Icon(Icons.menu_book),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _carrerasDisponibles.map((carrera) {
                  return DropdownMenuItem(
                    value: carrera,
                    child: Text(
                      carrera,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _onCarreraChanged,
              ),
            ],

            // Info de eventos disponibles
            if (_facultadSeleccionada != null &&
                (!_requiereCarrera(_facultadSeleccionada) ||
                    _carreraSeleccionada != null)) ...[
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
                const Text(
                  '2. Seleccionar Evento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
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

  Widget _buildJuradoCard() {
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
                      colors: [Color(0xFFFF9800), Color(0xFFFF6F00)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '3. Seleccionar Jurado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _juradoSeleccionado,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Jurado',
                prefixIcon: const Icon(Icons.badge),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _juradosDisponibles.map((jurado) {
                return DropdownMenuItem<String>(
                  value: jurado['id'] as String,
                  child: Text(
                    jurado['nombre'] as String,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _juradosDisponibles.isEmpty ? null : _onJuradoChanged,
            ),
            if (_isLoadingJurados)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cargando jurados...',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
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

  Widget _buildRubricaCard() {
    return Card(
      elevation: 2,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Rúbrica Asignada',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.assignment,
              'Rúbrica',
              _rubricaAsignada!.nombre,
            ),
            const SizedBox(height: 6),
            _buildInfoRow(
              Icons.checklist,
              'Criterios',
              '${_rubricaAsignada!.totalCriterios} criterios',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProyectosPorCategoriaCard() {
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
                    Icons.folder_open,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '4. Seleccionar Proyectos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_proyectosSeleccionados.length} seleccionados',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9C27B0),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingProyectos)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_proyectosPorCategoria.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No hay proyectos disponibles',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              _buildCategoriasList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriasList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _proyectosPorCategoria.keys.length,
      itemBuilder: (context, index) {
        final categoria = _proyectosPorCategoria.keys.elementAt(index);
        final proyectos = _proyectosPorCategoria[categoria]!;
        return _buildCategoryCard(categoria, proyectos, index);
      },
    );
  }

  Widget _buildCategoryCard(
    String categoria,
    List<Map<String, dynamic>> proyectos,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getColorForCategory(index).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _getColorForCategory(index).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            categoria,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF2C3E50),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${proyectos.length} proyecto${proyectos.length != 1 ? 's' : ''}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getColorForCategory(index),
                  _getColorForCategory(index).withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                proyectos.length.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          children: proyectos
              .map((proyecto) => _buildProjectItem(proyecto))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildProjectItem(Map<String, dynamic> proyecto) {
    final codigo = proyecto['codigo'] as String;
    final yaAsignado = proyecto['yaAsignado'] as bool;
    final isSelected = _proyectosSeleccionados.contains(codigo);

    return Card(
      margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      color: yaAsignado
          ? Colors.green.shade50
          : (isSelected ? Colors.blue.shade50 : const Color(0xFFF8F9FA)),
      child: CheckboxListTile(
        value: yaAsignado || isSelected,
        enabled: !yaAsignado,
        onChanged: yaAsignado
            ? null
            : (bool? value) {
                setState(() {
                  if (value == true) {
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
                  fontSize: 14,
                  color: yaAsignado
                      ? Colors.green[800]
                      : const Color(0xFF2C3E50),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (yaAsignado)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Asignado',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.qr_code, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  codigo,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
            if ((proyecto['integrantes'] as String).isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.people, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      proyecto['integrantes'] as String,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if ((proyecto['sala'] as String).isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.meeting_room, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    proyecto['sala'] as String,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
        activeColor: const Color(0xFF1E3A5F),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildBotonAsignar() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isAsignando || _proyectosSeleccionados.isEmpty
            ? null
            : _asignarProyectos,
        icon: _isAsignando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle, size: 24),
        label: Text(
          _isAsignando
              ? 'Asignando...'
              : 'Asignar ${_proyectosSeleccionados.length} Proyecto(s)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          elevation: _proyectosSeleccionados.isNotEmpty ? 4 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.green[700]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.green[900],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: Colors.green[800]),
          ),
        ),
      ],
    );
  }
}
