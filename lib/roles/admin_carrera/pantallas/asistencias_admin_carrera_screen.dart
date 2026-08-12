import 'package:flutter/material.dart';
import '/shared/pantallas/asistencias_estudiantes_resultados_screen.dart';
import '/shared/logica/asistencias_service.dart';
import '../logica/asistencias_carrera_excel.dart';
import '../logica/asistencias_admin_carrera_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

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
  final AsistenciasAdminCarreraService _service =
      AsistenciasAdminCarreraService();
  final AsistenciasService _asistenciasService = AsistenciasService();
  final AsistenciasCarreraExcelService _excelService =
      AsistenciasCarreraExcelService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<Map<String, dynamic>> _eventos = [];
  String? _eventoSeleccionadoId;
  Map<String, dynamic>? _eventoSeleccionadoData;

  List<Map<String, dynamic>> _estudiantesEvento = [];

  int _totalAsistencias = 0;
  bool _isLoadingEventos = true;
  bool _isLoadingResumen = false;
  bool _isGeneratingExcel = false;

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

  Future<void> _cargarEventos() async {
    setState(() => _isLoadingEventos = true);
    try {
      final filtrados = await _service.cargarEventos(
        filialId: widget.filialId,
        filialNombre: widget.filialNombre,
        facultad: widget.facultad,
        carrera: widget.carrera,
      );

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

  Future<void> _cargarResumen(String eventoId) async {
    setState(() {
      _isLoadingResumen = true;
      _estudiantesEvento = [];
    });

    try {
      final lista = await _asistenciasService.cargarResumen(eventoId);
      if (mounted) {
        setState(() {
          _totalAsistencias = lista.length;
          _estudiantesEvento = lista;
        });
      }
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
      _estudiantesEvento = [];
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

  Future<void> _exportarExcel() async {
    if (_eventoSeleccionadoId == null) return;

    if (_estudiantesEvento.isEmpty) {
      _showSnackBar('No hay asistencias para exportar', isError: true);
      return;
    }

    setState(() => _isGeneratingExcel = true);

    final eventoNombre = _eventoSeleccionadoData!['name'] as String;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final maxH = (mq.size.height
                - mq.viewInsets.bottom
                - mq.padding.top
                - mq.padding.bottom
                - 48)
            .clamp(160.0, 300.0);
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF1E3A5F)),
                  const SizedBox(height: 20),
                  const Text(
                    'Generando reporte Excel...',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_totalAsistencias estudiantes · $eventoNombre',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final rutaArchivo = await _excelService.generarReporteAsistencias(
        estudiantes: _estudiantesEvento,
        eventoNombre: eventoNombre,
        eventoId: _eventoSeleccionadoId!,
        filialId: widget.filialId,
        filialNombre: widget.filialNombre,
        facultad: widget.facultad,
        carreraId: _eventoSeleccionadoData?['carreraId']?.toString(),
        carrera: widget.carrera,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isGeneratingExcel = false);

      if (rutaArchivo == null) {
        _showSnackBar('❌ Error al generar el reporte Excel', isError: true);
        return;
      }

      _mostrarOpcionesArchivo(rutaArchivo);
    } catch (e) {
      debugPrint('Error al exportar Excel: $e');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isGeneratingExcel = false);
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  void _mostrarOpcionesArchivo(String rutaArchivo) {
    final eventoNombre =
        _eventoSeleccionadoData?['name'] as String? ?? '';
    showDialog(
      context: context,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final maxH = (mq.size.height
                - mq.viewInsets.bottom
                - mq.padding.top
                - mq.padding.bottom
                - 48)
            .clamp(200.0, 420.0);
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Color(0xFF27AE60),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Reporte generado',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '¿Qué deseas hacer con el archivo Excel?',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final result = await OpenFilex.open(rutaArchivo);
                        if (result.type != ResultType.done && mounted) {
                          _showSnackBar(
                            'No se encontró una app para abrir archivos Excel. Prueba compartirlo.',
                            isError: true,
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 20),
                      label: const Text(
                        'Abrir archivo',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await Share.shareXFiles(
                          [XFile(rutaArchivo)],
                          subject:
                              'Reporte de Asistencias – $eventoNombre',
                        );
                      },
                      icon: const Icon(Icons.share, size: 20),
                      label: const Text(
                        'Compartir',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E3A5F),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(
                            color: Color(0xFF1E3A5F), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                        CircularProgressIndicator(color: Color(0xFF1E3A5F)),
                        SizedBox(height: 14),
                        Text('Cargando eventos...',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 15)),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildContextCard(),
                        const SizedBox(height: 20),
                        _buildEventoCard(),
                        if (_eventoSeleccionadoId != null) ...[
                          const SizedBox(height: 16),
                          _buildResumenCard(),
                          const SizedBox(height: 16),
                          _buildBotonVerAsistencias(),
                          const SizedBox(height: 12),
                          _buildBotonExportarExcel(),
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

  Widget _buildContextCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
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
                  widget.carrera,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  widget.facultad,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.filialNombre,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildEventoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Selecciona un evento para ver sus asistencias o exportar el reporte Excel.',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
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
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_eventos.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1E3A5F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _cargarEventos,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF1E3A5F).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.refresh,
                      size: 18, color: Color(0xFF1E3A5F)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingEventos)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFF1E3A5F)),
                ),
              ),
            )
          else if (_eventos.isEmpty)
            _buildEmptyEventos()
          else
            ...List.generate(_eventos.length, (i) {
              final evento = _eventos[i];
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 280 + i * 50),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutCubic,
                builder: (ctx, v, child) => Transform.translate(
                  offset: Offset(0, 16 * (1 - v)),
                  child: Opacity(opacity: v, child: child),
                ),
                child: _buildEventoItem(evento),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyEventos() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF3E0),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_busy_rounded,
                size: 48, color: Color(0xFFFF9800)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay eventos disponibles',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay eventos registrados para esta carrera.',
            style: TextStyle(
                fontSize: 13, color: Colors.grey[500], height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEventoItem(Map<String, dynamic> evento) {
    final nombre = (evento['name'] as String?) ?? '';
    final inicial =
        nombre.isNotEmpty ? nombre.substring(0, 1).toUpperCase() : '?';
    final isSelected = _eventoSeleccionadoId == evento['id'];

    return GestureDetector(
      onTap: () => _onEventoChanged(evento['id'] as String),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1E3A5F).withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1E3A5F)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSelected
                      ? [
                          const Color(0xFF1E3A5F),
                          const Color(0xFF2D5F8D),
                        ]
                      : [
                          const Color(0xFF4A90E2),
                          const Color(0xFF357ABD),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1E3A5F),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            size: 12, color: Color(0xFF27AE60)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _isLoadingResumen
                                ? 'Cargando...'
                                : '$_totalAsistencias estudiantes',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF27AE60),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1E3A5F)
                    : const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSelected
                    ? Icons.check_rounded
                    : Icons.arrow_forward_ios_rounded,
                color:
                    isSelected ? Colors.white : const Color(0xFF1E3A5F),
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
              value: _isLoadingResumen ? '...' : '$_totalAsistencias',
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
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
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

  Widget _buildBotonExportarExcel() {
    final bool puedeExportar =
        !_isLoadingResumen && !_isGeneratingExcel && _totalAsistencias > 0;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: puedeExportar ? _exportarExcel : null,
        icon: _isGeneratingExcel
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : _isLoadingResumen
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  )
                : const Icon(Icons.file_download, size: 22),
        label: Text(
          _isGeneratingExcel
              ? 'Generando Excel...'
              : _isLoadingResumen
                  ? 'Cargando datos...'
                  : 'Exportar Reporte Excel',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF27AE60),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
