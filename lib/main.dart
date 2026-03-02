import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'dart:convert';
import 'firebase_options.dart';
import '/login.dart';
import '/admin/logica/admin.dart';
import '/usuarios/logica/estudiante.dart';
import '/Asistentes/asistentes.dart';
import '/Jurados/jurados.dart';
import '/prefs_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription? _linkSubscription;
  String? _pendingDeepLink;
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinkListener();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinkListener() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        print('Deep link recibido: ${uri.toString()}');
        _handleDeepLink(uri.toString());
      },
      onError: (err) {
        print('Error en deep link: $err');
      },
    );

    _handleInitialLink();
  }

  Future<void> _handleInitialLink() async {
    try {
      final Uri? initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        print('Deep link inicial: ${initialUri.toString()}');
        _pendingDeepLink = initialUri.toString();
      }
    } catch (e) {
      print('Error obteniendo deep link inicial: $e');
    }
  }

  void _handleDeepLink(String link) {
    try {
      final uri = Uri.parse(link);

      if (uri.scheme == 'myapp' && uri.host == 'asistencia') {
        final String? encodedData = uri.queryParameters['data'];

        if (encodedData != null) {
          try {
            final String decodedData = Uri.decodeComponent(encodedData);
            final Map<String, dynamic> qrData = jsonDecode(decodedData);

            print('Datos del QR decodificados: $qrData');
            _navigateToAsistencia(qrData);
          } catch (e) {
            print('Error decodificando datos del QR: $e');
            _showErrorDialog('Error', 'Código QR inválido o dañado');
          }
        } else {
          print('No se encontraron datos en el deep link');
          _showErrorDialog('Error', 'Enlace inválido');
        }
      } else {
        print('Deep link no reconocido: $link');
      }
    } catch (e) {
      print('Error procesando deep link: $e');
      _showErrorDialog('Error', 'Error al procesar el enlace');
    }
  }

  void _navigateToAsistencia(Map<String, dynamic> qrData) {
    PrefsHelper.isLoggedIn().then((isLoggedIn) {
      if (!isLoggedIn) {
        _pendingDeepLink = null;
        _showErrorDialog(
          'Sesión requerida',
          'Necesitas iniciar sesión para registrar tu asistencia',
        );
        return;
      }

      PrefsHelper.getUserType().then((userType) {
        if (userType != PrefsHelper.userTypeStudent) {
          _showErrorDialog(
            'Acceso denegado',
            'Solo los estudiantes pueden registrar asistencia',
          );
          return;
        }

        navigatorKey.currentState?.pushNamed(
          '/registro-asistencia',
          arguments: qrData,
        );
      });
    });
  }

  void _showErrorDialog(String title, String message) {
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Eventos',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
      locale: const Locale('es', 'ES'),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/admin': (context) => const AdminScreen(),
        '/estudiante': (context) => const EstudianteScreen(),
        '/asistente': (context) => const AsistentesScreen(),
        '/jurado': (context) => const JuradosScreen(),
        '/registro-asistencia': (context) => RegistroAsistenciaScreen(
          qrData:
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?,
        ),
      },
      home: AuthWrapper(pendingDeepLink: _pendingDeepLink),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final String? pendingDeepLink;

  const AuthWrapper({super.key, this.pendingDeepLink});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processPendingDeepLink();
    });
  }

  void _processPendingDeepLink() {
    if (widget.pendingDeepLink != null) {
      final myAppState = context.findAncestorStateOfType<_MyAppState>();
      myAppState?._handleDeepLink(widget.pendingDeepLink!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAuthStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Inicializando...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data == true) {
          return FutureBuilder<String?>(
            future: PrefsHelper.getUserType(),
            builder: (context, userTypeSnapshot) {
              if (userTypeSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Verificando usuario...'),
                      ],
                    ),
                  ),
                );
              }

              final userType = userTypeSnapshot.data;
              print('🔍 UserType detectado en AuthWrapper: $userType');

              if (userType == PrefsHelper.userTypeAdmin) {
                return const AdminScreen();
              } else if (userType == PrefsHelper.userTypeAsistente) {
                return const AsistentesScreen();
              } else if (userType == PrefsHelper.userTypeJurado) {
                print('✅ Navegando a JuradosScreen');
                return const JuradosScreen();
              } else if (userType == PrefsHelper.userTypeStudent) {
                return const EstudianteScreen();
              } else {
                print('❌ Tipo de usuario desconocido: $userType');
                PrefsHelper.logout();
                return const LoginScreen();
              }
            },
          );
        }

        // No hay sesión activa o fue invalidada
        return const LoginScreen();
      },
    );
  }

  // ✅ ACTUALIZADO: Verifica sesión activa Y que la contraseña no haya cambiado
  Future<bool> _checkAuthStatus() async {
    try {
      final isLoggedIn = await PrefsHelper.isLoggedIn();
      print('🔍 Estado de sesión: $isLoggedIn');
      if (!isLoggedIn) return false;

      // ✅ Verificar si la sesión sigue siendo válida (contraseña no cambió)
      final isValid = await PrefsHelper.isSessionValid();
      if (!isValid) {
        print('🔒 Sesión invalidada por cambio de contraseña');
        await PrefsHelper.logout();
        return false;
      }

      return true;
    } catch (e) {
      print('Error verificando estado de autenticación: $e');
      return false;
    }
  }
}

class RegistroAsistenciaScreen extends StatefulWidget {
  final Map<String, dynamic>? qrData;

  const RegistroAsistenciaScreen({super.key, this.qrData});

  @override
  State<RegistroAsistenciaScreen> createState() =>
      _RegistroAsistenciaScreenState();
}

class _RegistroAsistenciaScreenState extends State<RegistroAsistenciaScreen> {
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    if (widget.qrData != null) {
      _processAsistencia();
    }
  }

  void _processAsistencia() async {
    setState(() {
      _isRegistering = true;
    });

    try {
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Asistencia registrada exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error registrando asistencia: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.qrData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('No se recibieron datos del QR')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Asistencia'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isRegistering) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('Registrando asistencia...'),
            ] else ...[
              const Icon(Icons.event_available, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              Text(
                'Evento: ${widget.qrData!['eventName'] ?? 'Sin nombre'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text('Facultad: ${widget.qrData!['facultad'] ?? 'N/A'}'),
              Text('Carrera: ${widget.qrData!['carrera'] ?? 'N/A'}'),
              Text('Tipo: ${widget.qrData!['tipoInvestigacion'] ?? 'N/A'}'),
            ],
          ],
        ),
      ),
    );
  }
}
