import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import '/login.dart';
import '/admin/logica/registro_estudiantes.dart';
import '/admin/logica/gestion_grupos.dart';
import '/admin/logica/reportes.dart';
import '/admin/logica/asignar_proyectos.dart';
import '/admin/logica/evaluaciones.dart';
import 'editar_admin_carrera.dart';

class AdminCarreraScreen extends StatefulWidget {
  const AdminCarreraScreen({super.key});

  @override
  State<AdminCarreraScreen> createState() => _AdminCarreraScreenState();
}

class _AdminCarreraScreenState extends State<AdminCarreraScreen> {
  String _adminName = '';
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
          _adminName = adminData['userName'] ?? 'Administrador';
          _carrera = adminData['carrera'] ?? '';
          _facultad = adminData['facultad'] ?? '';
          _sede = adminData['filialNombre'] ?? '';
          _permisos = List<String>.from(adminData['permisos'] ?? []);
        });
      }
    } catch (e) {
      print('Error cargando datos del admin: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    await PrefsHelper.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  bool _tienePermiso(String permiso) {
    return _permisos.contains(permiso);
  }

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
            // Header
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.school,
                              color: Color(0xFF1E3A5F),
                              size: 30,
                            );
                          },
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
                            Text(
                              _adminName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: _logout,
                        tooltip: 'Cerrar Sesión',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Información de la carrera
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.business,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _facultad,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.school,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _carrera,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _sede,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
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
            // Content Area
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
                          // Registrar Estudiantes
                          if (_tienePermiso('estudiantes'))
                            _buildMenuCard(
                              imagePath: 'assets/icons/usuario.png',
                              title: 'Registrar\nEstudiantes',
                              subtitle: 'Crear cuentas de estudiantes',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RegistroEstudiantesScreen(),
                                  ),
                                );
                              },
                            ),

                          // Gestión de Grupos
                          if (_tienePermiso('grupos'))
                            _buildMenuCard(
                              imagePath: 'assets/icons/reunion.png',
                              title: 'Gestión de\nGrupos',
                              subtitle: 'Organizar estudiantes en grupos',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const GestionGruposScreen(),
                                  ),
                                );
                              },
                            ),

                          // Asignar Proyectos
                          if (_tienePermiso('proyectos'))
                            _buildMenuCard(
                              imagePath: 'assets/icons/notas.png',
                              title: 'Asignar\nProyectos',
                              subtitle: 'Asignar proyectos a jurados',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AsignarProyectosScreen(),
                                  ),
                                );
                              },
                            ),

                          // Ver Evaluaciones
                          if (_tienePermiso('evaluaciones'))
                            _buildMenuCard(
                              imagePath: 'assets/icons/evaluaciones.png',
                              title: 'Ver\nEvaluaciones',
                              subtitle: 'Revisar evaluaciones de jurados',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const EvaluacionesScreen(),
                                  ),
                                );
                              },
                            ),

                          // Reportes
                          if (_tienePermiso('reportes'))
                            _buildMenuCard(
                              imagePath: 'assets/icons/reporte.png',
                              title: 'Reportes',
                              subtitle: 'Ver estadísticas y reportes',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ReportesScreen(),
                                  ),
                                );
                              },
                            ),

                          // Editar Cuenta
                          _buildMenuCard(
                            imagePath: 'assets/icons/admin.png',
                            title: 'Editar\nCuenta',
                            subtitle: 'Modificar datos personales',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const EditarAdminCarreraScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Nota informativa
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue[700],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Solo puedes gestionar estudiantes y grupos de $_carrera',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
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
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.image_not_supported,
                      size: 32,
                      color: Colors.grey[400],
                    );
                  },
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
