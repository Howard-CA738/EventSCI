import 'dart:async';
import 'package:flutter/material.dart';
import '/roles/admin/pantallas/gestion_jurados_super_admin_screen.dart';
import '/roles/admin/pantallas/crear_eventos_screen.dart';
import '/roles/admin_carrera/pantallas/gestion_admins_carrera_screen.dart';
import '/login.dart';
import '/prefs_helper.dart';
import '/super_admin_login.dart';
import '/roles/admin/pantallas/asignar_proyectos_screen.dart';
import '/roles/admin/pantallas/configurar_firmas_screen.dart';
import '/roles/admin/pantallas/control_asistencias_screen.dart';
import '/roles/admin/pantallas/control_evaluaciones_screen.dart';
import '/roles/admin/pantallas/control_pagos_screen.dart';
import '/roles/admin/pantallas/crear_filiales_screen.dart';
import '/roles/admin/pantallas/editar_admin_screen.dart';
import '/roles/admin/pantallas/gestion_grupos_screen.dart';
import '/roles/admin/pantallas/gestion_rubricas_screen.dart';
import '/roles/admin/pantallas/periodos_screen.dart';
import '/roles/admin/pantallas/registro_estudiantes_screen.dart';
import '/roles/admin/pantallas/gestion_sesiones_super_admin_screen.dart';
import '/roles/admin/pantallas/reporte_usuarios_screen.dart';
import '/roles/admin/pantallas/control_bloqueo_escaner_screen.dart';
import '/roles/admin/pantallas/importar_notas_docente_screen.dart';
import '/roles/admin/pantallas/importar_codigos_certificado_screen.dart';
import '/roles/admin/pantallas/evaluacion_final_super_admin_screen.dart';


class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {

  static const Color _primaryColor = Color(0xFF1E3A5F);
  static const Color _panelColor = Color(0xFFE8EDF2);
  static const Color _cardIconBg = Color(0xFFF5F5F5);
  static const Color _subtitleColor = Color(0xFF64748B);

  static const double _smallScreenWidth = 360;
  static const double _largeScreenWidth = 768;

  String _adminName = 'Administrador';



  final List<_AdminMenuItem> _menuItems = <_AdminMenuItem>[
    _AdminMenuItem(
      imagePath: 'assets/icons/usuario.png',
      title: 'Registrar\nEstudiantes',
      subtitle: 'Crear cuentas de estudiantes',
      builder: () => const RegistroEstudiantesScreen(),
    ),
    _AdminMenuItem(
      imagePath: 'assets/icons/pagos.png',
      title: 'Control de\nPagos',
      subtitle: 'Ver pagos por evento',
      builder: () => const ControlPagosScreen(),
    ),
    _AdminMenuItem(
      imagePath: 'assets/icons/evento.png',
      title: 'Gestión de\nEventos',
      subtitle: 'Crear y administrar eventos',
      builder: () => const CrearEventosScreen(),
    ),
    _AdminMenuItem(
      imagePath: 'assets/icons/admin_carrera.png',
      title: 'Admins de\nCarrera',
      subtitle: 'Gestionar administradores',
      builder: () => const GestionAdminsCarreraScreen(),
    ),
    _AdminMenuItem(
      imagePath: 'assets/icons/reunion.png',
      title: 'Gestión de\nGrupos',
      subtitle: 'Organizar estudiantes en grupos',
      builder: () => const GestionGruposScreen(),
    ),
    _AdminMenuItem(
      imagePath: 'assets/icons/criterios.png',
      title: 'Gestión de\nRúbricas',
      subtitle: 'Crear y editar rúbricas',
      builder: () => const GestionCriteriosScreen(),
    ),
    _AdminMenuItem(
      imagePath: 'assets/icons/usuario.png',
      title: 'Reporte de\nUsuarios',
      subtitle: 'Usuarios por carrera y exportar Excel',
      builder: () => const ReporteUsuariosScreen(),
    ),
    _AdminMenuItem(
      imagePath: 'assets/icons/notas.png',
      title: 'Asignar\nProyectos',
      subtitle: 'Asignar proyectos a jurados',
      builder: () => const AsignarProyectosScreen(),
    ),
    _AdminMenuItem(
      imagePath: 'assets/icons/periodos.png',
      title: 'Gestión de\nPeríodos',
      subtitle: 'Administrar períodos académicos',
      builder: () => const PeriodosScreen(),
    ),
    _AdminMenuItem(
      imagePath: 'assets/icons/filiales.png',
      title: 'Gestión de\nFiliales',
      subtitle: 'Administrar filiales y carreras',
      builder: () => const CrearFilialesScreen(),
    ),
    _AdminMenuItem(
      imagePath: 'assets/icons/notas.png',
      title: 'Importar Notas\nDocente',
      subtitle: 'Subir notas de docente por evento',
      builder: () => const ImportarNotasDocenteScreen(),
    ),
    _AdminMenuItem(
      imagePath: 'assets/icons/firma.png',
      title: 'Configurar\nFirmas',
      subtitle: 'Gestionar firmantes del certificado',
      builder: () => const ConfigurarFirmasScreen(),
    ),
    _AdminMenuItem(
      imagePath: 'assets/icons/asistencias.png',
      title: 'Control de\nAsistencias',
      subtitle: 'Ver y gestionar asistencias',
      builder: () => const ControlAsistenciasScreen(),
    ),
    _AdminMenuItem(
      imagePath: 'assets/icons/evaluaciones.png',
      title: 'Control de\nEvaluaciones',
      subtitle: 'Ver y resetear evaluaciones',
      builder: () => const ControlEvaluacionesScreen(),
    ),
     _AdminMenuItem(
      imagePath: 'assets/icons/asistencias.png',
      title: 'Control de\nSesiones',
      subtitle: 'Gestionar sesiones por filial y carrera',
      builder: () => const GestionSesionesSuperAdminScreen(),
    ),
    _AdminMenuItem(
      imagePath: 'assets/icons/admin_carrera.png',
      title: 'Gestión de\nJurados',
      subtitle: 'Jurados por filial, facultad y carrera',
      builder: () => const GestionJuradosSuperAdminScreen(),
    ),
    _AdminMenuItem(
  imagePath: 'assets/icons/asistencias.png',
  title: 'Bloqueo de\nEscáner',
  subtitle: 'Controlar tiempo de espera del escáner',
  builder: () => const ControlBloqueoEscanerScreen(),
),
_AdminMenuItem(
  imagePath: 'assets/icons/notas.png',
  title: 'Evaluación\nFinal',
  subtitle: 'Reporte por filial, facultad y carrera',
  builder: () => const EvaluacionFinalSuperAdminScreen(),
),
_AdminMenuItem(
  imagePath: 'assets/icons/notas.png',
  title: 'Importar Códigos\nde Certificado',
  subtitle: 'Asignar códigos en bloque desde Excel',
  builder: () => const ImportarCodigosCertificadoScreen(),
),
    _AdminMenuItem(
      imagePath: 'assets/icons/admin.png',
      title: 'Editar\nCuenta',
      subtitle: 'Modificar datos de administrador',
      builder: () => const EditarAdminScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();


    unawaited(_loadAdminData());
  }

  Future<void> _loadAdminData() async {
    final String? name = await PrefsHelper.getUserName();
    if (!mounted) {
      return;
    }
    setState(() {
      _adminName = name ?? 'Administrador';
    });
  }

  Future<void> _logout() async {
    await SuperAdminAuthService.logout();


    if (!mounted) {
      return;
    }
    unawaited(
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      ),
    );
  }

  void _openScreen(Widget Function() builder) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => builder()),
      ),
    );
  }

  static int _crossAxisCount(double screenWidth) {
    if (screenWidth >= _largeScreenWidth) {
      return 3;
    }
    return 2;
  }

  static double _childAspectRatio(double screenWidth) {
    if (screenWidth < _smallScreenWidth) {
      return 0.88;
    }
    if (screenWidth >= _largeScreenWidth) {
      return 0.90;
    }
    return 0.82;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildHeader(),
            Expanded(child: _buildMenuPanel()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double horizontalPadding =
        screenWidth < _smallScreenWidth ? 14.0 : 20.0;
    final double titleSize = screenWidth < _smallScreenWidth ? 18.0 : 20.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 16.0,
      ),
      child: Row(
        children: <Widget>[
          _buildLogo(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Panel de Administrador',
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  _adminName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white, size: 26),
            onPressed: _logout,
            tooltip: 'Cerrar Sesión',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Image.asset(
        'assets/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.school,
          color: _primaryColor,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildMenuPanel() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double padding = screenWidth < _smallScreenWidth ? 14.0 : 20.0;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _panelColor,
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
          padding: EdgeInsets.all(padding),


          child: GridView.builder(
            itemCount: _menuItems.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _crossAxisCount(screenWidth),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: _childAspectRatio(screenWidth),
            ),
            itemBuilder: (BuildContext context, int index) {
              return _buildMenuCard(_menuItems[index]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(_AdminMenuItem item) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmall = screenWidth < _smallScreenWidth;
    final double iconSize = isSmall ? 54.0 : 62.0;
    final double iconPadding = isSmall ? 10.0 : 12.0;
    final double titleSize = isSmall ? 11.5 : 12.5;
    final double subtitleSize = isSmall ? 9.5 : 10.0;

    return Card(
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: InkWell(
        onTap: () => _openScreen(item.builder),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: iconSize,
                height: iconSize,
                decoration: const BoxDecoration(
                  color: _cardIconBg,
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(iconPadding),
                child: Image.asset(
                  item.imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.image_not_supported,
                    size: 28,
                    color: Colors.grey[400],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w600,
                  color: _primaryColor,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                style: TextStyle(
                  fontSize: subtitleSize,
                  color: _subtitleColor,
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


class _AdminMenuItem {
  const _AdminMenuItem({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  final String imagePath;
  final String title;
  final String subtitle;
  final Widget Function() builder;
}