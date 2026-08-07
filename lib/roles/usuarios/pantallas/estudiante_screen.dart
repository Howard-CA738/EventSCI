import 'package:flutter/material.dart';
import 'dart:async';
import '/prefs_helper.dart';
import '/login.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../logica/estudiante_service.dart';
import 'perfil_screen.dart';
import 'escanear_qr_screen.dart';
import 'asistencias_screen.dart';
import 'ver_certificados_screen.dart';
import 'asistente_qr_screen.dart';
import 'ver_proyectos_screen.dart';

class EstudianteScreen extends StatefulWidget {
  const EstudianteScreen({super.key});

  @override
  State<EstudianteScreen> createState() => _EstudianteScreenState();
}

class _EstudianteScreenState extends State<EstudianteScreen> {
  final EstudianteService _service = EstudianteService();

  String _studentName = '';
  String? _studentFilial;
  String? _studentCarrera;
  String? _studentFacultad;
  Stream<DocumentSnapshot>? _studentStream;
  int _segundos = 3;
  bool _infoExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    final perfil = await _service.cargarPerfil();
    if (!mounted) return;
    setState(() {
      _studentName = perfil.name;
      _studentFilial = perfil.filial;
      _studentFacultad = perfil.facultad;
      _studentCarrera = perfil.carrera;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarYMostrarAdvertencia();
    });
  }

  Future<void> _verificarYMostrarAdvertencia() async {
    final mostrar = await PrefsHelper.debemostrarAdvertenciaPrimeraVez();
    if (mostrar && mounted) {
      _showAdvertenciaSesionUnica();
    }
  }

  void _showAdvertenciaSesionUnica() {
    _segundos = 3;
    Timer? timer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (_segundos <= 0) {
                t.cancel();
                return;
              }
              setStateDialog(() => _segundos--);
            });

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E3A5F),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            size: 34,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Aviso de Sesión',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.lock_outline_rounded,
                                        color: Colors.red.shade700, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Sesión única',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Solo puedes ingresar una vez. Si cierras sesión, contacta a tu administrador.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red.shade700,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Colors.blue.shade100),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.tips_and_updates_outlined,
                                      color: Colors.blue.shade600, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Mantén la app abierta y no presiones "Cerrar Sesión".',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade800,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _segundos <= 0
                                    ? () {
                                        timer?.cancel();
                                        Navigator.of(context).pop();
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A5F),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      Colors.grey.shade300,
                                  disabledForegroundColor:
                                      Colors.grey.shade600,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  minimumSize:
                                      const Size(double.infinity, 50),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                ),
                                child: Text(
                                  _segundos > 0
                                      ? 'Entendido ($_segundos)'
                                      : 'Entendido',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600),
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
            );
          },
        );
      },
    ).then((_) => timer?.cancel());
  }

  Future<void> _showLogoutConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.logout, color: Color(0xFF1E3A5F), size: 28),
              SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Cerrar Sesión',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Estás seguro de que deseas cerrar sesión?',
                style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              _buildLogoutWarning(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
              ),
              child: const Text(
                'Cancelar',
                style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Cerrar Sesión',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) await _logout();
  }

  Widget _buildLogoutWarning() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.red.shade500, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Recuerda: si cierras sesión no podrás '
              'volver a ingresar sin asistencia del administrador.',
              style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await PrefsHelper.cerrarSesionEstudiante();
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
        child: _buildStreamBody(),
      ),
    );
  }

  Widget _buildStreamBody() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _buildStudentStream(),
      builder: (context, snapshot) {
        bool esAsisteQR = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          esAsisteQR = data?['esAsisteQR'] == true;
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    _buildHeaderRow(),
                    const SizedBox(height: 14),
                    _buildWelcomeCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double cardSpacing = 16;
                      final double totalHorizontalSpacing =
                          cardSpacing * (2 - 1);
                      final double cardWidth =
                          (constraints.maxWidth - totalHorizontalSpacing) /
                              2;
                      final double cardHeight = cardWidth * (1 / 0.80);

                      final List<Widget> menuItems = [
                        _buildMenuCard(
                          imagePath: 'assets/icons/perfil.png',
                          title: 'Mi Perfil',
                          subtitle: 'Ver información personal',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) =>
                                    const PerfilScreen()),
                          ),
                        ),
                        _buildMenuCard(
                          imagePath: 'assets/icons/escaner.png',
                          title: 'Escanear QR',
                          subtitle: 'Registrar asistencia',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) =>
                                    const EscanearQRScreen()),
                          ),
                        ),
                        _buildMenuCard(
                          imagePath: 'assets/icons/mis-asistencias.png',
                          title: 'Mis Asistencias',
                          subtitle: 'Ver historial de asistencias',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) =>
                                    AsistenciasScreen()),
                          ),
                        ),

_buildMenuCard(
  imagePath: 'assets/icons/lugar_evento.png',
  title: 'Proyectos',
  subtitle: 'Ver lugares de ponencia',
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const VerProyectosScreen()),
  ),
),
                        _buildMenuCard(
                          imagePath: 'assets/icons/certificado.png',
                          title: 'Mis Certificados',
                          subtitle: 'Ver y descargar certificados',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const VerCertificadosScreen()),
                          ),
                        ),
                        if (esAsisteQR)
                          _buildMenuCardDestacada(
                            imagePath: 'assets/icons/crear_qr.png',
                            title: 'Generar QR\nAsistencia',
                            subtitle: 'Crear QR para eventos',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AsistenteQRScreen()),
                            ),
                          ),
                      ];

                      return Wrap(
                        spacing: cardSpacing,
                        runSpacing: cardSpacing,
                        children: menuItems
                            .map(
                              (item) => SizedBox(
                                width: cardWidth,
                                height: cardHeight,
                                child: item,
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Container(color: const Color(0xFFE8EDF2)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        const Spacer(),
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            icon: const Icon(Icons.logout, color: Colors.white, size: 24),
            onPressed: _showLogoutConfirmation,
            tooltip: 'Cerrar Sesión',
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    final hasInfo = _studentFilial != null ||
        _studentFacultad != null ||
        _studentCarrera != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.18), width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      _studentName.isNotEmpty
                          ? _studentName[0].toUpperCase()
                          : 'E',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bienvenido',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _studentName.isNotEmpty
                            ? _studentName
                            : 'Estudiante',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (hasInfo && !_infoExpanded) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (_studentFilial != null) _studentFilial!,
                            if (_studentCarrera != null) _studentCarrera!,
                          ].join(' · '),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10.5,
                            height: 1.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasInfo)
                  GestureDetector(
                    onTap: () =>
                        setState(() => _infoExpanded = !_infoExpanded),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: AnimatedRotation(
                            turns: _infoExpanded ? 0 : 0.5,
                            duration: const Duration(milliseconds: 250),
                            child: const Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (hasInfo)
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: _infoExpanded
                  ? Column(
                      children: [
                        Divider(
                          color: Colors.white.withValues(alpha: 0.15),
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          child: _buildInfoRows(),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRows() {
    return Column(
      children: [
        if (_studentFilial != null)
          _buildInfoRow(
            icon: Icons.location_city_rounded,
            label: 'Filial',
            value: _studentFilial!,
            color: const Color(0xFF60A5FA),
          ),
        if (_studentFilial != null &&
            (_studentFacultad != null || _studentCarrera != null))
          const SizedBox(height: 8),
        if (_studentFacultad != null)
          _buildInfoRow(
            icon: Icons.account_balance_rounded,
            label: 'Facultad',
            value: _studentFacultad!,
            color: const Color(0xFFA78BFA),
          ),
        if (_studentFacultad != null && _studentCarrera != null)
          const SizedBox(height: 8),
        if (_studentCarrera != null)
          _buildInfoRow(
            icon: Icons.menu_book_rounded,
            label: 'Carrera',
            value: _studentCarrera!,
            color: const Color(0xFF34D399),
          ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Stream<DocumentSnapshot> _buildStudentStream() {
    _studentStream ??= _service.buildStudentStream();
    return _studentStream!;
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
                    return Icon(Icons.image_not_supported,
                        size: 32, color: Colors.grey[400]);
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
                overflow: TextOverflow.ellipsis,
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
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCardDestacada({
    required String imagePath,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shadowColor: const Color(0xFF0D7377).withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: const Color(0xFF0D7377),
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
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.qr_code_2_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white70,
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