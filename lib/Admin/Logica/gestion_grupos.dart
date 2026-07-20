import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/interfaz/grupos_screen.dart';
import '/admin/logica/filiales_service.dart';

class GestionGruposScreen extends StatefulWidget {
  const GestionGruposScreen({super.key});

  @override
  State<GestionGruposScreen> createState() => _GestionGruposScreenState();
}

class _GestionGruposScreenState extends State<GestionGruposScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FilialesService _filialesService = FilialesService();

  String? _selectedFilialId;
  String? _selectedFilialNombre;
  String? _selectedFacultad;
  String? _selectedCarreraId;
  String? _selectedCarreraNombre;

  List<Map<String, String>> _filiales = [];
  List<String> _facultades = [];
  List<Map<String, dynamic>> _carreras = [];
  bool _isLoadingData = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
    _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingData = true);

    try {
      final filiales = await _filialesService.getFiliales();
      final filialesData = <Map<String, String>>[];

      for (var filialId in filiales) {
        filialesData.add({
          'id': filialId,
          'nombre': _filialesService.getNombreFilial(filialId),
          'ubicacion': _filialesService.getUbicacionFilial(filialId),
        });
      }

      if (!mounted) return;

      setState(() {
        _filiales = filialesData;
        _isLoadingData = false;

        if (_filiales.isNotEmpty) {
          _selectedFilialId = _filiales.first['id'];
          _selectedFilialNombre = _filiales.first['nombre'];
          _loadFacultades(_selectedFilialId!);
        }
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
      final facultades =
          await _filialesService.getFacultadesByFilial(filialId);
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
      final carreras = await _filialesService.getCarrerasByFacultad(
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

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      appBar: AppBar(
        title: const Text(
          'Gestión de Grupos',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoadingData
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Cargando datos...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFilterSection(),
                        const SizedBox(height: 24),
                        if (_selectedFilialId != null &&
                            _selectedFacultad != null &&
                            _selectedCarreraId != null)
                          _buildEventsSection()
                        else
                          _buildEmptyState(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFilterSection() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2D5F8D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A5F).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.filter_list_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Filtrar Eventos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildAnimatedDropdown(
                    value: _selectedFilialId,
                    label: 'Filial / Campus',
                    icon: Icons.location_city_rounded,
                    items: _filiales.map((f) => f['id']!).toList(),
                    itemLabels: _filiales.map((f) {
                      return '${f['nombre']} - ${f['ubicacion']}';
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final filial = _filiales.firstWhere(
                          (f) => f['id'] == value,
                        );
                        setState(() {
                          _selectedFilialId = value;
                          _selectedFilialNombre = filial['nombre'];
                        });
                        _loadFacultades(value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildAnimatedDropdown(
                    value: _selectedFacultad,
                    label: 'Facultad',
                    icon: Icons.school_rounded,
                    items: _facultades,
                    onChanged: _selectedFilialId != null
                        ? (value) {
                            if (value != null) {
                              setState(() => _selectedFacultad = value);
                              _loadCarreras(_selectedFilialId!, value);
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _buildAnimatedDropdown(
                    value: _selectedCarreraId,
                    label: 'Carrera Profesional',
                    icon: Icons.book_rounded,
                    items: _carreras.map((c) => c['id'] as String).toList(),
                    itemLabels: _carreras
                        .map((c) => c['nombre'] as String)
                        .toList(),
                    onChanged: _selectedFacultad != null
                        ? (value) {
                            if (value != null) {
                              final carrera = _carreras.firstWhere(
                                (c) => c['id'] == value,
                              );
                              setState(() {
                                _selectedCarreraId = value;
                                _selectedCarreraNombre = carrera['nombre'];
                              });
                            }
                          }
                        : null,
                  ),
                  if (_selectedFilialId != null &&
                      _selectedFacultad != null &&
                      _selectedCarreraId != null)
                    Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Mostrando eventos de $_selectedCarreraNombre',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    List<String>? itemLabels,
    required void Function(String?)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            hint: Text(
              'Seleccionar $label',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F), size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            dropdownColor: Colors.white,
            items: List.generate(items.length, (index) {
              return DropdownMenuItem<String>(
                value: items[index],
                child: Text(
                  itemLabels != null ? itemLabels[index] : items[index],
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1E3A5F),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildEventsSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Eventos Disponibles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: Color(0xFF1E3A5F),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Toca un evento para gestionar grupos y proyectos',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E3A5F),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: _buildEventsQuery(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF1E3A5F),
                                ),
                              ),
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Cargando eventos...',
                              style: TextStyle(
                                color: Color(0xFF1E3A5F),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }

                  final events = snapshot.data?.docs ?? [];

                  if (events.isEmpty) {
                    return _buildNoEventsState();
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      return _buildEventCard(events[index], index);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _buildEventsQuery() {
    return _firestore
        .collection('events')
        .where('filialId', isEqualTo: _selectedFilialId)
        .where('facultad', isEqualTo: _selectedFacultad)
        .where('carreraId', isEqualTo: _selectedCarreraId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Widget _buildEventCard(DocumentSnapshot event, int index) {
    final eventData = event.data() as Map<String, dynamic>;
    final eventName = eventData['name'] ?? 'Sin nombre';
    final carreraNombre = eventData['carreraNombre'] ?? 'Sin carrera';
    final filialNombre = eventData['filialNombre'] ?? 'Sin filial';
    final eventId = event.id;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 80).clamp(0, 600)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFE0E0E0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () =>
                      _navigateToGrupos(context, eventId, eventData),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF2196F3),
                                Color(0xFF1976D2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2196F3)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.event_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                eventName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Color(0xFF1E3A5F),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  carreraNombre,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF4CAF50),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_city,
                                    size: 11,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      filialNombre,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (eventData['createdAt'] != null) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 11,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDate(eventData['createdAt']),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (eventData['proyectosCount'] != null) ...[
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.folder_rounded,
                                        size: 12,
                                        color: Color(0xFF2196F3),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${eventData['proyectosCount']} proyectos',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF2196F3),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Color(0xFF1E3A5F),
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 60),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0F4FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.filter_alt_rounded,
                      size: 52,
                      color: const Color(0xFF1E3A5F).withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Selecciona Filial, Facultad y Carrera',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Elige la filial, facultad y carrera para ver\nlos eventos disponibles',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoEventsState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3E0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_busy_rounded,
                size: 52,
                color: Color(0xFFFF9800),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No hay eventos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'No hay eventos registrados para esta carrera.\nCrea uno en Gestión de Eventos.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 52,
                color: Color(0xFFE53935),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Error al cargar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE53935),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                error,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToGrupos(
    BuildContext context,
    String eventId,
    Map<String, dynamic> eventData,
  ) {
    eventData['id'] = eventId;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            GruposScreen(eventData: eventData),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}