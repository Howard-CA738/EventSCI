import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '/roles/admin/logica/proyectos_categoria_service.dart';

class ProyectosCategoriaScreen extends StatefulWidget {
  final String eventId;
  final String eventName;
  final String facultad;
  final String carrera;
  final String categoria;

  const ProyectosCategoriaScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.facultad,
    required this.carrera,
    required this.categoria,
  });

  @override
  State<ProyectosCategoriaScreen> createState() =>
      _ProyectosCategoriaScreenState();
}

class _ProyectosCategoriaScreenState extends State<ProyectosCategoriaScreen>
    with TickerProviderStateMixin {
  final ProyectosCategoriaService _service = ProyectosCategoriaService();
  List<Map<String, dynamic>> _proyectos = [];
  bool _isLoading = true;
  String? _qrDataGenerado;
  Map<String, dynamic>? _proyectoSeleccionado;
  String? _qrId;
  bool _qrFinalizado = false;
  bool _finalizando = false;

  late AnimationController _fadeController;
  late AnimationController _scaleController;

  static const Color _primaryColor = Color(0xFF1E3A5F);
  static const Color _backgroundColor = Color(0xFFE8EFF5);
  static const Color _borderColor = Color(0xFFE0E7ED);
  static const Color _textSecondary = Color(0xFF4A5568);
  static const Color _surfaceColor = Color(0xFFF5F8FA);

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

  Future<void> _cargarProyectos() async {
    setState(() => _isLoading = true);

    try {
      final proyectos = await _service.cargarProyectos(
        eventId: widget.eventId,
        categoria: widget.categoria,
      );

      if (!mounted) return;

      setState(() {
        _proyectos = proyectos;
        _isLoading = false;
      });

      _fadeController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Error al cargar proyectos: $e', isError: true);
    }
  }

  Future<void> _generarQRParaProyecto(Map<String, dynamic> proyecto) async {
    try {
      final resultado = await _service.generarQRParaProyecto(
        eventId: widget.eventId,
        eventName: widget.eventName,
        facultad: widget.facultad,
        carrera: widget.carrera,
        categoria: widget.categoria,
        proyecto: proyecto,
      );

      if (!mounted) return;

      setState(() {
        _qrDataGenerado = resultado.qrData;
        _proyectoSeleccionado = proyecto;
        _qrId = resultado.qrId;
        _qrFinalizado = false;
      });

      _scaleController.forward(from: 0);
      _showSnackBar('¡Código QR generado y activo!');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error al generar QR: $e', isError: true);
    }
  }

  Future<void> _finalizarQR() async {
    if (_qrId == null || _qrFinalizado) return;

    setState(() => _finalizando = true);

    try {
      await _service.finalizarQR(eventId: widget.eventId, qrId: _qrId!);

      if (!mounted) return;

      setState(() {
        _qrFinalizado = true;
        _finalizando = false;
      });

      _showSnackBar('¡QR finalizado! Ya no se podrá escanear');

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor:
            isError ? Colors.red.shade600 : Colors.green.shade600,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Proyectos por Categoría',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            Text(
              widget.categoria,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        toolbarHeight: 60,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(_primaryColor),
                ),
              )
            : _qrDataGenerado != null
                ? _buildQRView()
                : _buildProyectosList(),
      ),
    );
  }

  Widget _buildProyectosList() {
    if (_proyectos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_off_rounded,
                size: 72,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No hay proyectos en esta categoría',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Selecciona un proyecto para generar su código QR',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _proyectos.length,
              itemBuilder: (context, index) {
                final proyecto = _proyectos[index];
                final delay = (index * 50).clamp(0, 500);
                return TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 300 + delay),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Opacity(opacity: value, child: child),
                    );
                  },
                  child: _buildProyectoCard(proyecto),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProyectoCard(Map<String, dynamic> proyecto) {
    final String codigo = proyecto['Código'] ?? 'Sin código';
    final String titulo = proyecto['Título'] ?? 'Sin título';
    final String? integrantes = proyecto['Integrantes']?.toString();
    final String? sala = proyecto['Sala']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryColor,
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
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.qr_code_rounded,
                      color: _primaryColor.withValues(alpha: 0.5),
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (integrantes != null && integrantes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.people_rounded,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          integrantes,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (sala != null && sala.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.room_rounded,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Sala: $sala',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
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
                        Icon(
                          Icons.touch_app_rounded,
                          size: 16,
                          color: Colors.green.shade700,
                        ),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQRView() {
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = (screenWidth - 96).clamp(180.0, 260.0);

    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(
          parent: _scaleController,
          curve: Curves.easeOutBack,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _qrFinalizado
                          ? Colors.red.shade600
                          : _primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _qrFinalizado
                              ? Icons.block
                              : Icons.check_circle,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _qrFinalizado
                                ? 'QR FINALIZADO'
                                : (_proyectoSeleccionado!['Código'] ??
                                    'Sin código'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            textAlign: TextAlign.center,
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _qrFinalizado
                                ? Colors.red.shade300
                                : _borderColor,
                            width: 2,
                          ),
                        ),
                        child: Opacity(
                          opacity: _qrFinalizado ? 0.3 : 1.0,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.block,
                                color: Colors.white,
                                size: 44,
                              ),
                              SizedBox(height: 8),
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
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Evento:', widget.eventName),
                        _buildInfoRow('Categoría:', widget.categoria),
                        _buildInfoRow(
                          'Código:',
                          _proyectoSeleccionado!['Código'] ?? 'N/A',
                        ),
                        _buildInfoRow(
                          'Título:',
                          _proyectoSeleccionado!['Título'] ?? 'N/A',
                        ),
                        if (_proyectoSeleccionado!['Sala'] != null)
                          _buildInfoRow(
                            'Sala:',
                            _proyectoSeleccionado!['Sala'].toString(),
                          ),
                        _buildInfoRow('ID QR:', _qrId ?? 'N/A'),
                        _buildInfoRow(
                          'Estado:',
                          _qrFinalizado ? '🔴 Inactivo' : '🟢 Activo',
                        ),
                        _buildInfoRow(
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
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _qrFinalizado ? null : _limpiarQR,
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Volver',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              side: BorderSide(
                                color: _qrFinalizado
                                    ? Colors.grey.shade300
                                    : _primaryColor,
                                width: 1.5,
                              ),
                              foregroundColor: _qrFinalizado
                                  ? Colors.grey.shade400
                                  : _primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _qrFinalizado || _finalizando
                                ? null
                                : _finalizarQR,
                            icon: _finalizando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _qrFinalizado
                                        ? Icons.check_circle
                                        : Icons.lock_outline,
                                    size: 18,
                                  ),
                            label: Text(
                              _finalizando
                                  ? 'Finalizando...'
                                  : (_qrFinalizado
                                      ? 'Finalizado'
                                      : 'Finalizar'),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: _primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}