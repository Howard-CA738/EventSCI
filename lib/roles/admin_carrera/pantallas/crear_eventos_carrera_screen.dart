import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import '/admin/logica/crear_eventos.dart';
import '/admin/logica/periodos_helper.dart';
import '/admin/logica/eventos_detalles.dart';

class CrearEventosCarreraScreen extends StatefulWidget {
  const CrearEventosCarreraScreen({super.key});

  @override
  State<CrearEventosCarreraScreen> createState() =>
      _CrearEventosCarreraScreenState();
}

class _CrearEventosCarreraScreenState
    extends State<CrearEventosCarreraScreen> {
  final TextEditingController _eventNameController = TextEditingController();
  final EventosService _eventosService = EventosService();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isLoadingData = true;

  String? _filialId;
  String? _filialNombre;
  String? _facultad;
  String? _carreraId;
  String? _carreraNombre;

  String? _selectedPeriodoId;
  String? _selectedPeriodoNombre;
  List<Map<String, dynamic>> _periodos = [];

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    setState(() => _isLoadingData = true);
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      final periodos = await PeriodosHelper.getPeriodosActivos();

      if (adminData != null) {
        setState(() {
          _filialId = adminData['filial'];
          _filialNombre = adminData['filialNombre'];
          _facultad = adminData['facultad'];
          _carreraId = adminData['carreraId'] ?? adminData['carrera'];
          _carreraNombre = adminData['carrera'];
          _periodos = periodos;
          if (periodos.isNotEmpty) {
            _selectedPeriodoId = periodos.first['id'];
            _selectedPeriodoNombre = periodos.first['nombre'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al cargar datos de la sesión', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  Future<void> _createEvent() async {
    FocusScope.of(context).unfocus();

    final nameError =
        _eventosService.validateEventName(_eventNameController.text);
    if (nameError != null) {
      _showSnackBar(nameError, isError: true);
      return;
    }

    if (_filialId == null ||
        _facultad == null ||
        _carreraId == null ||
        _carreraNombre == null) {
      _showSnackBar(
        'No se pudieron obtener los datos de la carrera. Cierra sesión e intenta de nuevo.',
        isError: true,
      );
      return;
    }

    final periodoError =
        _eventosService.validatePeriodo(_selectedPeriodoId);
    if (periodoError != null) {
      _showSnackBar(periodoError, isError: true);
      return;
    }

    if (_selectedPeriodoNombre == null) {
      _showSnackBar('Selecciona un período válido', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _eventosService.createEvent(
        name: _eventNameController.text.trim(),
        filialId: _filialId!,
        filialNombre: _filialNombre ?? _filialId!,
        facultad: _facultad!,
        carreraId: _carreraId!,
        carreraNombre: _carreraNombre!,
        periodoId: _selectedPeriodoId!,
        periodoNombre: _selectedPeriodoNombre!,
      );

      _eventNameController.clear();
      _showSnackBar('Evento creado exitosamente para $_carreraNombre');
    } catch (e) {
      _showSnackBar('Error al crear evento: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToEventDetails(
      String eventId, Map<String, dynamic> eventData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EventosDetallesScreen(eventId: eventId, eventData: eventData),
      ),
    );
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
        backgroundColor:
            isError ? const Color(0xFFE53935) : const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF2),
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
          ? const SafeArea(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF1E3A5F)),
              ),
            )
          : SafeArea(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.opaque,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    20 +
                        (keyboardPadding > 0
                            ? keyboardPadding
                            : bottomPadding),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildContextCard(),
                      const SizedBox(height: 20),
                      _buildCreateCard(),
                      const SizedBox(height: 20),
                      _buildEventsList(),
                    ],
                  ),
                ),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
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
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 3),
                Text(
                  _facultad ?? '—',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _filialNombre ?? '—',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30),
            ),
            child: const Text(
              'Tu carrera',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_available,
                    color: Color(0xFF1E3A5F), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crear nuevo evento',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'El evento se asociará automáticamente a tu carrera',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _eventNameController,
            label: 'Nombre del evento',
            hint: 'Ej: Conferencia de Tecnología',
            icon: Icons.event,
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            value: _selectedPeriodoId,
            label: 'Período académico',
            icon: Icons.calendar_month,
            items: _periodos.map((p) => p['id'] as String).toList(),
            itemLabels:
                _periodos.map((p) => p['nombre'] as String).toList(),
            onChanged: _periodos.isEmpty
                ? null
                : (String? newValue) {
                    if (newValue != null) {
                      final periodo = _periodos
                          .firstWhere((p) => p['id'] == newValue);
                      setState(() {
                        _selectedPeriodoId = newValue;
                        _selectedPeriodoNombre =
                            periodo['nombre'] as String?;
                      });
                    }
                  },
          ),
          if (_periodos.isEmpty) ...[
            const SizedBox(height: 12),
            _buildWarningBanner(
              icon: Icons.warning_amber,
              color: const Color(0xFFE53935),
              bgColor: const Color(0xFFFFEBEE),
              message:
                  'No hay períodos activos. Solicita al administrador que active un período.',
            ),
          ],
          const SizedBox(height: 24),
          _buildPrimaryButton(
            onPressed:
                (_isLoading || _periodos.isEmpty) ? null : _createEvent,
            text: 'Crear Evento',
            icon: Icons.add_circle_outline,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _eventosService.getEventsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(color: Color(0xFF1E3A5F)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFE53935), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Error al cargar eventos',
                    style: const TextStyle(
                        color: Color(0xFFE53935), fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        final events = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final mismaFilial = data['filialId'] == _filialId;
          final mismaFacultad = data['facultad'] == _facultad;
          final mismaCarrera = data['carreraId'] == _carreraId ||
              data['carreraNombre'] == _carreraNombre;
          return mismaFilial && mismaFacultad && mismaCarrera;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Row(
                children: [
                  const Flexible(
                    child: Text(
                      'Eventos de tu carrera',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A5F),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${events.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1E3A5F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (events.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.event_busy,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(
                      'Aún no hay eventos para esta carrera',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ...events.map((event) {
              final data = event.data() as Map<String, dynamic>;
              return _buildEventCard(event.id, data);
            }),
          ],
        );
      },
    );
  }

  Widget _buildEventCard(String eventId, Map<String, dynamic> data) {
    final name = (data['name'] as String?)?.trim().isNotEmpty == true
        ? data['name'] as String
        : 'Sin nombre';
    final periodo = (data['periodoNombre'] as String?) ?? '';

    DateTime? fecha;
    try {
      if (data['fecha'] is Timestamp) {
        fecha = (data['fecha'] as Timestamp).toDate();
      }
    } catch (_) {
      fecha = null;
    }

    final inicial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _navigateToEventDetails(eventId, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
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
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  inicial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1E3A5F),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  if (periodo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 11, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            periodo,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (fecha != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 11, color: Colors.blue[400]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _eventosService.formatDate(fecha),
                            style: TextStyle(
                                fontSize: 11, color: Colors.blue[400]),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0xFF94A3B8), size: 20),
          ],
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
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: 300,
      decoration: InputDecoration(
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: List.generate(items.length, (i) {
        return DropdownMenuItem<String>(
          value: items[i],
          child: Text(
            itemLabels != null ? itemLabels[i] : items[i],
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }),
      onChanged: onChanged,
    );
  }

  Widget _buildWarningBanner({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback? onPressed,
    required String text,
    required IconData icon,
    required bool isLoading,
  }) {
    return SizedBox(
      height: 52,
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
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}