import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Reutiliza la pantalla de resultados que ya tienes
import '/admin/logica/asistencias_estudiantes_resultados.dart';

/// Pantalla de asistencias para Admin de Carrera.
/// Recibe filialId, filialNombre, facultad y carrera directamente
/// desde [ReportesAdminCarreraScreen], por lo que NO muestra filtros
/// de ubicación — solo el selector de evento ya filtrado.
class AsistenciasAdminCarreraScreen extends StatefulWidget {
  final String filialId;
  final String filialNombre;
  final String facultad;
  final String carrera;

  const AsistenciasAdminCarreraScreen({
    super.key,
    required this.filialId,
    required this.filialNombre,
    required this.facultad,
    required this.carrera,
  });

  @override
  State<AsistenciasAdminCarreraScreen> createState() =>
      _AsistenciasAdminCarreraScreenState();
}

class _AsistenciasAdminCarreraScreenState
    extends State<AsistenciasAdminCarreraScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<Map<String, dynamic>> _eventos = [];
  String? _eventoSeleccionadoId;
  Map<String, dynamic>? _eventoSeleccionadoData;

  int _totalAsistencias = 0;
  bool _isLoadingEventos = true;
  bool _isLoadingResumen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _cargarEventos();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // Carga eventos filtrando por filial + facultad + carrera
  // ═══════════════════════════════════════════════════════════════
  Future<void> _cargarEventos() async {
    setState(() => _isLoadingEventos = true);
    try {
      final snap = await _firestore
          .collection('events')
          .orderBy('createdAt', descending: true)
          .get();

      final todos = snap.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'name': d['name'] ?? 'Sin nombre',
          'filialId': d['filialId'] ?? '',
          'filialNombre': d['filialNombre'] ?? d['sede'] ?? '',
          'sede': d['sede'] ?? d['filialNombre'] ?? '',
          'facultad': d['facultad'] ?? '',
          'carreraNombre': d['carreraNombre'] ?? d['carrera'] ?? '',
          'carrera': d['carrera'] ?? '',
        };
      }).toList();

      // Filtrar: filial + facultad + carrera del admin
      final filtrados = todos.where((e) {
        final filialMatch = e['filialId'] == widget.filialId ||
            e['filialNombre'] == widget.filialNombre ||
            e['sede'] == widget.filialNombre;
        if (!filialMatch) return false;

        final facultadMatch = e['facultad'] == widget.facultad;
        if (!facultadMatch) return false;

        final carreraMatch = e['carreraNombre'] == widget.carrera ||
            e['carrera'] == widget.carrera;
        return carreraMatch;
      }).toList();

      if (mounted) {
        setState(() {
          _eventos = filtrados;
          _isLoadingEventos = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      debugPrint('Error cargando eventos: $e');
      if (mounted) setState(() => _isLoadingEventos = false);
    }
  }

  // Carga total de asistencias del evento elegido
  Future<void> _cargarResumen(String eventoId) async {
    setState(() => _isLoadingResumen = true);
    try {
      final snap = await _firestore
          .collection('events')
          .doc(eventoId)
          .collection('asistencias')
          .get();
      if (mounted) setState(() => _totalAsistencias = snap.docs.length);
    } catch (e) {
      debugPrint('Error cargando resumen: $e');
    } finally {
      if (mounted) setState(() => _isLoadingResumen = false);
    }
  }

  void _onEventoChanged(String? id) {
    if (id == null) return;
    final data = _eventos.firstWhere((e) => e['id'] == id);
    setState(() {
      _eventoSeleccionadoId = id;
      _eventoSeleccionadoData = data;
      _totalAsistencias = 0;
    });
    _cargarResumen(id);
  }

  void _verAsistencias() {
    if (_eventoSeleccionadoId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AsistenciasEstudiantesResultadosScreen(
          eventoId: _eventoSeleccionadoId!,
          eventoNombre: _eventoSeleccionadoData!['name'],
          filialId: widget.filialId,
          facultad: widget.facultad,
          carrera: widget.carrera,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      appBar: AppBar(
        title: const Text(
          'Asistencias',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        // Subtítulo con la ruta del admin
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.location_city,
                    color: Colors.white60, size: 13),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    '${widget.filialNombre} › ${widget.facultad} › ${widget.carrera}',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            margin: const EdgeInsets.only(top: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F7FA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: _isLoadingEventos
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                            color: Color(0xFF1E3A5F)),
                        SizedBox(height: 14),
                        Text('Cargando eventos...',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 15)),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Tarjeta de contexto (solo lectura) ──────────
                        _buildContextCard(),

                        const SizedBox(height: 20),

                        // ── Selector de evento ───────────────────────────
                        _buildEventoCard(),

                        // ── Resumen ──────────────────────────────────────
                        if (_eventoSeleccionadoId != null) ...[
                          const SizedBox(height: 16),
                          _buildResumenCard(),
                          const SizedBox(height: 24),
                          _buildBotonVerAsistencias(),
                        ],

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Tarjeta de contexto (filial / facultad / carrera) ──────────
  Widget _buildContextCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  color: const Color(0xFF1E3A5F).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school,
                    color: Color(0xFF1E3A5F), size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Tu carrera asignada',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.location_city, widget.filialNombre),
          const SizedBox(height: 6),
          _buildInfoRow(Icons.business, widget.facultad),
          const SizedBox(height: 6),
          _buildInfoRow(Icons.school, widget.carrera),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // ── Selector de evento ─────────────────────────────────────────
  Widget _buildEventoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  color: const Color(0xFF4A90E2).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event,
                    color: Color(0xFF4A90E2), size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Seleccionar Evento',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_eventos.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange[700], size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'No hay eventos registrados para tu carrera.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: _eventoSeleccionadoId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Evento (${_eventos.length} disponible${_eventos.length != 1 ? 's' : ''})',
                prefixIcon:
                    const Icon(Icons.event_note, color: Color(0xFF4A90E2)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF4A90E2),
                    width: 2,
                  ),
                ),
              ),
              items: _eventos.map((e) {
                return DropdownMenuItem<String>(
                  value: e['id'] as String,
                  child: Text(
                    e['name'] as String,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _onEventoChanged,
            ),
        ],
      ),
    );
  }

  // ── Resumen del evento seleccionado ────────────────────────────
  Widget _buildResumenCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildResumenStat(
              icon: Icons.people_alt,
              label: 'Estudiantes registrados',
              value: _isLoadingResumen
                  ? '...'
                  : '$_totalAsistencias',
              color: Colors.green.shade300,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildResumenStat(
              icon: Icons.event_available,
              label: 'Evento',
              value: _eventoSeleccionadoData?['name'] ?? '',
              color: Colors.blue.shade300,
            ),
          ),
        ],
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
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 5),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ── Botón ver asistencias ──────────────────────────────────────
  Widget _buildBotonVerAsistencias() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _verAsistencias,
        icon: const Icon(Icons.people_alt, size: 22),
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
    );
  }
}