import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/prefs_helper.dart';

class EditarAdminScreen extends StatefulWidget {
  const EditarAdminScreen({super.key});

  @override
  State<EditarAdminScreen> createState() => _EditarAdminScreenState();
}

class _EditarAdminScreenState extends State<EditarAdminScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // OTP: un solo controlador para manejar el input completo internamente
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  // Los 6 dígitos como lista para mostrar en UI
  final List<String> _otpDigits = List.filled(6, '');

  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _verificado = false;
  bool _enviandoSMS = false;
  bool _verificandoCodigo = false;

  String? _adminUid;
  String? _phoneNumber;
  Map<String, dynamic>? _adminData;
  String? _verificationId;
  int? _resendToken;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Tema
  static const _navy = Color(0xFF1E3A5F);
  static const _navyLight = Color(0xFF2D5080);
  static const _bg = Color(0xFFF0F4F8);
  static const _success = Color(0xFF16A34A);
  static const _warning = Color(0xFFD97706);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadAdminData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // CARGAR DATOS
  // ─────────────────────────────────────────────────────────
  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('No hay sesión activa');
        return;
      }
      _adminUid = user.uid;

      final doc = await FirebaseFirestore.instance
          .collection('superadmins')
          .doc(_adminUid)
          .get();

      if (!doc.exists) {
        _showError('No se encontró el documento de superAdmin');
        return;
      }

      if (mounted) {
        setState(() {
          _adminData = doc.data();
          _phoneNumber = _adminData?['phone'];
          _nameController.text = _adminData?['nombre'] ?? '';
          _emailController.text = _adminData?['email'] ?? user.email ?? '';
        });
        // FIX #8: reset antes de forward para evitar warning si ya está en completed
        _fadeController.reset();
        _fadeController.forward();
      }
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      _showError('Error al cargar los datos');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────
  // ENVIAR SMS
  // ─────────────────────────────────────────────────────────
  Future<void> _enviarSMS() async {
    if (_phoneNumber == null || _phoneNumber!.isEmpty) {
      _showError('No hay número de teléfono registrado en tu cuenta');
      return;
    }
    if (mounted) setState(() => _enviandoSMS = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phoneNumber!,
        timeout: const Duration(seconds: 120),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('✅ Auto-verificación completada');
          await _autoVerificar(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ Error: ${e.code}');
          if (mounted) setState(() => _enviandoSMS = false);
          _showError(_mensajeErrorSMS(e.code));
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('✅ SMS enviado');
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
              _enviandoSMS = false;
            });
          }
          _showCodigoDialog();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (_verificationId == null) {
            _verificationId = verificationId;
          }
        },
      );
    } catch (e) {
      debugPrint('Error enviando SMS: $e');
      if (mounted) setState(() => _enviandoSMS = false);
      _showError('Error al enviar el SMS. Intenta de nuevo.');
    }
  }

  Future<void> _autoVerificar(PhoneAuthCredential credential) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await user.reauthenticateWithCredential(credential);
      if (mounted) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        setState(() => _verificado = true);
        _showSuccess('Verificación exitosa automáticamente');
      }
    } catch (e) {
      debugPrint('Error en auto-verificación: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // VERIFICAR CÓDIGO
  // ─────────────────────────────────────────────────────────
  Future<void> _verificarCodigo() async {
    // FIX #2: usar _otpController.text directamente en lugar de _otpDigits.join()
    // para garantizar que el valor es el real del controlador, sin depender del
    // estado asíncrono de setSheetState.
    final codigo = _otpController.text.trim();

    if (codigo.length != 6) {
      _showError('Ingresa los 6 dígitos del código');
      return;
    }
    if (_verificationId == null) {
      _showError('Solicita un nuevo código SMS');
      return;
    }

    if (mounted) setState(() => _verificandoCodigo = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: codigo,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('No hay sesión activa');
        return;
      }

      try {
        await user.reauthenticateWithCredential(credential);
        debugPrint('✅ Reautenticación exitosa');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-mismatch' || e.code == 'user-not-found') {
          debugPrint('⚠️ user-mismatch, intentando link...');
          try {
            await user.linkWithCredential(credential);
            debugPrint('✅ Teléfono vinculado');
          } on FirebaseAuthException catch (linkError) {
            if (linkError.code != 'provider-already-linked' &&
                linkError.code != 'credential-already-in-use') {
              rethrow;
            }
            debugPrint('✅ Ya vinculado — aceptado');
          }
        } else {
          rethrow;
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        setState(() => _verificado = true);
        _showSuccess('Identidad verificada correctamente');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error: ${e.code}');
      if (e.code == 'session-expired') {
        if (mounted) setState(() => _verificationId = null);
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        _showError('El código expiró. Solicita uno nuevo.');
      } else if (e.code == 'invalid-verification-code') {
        _showError('Código incorrecto. Verifica e intenta de nuevo.');
      } else {
        _showError('Error: ${e.code}. Solicita un nuevo código.');
      }
    } catch (e) {
      debugPrint('Error inesperado: $e');
      _showError('Error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _verificandoCodigo = false);
    }
  }

  // ─────────────────────────────────────────────────────────
  // GUARDAR CAMBIOS
  // ─────────────────────────────────────────────────────────
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_verificado) {
      _showError('Debes verificar tu identidad por SMS primero');
      return;
    }

    if (_newPasswordController.text.isNotEmpty) {
      if (_newPasswordController.text != _confirmPasswordController.text) {
        _showError('Las contraseñas nuevas no coinciden');
        return;
      }
      if (_newPasswordController.text.length < 6) {
        _showError('La contraseña debe tener al menos 6 caracteres');
        return;
      }
    }

    if (mounted) setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('No hay sesión activa');
        return;
      }

      // FIX #4: Actualizar contraseña justo después de la reautenticación
      // (que ya ocurrió en _verificarCodigo), antes de cualquier otra operación.
      if (_newPasswordController.text.isNotEmpty) {
        await user.updatePassword(_newPasswordController.text);
        debugPrint('✅ Contraseña actualizada');
      }

      final nuevoEmail = _emailController.text.trim();

      // FIX #5: Solo actualizar Firestore con el email actual verificado.
      // verifyBeforeUpdateEmail envía un correo de confirmación; el email real
      // en Auth cambia solo cuando el usuario hace clic en ese enlace.
      // Por eso guardamos en Firestore el email actual de Auth, no el nuevo,
      // y notificamos al usuario que debe confirmar el cambio.
      if (nuevoEmail != user.email) {
        await user.verifyBeforeUpdateEmail(nuevoEmail);
        _showSuccess(
            'Se envió un correo a $nuevoEmail para confirmar el cambio. '
            'El email se actualizará al confirmar el enlace.');
      }

      // Guardamos en Firestore el email actual confirmado (user.email),
      // no el pendiente de verificación.
      await FirebaseFirestore.instance
          .collection('superadmins')
          .doc(_adminUid)
          .update({
        'nombre': _nameController.text.trim(),
        // Solo actualizamos el email en Firestore si no hubo cambio pendiente,
        // o si el email nuevo ya es el mismo (no hubo intención de cambiar).
        if (nuevoEmail == user.email) 'email': nuevoEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await PrefsHelper.saveUserData(
        userType: 'superAdmin',
        userName: _nameController.text.trim(),
        userId: _adminUid!,
      );

      if (mounted) {
        if (nuevoEmail == user.email) {
          _showSuccess('Datos actualizados exitosamente');
        }
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        setState(() => _verificado = false);
        await _loadAdminData();
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error Auth: ${e.code}');
      _showError(_mensajeErrorGuardar(e.code));
    } catch (e) {
      debugPrint('Error guardando: $e');
      _showError('Error al guardar los cambios');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─────────────────────────────────────────────────────────
  // DIÁLOGO OTP — input unificado, sin lag, sin saltos
  // ─────────────────────────────────────────────────────────
  void _showCodigoDialog() {
    // Reset OTP
    _otpController.clear();
    for (int i = 0; i < 6; i++) _otpDigits[i] = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 28,
                  right: 28,
                  top: 12,
                  bottom: keyboardHeight + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Icono
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_navy, _navyLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _navy.withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Verificación',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _navy,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ingresa el código enviado a\n${_phoneNumber != null ? _ocultarNumero(_phoneNumber!) : 'tu número'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // ── OTP Widget: input invisible + cajas decorativas ──
                    // Esta técnica es la misma que usan WhatsApp y Google:
                    // un TextField invisible captura todo el input y las
                    // cajas son solo decoración. Esto elimina el lag y saltos.
                    SizedBox(
                      // FIX #9: altura explícita sin depender del counter invisible.
                      // Al suprimir counterText con '' ya no hay espacio extra,
                      // pero definimos la altura del Stack de forma fija.
                      height: 56,
                      child: Stack(
                        children: [
                          // TextField invisible que captura el input
                          Opacity(
                            opacity: 0,
                            child: TextField(
                              controller: _otpController,
                              focusNode: _otpFocusNode,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              // FIX #9: suprimir el counter que ocupa espacio en el Stack
                              decoration: const InputDecoration(
                                counterText: '',
                                border: InputBorder.none,
                              ),
                              onChanged: (value) {
                                // Actualizar los dígitos mostrados
                                setSheetState(() {
                                  for (int i = 0; i < 6; i++) {
                                    _otpDigits[i] =
                                        i < value.length ? value[i] : '';
                                  }
                                });
                                // Auto-verificar cuando se completan 6 dígitos.
                                // FIX #2: _verificarCodigo usa _otpController.text
                                // internamente, por lo que no depende del estado
                                // asíncrono de _otpDigits.
                                if (value.length == 6) {
                                  _verificarCodigo();
                                }
                              },
                            ),
                          ),
                          // Cajas decorativas — solo visual, sin input propio
                          GestureDetector(
                            onTap: () => _otpFocusNode.requestFocus(),
                            child: Row(
                              children: List.generate(6, (i) {
                                final hasDigit = _otpDigits[i].isNotEmpty;
                                final isCurrent =
                                    _otpDigits.where((d) => d.isNotEmpty).length == i;

                                return Expanded(
                                  child: Padding(
                                    padding:
                                        EdgeInsets.only(right: i < 5 ? 8 : 0),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: hasDigit
                                            ? _navy.withOpacity(0.06)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isCurrent
                                              ? _navy
                                              : hasDigit
                                                  ? _navy.withOpacity(0.3)
                                                  : Colors.transparent,
                                          width: isCurrent ? 2 : 1,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: hasDigit
                                          ? Text(
                                              _otpDigits[i],
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                                color: _navy,
                                              ),
                                            )
                                          : isCurrent
                                              // FIX #3: key estable para evitar
                                              // que el cursor se recree en cada
                                              // rebuild del StatefulBuilder.
                                              ? const _BlinkingCursor(
                                                  key: ValueKey('otp_cursor'),
                                                )
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
                    const SizedBox(height: 28),

                    // Botón verificar
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _verificandoCodigo ? null : _verificarCodigo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _navy.withOpacity(0.4),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _verificandoCodigo
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Verificar código',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _enviarSMS();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: _navy,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Reenviar código',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // FIX #7: verificar canRequestFocus antes de pedir foco para evitar
    // crashes si el nodo fue desconectado (app en background, etc.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_otpFocusNode.canRequestFocus) {
        _otpFocusNode.requestFocus();
      }
    });
  }

  // ─────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────
  String _ocultarNumero(String phone) {
    if (phone.length < 5) return phone;
    return '${phone.substring(0, phone.length - 4)}****';
  }

  String _mensajeErrorSMS(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'El número de teléfono no es válido';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos';
      case 'quota-exceeded':
        return 'Cuota de SMS superada. Intenta más tarde';
      default:
        return 'Error al enviar el SMS ($code)';
    }
  }

  String _mensajeErrorGuardar(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Ese correo ya está en uso por otra cuenta';
      case 'invalid-email':
        return 'El correo no es válido';
      case 'weak-password':
        return 'La contraseña es muy débil. Usa al menos 6 caracteres';
      case 'requires-recent-login':
        return 'Sesión expirada. Vuelve a iniciar sesión';
      default:
        return 'Error al guardar ($code)';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: _success,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}, '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Editar Cuenta',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildProfileHeader(),
                            const SizedBox(height: 24),
                            _buildVerificationBadge(),
                            const SizedBox(height: 28),
                            _buildCard(
                              title: 'Información personal',
                              icon: Icons.person_outline_rounded,
                              children: [
                                _buildTextField(
                                  controller: _nameController,
                                  label: 'Nombre completo',
                                  icon: Icons.badge_outlined,
                                  enabled: _verificado,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'El nombre es obligatorio';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                _buildTextField(
                                  controller: _emailController,
                                  label: 'Correo electrónico',
                                  icon: Icons.alternate_email_rounded,
                                  enabled: _verificado,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'El correo es obligatorio';
                                    }
                                    if (!v.contains('@')) {
                                      return 'Correo inválido';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildCard(
                              title: 'Contraseña',
                              icon: Icons.lock_outline_rounded,
                              subtitle: 'Deja vacío para no cambiarla',
                              children: [
                                _buildPasswordField(
                                  controller: _newPasswordController,
                                  label: 'Nueva contraseña',
                                  obscureText: _obscureNewPassword,
                                  enabled: _verificado,
                                  onToggle: () => setState(() =>
                                      _obscureNewPassword =
                                          !_obscureNewPassword),
                                ),
                                const SizedBox(height: 14),
                                _buildPasswordField(
                                  controller: _confirmPasswordController,
                                  label: 'Confirmar contraseña',
                                  obscureText: _obscureConfirmPassword,
                                  enabled: _verificado,
                                  onToggle: () => setState(() =>
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            _buildActionButton(),
                            if (_adminData != null) ...[
                              const SizedBox(height: 20),
                              _buildInfoCard(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // WIDGETS
  // ─────────────────────────────────────────────────────────
  Widget _buildProfileHeader() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_navy, _navyLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _navy.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: Icon(
              Icons.admin_panel_settings_rounded,
              size: 42,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _nameController.text.isNotEmpty
              ? _nameController.text
              : 'Super Admin',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _navy,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _emailController.text,
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildVerificationBadge() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _verificado
            ? _success.withOpacity(0.08)
            : _warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _verificado
              ? _success.withOpacity(0.3)
              : _warning.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _verificado
                  ? _success.withOpacity(0.15)
                  : _warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _verificado
                  ? Icons.verified_user_rounded
                  : Icons.lock_person_rounded,
              size: 18,
              color: _verificado ? _success : _warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _verificado
                      ? 'Identidad verificada'
                      : 'Verificación pendiente',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _verificado ? _success : _warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _verificado
                      ? 'Puedes editar tu información'
                      : 'Verifica tu identidad para editar',
                  style: TextStyle(
                    fontSize: 11,
                    color: _verificado
                        ? _success.withOpacity(0.8)
                        : _warning.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    String? subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _navy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: _navy),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: const TextStyle(
          fontSize: 14, color: _navy, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 13,
          color: enabled ? Colors.grey[600] : Colors.grey[400],
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(icon,
              size: 18, color: enabled ? _navy : Colors.grey[400]),
        ),
        filled: true,
        fillColor:
            enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _navy, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade100),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      style: const TextStyle(
          fontSize: 14, color: _navy, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 13,
          color: enabled ? Colors.grey[600] : Colors.grey[400],
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(Icons.lock_outline_rounded,
              size: 18, color: enabled ? _navy : Colors.grey[400]),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
            color: enabled ? Colors.grey[500] : Colors.grey[300],
          ),
          onPressed: enabled ? onToggle : null,
          splashRadius: 20,
        ),
        filled: true,
        fillColor:
            enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _navy, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade100),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (!_verificado) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _enviandoSMS ? null : _enviarSMS,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _navy.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _enviandoSMS
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sms_outlined, size: 20),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Verificar identidad por SMS',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Se enviará a ${_phoneNumber != null ? _ocultarNumero(_phoneNumber!) : 'tu número registrado'}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _navy.withOpacity(0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.save_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Guardar cambios',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: _enviandoSMS ? null : _enviarSMS,
            icon: Icon(Icons.refresh_rounded,
                size: 15, color: Colors.grey[500]),
            label: Text(
              'Verificar de nuevo',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    final createdAt = _adminData?['createdAt'] as Timestamp?;
    final updatedAt = _adminData?['updatedAt'] as Timestamp?;

    return Container(
      decoration: BoxDecoration(
        color: _navy.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _navy.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                'Detalles de la cuenta',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Rol', _adminData?['rol'] ?? 'superAdmin'),
          _buildInfoRow(
            'Teléfono',
            _phoneNumber != null
                ? _ocultarNumero(_phoneNumber!)
                : 'No registrado',
          ),
          if (createdAt != null)
            _buildInfoRow('Creado', _formatDate(createdAt.toDate())),
          if (updatedAt != null)
            _buildInfoRow('Actualizado', _formatDate(updatedAt.toDate())),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: _navy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget cursor parpadeante para la caja OTP activa
// FIX #3: es const-constructible para que pueda recibir una ValueKey estable
// y no se recree en cada rebuild del StatefulBuilder.
// ─────────────────────────────────────────────────────────────────────────────
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor({super.key});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
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
        width: 2,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}