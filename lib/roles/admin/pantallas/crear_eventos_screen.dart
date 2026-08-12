import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/shared/logica/eventos_service.dart';
import '/shared/logica/periodos_helper.dart';
import 'dart:async';
import 'lista_eventos_screen.dart';

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

  String? _selectedFilialId;
  String? _selectedFilialNombre;
  String? _selectedFacultad;
  String? _selectedCarreraId;
  String? _selectedCarreraNombre;
  String? _selectedPeriodoId;
  String? _selectedPeriodoNombre;

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
    unawaited(_fadeController.forward());
    _loadInitialData().ignore();
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
      final results = await Future.wait([
        _eventosService.getFiliales(),
        PeriodosHelper.getPeriodosActivos(),
      ]);

      final filiales = results[0] as List<Map<String, String>>;
      final periodos = (results[1] as List).cast<Map<String, dynamic>>();

      if (!mounted) return;

      setState(() {
        _filiales = filiales;
        _periodos = periodos;

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
      debugPrint('Error cargando datos iniciales: $e');
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      _showSnackBar('Error al cargar datos', isError: true);
    }
  }

  Future<void> _loadFacultades(String filialId) async {
    try {
      final facultades = await _eventosService.getFacultadesByFilial(filialId);
      if (!mounted) return;
      setState(() {
        _facultades = facultades;
        _selectedFacultad = null;
        _selectedCarreraId = null;
        _selectedCarreraNombre = null;
        _carreras = [];
      });
    } catch (e) {
      debugPrint('Error cargando facultades: $e');
      if (!mounted) return;
      _showSnackBar('Error al cargar facultades', isError: true);
    }
  }

  Future<void> _loadCarreras(String filialId, String facultadNombre) async {
    try {
      final carreras = await _eventosService.getCarrerasByFacultad(
        filialId,
        facultadNombre,
      );
      if (!mounted) return;
      setState(() {
        _carreras = carreras;
        _selectedCarreraId = null;
        _selectedCarreraNombre = null;
      });
    } catch (e) {
      debugPrint('Error cargando carreras: $e');
      if (!mounted) return;
      _showSnackBar('Error al cargar carreras', isError: true);
    }
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
          final tween = Tween(
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

    final carreraNameSnapshot = _selectedCarreraNombre ?? '';

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

      if (!mounted) return;
      _showSnackBar('Evento creado exitosamente para $carreraNameSnapshot');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error al crear evento: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
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
      body: SafeArea(
        child: _isLoadingData
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
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
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
                              color: const Color(0xFF1E3A5F)
                                  .withValues(alpha: 0.15),
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
                                    color: const Color(0xFF1E3A5F)
                                        .withValues(alpha: 0.1),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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

                            _buildDropdown(
                              value: _selectedFilialId,
                              label: 'Filial / Campus',
                              icon: Icons.location_city,
                              items:
                                  _filiales.map((f) => f['id']!).toList(),
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
                                        final carrera =
                                            _carreras.firstWhere(
                                          (c) => c['id'] == newValue,
                                        );
                                        setState(() {
                                          _selectedCarreraId = newValue;
                                          _selectedCarreraNombre =
                                              carrera['nombre'] as String?;
                                        });
                                      }
                                    }
                                  : null,
                            ),
                            const SizedBox(height: 16),

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
                                    _selectedPeriodoNombre =
                                        periodo['nombre'] as String?;
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

                            if (_selectedFilialId != null &&
                                _facultades.isEmpty)
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
                            final eventCount =
                                snapshot.data?.docs.length ?? 0;
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
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.done,
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
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: DropdownButtonFormField<String?>(
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
        return DropdownMenuItem<String?>(
          value: items[index],
          child: Text(
            itemLabels != null ? itemLabels[index] : items[index],
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
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
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.5),
            spreadRadius: 0,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Semantics(
        label: isLoading ? 'Creando evento, por favor espere' : text,
        button: true,
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
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 24, color: Colors.white),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
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
            color: const Color(0xFF2E7D32).withValues(alpha: 0.5),
            spreadRadius: 0,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Semantics(
        label: '$text, $count eventos',
        button: true,
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
              Flexible(
                child: Text(
                  '$text ($count)',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
