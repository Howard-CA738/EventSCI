import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '/prefs_helper.dart';
import '/Admin/logica/admin.dart';
import '/usuarios/logica/estudiante.dart';
import '/Jurados/jurados.dart';
import '/admin_carrera/admin_carrera_service.dart';
import '/admin_carrera/interfaz/admin_carrera_screen.dart';
import '/super_admin_login.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController     = TextEditingController();
  final _passwordController = TextEditingController();

  bool   _isLoading              = false;
  bool   _obscurePassword        = true;
  int    _currentBackgroundIndex = 0;
  Timer? _backgroundTimer;
  bool   _imageLoaded            = false;

  final List<String> _backgrounds = [
    'assets/images/fondo01.png',
    'assets/images/fondo02.png',
    'assets/images/fondo03.png',
  ];

  @override
  void initState() {
    super.initState();
    _startBackgroundRotation();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheImages());
  }

  @override
  void dispose() {
    _backgroundTimer?.cancel();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _precacheImages() async {
    try {
      await precacheImage(const AssetImage('assets/images/logoupeu.jpg'), context);
      for (final bg in _backgrounds) {
        await precacheImage(AssetImage(bg), context);
      }
    } catch (e) {
      debugPrint('Error precaching images: $e');
    } finally {
      if (mounted) setState(() => _imageLoaded = true);
    }
  }

  void _startBackgroundRotation() {
    _backgroundTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _currentBackgroundIndex =
              (_currentBackgroundIndex + 1) % _backgrounds.length;
        });
      }
    });
  }

  Future<void> _login() async {
    final username = _userController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showMessage('Por favor, completa todos los campos');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _ejecutarLogin().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('timeout'),
      );
    } on TimeoutException {
      if (mounted) _showSinInternetDialog();
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('unavailable')      ||
          msg.contains('network')          ||
          msg.contains('unreachable')      ||
          msg.contains('failed-precondition')) {
        if (mounted) _showSinInternetDialog();
      } else {
        if (mounted) _showMessage('Error al iniciar sesión: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _ejecutarLogin() async {
    final username = _userController.text.trim();
    final password = _passwordController.text;

    if (username.contains('@')) {
      final error = await SuperAdminAuthService.login(username, password);
      if (error != null) {
        if (mounted) _showMessage(error);
        return;
      }
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser!;
      final errorCodigo = await SuperAdminAuthService.enviarCodigoEmail(
          user.uid, username);
      if (!mounted) return;
      if (errorCodigo != null) {
        _showMessage(errorCodigo);
        return;
      }
      _mostrarDialogOTP(user.uid, username);
      return;
    }

    await PrefsHelper.ensureAuthActiva();

    final rolData = await PrefsHelper.detectarRolConDoc(username.toLowerCase());

    if (rolData == null) {
      if (mounted) _showMessage('Usuario o contraseña incorrectos');
      return;
    }

    final rol = rolData['rol'] as String;

    switch (rol) {
      case 'admin_carrera':
        final adminCarreraService = AdminCarreraService();
        final adminCarreraData = await adminCarreraService.loginAdminCarrera(
          usuario:  username,
          password: password,
        );
        if (adminCarreraData == null) {
          if (mounted) _showMessage('Usuario o contraseña incorrectos');
          return;
        }
        await PrefsHelper.saveAdminCarreraData(
          userId:       adminCarreraData['id'],
          userName:     adminCarreraData['usuario'] ?? 'Admin',
          filial:       adminCarreraData['filial'],
          filialNombre: adminCarreraData['filialNombre'],
          facultad:     adminCarreraData['facultad'],
          carrera:      adminCarreraData['carrera'],
          carreraId:    adminCarreraData['carreraId'],
          permisos:     adminCarreraData['permisos'],
        );
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AdminCarreraScreen()),
          );
        }
        break;

      case 'jurado':
        final esJurado = await PrefsHelper.loginJurado(username, password);
        if (!esJurado) {
          if (mounted) _showMessage('Usuario o contraseña incorrectos');
          return;
        }
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const JuradosScreen()),
          );
        }
        break;

      case 'student':
        final success = await PrefsHelper.loginStudent(username, password);
        if (!success) {
          if (mounted) _showMessage('Usuario o contraseña incorrectos');
          return;
        }

        final userIdPath = await PrefsHelper.getCurrentUserId();
        if (userIdPath != null && userIdPath.contains('/')) {
          final parts       = userIdPath.split('/');
          final carreraPath = parts[0];
          final studentId   = parts[1];

          final bloqueado = await PrefsHelper.verificarBloqueoporPago(
            carreraPath: carreraPath,
            studentId:   studentId,
          );

          if (bloqueado) {
            await PrefsHelper.logout();
            if (mounted) {
              setState(() => _isLoading = false);
              _showPagoPendienteDialog();
            }
            return;
          }

          final estadoSesion = await PrefsHelper.verificarSesionEstudiante(
            carreraPath: carreraPath,
            studentId:   studentId,
          );

          // ⬅️ DESHABILITADO (eliminación lógica): cuenta deshabilitada por el admin
          if (estadoSesion == 'deshabilitado') {
            await PrefsHelper.logout();
            if (mounted) {
              setState(() => _isLoading = false);
              _showCuentaDeshabilitadaDialog();
            }
            return;
          }

          if (estadoSesion == 'dispositivo_bloqueado') {
            await PrefsHelper.logout();
            if (mounted) {
              setState(() => _isLoading = false);
              _showDispositivoBloqueadoDialog();
            }
            return;
          }
          if (estadoSesion == 'bloqueado') {
            await PrefsHelper.logout();
            if (mounted) {
              setState(() => _isLoading = false);
              _showSesionBloqueadaDialog();
            }
            return;
          }
          if (estadoSesion == 'celular_bloqueado') {
            await PrefsHelper.logout();
            if (mounted) {
              setState(() => _isLoading = false);
              _showCelularBloqueadoDialog();
            }
            return;
          }

          await PrefsHelper.activarSesionEstudiante(
            carreraPath: carreraPath,
            studentId:   studentId,
          );
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const EstudianteScreen()),
          );
        }
        break;
    }
  }

  void _mostrarDialogOTP(String uid, String email) {
    final otpController = TextEditingController();
    final otpFocusNode  = FocusNode();
    final otpDigits     = List.filled(6, '', growable: false);
    bool  verificando   = false;
    String? errorOtp;
    int segundos        = 300;
    Timer? countdownTimer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible:       false,
      backgroundColor:     Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
            if (!ctx.mounted) {
              countdownTimer?.cancel();
              return;
            }
            if (segundos > 0) {
              setSheet(() => segundos--);
            } else {
              countdownTimer?.cancel();
            }
          });

          final mm       = (segundos ~/ 60).toString().padLeft(2, '0');
          final ss       = (segundos %  60).toString().padLeft(2, '0');
          final expirado = segundos <= 0;

          return PopScope(
            canPop: false,
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color:        Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color:  const Color(0xFF1E3A5F).withAlpha(25),
                            shape:  BoxShape.circle,
                          ),
                          child: const Icon(Icons.mark_email_read_outlined,
                              color: Color(0xFF1E3A5F), size: 32),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Verifica tu identidad',
                          style: TextStyle(
                              fontSize:   20,
                              fontWeight: FontWeight.w800,
                              color:      Color(0xFF1E3A5F)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ingresa el código enviado a\n$email',
                          style: TextStyle(
                              fontSize: 13,
                              color:    Colors.grey[500],
                              height:   1.5),
                          textAlign: TextAlign.center,
                          overflow:  TextOverflow.ellipsis,
                          maxLines:  3,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          expirado ? '⏰ Código expirado' : 'Expira en $mm:$ss',
                          style: TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w600,
                            color: (expirado || segundos < 60)
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _OtpInputRow(
                          otpDigits:     otpDigits,
                          otpController: otpController,
                          otpFocusNode:  otpFocusNode,
                          expirado:      expirado,
                          onChanged: (value) {
                            setSheet(() {
                              for (int i = 0; i < 6; i++) {
                                otpDigits[i] = i < value.length ? value[i] : '';
                              }
                              errorOtp = null;
                            });
                            if (value.length == 6 && !expirado) {
                              _verificarOTP(
                                uid, value, ctx, setSheet,
                                (v) => verificando = v,
                                (e) => errorOtp    = e,
                              );
                            }
                          },
                        ),
                        if (errorOtp != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            errorOtp!,
                            style: const TextStyle(
                                color: Color(0xFFEF4444), fontSize: 13),
                            textAlign: TextAlign.center,
                            overflow:  TextOverflow.ellipsis,
                            maxLines:  2,
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: (verificando || expirado)
                                ? null
                                : () => _verificarOTP(
                                      uid, otpController.text, ctx, setSheet,
                                      (v) => verificando = v,
                                      (e) => errorOtp    = e,
                                    ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:        const Color(0xFF1E3A5F),
                              foregroundColor:        Colors.white,
                              disabledBackgroundColor:
                                  const Color(0xFF1E3A5F).withAlpha(100),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: verificando
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        color:       Colors.white,
                                        strokeWidth: 2.5))
                                : const Text(
                                    'Verificar',
                                    style: TextStyle(
                                        fontSize:   15,
                                        fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: expirado
                              ? () async {
                                  countdownTimer?.cancel();
                                  Navigator.of(ctx).pop();
                                  setState(() => _isLoading = true);
                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  if (user != null) {
                                    await SuperAdminAuthService
                                        .enviarCodigoEmail(uid, email);
                                  }
                                  if (mounted) {
                                    setState(() => _isLoading = false);
                                    _mostrarDialogOTP(uid, email);
                                  }
                                }
                              : null,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                          ),
                          child: Text(
                            expirado
                                ? 'Reenviar código'
                                : 'Reenviar (disponible al expirar)',
                            style: TextStyle(
                              color: expirado
                                  ? const Color(0xFF1E3A5F)
                                  : Colors.grey[400],
                              fontSize:   13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            countdownTimer?.cancel();
                            Navigator.of(ctx).pop();
                            FirebaseAuth.instance.signOut();
                          },
                          style: TextButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                                color: Color(0xFFEF4444), fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() => countdownTimer?.cancel());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (otpFocusNode.canRequestFocus) otpFocusNode.requestFocus();
    });
  }

  Future<void> _verificarOTP(
    String uid,
    String codigo,
    BuildContext ctx,
    StateSetter setSheet,
    void Function(bool)    setVerificando,
    void Function(String?) setError,
  ) async {
    if (codigo.length != 6) return;
    setSheet(() => setVerificando(true));

    final error = await SuperAdminAuthService.verificarCodigo(uid, codigo);

    if (!mounted) return;

    if (error != null) {
      setSheet(() {
        setVerificando(false);
        setError(error);
      });
      return;
    }

    Navigator.of(ctx).pop();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminScreen()),
      );
    }
  }

  void _showSinInternetDialog() => _showErrorDialog(
        icono:       Icons.wifi_off_rounded,
        iconColor:   Colors.orange.shade700,
        bgColor:     Colors.orange.shade50,
        borderColor: Colors.orange.shade200,
        titulo:      'Sin conexión a internet',
        mensaje:     'No tienes internet o está fallando tu conexión. '
            'Verifica tu red e intenta de nuevo.',
        textoColor: const Color(0xFF78350F),
      );

  void _showSesionBloqueadaDialog() => _showErrorDialog(
        icono:       Icons.devices_outlined,
        iconColor:   Colors.orange.shade700,
        bgColor:     Colors.orange.shade50,
        borderColor: Colors.orange.shade200,
        titulo:      'Sesión ya iniciada',
        mensaje:     'Ya iniciaste sesión anteriormente y no la cerraste '
            'correctamente. Solo se permite una sesión activa.\n\n'
            'Comunícate con el administrador de tu carrera '
            'para que restablezca tu acceso.',
        textoColor: const Color(0xFF78350F),
      );

  void _showDispositivoBloqueadoDialog() => _showErrorDialog(
        icono:       Icons.phonelink_lock_rounded,
        iconColor:   Colors.red.shade700,
        bgColor:     Colors.red.shade50,
        borderColor: Colors.red.shade200,
        titulo:      'Acceso Bloqueado',
        mensaje:     'Tu cuenta ha sido bloqueada. '
            'No puedes volver a iniciar sesión.\n\n'
            'Comunícate con el administrador de tu carrera '
            'para restablecer tu acceso.',
        textoColor: const Color(0xFF7F1D1D),
      );

  void _showCelularBloqueadoDialog() => _showErrorDialog(
        icono:       Icons.phone_locked_rounded,
        iconColor:   Colors.red.shade700,
        bgColor:     Colors.red.shade50,
        borderColor: Colors.red.shade200,
        titulo:      'Celular no autorizado',
        mensaje:     'Este celular ya está registrado con otra cuenta. '
            'No puedes iniciar sesión con una cuenta diferente '
            'desde este dispositivo.',
        textoColor: const Color(0xFF7F1D1D),
      );

  void _showPagoPendienteDialog() => _showErrorDialog(
        icono:       Icons.money_off_rounded,
        iconColor:   Colors.orange.shade700,
        bgColor:     Colors.orange.shade50,
        borderColor: Colors.orange.shade200,
        titulo:      'Pago pendiente',
        mensaje:     'No puedes ingresar porque tienes un pago pendiente.\n\n'
            'Comunícate con el administrador de tu carrera '
            'para regularizar tu situación.',
        textoColor: const Color(0xFF78350F),
      );

  // ⬅️ DESHABILITADO (eliminación lógica): diálogo para cuenta deshabilitada
  void _showCuentaDeshabilitadaDialog() => _showErrorDialog(
        icono:       Icons.no_accounts_rounded,
        iconColor:   Colors.red.shade700,
        bgColor:     Colors.red.shade50,
        borderColor: Colors.red.shade200,
        titulo:      'Cuenta deshabilitada',
        mensaje:     'Tu cuenta ha sido deshabilitada y no puede iniciar sesión.\n\n'
            'Comunícate con el administrador de tu carrera '
            'si crees que es un error.',
        textoColor: const Color(0xFF7F1D1D),
      );

  void _showErrorDialog({
    required IconData icono,
    required Color    iconColor,
    required Color    bgColor,
    required Color    borderColor,
    required String   titulo,
    required String   mensaje,
    required Color    textoColor,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        return Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.80,
              minWidth:  280,
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width:  80,
                      height: 80,
                      decoration: BoxDecoration(
                        color:  bgColor,
                        shape:  BoxShape.circle,
                        border: Border.all(color: borderColor, width: 2),
                      ),
                      child: Icon(icono, size: 40, color: iconColor),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      titulo,
                      style: const TextStyle(
                          fontSize:   20,
                          fontWeight: FontWeight.bold,
                          color:      Color(0xFF1E3A5F)),
                      textAlign: TextAlign.center,
                      overflow:  TextOverflow.ellipsis,
                      maxLines:  2,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:        bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border:       Border.all(color: borderColor),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              color: iconColor, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              mensaje,
                              style: TextStyle(
                                  fontSize: 13,
                                  color:    textoColor,
                                  height:   1.4),
                              overflow: TextOverflow.visible,
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width:  double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A5490),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Entendido',
                          style: TextStyle(
                              fontSize:   16,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(message),
      backgroundColor: const Color(0xFF1A5490),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_imageLoaded) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final mq            = MediaQuery.of(context);
    final isLandscape   = mq.orientation == Orientation.landscape;
    final screenWidth   = mq.size.width;
    final screenHeight  = mq.size.height;
    final isSmallPhone  = screenWidth < 375;

    final logoHeight    = isLandscape
        ? screenHeight * 0.22
        : (isSmallPhone ? 120.0 : 160.0);

    final cardPadding   = isLandscape ? 20.0 : (isSmallPhone ? 20.0 : 28.0);
    final cardMaxWidth  = isLandscape ? 500.0 : double.infinity;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1000),
            child: Container(
              key: ValueKey<int>(_currentBackgroundIndex),
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(_backgrounds[_currentBackgroundIndex]),
                  fit:   BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                      Colors.black.withAlpha(76), BlendMode.darken),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 40.0 : 24.0,
                  vertical:   16.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: logoHeight,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.school,
                        size:  logoHeight,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: isLandscape ? 16 : (isSmallPhone ? 24 : 36)),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: cardMaxWidth),
                      child: Container(
                        padding: EdgeInsets.all(cardPadding),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(184, 78, 94, 123),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withAlpha(20),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:      Colors.black.withAlpha(64),
                              blurRadius: 20,
                              offset:     const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTextField(
                              controller:   _userController,
                              hint:         'Usuario',
                              icon:         Icons.person_outline,
                              isSmallPhone: isSmallPhone,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            SizedBox(height: isSmallPhone ? 14 : 18),
                            _buildPasswordField(isSmallPhone),
                            SizedBox(height: isSmallPhone ? 20 : 28),
                            SizedBox(
                              width:  double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF5B731),
                                  foregroundColor: const Color(0xFF0F1E35),
                                  elevation:       0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15)),
                                  disabledBackgroundColor:
                                      const Color(0xFFF5B731).withAlpha(100),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24, width: 24,
                                        child: CircularProgressIndicator(
                                            color:       Color(0xFF0F1E35),
                                            strokeWidth: 2.5))
                                    : const Text(
                                        'Ingresar',
                                        style: TextStyle(
                                            fontSize:      18,
                                            fontWeight:    FontWeight.w700,
                                            letterSpacing: 0.5),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isLandscape ? 16 : 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isSmallPhone,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border:       Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: TextField(
        controller:   controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        decoration: InputDecoration(
          hintText:   hint,
          hintStyle:  TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(icon,
              color: const Color(0xFF1A5490), size: 24),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical:   isSmallPhone ? 14 : 18),
        ),
      ),
    );
  }

  Widget _buildPasswordField(bool isSmallPhone) {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border:       Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: TextField(
        controller:  _passwordController,
        obscureText: _obscurePassword,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        decoration: InputDecoration(
          hintText:   'Contraseña',
          hintStyle:  TextStyle(color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.lock_outline,
              color: Color(0xFF1A5490), size: 24),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: const Color(0xFF1A5490),
              size:  24,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            tooltip: _obscurePassword
                ? 'Mostrar contraseña'
                : 'Ocultar contraseña',
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical:   isSmallPhone ? 14 : 18),
        ),
      ),
    );
  }
}

class _OtpInputRow extends StatelessWidget {
  const _OtpInputRow({
    required this.otpDigits,
    required this.otpController,
    required this.otpFocusNode,
    required this.expirado,
    required this.onChanged,
  });

  final List<String>         otpDigits;
  final TextEditingController otpController;
  final FocusNode            otpFocusNode;
  final bool                 expirado;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Campo de código de verificación de 6 dígitos',
      child: SizedBox(
        height: 56,
        child: Stack(
          children: [
            Opacity(
              opacity: 0.01,
              child: TextField(
                controller:      otpController,
                focusNode:       otpFocusNode,
                keyboardType:    TextInputType.number,
                maxLength:       6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                    counterText: '', border: InputBorder.none),
                onChanged: onChanged,
              ),
            ),
            GestureDetector(
              onTap: () => otpFocusNode.requestFocus(),
              child: Row(
                children: List.generate(6, (i) {
                  final has      = otpDigits[i].isNotEmpty;
                  final filledCount = otpDigits
                      .where((d) => d.isNotEmpty)
                      .length;
                  final isCurrent = filledCount == i;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 5 ? 6.0 : 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height:   56,
                        decoration: BoxDecoration(
                          color: has
                              ? const Color(0xFF1E3A5F).withAlpha(15)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? const Color(0xFF1E3A5F)
                                : has
                                    ? const Color(0xFF1E3A5F).withAlpha(76)
                                    : Colors.transparent,
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: has
                            ? Text(
                                otpDigits[i],
                                style: const TextStyle(
                                    fontSize:   22,
                                    fontWeight: FontWeight.w700,
                                    color:      Color(0xFF1E3A5F)),
                              )
                            : isCurrent
                                ? const _BlinkingCursor()
                                : const SizedBox.shrink(),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width:  2,
        height: 24,
        decoration: BoxDecoration(
          color:        const Color(0xFF1E3A5F),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}