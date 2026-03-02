import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'asistencias_estudiantes_resultados.dart';
import 'filiales_service.dart';
import 'gestion_criterios.dart';

class AsistenciasEstudiantesScreen extends StatefulWidget {
  const AsistenciasEstudiantesScreen({super.key});

  @override
  State<AsistenciasEstudiantesScreen> createState() =>
      _AsistenciasEstudiantesScreenState();
}

class _AsistenciasEstudiantesScreenState
    extends State<AsistenciasEstudiantesScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RubricasService _rubricasService = RubricasService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ── Filtros de ubicación ─────────────────────────────────────────
  String? _filialSeleccionada;
  String? _filialNombreSeleccionada; // ✅ nombre legible de la filial
  String? _facultadSeleccionada;
  String? _carreraSeleccionada;

  List<String> _filialesDisponibles = [];
  List<String> _facultadesDisponibles = [];
  List<Map<String, dynamic>> _carrerasDisponibles = [];

  // ── Datos de eventos ─────────────────────────────────────────────
  String? _eventoSeleccionado;
  Map<String, dynamic>? _eventoData;
  List<Map<String, dynamic>> _eventosDisponibles = [];
  List<Map<String, dynamic>> _eventosFiltrados = [];

  // ── Estados ──────────────────────────────────────────────────────
  bool _isLoadingInitial = true;
  bool _isLoadingEventos = false;

  // ── Resumen de asistencias (para el banner informativo) ──────────
  int _totalAsistencias = 0;
  bool _isLoadingResumen = false;

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
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // CARGA INICIAL
  // ═══════════════════════════════════════════════════════════════
  Future<void> _cargarDatosIniciales() async {
    if (!mounted) return;
    setState(() => _isLoadingInitial = true);

    try {
      final filiales = await _rubricasService.getFiliales();
      if (mounted) {
        setState(() => _filialesDisponibles = filiales);
      }
      await _cargarEventos();
      if (mounted) {
        setState(() => _isLoadingInitial = false);
      }
    } catch (e) {
      print('Error cargando datos iniciales: $e');
      if (mounted) {
        setState(() => _isLoadingInitial = false);
        _showSnackBar('Error al cargar datos: $e', isError: true);
      }
    }
  }

  // ── Cambio de filial ─────────────────────────────────────────────
  Future<void> _onFilialChanged(String? filialId) async {
    setState(() {
      _filialSeleccionada = filialId;
      _filialNombreSeleccionada = null;
      _facultadSeleccionada = null;
      _carreraSeleccionada = null;
      _eventoSeleccionado = null;
      _eventoData = null;
      _facultadesDisponibles = [];
      _carrerasDisponibles = [];
      _totalAsistencias = 0;
    });

    if (filialId != null) {
      // Obtener nombre legible de la filial
      final nombre = await _rubricasService.getNombreFilial(filialId);
      if (mounted) setState(() => _filialNombreSeleccionada = nombre);

      final facultades = await _rubricasService.getFacultadesByFilial(filialId);
      if (mounted) setState(() => _facultadesDisponibles = facultades);
      _filtrarEventos();
    }
  }

  // ── Cambio de facultad ───────────────────────────────────────────
  Future<void> _onFacultadChanged(String? facultad) async {
    setState(() {
      _facultadSeleccionada = facultad;
      _carreraSeleccionada = null;
      _eventoSeleccionado = null;
      _eventoData = null;
      _carrerasDisponibles = [];
      _totalAsistencias = 0;
    });

    if (_filialSeleccionada != null && facultad != null) {
      final carreras = await _rubricasService.getCarrerasByFacultad(
        _filialSeleccionada!,
        facultad,
      );
      if (mounted) setState(() => _carrerasDisponibles = carreras);
    }
    _filtrarEventos();
  }

  // ── Cambio de carrera ────────────────────────────────────────────
  void _onCarreraChanged(String? carrera) {
    setState(() {
      _carreraSeleccionada = carrera;
      _eventoSeleccionado = null;
      _eventoData = null;
      _totalAsistencias = 0;
    });
    _filtrarEventos();
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ FILTRAR EVENTOS por filial + facultad + carrera
  // ═══════════════════════════════════════════════════════════════
  void _filtrarEventos() {
    if (_filialSeleccionada == null) {
      setState(() => _eventosFiltrados = []);
      return;
    }

    List<Map<String, dynamic>> filtrados = _eventosDisponibles.where((evento) {
      // Comparar por filialId o filialNombre
      final filialMatch =
          evento['filialId'] == _filialSeleccionada ||
          (_filialNombreSeleccionada != null &&
              evento['filialNombre'] == _filialNombreSeleccionada);

      if (!filialMatch) return false;

      if (_facultadSeleccionada != null) {
        if (evento['facultad'] != _facultadSeleccionada) return false;

        if (_carreraSeleccionada != null) {
          return evento['carreraNombre'] == _carreraSeleccionada ||
              evento['carrera'] == _carreraSeleccionada;
        }
        return true;
      }
      return true;
    }).toList();

    setState(() => _eventosFiltrados = filtrados);
  }

  // ── Cargar todos los eventos ─────────────────────────────────────
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
          'filialId': data['filialId'] ?? 'lima',
          'filialNombre': data['filialNombre'] ?? data['sede'] ?? '',
          'facultad': data['facultad'] ?? '',
          'carreraId': data['carreraId'] ?? '',
          'carreraNombre': data['carreraNombre'] ?? data['carrera'] ?? '',
          'carrera': data['carrera'] ?? '',
          // ✅ Guardar sede del evento
          'sede': data['sede'] ?? data['filialNombre'] ?? '',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _eventosDisponibles = eventos;
          _isLoadingEventos = false;
        });
      }
    } catch (e) {
      print('Error cargando eventos: $e');
      if (mounted) {
        setState(() => _isLoadingEventos = false);
        _showSnackBar('Error al cargar eventos: $e', isError: true);
      }
    }
  }

  void _onEventoChanged(String? eventoId) {
    if (eventoId == null) return;
    final eventoData = _eventosFiltrados.firstWhere((e) => e['id'] == eventoId);
    setState(() {
      _eventoSeleccionado = eventoId;
      _eventoData = eventoData;
    });
    _cargarResumenAsistencias(eventoId);
  }

  // ✅ Cargar número total de asistencias del evento seleccionado
  Future<void> _cargarResumenAsistencias(String eventoId) async {
    setState(() => _isLoadingResumen = true);
    try {
      final asistenciasSnap = await _firestore
          .collection('events')
          .doc(eventoId)
          .collection('asistencias')
          .get();
      if (mounted)
        setState(() => _totalAsistencias = asistenciasSnap.docs.length);
    } catch (e) {
      print('Error cargando resumen: $e');
    } finally {
      if (mounted) setState(() => _isLoadingResumen = false);
    }
  }

  Future<void> _verAsistencias() async {
    if (_eventoSeleccionado == null) {
      _showSnackBar('Selecciona un evento primero', isError: true);
      return;
    }
    if (_facultadSeleccionada == null) {
      _showSnackBar('Selecciona una facultad primero', isError: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AsistenciasEstudiantesResultadosScreen(
          eventoId: _eventoSeleccionado!,
          eventoNombre: _eventoData!['name'],
          filialId: _filialSeleccionada!,
          facultad: _facultadSeleccionada!,
          carrera: _carreraSeleccionada,
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      appBar: AppBar(
        title: const Text(
          'Asistencias de Estudiantes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        // ✅ Mostrar sede seleccionada en el subtítulo del AppBar
        bottom: _filialNombreSeleccionada != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_city,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _filialNombreSeleccionada!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      if (_facultadSeleccionada != null) ...[
                        const Text(
                          ' › ',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                        Flexible(
                          child: Text(
                            _facultadSeleccionada!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (_carreraSeleccionada != null) ...[
                        const Text(
                          ' › ',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                        Flexible(
                          child: Text(
                            _carreraSeleccionada!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : null,
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
                  child: _isLoadingInitial
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF1A5490),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Cargando datos...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // PASO 1: Filtros de ubicación
                                _buildFiltrosCard(),

                                // PASO 2: Selector de evento
                                if (_filialSeleccionada != null &&
                                    _facultadSeleccionada != null) ...[
                                  const SizedBox(height: 16),
                                  _buildEventoCard(),
                                ],

                                // ✅ Resumen del evento seleccionado
                                if (_eventoSeleccionado != null &&
                                    _eventoData != null) ...[
                                  const SizedBox(height: 16),
                                  _buildResumenEventoCard(),
                                ],

                                // PASO 3: Botón ver asistencias
                                if (_eventoSeleccionado != null) ...[
                                  const SizedBox(height: 24),
                                  _buildBotonVerAsistencias(),
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
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ CARD DE FILTROS CON RUTA DE NAVEGACIÓN (Filial › Facultad › Carrera)
  // ═══════════════════════════════════════════════════════════════
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
                    '1. Seleccionar Ubicación',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
              ],
            ),

            // ✅ Breadcrumb visual
            if (_filialNombreSeleccionada != null) ...[
              const SizedBox(height: 12),
              _buildBreadcrumb(),
            ],

            const SizedBox(height: 16),

            // Selector de Filial
            DropdownButtonFormField<String>(
              value: _filialSeleccionada,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Filial / Sede',
                prefixIcon: const Icon(
                  Icons.location_city,
                  color: Color(0xFF1E3A5F),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E3A5F),
                    width: 2,
                  ),
                ),
              ),
              items: _filialesDisponibles.map((filialId) {
                return DropdownMenuItem(
                  value: filialId,
                  child: FutureBuilder<String>(
                    future: _rubricasService.getNombreFilial(filialId),
                    builder: (context, snapshot) {
                      return Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: Color(0xFF1E3A5F),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            snapshot.data ?? filialId,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      );
                    },
                  ),
                );
              }).toList(),
              onChanged: _onFilialChanged,
            ),

            // Selector de Facultad
            if (_filialSeleccionada != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _facultadSeleccionada,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Facultad',
                  prefixIcon: const Icon(
                    Icons.account_balance,
                    color: Color(0xFF3F51B5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF3F51B5),
                      width: 2,
                    ),
                  ),
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

            // Selector de Carrera (opcional)
            if (_facultadSeleccionada != null &&
                _carrerasDisponibles.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _carreraSeleccionada,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Carrera (opcional)',
                  prefixIcon: const Icon(
                    Icons.menu_book,
                    color: Color(0xFF00897B),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF00897B),
                      width: 2,
                    ),
                  ),
                  suffixIcon: _carreraSeleccionada != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _onCarreraChanged(null),
                          tooltip: 'Limpiar',
                        )
                      : null,
                ),
                items: _carrerasDisponibles.map((carrera) {
                  return DropdownMenuItem(
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

            // Contador de eventos disponibles
            if (_filialSeleccionada != null &&
                _facultadSeleccionada != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_eventosFiltrados.length} evento(s) disponible(s)${_carreraSeleccionada != null ? ' para $_carreraSeleccionada' : ''}',
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

  // ✅ Breadcrumb: Filial › Facultad › Carrera
  Widget _buildBreadcrumb() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.navigation, size: 14, color: Color(0xFF1E3A5F)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              [
                _filialNombreSeleccionada ?? '',
                if (_facultadSeleccionada != null) _facultadSeleccionada!,
                if (_carreraSeleccionada != null) _carreraSeleccionada!,
              ].where((s) => s.isNotEmpty).join(' › '),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1E3A5F),
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CARD DE SELECCIÓN DE EVENTO
  // ═══════════════════════════════════════════════════════════════
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        evento['name'] as String,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      // ✅ Mostrar sede del evento en el dropdown
                      if ((evento['sede'] as String?)?.isNotEmpty == true)
                        Text(
                          '🏛️ ${evento['sede']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
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
                  border: Border.all(color: Colors.green.shade300),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _eventoData!['name'],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[900],
                            ),
                          ),
                          // ✅ Sede del evento seleccionado
                          if ((_eventoData!['sede'] as String?)?.isNotEmpty ==
                              true)
                            Row(
                              children: [
                                Icon(
                                  Icons.location_city,
                                  size: 12,
                                  color: Colors.blue.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _eventoData!['sede'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
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

  // ═══════════════════════════════════════════════════════════════
  // ✅ CARD RESUMEN DEL EVENTO (muestra sede + total asistencias)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildResumenEventoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: Colors.white70, size: 18),
                SizedBox(width: 8),
                Text(
                  'Resumen del Evento',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildResumenStat(
                    icon: Icons.people_alt,
                    label: 'Estudiantes',
                    value: _isLoadingResumen ? '...' : '$_totalAsistencias',
                    color: Colors.green.shade300,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildResumenStat(
                    icon: Icons.location_city,
                    label: 'Sede',
                    value: _filialNombreSeleccionada ?? 'N/A',
                    color: Colors.blue.shade300,
                  ),
                ),
              ],
            ),
            if (_facultadSeleccionada != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.account_balance,
                    color: Colors.white54,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _facultadSeleccionada!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_carreraSeleccionada != null) ...[
                    const Text(
                      ' › ',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    Flexible(
                      child: Text(
                        _carreraSeleccionada!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResumenStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BOTÓN VER ASISTENCIAS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBotonVerAsistencias() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _verAsistencias,
            icon: const Icon(Icons.people_alt, size: 24),
            label: const Text(
              'Ver Asistencias',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (_filialNombreSeleccionada != null) ...[
          const SizedBox(height: 8),
          Text(
            'Filtrando asistencias de: $_filialNombreSeleccionada${_carreraSeleccionada != null ? ' › $_carreraSeleccionada' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
