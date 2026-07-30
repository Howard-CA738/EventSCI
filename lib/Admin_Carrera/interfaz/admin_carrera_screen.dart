import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import '/login.dart';
import '/admin_carrera/registro_estudiantes_carrera.dart';
import '/admin_carrera/editar_admin_carrera.dart';
import '/admin_carrera/crear_eventos_carrera_screen.dart';
import '/admin_carrera/gestion_grupos_carrera_screen.dart';
import '/admin_carrera/asignar_proyectos_carrera_screen.dart';
import '/admin_carrera/gestion_rubricas_carrera_screen.dart';
import '/admin_carrera/gestion_jurados_carrera_screen.dart';
import '/admin_carrera/generar_certificados_screen.dart';
import '/admin_carrera/gestion_sesiones_screen.dart';
import '/admin_carrera/reportes_admin_carrera_screen.dart';
import '/admin_carrera/gestion_roles_screen.dart';


class AdminCarreraScreen extends StatefulWidget {
  const AdminCarreraScreen({super.key});

  @override
  State<AdminCarreraScreen> createState() => _AdminCarreraScreenState();
}

class _AdminCarreraScreenState extends State<AdminCarreraScreen> {
  String _carrera = '';
  String _facultad = '';
  String _sede = '';
  List<String> _permisos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData != null) {
        setState(() {
          _carrera = adminData['carrera'] ?? '';
          _facultad = adminData['facultad'] ?? '';
          _sede = adminData['filialNombre'] ?? '';
          _permisos = List<String>.from(adminData['permisos'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos del admin: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    await PrefsHelper.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  bool _tienePermiso(String permiso) => _permisos.contains(permiso);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E3A5F),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.asset(
                          'assets/icons/panel_admin.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.admin_panel_settings,
                            color: Color(0xFF1E3A5F),
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Panel de Administrador',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout,
                            color: Colors.white, size: 28),
                        onPressed: _logout,
                        tooltip: 'Cerrar Sesión',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tarjeta de información de carrera
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.business,
                                color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_facultad,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.school,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _carrera,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Text(_sede,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Content Area ──────────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gestión de Carrera',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      const SizedBox(height: 16),

                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.80,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [

                          // 1. Registrar Estudiantes
                          if (_tienePermiso('estudiantes'))
                            _buildMenuCard(
                              imagePath: 'assets/icons/usuario.png',
                              title: 'Registrar\nEstudiantes',
                              subtitle: 'Crear cuentas de estudiantes',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegistroEstudiantesCarreraScreen(),
                                ),
                              ),
                            ),

                          // 2. Gestión de Sesiones
                          _buildMenuCard(
                            imagePath: 'assets/icons/sesiones.png',
                            title: 'Gestión de\nSesiones',
                            subtitle: 'Controlar sesiones de estudiantes',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const GestionSesionesScreen(),
                              ),
                            ),
                          ),

                          // 3. Gestión de Eventos
                          if (_tienePermiso('eventos'))
                            _buildMenuCard(
                              imagePath: 'assets/icons/evento.png',
                              title: 'Gestión de\nEventos',
                              subtitle: 'Crear y ver eventos',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CrearEventosCarreraScreen(),
                                ),
                              ),
                            ),

                          // 4. Gestión de Grupos
                          if (_tienePermiso('grupos'))
                            _buildMenuCard(
                              imagePath: 'assets/icons/reunion.png',
                              title: 'Gestión de\nGrupos',
                              subtitle: 'Organizar estudiantes en grupos',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const GestionGruposCarreraScreen(),
                                ),
                              ),
                            ),

                          // 5. Gestión de Jurados
                          if (_tienePermiso('proyectos'))
                            _buildMenuCard(
                              imagePath: 'assets/icons/jurado.png',
                              title: 'Gestión de\nJurados',
                              subtitle: 'Ver y gestionar jurados',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const GestionJuradosCarreraScreen(),
                                ),
                              ),
                            ),

                          // 6. Asignar Proyectos
                          if (_tienePermiso('proyectos'))
                            _buildMenuCard(
                              imagePath: 'assets/icons/notas.png',
                              title: 'Asignar\nProyectos',
                              subtitle: 'Asignar proyectos a jurados',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AsignarProyectosCarreraScreen(),
                                ),
                              ),
                            ),

                          // 7. Gestión de Rúbricas
                          if (_tienePermiso('proyectos'))
                            _buildMenuCard(
                              imagePath: 'assets/icons/criterios.png',
                              title: 'Gestión de\nRúbricas',
                              subtitle: 'Crear y editar rúbricas',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const GestionRubricasCarreraScreen(),
                                ),
                              ),
                            ),

                          // 8. Gestión de Roles
                          _buildMenuCard(
                            imagePath: 'assets/icons/roles.png',
                            title: 'Gestión de\nRoles',
                            subtitle: 'Asignar roles a estudiantes',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const GestionRolesScreen(),
                              ),
                            ),
                          ),

                          // 9. Generar Certificados
                          _buildMenuCard(
                            imagePath: 'assets/icons/certificado.png',
                            title: 'Certificados por Roles',
                            subtitle: 'Ver y descargar certificados',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const GenerarCertificadosScreen(),
                              ),
                            ),
                          ),

                          // 10. Reportes
                          if (_tienePermiso('reportes'))
                            _buildMenuCard(
                              imagePath: 'assets/icons/reporte.png',
                              title: 'Reportes',
                              subtitle: 'Ver Reportes generales',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ReportesAdminCarreraScreen(),
                                ),
                              ),
                            ),

                          // 11. Editar Cuenta
                          _buildMenuCard(
                            imagePath: 'assets/icons/admin.png',
                            title: 'Editar\nCuenta',
                            subtitle: 'Modificar datos personales',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EditarAdminCarreraScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required String imagePath,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 65,
                height: 65,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(13),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.image_not_supported,
                    size: 32,
                    color: Colors.grey[400],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A5F),
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}