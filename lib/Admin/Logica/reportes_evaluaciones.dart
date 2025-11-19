import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/logica/gestion_criterios.dart';
import 'reportes_evaluaciones_excel.dart';

class ReportesEvaluacionesScreen extends StatefulWidget {
  const ReportesEvaluacionesScreen({super.key});

  @override
  State<ReportesEvaluacionesScreen> createState() =>
      _ReportesEvaluacionesScreenState();
}

class _ReportesEvaluacionesScreenState extends State<ReportesEvaluacionesScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RubricasService _rubricasService = RubricasService();
  final ReportesEvaluacionesExcelService _excelService =
      ReportesEvaluacionesExcelService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Estructura de facultades y carreras
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

  // FILTROS
  String? _facultadSeleccionada;
  String? _carreraSeleccionada;
  List<String> _carrerasDisponibles = [];

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
  bool _isGeneratingExcel = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
    _cargarEventos();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      _evaluaciones.clear();

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
      _evaluaciones.clear();
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
      _evaluaciones.clear();
    });

    await _cargarEvaluaciones();
  }

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

      // 4. Obtener evaluaciones en batch usando Future.wait
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

            // Conversión segura de notas
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

      // 5. Esperar todas las evaluaciones en paralelo
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

  Future<void> _descargarExcel() async {
    if (_evaluaciones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay evaluaciones para exportar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGeneratingExcel = true);

    try {
      final resultado = await _excelService.generarReporteEvaluaciones(
        evaluaciones: _evaluaciones,
        eventoNombre: _eventoData!['name'],
        facultad: _facultadSeleccionada ?? '',
        carrera: _carreraSeleccionada,
      );

      if (mounted) {
        setState(() => _isGeneratingExcel = false);

        if (resultado['success'] == true) {
          // Mostrar diálogo de éxito con ubicación
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Reporte Generado',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✅ El archivo Excel se ha generado exitosamente',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 18,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Ubicación:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          resultado['directory'] ?? 'Carpeta de Documentos',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.description,
                              size: 18,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Archivo:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          resultado['fileName'] ?? 'reporte.xlsx',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.amber.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Busca el archivo en tu administrador de archivos',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );

          // También mostrar SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Archivo guardado en: ${resultado['directory']}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          // Mostrar error
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Error al Exportar',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resultado['message'] ?? 'Error desconocido',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Posibles soluciones:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSolucionItem(
                          'Verifica los permisos de almacenamiento',
                        ),
                        _buildSolucionItem(
                          'Asegúrate de tener espacio disponible',
                        ),
                        _buildSolucionItem(
                          'Reinicia la aplicación e intenta de nuevo',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('Error al generar Excel: $e');
      if (mounted) {
        setState(() => _isGeneratingExcel = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSolucionItem(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_right, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      appBar: AppBar(
        title: const Text(
          'Reportes de Evaluaciones',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_eventoSeleccionado != null && !_isLoadingEvaluaciones)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _cargarEvaluaciones,
              tooltip: 'Actualizar',
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // PASO 1: Filtros
                          _buildFiltrosCard(),

                          // PASO 2: Selector de Evento
                          if (_facultadSeleccionada != null &&
                              (!_requiereCarrera(_facultadSeleccionada) ||
                                  _carreraSeleccionada != null)) ...[
                            const SizedBox(height: 16),
                            _buildEventoCard(),
                          ],

                          // Resumen de evaluaciones
                          if (_eventoSeleccionado != null &&
                              !_isLoadingEvaluaciones &&
                              _evaluaciones.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildResumenCard(),
                          ],

                          // Botón descargar Excel
                          if (_eventoSeleccionado != null &&
                              !_isLoadingEvaluaciones &&
                              _evaluaciones.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildBotonDescargar(),
                          ],

                          // Estado de carga o vacío
                          if (_eventoSeleccionado != null &&
                              _isLoadingEvaluaciones)
                            _buildLoadingState(),

                          if (_eventoSeleccionado != null &&
                              !_isLoadingEvaluaciones &&
                              _evaluaciones.isEmpty)
                            _buildEmptyState(),

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
                    '1. Filtrar por Facultad y Carrera',
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

            // Filtro Carrera
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
                        _eventoData!['name'],
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

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF27AE60), Color(0xFF229954)],
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
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEstadisticaItem(
                    'Pendientes',
                    pendientes.toString(),
                    Icons.pending,
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

  Widget _buildBotonDescargar() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isGeneratingExcel ? null : _descargarExcel,
        icon: _isGeneratingExcel
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.file_download, size: 24),
        label: Text(
          _isGeneratingExcel
              ? 'Generando Excel...'
              : 'Descargar Reporte en Excel',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF27AE60),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(40.0),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Cargando evaluaciones...',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
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
    );
  }
}
