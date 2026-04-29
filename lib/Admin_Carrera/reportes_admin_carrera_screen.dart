import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import 'ver_ganadores.dart';
import 'ventanas_asistencia.dart';
import 'evaluaciones_carrera.dart'; // ← nueva pantalla de evaluaciones
import 'informe_evento_carrera.dart';

class ReportesAdminCarreraScreen extends StatefulWidget {
  const ReportesAdminCarreraScreen({super.key});

  @override
  State<ReportesAdminCarreraScreen> createState() =>
      _ReportesAdminCarreraScreenState();
}

class _ReportesAdminCarreraScreenState
    extends State<ReportesAdminCarreraScreen>
    with SingleTickerProviderStateMixin {
  String _carrera = '';
  String _facultad = '';
  String _sede = '';
  String _filialId = '';

  bool _isLoading = true;

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
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _inicializar();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData != null && mounted) {
        setState(() {
          _carrera = adminData['carrera'] ?? '';
          _facultad = adminData['facultad'] ?? '';
          _sede = adminData['filialNombre'] ?? '';
          _filialId = adminData['filial'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos del admin: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _animationController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E3A5F),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      appBar: AppBar(
        title: const Text(
          'Reportes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Tarjeta de contexto ────────────────────────
                        _buildAnimatedCard(
                          delay: 100,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A5F),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1E3A5F)
                                      .withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.bar_chart_rounded,
                                    size: 30,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Reportes de Carrera',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      _buildInfoChip(
                                          Icons.location_city, _sede),
                                      const SizedBox(height: 4),
                                      _buildInfoChip(
                                          Icons.business, _facultad),
                                      const SizedBox(height: 4),
                                      _buildInfoChip(
                                          Icons.school, _carrera),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Opciones de reportes ───────────────────────
                        Expanded(
                          child: ListView(
                            children: [
                              // Asistencias
                              _buildAnimatedCard(
                                delay: 200,
                                child: _buildReportOption(
                                  title: 'Asistencias',
                                  subtitle:
                                      'Registro de asistencias de tu carrera',
                                  icon: Icons.people,
                                  color: const Color(0xFF4A90E2),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => VentanasAsistenciaScreen(
                                        filialId: _filialId,
                                        filialNombre: _sede,
                                        facultad: _facultad,
                                        carrera: _carrera,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Evaluaciones
                              _buildAnimatedCard(
                                delay: 300,
                                child: _buildReportOption(
                                  title: 'Evaluaciones',
                                  subtitle:
                                      'Revisa y gestiona las evaluaciones de tu carrera',
                                  icon: Icons.assignment_turned_in,
                                  color: const Color(0xFF9C27B0),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const EvaluacionesCarreraScreen(),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),
_buildReportOption(
  title: 'Informe Final',
  subtitle: 'Genera el informe completo del evento',
  icon: Icons.description_rounded,
  color: const Color(0xFF009688),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const InformeEventoCarreraScreen()),
  ),
),
                              // Ganadores
                              _buildAnimatedCard(
                                delay: 400,
                                child: _buildReportOption(
                                  title: 'Ganadores',
                                  subtitle:
                                      'Top 3 de proyectos por categoría en cada evento',
                                  icon: Icons.emoji_events,
                                  color: const Color(0xFFF59E0B),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const VerGanadoresScreen(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Footer informativo ─────────────────────────
                        _buildAnimatedCard(
                          delay: 500,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF1E3A5F)
                                    .withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E3A5F)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.info_outline,
                                    color: Color(0xFF1E3A5F),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Los reportes se filtran automáticamente según tu carrera asignada.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF1E3A5F),
                                      fontWeight: FontWeight.w500,
                                    ),
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
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers de UI ──────────────────────────────────────────────

  Widget _buildInfoChip(IconData icon, String label) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(icon, color: Colors.white60, size: 13),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedCard({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: child,
    );
  }

  Widget _buildReportOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 30, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 15,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}