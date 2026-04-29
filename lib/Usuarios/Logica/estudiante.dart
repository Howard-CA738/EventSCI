import 'package:flutter/material.dart';
import 'dart:async';
import '/prefs_helper.dart';
import '/login.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/usuarios/interfaz/perfil_screen.dart';
import 'escanear_qr.dart';
import 'asistencias.dart';
import '/usuarios/interfaz/ver_certificados_screen.dart';
import 'asistente_qr.dart';

class EstudianteScreen extends StatefulWidget {
  const EstudianteScreen({super.key});

  @override
  State<EstudianteScreen> createState() => _EstudianteScreenState();
}

class _EstudianteScreenState extends State<EstudianteScreen> {
  String _studentName = '';
  String? _studentFilial;
  String? _studentCarrera;
  String? _studentFacultad;
  Stream<DocumentSnapshot>? _studentStream;
  int _segundos = 5;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    final name     = await PrefsHelper.getUserName();
    final userData = await PrefsHelper.getCurrentUserData(forceRefresh: true);

    if (!mounted) return;

    if (userData == null) {
      setState(() => _studentName = name ?? 'Estudiante');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verificarYMostrarAdvertencia();
      });
      return;
    }

    String filial   = userData['filial']?.toString().trim()   ?? '';
    String facultad = userData['facultad']?.toString().trim() ?? '';
    String carrera  = userData['carrera']?.toString().trim()  ?? '';

    final bool needsParentDoc =
        filial.isEmpty || facultad.isEmpty || carrera.isEmpty;

    if (needsParentDoc) {
      final carreraPath = userData['carreraPath']?.toString() ?? '';
      if (carreraPath.isNotEmpty) {
        try {
          final parentDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(carreraPath)
              .get();
          if (parentDoc.exists) {
            final parentData = parentDoc.data() ?? {};
            if (filial.isEmpty)   filial   = parentData['filial']?.toString().trim()   ?? '';
            if (facultad.isEmpty) facultad = parentData['facultad']?.toString().trim() ?? '';
            if (carrera.isEmpty)  carrera  = parentData['carrera']?.toString().trim()  ?? '';
          }
        } catch (e) {
          debugPrint('⚠️ Error leyendo doc padre: $e');
        }
      }
      if (carreraPath.contains('_')) {
        final parts = carreraPath.split('_');
        if (filial.isEmpty)  filial  = parts.first.trim();
        if (carrera.isEmpty) carrera = parts.skip(1).join('_').trim();
      }
    }

    setState(() {
      _studentName     = name ?? 'Estudiante';
      _studentFilial   = filial.isNotEmpty   ? filial   : null;
      _studentFacultad = facultad.isNotEmpty ? facultad : null;
      _studentCarrera  = carrera.isNotEmpty  ? carrera  : null;
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
    _segundos = 5;
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
                  // Header
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
                            color: Colors.white.withOpacity(0.15),
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

                  // Contenido
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Alerta roja
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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

                        // Recomendación azul
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(
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

                        // Botón
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
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade600,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              _segundos > 0
                                  ? 'Entendido ($_segundos)'
                                  : 'Entendido',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
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

  // ── Logout ────────────────────────────────────────────────────────────────

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
              Text(
                'Cerrar Sesión',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildContentArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderRow(),
          const SizedBox(height: 16),
          _buildWelcomeCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
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
              return const Icon(Icons.school,
                  color: Color(0xFF1E3A5F), size: 30);
            },
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Text(
            'Panel de Estudiante',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white, size: 28),
          onPressed: _showLogoutConfirmation,
          tooltip: 'Cerrar Sesión',
        ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.waving_hand, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bienvenido, $_studentName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_studentFilial != null ||
              _studentFacultad != null ||
              _studentCarrera != null) ...[
            const SizedBox(height: 10),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 10),
            _buildInfoChips(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (_studentFilial != null)
          _buildInfoChip(
            icon: Icons.location_city,
            label: _studentFilial!,
            color: const Color(0xFF1E88E5),
          ),
        if (_studentFacultad != null)
          _buildInfoChip(
            icon: Icons.account_balance,
            label: _studentFacultad!,
            color: const Color(0xFF6A1B9A),
          ),
        if (_studentCarrera != null)
          _buildInfoChip(
            icon: Icons.menu_book,
            label: _studentCarrera!,
            color: const Color(0xFF00897B),
          ),
      ],
    );
  }

  Stream<DocumentSnapshot> _buildStudentStream() {
    if (_studentStream != null) return _studentStream!;

    _studentStream = PrefsHelper.getCurrentUserData(forceRefresh: false)
        .asStream()
        .asyncExpand((userData) {
      if (userData == null) return const Stream.empty();

      final carreraPath = userData['carreraPath']?.toString() ?? '';
      final docId = userData['docId']?.toString() ??
                    userData['id']?.toString() ?? '';

      if (carreraPath.isEmpty || docId.isEmpty) return const Stream.empty();

      return FirebaseFirestore.instance
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .doc(docId)
          .snapshots();
    });

    return _studentStream!;
  }

  Widget _buildContentArea() {
    return Expanded(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFE8EDF2),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: _buildStudentStream(),
          builder: (context, snapshot) {
            bool esAsisteQR = false;

            if (snapshot.hasData && snapshot.data!.exists) {
              final data =
                  snapshot.data!.data() as Map<String, dynamic>?;
              esAsisteQR = data?['esAsisteQR'] == true;
            }

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.80,
                children: [
                  _buildMenuCard(
                    imagePath: 'assets/icons/perfil.png',
                    title: 'Mi Perfil',
                    subtitle: 'Ver información personal',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const PerfilScreen()),
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
                          builder: (context) => AsistenciasScreen()),
                    ),
                  ),
                  _buildMenuCard(
                    imagePath: 'assets/icons/certificados.png',
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
                      imagePath: 'assets/icons/escaner.png',
                      title: 'Generar QR\nAsistencia',
                      subtitle: 'Crear QR para eventos',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                const AsistenteQRScreen()),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
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

  Widget _buildMenuCardDestacada({
    required String imagePath,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shadowColor: const Color(0xFF0D7377).withOpacity(0.4),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: const Color(0xFF0D7377),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(13),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  color: Colors.white,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.qr_code_scanner,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}