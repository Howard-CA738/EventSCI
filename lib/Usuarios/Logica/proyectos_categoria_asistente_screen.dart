import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '/admin_carrera/codigo_asistencia_service.dart';

class ProyectosCategoriaAsistenteScreen extends StatefulWidget {
  final String eventId;
  final String eventName;
  final String filialId;
  final String filialNombre;
  final String facultad;
  final String carrera;
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
  List<Map<String, dynamic>> _proyectos = [];
  bool _isLoading = true;

  String? _qrDataGenerado;
  String? _codigoGenerado;
  Map<String, dynamic>? _proyectoSeleccionado;
  String? _qrId;
  bool _qrFinalizado = false;
  bool _finalizando = false;

  late AnimationController _fadeController;
  late AnimationController _scaleController;

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

  Future<void> _finalizarQRSiActivo() async {
    if (_qrId == null || _qrFinalizado) return;
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

      if (_codigoGenerado != null) {
        await CodigoAsistenciaService.eliminar(_codigoGenerado!);
      }
    } catch (e) {
      debugPrint('Error al auto-finalizar QR: $e');
    }
  }

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

  Future<void> _generarQRParaProyecto(Map<String, dynamic> proyecto) async {
    String safeString(dynamic value) {
      if (value == null) return '';
      if (value is List) return value.join(', ');
      return value.toString();
    }

    final codigoProyecto = safeString(proyecto['Código']).isEmpty
        ? 'Sin código'
        : safeString(proyecto['Código']);
    final tituloProyecto = safeString(proyecto['Título']).isEmpty
        ? 'Sin título'
        : safeString(proyecto['Título']);
    final grupo = safeString(proyecto['Sala']);

    final qrDocRef = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('qr_codes')
        .doc();

    final qrId = qrDocRef.id;

    final qrPayload = {
      'filialId': widget.filialId,
      'filialNombre': widget.filialNombre,
      'facultad': widget.facultad,
      'carrera': widget.carrera,
      'eventId': widget.eventId,
      'eventName': widget.eventName,
      'categoria': widget.categoria,
      'codigoProyecto': codigoProyecto,
      'tituloProyecto': tituloProyecto,
      'grupo': grupo,
      'qrId': qrId,
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'asistencia_categoria_asistente',
      'activo': true,
    };

    try {
      final qrJson = jsonEncode(qrPayload);



      final codigo = await CodigoAsistenciaService.generarYRegistrar(
        eventId: widget.eventId,
        qrId: qrId,
        type: 'proyecto',
        qrData: qrJson,
      );

      await qrDocRef.set({
        'filialId': widget.filialId,
        'filialNombre': widget.filialNombre,
        'facultad': widget.facultad,
        'carrera': widget.carrera,
        'eventId': widget.eventId,
        'eventName': widget.eventName,
        'categoria': widget.categoria,
        'codigoProyecto': codigoProyecto,
        'tituloProyecto': tituloProyecto,
        'grupo': grupo,
        'codigo': codigo,
        'activo': true,
        'createdAt': FieldValue.serverTimestamp(),
        'finalizadoAt': null,
        'generadoPor': 'asistente_qr',
      });

      setState(() {
        _qrDataGenerado = qrJson;
        _codigoGenerado = codigo;
        _proyectoSeleccionado = proyecto;
        _qrId = qrId;
        _qrFinalizado = false;
      });

      _scaleController.forward(from: 0);
      _showSnackBar('¡Código QR generado y activo!');
    } catch (e) {
      _showSnackBar('Error al generar QR: $e', isError: true);
    }
  }

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


      if (_codigoGenerado != null) {
        await CodigoAsistenciaService.eliminar(_codigoGenerado!);
      }

      setState(() {
        _qrFinalizado = true;
        _finalizando = false;
      });

      _showSnackBar('¡QR finalizado! Ya no se podrá escanear');

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _finalizando = false);
      _showSnackBar('Error al finalizar QR: $e', isError: true);
    }
  }

  void _limpiarQR() async {
    await _finalizarQRSiActivo();
    setState(() {
      _qrDataGenerado = null;
      _codigoGenerado = null;
      _proyectoSeleccionado = null;
      _qrId = null;
      _qrFinalizado = false;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _finalizarQRSiActivo();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE8EDF2),
        appBar: _buildAppBar(),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_primary),
                  ),
                )
              : _qrDataGenerado != null
                  ? _buildQRView()
                  : _buildProyectosList(),
        ),
      ),
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
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            widget.categoria,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        if (widget.filialNombre.isNotEmpty)
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 140),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_city,
                          size: 12, color: Colors.white70),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          widget.filialNombre,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProyectosList() {
    if (_proyectos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_off_rounded,
                  size: 72, color: Colors.grey[300]),
              const SizedBox(height: 14),
              Text(
                'No hay proyectos en esta categoría',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeController,
      child: Column(
        children: [
          _buildContextBanner(),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    color: Colors.blue.shade700, size: 18),
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

  Widget _buildContextBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.verified_outlined, color: _primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
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
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: _primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: _primary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProyectoCard(Map<String, dynamic> proyecto) {
    String resolverCampo(dynamic valor) {
      if (valor == null) return '';
      if (valor is List) return valor.map((e) => e.toString()).join(', ');
      return valor.toString();
    }

    final integrantes = resolverCampo(proyecto['Integrantes']);
    final sala = resolverCampo(proyecto['Sala']);
    final codigo = resolverCampo(proyecto['Código']).isNotEmpty
        ? resolverCampo(proyecto['Código'])
        : 'Sin código';
    final titulo = resolverCampo(proyecto['Título']).isNotEmpty
        ? resolverCampo(proyecto['Título'])
        : 'Sin título';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7ED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
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
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          codigo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.qr_code_rounded,
                      color: const Color(0xFF1E3A5F).withValues(alpha: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A5F),
                    height: 1.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
                if (integrantes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(Icons.people_rounded,
                            size: 16, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          integrantes,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (sala.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.room_rounded,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Sala: $sala',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app_rounded,
                              size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Toca para generar QR',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQRView() {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(
            parent: _scaleController, curve: Curves.easeOutBack),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final qrSize = (constraints.maxWidth - 80).clamp(160.0, 240.0);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _qrFinalizado
                              ? Colors.red.shade600
                              : _primary,
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
                            Flexible(
                              child: Text(
                                _qrFinalizado
                                    ? 'QR FINALIZADO'
                                    : _proyectoSeleccionado!['Código']
                                            ?.toString() ??
                                        'Sin código',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

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
                                size: qrSize,
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
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),


                      if (_codigoGenerado != null && !_qrFinalizado) ...[
                        const SizedBox(height: 18),
                        _buildCodigoManual(_codigoGenerado!),
                      ],

                      const SizedBox(height: 20),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F8FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionLabel('Identidad del QR'),
                            _buildInfoRow(Icons.location_city, 'Filial:',
                                widget.filialNombre),
                            _buildInfoRow(Icons.account_balance, 'Facultad:',
                                widget.facultad),
                            _buildInfoRow(
                                Icons.menu_book, 'Carrera:', widget.carrera),
                            const Divider(height: 20, thickness: 0.6),
                            _buildSectionLabel('Evento y proyecto'),
                            _buildInfoRow(
                                Icons.event, 'Evento:', widget.eventName),
                            _buildInfoRow(Icons.category, 'Categoría:',
                                widget.categoria),
                            _buildInfoRow(
                              Icons.tag,
                              'Código:',
                              _proyectoSeleccionado!['Código']?.toString() ??
                                  'N/A',
                            ),
                            _buildInfoRow(
                              Icons.title,
                              'Título:',
                              _proyectoSeleccionado!['Título']?.toString() ??
                                  'N/A',
                            ),
                            if (_proyectoSeleccionado!['Sala'] != null)
                              _buildInfoRow(
                                Icons.room,
                                'Sala:',
                                _proyectoSeleccionado!['Sala'] is List
                                    ? (_proyectoSeleccionado!['Sala'] as List)
                                        .join(', ')
                                    : _proyectoSeleccionado!['Sala']
                                        .toString(),
                              ),
                            const Divider(height: 20, thickness: 0.6),
                            _buildSectionLabel('Control'),
                            if (_codigoGenerado != null)
                              _buildInfoRow(Icons.dialpad, 'Código manual:',
                                  _codigoGenerado!),
                            _buildInfoRow(Icons.fingerprint, 'ID QR:',
                                _qrId ?? 'N/A'),
                            _buildInfoRow(
                              Icons.circle,
                              'Estado:',
                              _qrFinalizado ? '🔴 Inactivo' : '🟢 Activo',
                            ),
                            _buildInfoRow(
                              Icons.schedule,
                              'Generado:',
                              DateTime.now().toString().split('.')[0],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _qrFinalizado ? null : _limpiarQR,
                              icon: const Icon(Icons.arrow_back_rounded,
                                  size: 19),
                              label: const Text(
                                'Volver',
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
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
                              onPressed: _qrFinalizado || _finalizando
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
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
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
          );
        },
      ),
    );
  }


  Widget _buildCodigoManual(String codigo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.dialpad_rounded, size: 16, color: _accent),
              SizedBox(width: 6),
              Text(
                'Código para ingreso manual',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            codigo,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
              color: _primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'El alumno puede escanear el QR o escribir este número.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
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
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 13, color: _primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 6),
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: _primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            flex: 3,
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