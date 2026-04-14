import 'package:flutter/material.dart';
import 'dart:async';
import '/prefs_helper.dart';
import '/Admin/logica/admin.dart';
import '/usuarios/logica/estudiante.dart';
import '/Asistentes/asistentes.dart';
import '/Jurados/jurados.dart';
import '/admin_carrera/admin_carrera_service.dart';
import '/admin_carrera/admin_carrera_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  int _currentBackgroundIndex = 0;
  Timer? _backgroundTimer;
  bool _imageLoaded = false;

  final List<String> _backgrounds = [
    'assets/images/fondo01.png',
    'assets/images/fondo02.png',
    'assets/images/fondo03.png',
  ];

  @override
  void initState() {
    super.initState();
    _startBackgroundRotation();
    _precacheImages();
  }

  Future<void> _precacheImages() async {
    try {
      await precacheImage(
        const AssetImage('assets/images/logoupeu.jpg'),
        context,
      );
      for (var bg in _backgrounds) {
        await precacheImage(AssetImage(bg), context);
      }
      if (mounted) {
        setState(() {
          _imageLoaded = true;
        });
      }
    } catch (e) {
      print('Error precaching images: $e');
      if (mounted) {
        setState(() {
          _imageLoaded = true;
        });
      }
    }
  }

  void _startBackgroundRotation() {
    _backgroundTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentBackgroundIndex =
              (_currentBackgroundIndex + 1) % _backgrounds.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _backgroundTimer?.cancel();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
  if (_userController.text.trim().isEmpty ||
      _passwordController.text.isEmpty) {
    _showMessage('Por favor, completa todos los campos');
    return;
  }

  setState(() {
    _isLoading = true;
  });

  bool success = false;
  String? loggedInUserType;

  try {
    final username = _userController.text.trim();
    final password = _passwordController.text;

    // ✅ 1. INTENTAR LOGIN COMO ADMIN O ASISTENTE
    if (username == PrefsHelper.adminEmail ||
        username == PrefsHelper.asistenteEmail) {
      success = await PrefsHelper.loginAdmin(username, password);
      if (success) {
        loggedInUserType = await PrefsHelper.getUserType();
      }
    }
    // ✅ 2. INTENTAR LOGIN COMO ADMIN DE CARRERA
    else {
      final adminCarreraService = AdminCarreraService();
      final adminCarreraData = await adminCarreraService.loginAdminCarrera(
        usuario: username,
        password: password,
      );

      if (adminCarreraData != null) {
        await PrefsHelper.saveAdminCarreraData(
          userId: adminCarreraData['id'],
          userName: adminCarreraData['usuario'] ?? 'Admin',
          filial: adminCarreraData['filial'],
          filialNombre: adminCarreraData['filialNombre'],
          facultad: adminCarreraData['facultad'],
          carrera: adminCarreraData['carrera'],
          carreraId: adminCarreraData['carreraId'],
          permisos: adminCarreraData['permisos'],
        );

        success = true;
        loggedInUserType = PrefsHelper.userTypeAdminCarrera;
      }
      // ✅ 3. INTENTAR LOGIN COMO JURADO
      else {
        success = await PrefsHelper.loginJurado(username, password);
        if (success) {
          loggedInUserType = await PrefsHelper.getUserType();
        }
        // ✅ 4. INTENTAR LOGIN COMO ESTUDIANTE
        else {
          success = await PrefsHelper.loginStudent(username, password);
          if (success) {
            loggedInUserType = await PrefsHelper.getUserType();
          }
        }
      }
    }

    // ✅ 5. REDIRIGIR SEGÚN EL TIPO DE USUARIO + VALIDACIÓN DE PAGO
    if (success && loggedInUserType != null) {
      if (loggedInUserType == PrefsHelper.userTypeAdmin) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AdminScreen()),
          );
        }
      } else if (loggedInUserType == PrefsHelper.userTypeAsistente) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AsistentesScreen()),
          );
        }
      } else if (loggedInUserType == PrefsHelper.userTypeAdminCarrera) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const AdminCarreraScreen(),
            ),
          );
        }
      } else if (loggedInUserType == PrefsHelper.userTypeJurado) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const JuradosScreen()),
          );
        }
      } else if (loggedInUserType == PrefsHelper.userTypeStudent) {
  final userData = await PrefsHelper.getCurrentUserData();

  // ── 1. Verificar pago ────────────────────────────────────────
  final pago = (userData?['pago'] ?? '').toString().toLowerCase();
  final isPagado = pago == 'si';

  if (!isPagado) {
    await PrefsHelper.logout();
    if (mounted) {
      setState(() => _isLoading = false);
      _showBlockedDialog();
    }
    return;
  }

  // ── 2. Verificar sesión única ────────────────────────────────
  final userIdPath = await PrefsHelper.getCurrentUserId();
  if (userIdPath != null && userIdPath.contains('/')) {
    final parts = userIdPath.split('/');
    final carreraPath = parts[0];
    final studentId = parts[1];

    final estadoSesion = await PrefsHelper.verificarSesionEstudiante(
      carreraPath: carreraPath,
      studentId: studentId,
    );

    if (estadoSesion == 'bloqueado') {
      // Ya tiene sesión activa → bloquear
      await PrefsHelper.logout();
      if (mounted) {
        setState(() => _isLoading = false);
        _showSesionBloqueadaDialog();
      }
      return;
    }

    // ── 3. Activar sesión ──────────────────────────────────────
    await PrefsHelper.activarSesionEstudiante(
      carreraPath: carreraPath,
      studentId: studentId,
    );
  }

  if (mounted) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const EstudianteScreen()),
    );
  }
}
    } else {
      _showMessage('Usuario o contraseña incorrectos');
    }
  } catch (e) {
    _showMessage('Error al iniciar sesión: $e');
  }

  if (mounted) {
    setState(() {
      _isLoading = false;
    });
  }
}
void _showSesionBloqueadaDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orange.shade200, width: 2),
              ),
              child: Icon(
                Icons.devices_outlined,
                size: 40,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sesión ya iniciada',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange.shade700, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Ya iniciaste sesión anteriormente y no la cerraste '
                      'correctamente. Solo se permite una sesión activa.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF78350F),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Comunícate con el administrador de tu carrera '
              'para que restablezca tu acceso.',
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A5490),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Entendido',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A5490),
      ),
    );
  }
void _showBlockedDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono de bloqueo animado
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.shade200, width: 2),
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 40,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 20),
 
            const Text(
              'Acceso Restringido',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
 
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber.shade700, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Tu pago se encuentra PENDIENTE. '
                      'No puedes acceder hasta que tu pago sea confirmado.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF78350F),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
 
            const Text(
              'Comunícate con la administración de tu carrera '
              'para verificar tu estado de pago.',
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
 
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A5490),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Entendido',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    if (!_imageLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ✅ Detectar orientación
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo animado
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1000),
            child: Container(
              key: ValueKey<int>(_currentBackgroundIndex),
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(_backgrounds[_currentBackgroundIndex]),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.3),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),
          ),

          // Contenido
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 40.0 : 24.0,
                  vertical: 20.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ✅ Logo adaptativo según orientación
                    Image.asset(
                      'assets/images/logo.png',
                      height: isLandscape
                          ? screenHeight *
                                0.25 // 25% de la altura en horizontal
                          : 180,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.school,
                          size: isLandscape ? screenHeight * 0.25 : 180,
                          color: Colors.white,
                        );
                      },
                    ),

                    SizedBox(height: isLandscape ? 20 : 40),

                    // ✅ Card de login con ancho máximo en horizontal
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isLandscape ? 500 : double.infinity,
                      ),
                      child: Container(
                        padding: EdgeInsets.all(isLandscape ? 24 : 30),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Campo usuario
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _userController,
                                keyboardType: TextInputType.text,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Usuario',
                                  hintStyle: TextStyle(color: Colors.grey[400]),
                                  prefixIcon: const Icon(
                                    Icons.person_outline,
                                    color: Color(0xFF1A5490),
                                    size: 24,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: isLandscape ? 14 : 18,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: isLandscape ? 15 : 20),

                            // Campo contraseña
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Contraseña',
                                  hintStyle: TextStyle(color: Colors.grey[400]),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: Color(0xFF1A5490),
                                    size: 24,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: const Color(0xFF1A5490),
                                      size: 24,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: isLandscape ? 14 : 18,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: isLandscape ? 20 : 30),

                            // Botón de login
                            SizedBox(
                              width: double.infinity,
                              height: isLandscape ? 50 : 55,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A5490),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  disabledBackgroundColor: Colors.grey[400],
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Ingresar',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: isLandscape ? 20 : 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
