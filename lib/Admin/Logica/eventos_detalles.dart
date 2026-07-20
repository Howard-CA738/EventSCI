import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/logica/periodos_helper.dart';

class EventosDetallesScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const EventosDetallesScreen({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  @override
  State<EventosDetallesScreen> createState() => _EventosDetallesScreenState();
}

class _EventosDetallesScreenState extends State<EventosDetallesScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();

  bool _isLoading = false;
  bool _hasChanges = false;

  String? _selectedPeriodoId;
  String? _selectedPeriodoNombre;
  List<Map<String, dynamic>> _periodos = [];

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadEventDetails();
    _loadPeriodos();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _loadEventDetails() {
    final d = widget.eventData;
    _nameController.text = d['name'] ?? '';
    _selectedPeriodoId = d['periodoId'];
    _selectedPeriodoNombre = d['periodoNombre'];
    _nameController.addListener(_onFieldChanged);
  }

  Future<void> _loadPeriodos() async {
    try {
      final periodos = await PeriodosHelper.getPeriodosActivos();
      setState(() {
        _periodos = periodos;
        final ids = _periodos.map((p) => p['id'] as String).toList();
        if (_selectedPeriodoId != null && !ids.contains(_selectedPeriodoId)) {
          _periodos.insert(0, {
            'id': _selectedPeriodoId,
            'nombre': _selectedPeriodoNombre ?? _selectedPeriodoId,
          });
        }
      });
    } catch (e) {
      debugPrint('Error cargando períodos: $e');
    }
  }

  void _onFieldChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<void> _saveChanges() async {
    final nombre = _nameController.text.trim();
    if (nombre.isEmpty) {
      _showSnackBar('El nombre del evento no puede estar vacío', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final updateData = <String, dynamic>{
        'name': nombre,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_selectedPeriodoId != null) {
        updateData['periodoId'] = _selectedPeriodoId;
        updateData['periodoNombre'] = _selectedPeriodoNombre;
      }

      await _firestore
          .collection('events')
          .doc(widget.eventId)
          .update(updateData);

      setState(() => _hasChanges = false);
      _showSnackBar('Evento actualizado correctamente', isSuccess: true);
    } catch (e) {
      _showSnackBar('Error al guardar: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message,
      {bool isError = false, bool isSuccess = false}) {
    final color = isError
        ? const Color(0xFFE53935)
        : isSuccess
            ? const Color(0xFF43A047)
            : const Color(0xFF1E3A5F);
    final icon = isError
        ? Icons.error_outline
        : isSuccess
            ? Icons.check_circle_outline
            : Icons.info_outline;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFE8EDF2),
      appBar: AppBar(
        title: const Text(
          'Editar Evento',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_hasChanges)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: SizedBox(
                height: 44,
                child: TextButton.icon(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check, color: Colors.white, size: 20),
                  label: const Text(
                    'Guardar',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildContextChip(),
                const SizedBox(height: 16),
                _buildSection(
                  icon: Icons.event_note,
                  iconColor: const Color(0xFF1E3A5F),
                  title: 'Datos del evento',
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Nombre del evento',
                      hint: 'Ej: Conferencia de Tecnología',
                      icon: Icons.event,
                    ),
                    const SizedBox(height: 14),
                    _buildDropdown(),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContextChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.school, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              [
                widget.eventData['carrera'] ??
                    widget.eventData['carreraNombre'] ??
                    '',
                widget.eventData['facultad'] ?? '',
              ].where((s) => s.isNotEmpty).join(' · '),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Editando',
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
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
      maxLines: 1,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F), size: 20),
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
          borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }

  Widget _buildDropdown() {
    if (_periodos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red.shade600, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'No hay períodos activos disponibles.',
                style: TextStyle(fontSize: 12, color: Color(0xFFE53935)),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedPeriodoId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Período académico',
        prefixIcon: const Icon(Icons.calendar_month,
            color: Color(0xFF1E3A5F), size: 20),
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
          borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      items: _periodos.map((p) {
        return DropdownMenuItem<String>(
          value: p['id'] as String,
          child: Text(
            p['nombre'] as String,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (newValue) {
        if (newValue != null) {
          final periodo = _periodos.firstWhere((p) => p['id'] == newValue);
          setState(() {
            _selectedPeriodoId = newValue;
            _selectedPeriodoNombre = periodo['nombre'] as String;
            _hasChanges = true;
          });
        }
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.save_outlined, size: 22),
        label: Text(
          _isLoading ? 'Guardando…' : 'Guardar cambios',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}