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
        // Importar el servicio al inicio del archivo:
        // import 'admin_carrera_service.dart';

        final adminCarreraService = AdminCarreraService();
        final adminCarreraData = await adminCarreraService.loginAdminCarrera(
          usuario: username,
          password: password,
        );

        if (adminCarreraData != null) {
          // Login exitoso como admin de carrera
          await PrefsHelper.saveAdminCarreraData(
            userId: adminCarreraData['id'],
            userName: adminCarreraData['nombre'],
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

      // ✅ 5. REDIRIGIR SEGÚN EL TIPO DE USUARIO
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
          // ✅ REDIRIGIR AL PANEL DE ADMIN DE CARRERA
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A5490),
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
