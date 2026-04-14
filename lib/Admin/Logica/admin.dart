import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import '/login.dart';
import 'registro_estudiantes.dart';
import '/admin/interfaz/crear_eventos_screen.dart';
import 'gestion_grupos.dart';

import 'reportes.dart';
import 'asignar_proyectos.dart';
import 'periodos.dart';
import 'gestion_rubricas.dart';
import 'evaluaciones.dart';
import 'editar_admin.dart';
import 'crear_filiales.dart';
import '/admin_carrera/gestion_admins_carrera.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _adminName = '';

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    final name = await PrefsHelper.getUserName();
    setState(() {
      _adminName = name ?? 'Administrador';
    });
  }

  Future<void> _logout() async {
    await PrefsHelper.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
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
                  const Expanded(
                    child: Text(
                      'Panel de Administrador',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.80,
                    children: [
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
                      _buildMenuCard(
                        imagePath: 'assets/icons/evento.png',
                        title: 'Gestión de\nEventos',
                        subtitle: 'Crear y administrar eventos',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const CrearEventosScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMenuCard(
                        imagePath:
                            'assets/icons/admin_carrera.png', // Puedes usar otro icono si no tienes este
                        title: 'Admins de\nCarrera',
                        subtitle: 'Gestionar administradores',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const GestionAdminsCarreraScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMenuCard(
                        imagePath: 'assets/icons/reunion.png',
                        title: 'Gestión de\nGrupos',
                        subtitle: 'Organizar estudiantes en grupos',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const GestionGruposScreen(),
                            ),
                          );
                        },
                      ),

                      _buildMenuCard(
                        imagePath: 'assets/icons/criterios.png',
                        title: 'Gestión de\nRúbricas',
                        subtitle: 'Crear y editar rúbricas',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const GestionCriteriosScreen(),
                            ),
                          );
                        },
                      ),
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
                      _buildMenuCard(
                        imagePath: 'assets/icons/evaluaciones.png',
                        title: 'Ver\nEvaluaciones',
                        subtitle: 'Revisar evaluaciones de jurados',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const EvaluacionesScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMenuCard(
                        imagePath: 'assets/icons/periodos.png',
                        title: 'Gestión de\nPeríodos',
                        subtitle: 'Administrar períodos académicos',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const PeriodosScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMenuCard(
                        imagePath: 'assets/icons/reporte.png',
                        title: 'Reportes',
                        subtitle: 'Ver estadísticas y reportes',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ReportesScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMenuCard(
                        imagePath: 'assets/icons/filiales.png',
                        title: 'Gestión de\nFiliales',
                        subtitle: 'Administrar filiales y carreras',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const CrearFilialesScreen(),
                            ),
                          );
                        },
                      ),

                      _buildMenuCard(
                        imagePath: 'assets/icons/admin.png',
                        title: 'Editar\nCuenta',
                        subtitle: 'Modificar datos de administrador',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const EditarAdminScreen(),
                            ),
                          );
                        },
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
              // Contenedor circular para la imagen
              Container(
                width: 65,
                height: 65,
                decoration: const BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(13),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback a un icono de Material si la imagen no existe
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
