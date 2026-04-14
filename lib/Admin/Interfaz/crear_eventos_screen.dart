import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/logica/eventos_detalles.dart';
import '/admin/logica/crear_eventos.dart';
import '/admin/logica/periodos_helper.dart';

class CrearEventosScreen extends StatefulWidget {
  const CrearEventosScreen({super.key});

  @override
  State<CrearEventosScreen> createState() => _CrearEventosScreenState();
}

class _CrearEventosScreenState extends State<CrearEventosScreen>
    with TickerProviderStateMixin {
  final TextEditingController _eventNameController = TextEditingController();
  final EventosService _eventosService = EventosService();
  bool _isLoading = false;
  bool _isLoadingData = true;

  // Selecciones actuales
  String? _selectedFilialId;
  String? _selectedFilialNombre;
  String? _selectedFacultad;
  String? _selectedCarreraId;
  String? _selectedCarreraNombre;
  String? _selectedPeriodoId;
  String? _selectedPeriodoNombre;

  // Datos dinámicos
  List<Map<String, String>> _filiales = [];
  List<String> _facultades = [];
  List<Map<String, dynamic>> _carreras = [];
  List<Map<String, dynamic>> _periodos = [];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _fadeController.forward();
    _loadInitialData();
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingData = true);

    try {
      // Cargar filiales y períodos en paralelo
      final results = await Future.wait([
        _eventosService.getFiliales(),
        PeriodosHelper.getPeriodosActivos(),
      ]);

      final filiales = results[0] as List<Map<String, String>>;
      final periodos = results[1] as List<Map<String, dynamic>>;

      setState(() {
        _filiales = filiales;
        _periodos = periodos;

        // Seleccionar valores por defecto
        if (_filiales.isNotEmpty) {
          _selectedFilialId = _filiales.first['id'];
          _selectedFilialNombre = _filiales.first['nombre'];
          _loadFacultades(_selectedFilialId!);
        }

        if (periodos.isNotEmpty) {
          _selectedPeriodoId = periodos.first['id'];
          _selectedPeriodoNombre = periodos.first['nombre'];
        }

        _isLoadingData = false;
      });
    } catch (e) {
      print('Error cargando datos iniciales: $e');
      setState(() => _isLoadingData = false);
      _showSnackBar('Error al cargar datos', isError: true);
    }
  }

  Future<void> _loadFacultades(String filialId) async {
    try {
      final facultades = await _eventosService.getFacultadesByFilial(filialId);
      setState(() {
        _facultades = facultades;
        _selectedFacultad = null;
        _selectedCarreraId = null;
        _selectedCarreraNombre = null;
        _carreras = [];
      });
    } catch (e) {
      print('Error cargando facultades: $e');
      _showSnackBar('Error al cargar facultades', isError: true);
    }
  }

  Future<void> _loadCarreras(String filialId, String facultadNombre) async {
    try {
      final carreras = await _eventosService.getCarrerasByFacultad(
        filialId,
        facultadNombre,
      );
      setState(() {
        _carreras = carreras;
        _selectedCarreraId = null;
        _selectedCarreraNombre = null;
      });
    } catch (e) {
      print('Error cargando carreras: $e');
      _showSnackBar('Error al cargar carreras', isError: true);
    }
  }

  void _navigateToEventDetails(String eventId, Map<String, dynamic> eventData) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            EventosDetallesScreen(eventId: eventId, eventData: eventData),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  void _navigateToEventsList() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ListaEventosScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _createEvent() async {
    // Validaciones
    final nameError = _eventosService.validateEventName(
      _eventNameController.text,
    );
    if (nameError != null) {
      _showSnackBar(nameError, isError: true);
      return;
    }

    final filialError = _eventosService.validateFilial(_selectedFilialId);
    if (filialError != null) {
      _showSnackBar(filialError, isError: true);
      return;
    }

    final facultadError = _eventosService.validateFacultad(_selectedFacultad);
    if (facultadError != null) {
      _showSnackBar(facultadError, isError: true);
      return;
    }

    final carreraError = _eventosService.validateCarrera(_selectedCarreraId);
    if (carreraError != null) {
      _showSnackBar(carreraError, isError: true);
      return;
    }

    final periodoError = _eventosService.validatePeriodo(_selectedPeriodoId);
    if (periodoError != null) {
      _showSnackBar(periodoError, isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _eventosService.createEvent(
        name: _eventNameController.text.trim(),
        filialId: _selectedFilialId!,
        filialNombre: _selectedFilialNombre!,
        facultad: _selectedFacultad!,
        carreraId: _selectedCarreraId!,
        carreraNombre: _selectedCarreraNombre!,
        periodoId: _selectedPeriodoId!,
        periodoNombre: _selectedPeriodoNombre!,
      );

      _eventNameController.clear();
      setState(() {
        _selectedFacultad = null;
        _selectedCarreraId = null;
        _selectedCarreraNombre = null;
        _carreras = [];
      });

      _showSnackBar('Evento creado exitosamente para $_selectedCarreraNombre');
    } catch (e) {
      _showSnackBar('Error al crear evento: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFE53935)
            : const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EAF6),
      appBar: AppBar(
        title: const Text(
          'Gestión de Eventos',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoadingData
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1E3A5F)),
                  SizedBox(height: 16),
                  Text('Cargando datos...'),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.white, Color(0xFFF5F7FA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E3A5F).withOpacity(0.15),
                            spreadRadius: 0,
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1E3A5F,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.event_available,
                                  color: Color(0xFF1E3A5F),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Crear Nuevo Evento',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E3A5F),
                                      ),
                                    ),
                                    Text(
                                      'Completa los datos del evento',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          _buildTextField(
                            controller: _eventNameController,
                            label: 'Nombre del evento',
                            hint: 'Ej: Conferencia de Tecnología',
                            icon: Icons.event,
                          ),
                          const SizedBox(height: 16),

                          // Dropdown de Filial
                          _buildDropdown(
                            value: _selectedFilialId,
                            label: 'Filial / Campus',
                            icon: Icons.location_city,
                            items: _filiales.map((f) => f['id']!).toList(),
                            itemLabels: _filiales.map((f) {
                              return '${f['nombre']} - ${f['ubicacion']}';
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                final filial = _filiales.firstWhere(
                                  (f) => f['id'] == newValue,
                                );
                                setState(() {
                                  _selectedFilialId = newValue;
                                  _selectedFilialNombre = filial['nombre'];
                                });
                                _loadFacultades(newValue);
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Dropdown de Facultad
                          _buildDropdown(
                            value: _selectedFacultad,
                            label: 'Facultad',
                            icon: Icons.school,
                            items: _facultades,
                            onChanged: _selectedFilialId != null
                                ? (String? newValue) {
                                    if (newValue != null) {
                                      setState(
                                        () => _selectedFacultad = newValue,
                                      );
                                      _loadCarreras(
                                        _selectedFilialId!,
                                        newValue,
                                      );
                                    }
                                  }
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Dropdown de Carrera
                          _buildDropdown(
                            value: _selectedCarreraId,
                            label: 'Carrera / Escuela Profesional',
                            icon: Icons.book,
                            items: _carreras
                                .map((c) => c['id'] as String)
                                .toList(),
                            itemLabels: _carreras
                                .map((c) => c['nombre'] as String)
                                .toList(),
                            onChanged: _selectedFacultad != null
                                ? (String? newValue) {
                                    if (newValue != null) {
                                      final carrera = _carreras.firstWhere(
                                        (c) => c['id'] == newValue,
                                      );
                                      setState(() {
                                        _selectedCarreraId = newValue;
                                        _selectedCarreraNombre =
                                            carrera['nombre'];
                                      });
                                    }
                                  }
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Dropdown de Período
                          _buildDropdown(
                            value: _selectedPeriodoId,
                            label: 'Período Académico',
                            icon: Icons.calendar_month,
                            items: _periodos
                                .map((p) => p['id'] as String)
                                .toList(),
                            itemLabels: _periodos
                                .map((p) => p['nombre'] as String)
                                .toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                final periodo = _periodos.firstWhere(
                                  (p) => p['id'] == newValue,
                                );
                                setState(() {
                                  _selectedPeriodoId = newValue;
                                  _selectedPeriodoNombre = periodo['nombre'];
                                });
                              }
                            },
                          ),

                          if (_periodos.isEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE53935),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber,
                                    size: 20,
                                    color: Color(0xFFE53935),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'No hay períodos activos. Activa un período primero.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.red.shade900,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (_selectedFilialId != null && _facultades.isEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFFB74D),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'No hay facultades disponibles para esta filial',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.orange.shade900,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (_selectedFacultad != null && _carreras.isEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFFB74D),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'No hay carreras disponibles para esta facultad',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.orange.shade900,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 24),

                          _buildPrimaryButton(
                            onPressed: _isLoading ? null : _createEvent,
                            text: 'Crear Evento',
                            icon: Icons.add_circle_outline,
                            isLoading: _isLoading,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _eventosService.getEventsCountStream(),
                        builder: (context, snapshot) {
                          final eventCount = snapshot.data?.docs.length ?? 0;
                          return _buildSecondaryButton(
                            onPressed: _navigateToEventsList,
                            text: 'Ver Todos los Eventos',
                            count: eventCount,
                            icon: Icons.list_alt,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    List<String>? itemLabels,
    required void Function(String?)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        items: List.generate(items.length, (index) {
          return DropdownMenuItem<String>(
            value: items[index],
            child: Text(
              itemLabels != null ? itemLabels[index] : items[index],
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback? onPressed,
    required String text,
    required IconData icon,
    required bool isLoading,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.5),
            spreadRadius: 0,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required VoidCallback onPressed,
    required String text,
    required int count,
    required IconData icon,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.5),
            spreadRadius: 0,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              '$text ($count)',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// LISTA DE EVENTOS
class ListaEventosScreen extends StatefulWidget {
  const ListaEventosScreen({super.key});

  @override
  State<ListaEventosScreen> createState() => _ListaEventosScreenState();
}

class _ListaEventosScreenState extends State<ListaEventosScreen>
    with SingleTickerProviderStateMixin {
  final EventosService _eventosService = EventosService();

  String? _filtroFilialId;
  String? _filtroFacultad;
  String? _filtroCarreraId;
  String? _filtroPeriodo;

  List<Map<String, String>> _filiales = [];
  List<String> _facultades = [];
  List<Map<String, dynamic>> _carreras = [];
  List<Map<String, dynamic>> _periodos = [];

  late AnimationController _animationController;
  bool _isLoadingFilters = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();
    _loadFilterData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadFilterData() async {
    try {
      final results = await Future.wait([
        _eventosService.getFiliales(),
        PeriodosHelper.getPeriodosActivos(),
      ]);

      setState(() {
        _filiales = results[0] as List<Map<String, String>>;
        _periodos = results[1] as List<Map<String, dynamic>>;
        _isLoadingFilters = false;
      });
    } catch (e) {
      print('Error cargando datos de filtros: $e');
      setState(() => _isLoadingFilters = false);
    }
  }

  Future<void> _loadFacultadesForFilter(String filialId) async {
    try {
      final facultades = await _eventosService.getFacultadesByFilial(filialId);
      setState(() {
        _facultades = facultades;
        _filtroFacultad = null;
        _filtroCarreraId = null;
        _carreras = [];
      });
    } catch (e) {
      print('Error cargando facultades: $e');
    }
  }

  Future<void> _loadCarrerasForFilter(
    String filialId,
    String facultadNombre,
  ) async {
    try {
      final carreras = await _eventosService.getCarrerasByFacultad(
        filialId,
        facultadNombre,
      );
      setState(() {
        _carreras = carreras;
        _filtroCarreraId = null;
      });
    } catch (e) {
      print('Error cargando carreras: $e');
    }
  }

  void _navigateToEventDetails(String eventId, Map<String, dynamic> eventData) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            EventosDetallesScreen(eventId: eventId, eventData: eventData),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _editEvent(
    String eventId,
    Map<String, dynamic> eventData,
  ) async {
    // Similar al anterior pero con los nuevos campos
    TextEditingController editNameController = TextEditingController(
      text: eventData['name'] ?? '',
    );
    String? editFilialId = eventData['filialId'];
    String? editFilialNombre = eventData['filialNombre'];
    String? editFacultad = eventData['facultad'];
    String? editCarreraId = eventData['carreraId'];
    String? editCarreraNombre = eventData['carreraNombre'];

    List<String> editFacultades = [];
    List<Map<String, dynamic>> editCarreras = [];

    if (editFilialId != null) {
  editFacultades = await _eventosService.getFacultadesByFilial(
    editFilialId,
  );
  if (editFacultad != null) {
    editCarreras = await _eventosService.getCarrerasByFacultad(
      editFilialId,
      editFacultad,
    );
  }
}

if (!mounted) return; // ✅ AGREGAR ESTA LÍNEA

showDialog(
  context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: Color(0xFF1E3A5F)),
              ),
              const SizedBox(width: 12),
              const Text('Editar Evento'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: editNameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre del evento',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.event),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: editFilialId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Filial',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.location_city),
                    ),
                    items: _filiales.map((filial) {
                      return DropdownMenuItem<String>(
                        value: filial['id'],
                        child: Text(
                          '${filial['nombre']} - ${filial['ubicacion']}',
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) async {
                      if (newValue != null) {
                        final filial = _filiales.firstWhere(
                          (f) => f['id'] == newValue,
                        );
                        final nuevasFacultades = await _eventosService
                            .getFacultadesByFilial(newValue);
                        setDialogState(() {
                          editFilialId = newValue;
                          editFilialNombre = filial['nombre'];
                          editFacultades = nuevasFacultades;
                          editFacultad = null;
                          editCarreraId = null;
                          editCarreraNombre = null;
                          editCarreras = [];
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: editFacultad,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Facultad',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.school),
                    ),
                    items: editFacultades.map((String facultad) {
                      return DropdownMenuItem<String>(
                        value: facultad,
                        child: Text(
                          facultad,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: editFilialId != null
                        ? (String? newValue) async {
                            if (newValue != null) {
                              final nuevasCarreras = await _eventosService
                                  .getCarrerasByFacultad(
                                    editFilialId!,
                                    newValue,
                                  );
                              setDialogState(() {
                                editFacultad = newValue;
                                editCarreras = nuevasCarreras;
                                editCarreraId = null;
                                editCarreraNombre = null;
                              });
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: editCarreraId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Carrera',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.book),
                    ),
                    items: editCarreras.map((carrera) {
                      return DropdownMenuItem<String>(
                        value: carrera['id'],
                        child: Text(
                          carrera['nombre'],
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: editFacultad != null
                        ? (String? newValue) {
                            if (newValue != null) {
                              final carrera = editCarreras.firstWhere(
                                (c) => c['id'] == newValue,
                              );
                              setDialogState(() {
                                editCarreraId = newValue;
                                editCarreraNombre = carrera['nombre'];
                              });
                            }
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final nameError = _eventosService.validateEventName(
                  editNameController.text,
                );
                if (nameError != null) {
                  _showSnackBar(nameError, isError: true);
                  return;
                }

                final filialError = _eventosService.validateFilial(
                  editFilialId,
                );
                if (filialError != null) {
                  _showSnackBar(filialError, isError: true);
                  return;
                }

                final facultadError = _eventosService.validateFacultad(
                  editFacultad,
                );
                if (facultadError != null) {
                  _showSnackBar(facultadError, isError: true);
                  return;
                }

                final carreraError = _eventosService.validateCarrera(
                  editCarreraId,
                );
                if (carreraError != null) {
                  _showSnackBar(carreraError, isError: true);
                  return;
                }

                try {
                  await _eventosService.updateEvent(
                    eventId: eventId,
                    name: editNameController.text.trim(),
                    filialId: editFilialId!,
                    filialNombre: editFilialNombre!,
                    facultad: editFacultad!,
                    carreraId: editCarreraId!,
                    carreraNombre: editCarreraNombre!,
                  );

                  Navigator.pop(context);
                  _showSnackBar('Evento actualizado exitosamente');
                } catch (e) {
                  _showSnackBar(
                    'Error al actualizar evento: $e',
                    isError: true,
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEvent(String eventId, String eventName) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text('Eliminar Evento'),
          ],
        ),
        content: Text('¿Estás seguro de que quieres eliminar "$eventName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              try {
                await _eventosService.deleteEvent(eventId);
                Navigator.pop(context);
                _showSnackBar('Evento eliminado exitosamente');
              } catch (e) {
                _showSnackBar('Error al eliminar evento: $e', isError: true);
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFE53935)
            : const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EAF6),
      appBar: AppBar(
        title: const Text(
          'Todos los Eventos',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.all(16.0),
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFF5F7FA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A5F).withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.filter_list,
                        color: Color(0xFF1E3A5F),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Filtros',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    const Spacer(),
                    if (_filtroFilialId != null ||
                        _filtroFacultad != null ||
                        _filtroCarreraId != null ||
                        _filtroPeriodo != null)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _filtroFilialId = null;
                            _filtroFacultad = null;
                            _filtroCarreraId = null;
                            _filtroPeriodo = null;
                            _facultades = [];
                            _carreras = [];
                          });
                        },
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Limpiar'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFE53935),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Filtro Filial
                DropdownButtonFormField<String>(
                  value: _filtroFilialId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Filial',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    prefixIcon: const Icon(Icons.location_city),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Todas'),
                    ),
                    ..._filiales.map((filial) {
                      return DropdownMenuItem<String>(
                        value: filial['id'],
                        child: Text(
                          '${filial['nombre']} - ${filial['ubicacion']}',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (String? newValue) {
                    setState(() {
                      _filtroFilialId = newValue;
                      _filtroFacultad = null;
                      _filtroCarreraId = null;
                      _facultades = [];
                      _carreras = [];
                    });
                    if (newValue != null) {
                      _loadFacultadesForFilter(newValue);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Filtro Facultad
                DropdownButtonFormField<String>(
                  value: _filtroFacultad,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Facultad',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    prefixIcon: const Icon(Icons.school),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Todas'),
                    ),
                    ..._facultades.map((String facultad) {
                      return DropdownMenuItem<String>(
                        value: facultad,
                        child: Text(
                          facultad,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: _filtroFilialId != null
                      ? (String? newValue) {
                          setState(() {
                            _filtroFacultad = newValue;
                            _filtroCarreraId = null;
                            _carreras = [];
                          });
                          if (newValue != null && _filtroFilialId != null) {
                            _loadCarrerasForFilter(_filtroFilialId!, newValue);
                          }
                        }
                      : null,
                ),
                const SizedBox(height: 12),

                // Filtro Carrera
                DropdownButtonFormField<String>(
                  value: _filtroCarreraId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Carrera',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    prefixIcon: const Icon(Icons.book),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Todas'),
                    ),
                    ..._carreras.map((carrera) {
                      return DropdownMenuItem<String>(
                        value: carrera['id'],
                        child: Text(
                          carrera['nombre'],
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: _filtroFacultad != null
                      ? (String? newValue) {
                          setState(() => _filtroCarreraId = newValue);
                        }
                      : null,
                ),
                const SizedBox(height: 12),

                // Filtro Período
                DropdownButtonFormField<String>(
                  value: _filtroPeriodo,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Período Académico',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    prefixIcon: const Icon(Icons.calendar_month),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Todos'),
                    ),
                    ..._periodos.map((periodo) {
                      return DropdownMenuItem<String>(
                        value: periodo['id'],
                        child: Text(
                          periodo['nombre'],
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (String? newValue) {
                    setState(() => _filtroPeriodo = newValue);
                  },
                ),
              ],
            ),
          ),

          // Lista de eventos
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _eventosService.getEventsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E3A5F)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  );
                }

                var events = snapshot.data?.docs ?? [];

                // Aplicar filtros
                events = _eventosService.filterByFilial(
                  events,
                  _filtroFilialId,
                );
                events = _eventosService.filterByFacultad(
                  events,
                  _filtroFacultad,
                );
                events = _eventosService.filterByCarrera(
                  events,
                  _filtroCarreraId,
                );
                events = _eventosService.filterByPeriodo(
                  events,
                  _filtroPeriodo,
                );

                if (events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.event_busy,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filtroFilialId != null ||
                                  _filtroFacultad != null ||
                                  _filtroCarreraId != null ||
                                  _filtroPeriodo != null
                              ? 'No hay eventos con estos filtros'
                              : 'No hay eventos creados',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final eventData = event.data() as Map<String, dynamic>;
                    final eventName = eventData['name'] ?? 'Sin nombre';
                    final filialNombre =
                        eventData['filialNombre'] ?? 'Sin filial';
                    final carreraNombre =
                        eventData['carreraNombre'] ?? 'Sin carrera';
                    final eventId = event.id;

                    return FadeTransition(
                      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _animationController,
                          curve: Interval(
                            (index / events.length) * 0.5,
                            ((index + 1) / events.length) * 0.5 + 0.5,
                            curve: Curves.easeOut,
                          ),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.white, Color(0xFFFAFAFA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E3A5F).withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () =>
                                _navigateToEventDetails(eventId, eventData),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF1E3A5F),
                                          Color(0xFF2E5A8F),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF1E3A5F,
                                          ).withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        eventName.substring(0, 1).toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          eventName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: Color(0xFF1E3A5F),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(
                                                  0xFF43A047,
                                                ).withOpacity(0.15),
                                                const Color(
                                                  0xFF66BB6A,
                                                ).withOpacity(0.15),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFF43A047,
                                              ).withOpacity(0.3),
                                            ),
                                          ),
                                          child: Text(
                                            carreraNombre,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2E7D32),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_city,
                                              size: 12,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                filialNombre,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (eventData['fecha'] != null ||
                                            eventData['lugar'] != null)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Row(
                                              children: [
                                                if (eventData['fecha'] !=
                                                    null) ...[
                                                  Icon(
                                                    Icons.calendar_today,
                                                    size: 12,
                                                    color: Colors.blue.shade600,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _eventosService.formatDate(
                                                      (eventData['fecha']
                                                              as Timestamp)
                                                          .toDate(),
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          Colors.blue.shade600,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                                if (eventData['fecha'] !=
                                                        null &&
                                                    eventData['lugar'] !=
                                                        null &&
                                                    eventData['lugar'] != '')
                                                  const Text(
                                                    ' • ',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                if (eventData['lugar'] !=
                                                        null &&
                                                    eventData['lugar'] !=
                                                        '') ...[
                                                  Icon(
                                                    Icons.location_on,
                                                    size: 12,
                                                    color:
                                                        Colors.orange.shade600,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      eventData['lugar'],
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors
                                                            .orange
                                                            .shade600,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: Color(0xFF1E3A5F),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'details':
                                            _navigateToEventDetails(
                                              eventId,
                                              eventData,
                                            );
                                            break;
                                          case 'edit':
                                            _editEvent(eventId, eventData);
                                            break;
                                          case 'delete':
                                            _deleteEvent(eventId, eventName);
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'details',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.visibility,
                                                color: Color(0xFF43A047),
                                                size: 20,
                                              ),
                                              SizedBox(width: 12),
                                              Text('Ver Detalles'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.edit,
                                                color: Color(0xFF1E88E5),
                                                size: 20,
                                              ),
                                              SizedBox(width: 12),
                                              Text('Editar'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete,
                                                color: Color(0xFFE53935),
                                                size: 20,
                                              ),
                                              SizedBox(width: 12),
                                              Text('Eliminar'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
