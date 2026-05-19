import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

/// Pantalla de proyectos por categoría EXCLUSIVA para el rol [esAsisteQR].
/// A diferencia de la pantalla general del admin, esta versión embebe
/// [filialId] y [filialNombre] en el payload del QR y en el registro
/// de Firestore, garantizando que cada QR sea único por:
///   filial → facultad → carrera → evento → categoría → proyecto
class ProyectosCategoriaAsistenteScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  // ── Datos de identidad del asistente ──────────────────────────────────────
  final String filialId;
  final String filialNombre;
  final String facultad;
  final String carrera; // carreraNombre

  final String categoria;

  const ProyectosCategoriaAsistenteScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.filialId,
    required this.filialNombre,
    required this.facultad,
    required this.carrera,
    required this.categoria,
  });

  @override
  State<ProyectosCategoriaAsistenteScreen> createState() =>
      _ProyectosCategoriaAsistenteScreenState();
}

class _ProyectosCategoriaAsistenteScreenState
    extends State<ProyectosCategoriaAsistenteScreen>
    with TickerProviderStateMixin {
  // ── Estado ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _proyectos = [];
  bool _isLoading = true;

  String? _qrDataGenerado;
  Map<String, dynamic>? _proyectoSeleccionado;
  String? _qrId;
  bool _qrFinalizado = false;
  bool _finalizando = false;

  late AnimationController _fadeController;
  late AnimationController _scaleController;

  // ── Colores del tema ──────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF1E3A5F);
  static const Color _accent = Color(0xFF0D7377);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _cargarProyectos();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CARGA DE PROYECTOS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _cargarProyectos() async {
    setState(() => _isLoading = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('proyectos')
          .where('Clasificación', isEqualTo: widget.categoria)
          .orderBy('Código')
          .get();

      final proyectos = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();

      setState(() {
        _proyectos = proyectos;
        _isLoading = false;
      });

      _fadeController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error al cargar proyectos: $e', isError: true);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GENERACIÓN DEL QR — incluye filialId + filialNombre para unicidad total
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _generarQRParaProyecto(Map<String, dynamic> proyecto) async {
    debugPrint('🎯 GENERANDO QR (Asistente) para:'
        '\n  filialId   : ${widget.filialId}'
        '\n  filialNombre: ${widget.filialNombre}'
        '\n  facultad   : ${widget.facultad}'
        '\n  carrera    : ${widget.carrera}'
        '\n  eventId    : ${widget.eventId}'
        '\n  categoría  : ${widget.categoria}'
        '\n  código     : ${proyecto['Código']}'
        '\n  título     : ${proyecto['Título']}');

    // Referencia con ID automático en la subcolección qr_codes del evento
    final qrDocRef = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('qr_codes')
        .doc();

    final qrId = qrDocRef.id;

    // ── Payload embebido en el QR ──────────────────────────────────────────
    // Todos los campos de identidad van en el JSON para que el escáner
    // pueda validar que el QR pertenece a la filial/facultad/carrera correcta.
    final qrPayload = {
      // Identidad del asistente
      'filialId': widget.filialId,
      'filialNombre': widget.filialNombre,
      'facultad': widget.facultad,
      'carrera': widget.carrera,

      // Identidad del evento
      'eventId': widget.eventId,
      'eventName': widget.eventName,
      'categoria': widget.categoria,

      // Identidad del proyecto
      'codigoProyecto': proyecto['Código'] ?? 'Sin código',
      'tituloProyecto': proyecto['Título'] ?? 'Sin título',
      'grupo': proyecto['Sala'] ?? '',

      // Control del QR
      'qrId': qrId,
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'asistencia_categoria_asistente',
      'activo': true,
    };

    try {
      // ── Registro en Firestore ──────────────────────────────────────────
      // La clave de unicidad real está en la combinación de estos campos.
      // El escáner debe verificar que filialId + facultad + carrera + eventId
      // coincidan con los del usuario que escanea antes de registrar asistencia.
      await qrDocRef.set({
        // Identidad
        'filialId': widget.filialId,
        'filialNombre': widget.filialNombre,
        'facultad': widget.facultad,
        'carrera': widget.carrera,

        // Evento
        'eventId': widget.eventId,
        'eventName': widget.eventName,
        'categoria': widget.categoria,

        // Proyecto
        'codigoProyecto': proyecto['Código'] ?? 'Sin código',
        'tituloProyecto': proyecto['Título'] ?? 'Sin título',
        'grupo': proyecto['Sala'] ?? '',

        // Estado
        'activo': true,
        'createdAt': FieldValue.serverTimestamp(),
        'finalizadoAt': null,

        // Quién generó el QR (para auditoría)
        'generadoPor': 'asistente_qr',
      });

      final qrJson = jsonEncode(qrPayload);

      debugPrint('✅ QR registrado en Firestore'
          '\n  qrId: $qrId'
          '\n  activo: true');

      setState(() {
        _qrDataGenerado = qrJson;
        _proyectoSeleccionado = proyecto;
        _qrId = qrId;
        _qrFinalizado = false;
      });

      _scaleController.forward(from: 0);
      _showSnackBar('¡Código QR generado y activo!');
    } catch (e) {
      debugPrint('❌ Error al registrar QR: $e');
      _showSnackBar('Error al generar QR: $e', isError: true);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FINALIZAR QR
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _finalizarQR() async {
    if (_qrId == null || _qrFinalizado) return;

    setState(() => _finalizando = true);

    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('qr_codes')
          .doc(_qrId)
          .update({
        'activo': false,
        'finalizadoAt': FieldValue.serverTimestamp(),
      });

      debugPrint('🔒 QR FINALIZADO: $_qrId → activo: false');

      setState(() {
        _qrFinalizado = true;
        _finalizando = false;
      });

      _showSnackBar('¡QR finalizado! Ya no se podrá escanear');

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ Error al finalizar QR: $e');
      setState(() => _finalizando = false);
      _showSnackBar('Error al finalizar QR: $e', isError: true);
    }
  }

  void _limpiarQR() {
    setState(() {
      _qrDataGenerado = null;
      _proyectoSeleccionado = null;
      _qrId = null;
      _qrFinalizado = false;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red.shade600 : Colors.green.shade600,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF2),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primary),
              ),
            )
          : _qrDataGenerado != null
              ? _buildQRView()
              : _buildProyectosList(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proyectos por Categoría',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          Text(
            widget.categoria,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      // Badge de filial visible en el AppBar para recordar el contexto
      actions: [
        if (widget.filialNombre.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_city,
                        size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 100),
                      child: Text(
                        widget.filialNombre,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LISTA DE PROYECTOS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildProyectosList() {
    if (_proyectos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_rounded, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 14),
            Text(
              'No hay proyectos en esta categoría',
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeController,
      child: Column(
        children: [
          // ── Banda de contexto ────────────────────────────────────────────
          _buildContextBanner(),

          // ── Instrucción ──────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Selecciona un proyecto para generar su QR de asistencia.',
                    style: TextStyle(
                        color: Colors.blue.shade900, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),

          // ── Lista ────────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _proyectos.length,
              itemBuilder: (context, index) {
                final proyecto = _proyectos[index];
                return TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 280 + index * 45),
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, value, child) => Transform.translate(
                    offset: Offset(0, 18 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  ),
                  child: _buildProyectoCard(proyecto),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Banda que muestra filial → facultad → carrera para confirmar el contexto
  /// exacto del QR que se va a generar.
  Widget _buildContextBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha:0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withValues(alpha:0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, color: _primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _contextChip(Icons.location_city, widget.filialNombre),
                _contextChip(Icons.account_balance, widget.facultad),
                _contextChip(Icons.menu_book, widget.carrera),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contextChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha:0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: _primary),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 11,
                  color: _primary,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProyectoCard(Map<String, dynamic> proyecto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7ED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _generarQRParaProyecto(proyecto),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Código + ícono QR ──────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        proyecto['Código'] ?? 'Sin código',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.qr_code_rounded,
                        color: _primary.withValues(alpha:0.4), size: 22),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Título ─────────────────────────────────────────────────
                Text(
                  proyecto['Título'] ?? 'Sin título',
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: _primary,
                      height: 1.3),
                ),

                // ── Integrantes ────────────────────────────────────────────
                if (proyecto['Integrantes'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.people_rounded,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          proyecto['Integrantes'],
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // ── Sala ───────────────────────────────────────────────────
                if (proyecto['Sala'] != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.room_rounded,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 5),
                      Text(
                        'Sala: ${proyecto['Sala']}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // ── CTA ────────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded,
                          size: 15, color: Colors.green.shade700),
                      const SizedBox(width: 5),
                      Text(
                        'Toca para generar QR',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VISTA DEL QR GENERADO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildQRView() {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(
            parent: _scaleController, curve: Curves.easeOutBack),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha:0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ── Estado del QR ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          _qrFinalizado ? Colors.red.shade600 : _primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _qrFinalizado
                              ? Icons.block
                              : Icons.check_circle,
                          color: Colors.white,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _qrFinalizado
                              ? 'QR FINALIZADO'
                              : _proyectoSeleccionado!['Código'] ??
                                  'Sin código',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Imagen del QR ────────────────────────────────────────
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _qrFinalizado
                                ? Colors.red.shade300
                                : const Color(0xFFE0E7ED),
                            width: 2,
                          ),
                        ),
                        child: Opacity(
                          opacity: _qrFinalizado ? 0.25 : 1.0,
                          child: QrImageView(
                            data: _qrDataGenerado!,
                            version: QrVersions.auto,
                            size: 240.0,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                      if (_qrFinalizado)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.block,
                                  color: Colors.white, size: 44),
                              SizedBox(height: 6),
                              Text(
                                'QR INACTIVO',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Información del QR ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F8FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bloque de unicidad (datos que hacen único al QR)
                        _buildSectionLabel('Identidad del QR'),
                        _buildInfoRow(
                            Icons.location_city, 'Filial:', widget.filialNombre),
                        _buildInfoRow(
                            Icons.account_balance, 'Facultad:', widget.facultad),
                        _buildInfoRow(
                            Icons.menu_book, 'Carrera:', widget.carrera),
                        const Divider(height: 20, thickness: 0.6),

                        // Bloque del evento y proyecto
                        _buildSectionLabel('Evento y proyecto'),
                        _buildInfoRow(
                            Icons.event, 'Evento:', widget.eventName),
                        _buildInfoRow(
                            Icons.category, 'Categoría:', widget.categoria),
                        _buildInfoRow(
                            Icons.tag,
                            'Código:',
                            _proyectoSeleccionado!['Código'] ?? 'N/A'),
                        _buildInfoRow(
                            Icons.title,
                            'Título:',
                            _proyectoSeleccionado!['Título'] ?? 'N/A'),
                        if (_proyectoSeleccionado!['Sala'] != null)
                          _buildInfoRow(
                              Icons.room,
                              'Sala:',
                              _proyectoSeleccionado!['Sala']),
                        const Divider(height: 20, thickness: 0.6),

                        // Control
                        _buildSectionLabel('Control'),
                        _buildInfoRow(
                            Icons.fingerprint, 'ID QR:', _qrId ?? 'N/A'),
                        _buildInfoRow(
                            Icons.circle,
                            'Estado:',
                            _qrFinalizado ? '🔴 Inactivo' : '🟢 Activo'),
                        _buildInfoRow(
                            Icons.schedule,
                            'Generado:',
                            DateTime.now().toString().split('.')[0]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Botones ──────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _qrFinalizado ? null : _limpiarQR,
                          icon: const Icon(Icons.arrow_back_rounded, size: 19),
                          label: const Text('Volver'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: _qrFinalizado
                                  ? Colors.grey.shade300
                                  : _primary,
                              width: 1.5,
                            ),
                            foregroundColor: _qrFinalizado
                                ? Colors.grey.shade400
                                : _primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _qrFinalizado || _finalizando
                                  ? null
                                  : _finalizarQR,
                          icon: _finalizando
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _qrFinalizado
                                      ? Icons.check_circle
                                      : Icons.lock_outline,
                                  size: 19,
                                ),
                          label: Text(
                            _finalizando
                                ? 'Finalizando...'
                                : (_qrFinalizado
                                    ? 'Finalizado'
                                    : 'Finalizar QR'),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: _qrFinalizado
                                ? Colors.grey.shade400
                                : (_finalizando
                                    ? Colors.orange.shade600
                                    : Colors.red.shade600),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _accent,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: _primary.withValues(alpha:0.5)),
          const SizedBox(width: 6),
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: _primary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: Color(0xFF4A5568), fontSize: 12.5),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }
}