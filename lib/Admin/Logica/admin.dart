import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import '/login.dart';
import 'registro_estudiantes.dart';
import '/admin/interfaz/crear_eventos_screen.dart';
import 'gestion_grupos.dart';
import 'control_pagos.dart';
import 'configurar_firmas.dart';
import 'asignar_proyectos.dart';
import 'periodos.dart';
import 'gestion_rubricas.dart';
import 'editar_admin.dart';
import 'crear_filiales.dart';
import '/super_admin_login.dart';
import '/admin_carrera/gestion_admins_carrera.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _adminName = 'Administrador';

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    final name = await PrefsHelper.getUserName();
    if (mounted) {
      setState(() {
        _adminName = name ?? 'Administrador';
      });
    }
  }

  Future<void> _logout() async {
    await SuperAdminAuthService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  int _crossAxisCount(double screenWidth) {
    if (screenWidth >= 768) return 3;
    return 2;
  }

  double _childAspectRatio(double screenWidth) {
    if (screenWidth < 360) return 0.88;
    if (screenWidth >= 768) return 0.90;
    return 0.82;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 14.0 : 20.0;

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16.0,
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
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
                          size: 28,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Panel de Administrador',
                      style: TextStyle(
                        fontSize: screenWidth < 360 ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: _logout,
                    tooltip: 'Cerrar Sesión',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: GridView.count(
                      crossAxisCount: _crossAxisCount(screenWidth),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: _childAspectRatio(screenWidth),
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
                          imagePath: 'assets/icons/pagos.png',
                          title: 'Control de\nPagos',
                          subtitle: 'Ver pagos por evento',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ControlPagosScreen(),
                            ),
                          ),
                        ),
                        _buildMenuCard(
                          imagePath: 'assets/icons/evento.png',
                          title: 'Gestión de\nEventos',
                          subtitle: 'Crear y administrar eventos',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CrearEventosScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuCard(
                          imagePath: 'assets/icons/admin_carrera.png',
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
                                builder: (context) =>
                                    const GestionGruposScreen(),
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
                          imagePath: 'assets/icons/filiales.png',
                          title: 'Gestión de\nFiliales',
                          subtitle: 'Administrar filiales y carreras',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CrearFilialesScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuCard(
                          imagePath: 'assets/icons/firma.png',
                          title: 'Configurar\nFirmas',
                          subtitle: 'Gestionar firmantes del certificado',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ConfigurarFirmasScreen(),
                            ),
                          ),
                        ),
                        _buildMenuCard(
                          imagePath: 'assets/icons/admin.png',
                          title: 'Editar\nCuenta',
                          subtitle: 'Modificar datos de administrador',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const EditarAdminScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth < 360 ? 54.0 : 62.0;
    final iconPadding = screenWidth < 360 ? 10.0 : 12.0;

    return Card(
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(iconPadding),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.image_not_supported,
                      size: 28,
                      color: Colors.grey[400],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: screenWidth < 360 ? 11.5 : 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E3A5F),
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: screenWidth < 360 ? 9.5 : 10,
                  color: const Color(0xFF64748B),
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}