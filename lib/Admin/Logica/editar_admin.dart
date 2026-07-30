import 'package:flutter/material.dart';
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
  final _formKey                   = GlobalKey<FormState>();
  final _nameController            = TextEditingController();
  final _emailController           = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController     = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading      = true;
  bool _isSaving       = false;
  bool _obscureCurrent = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;

  String?               _adminUid;
  Map<String, dynamic>? _adminData;

  late AnimationController _fadeController;
  late Animation<double>   _fadeAnimation;

  static const _navy      = Color(0xFF1E3A5F);
  static const _navyLight = Color(0xFF2D5080);
  static const _bg        = Color(0xFFF0F4F8);
  static const _success   = Color(0xFF16A34A);

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
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

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
          _nameController.text  = _adminData?['nombre'] ?? '';
          _emailController.text = _adminData?['email']  ?? user.email ?? '';
        });
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final wantsPasswordChange = _newPasswordController.text.isNotEmpty;
    if (wantsPasswordChange) {
      if (_currentPasswordController.text.isEmpty) {
        _showError('Ingresa tu contraseña actual para cambiarla');
        return;
      }
      if (_newPasswordController.text != _confirmPasswordController.text) {
        _showError('Las contraseñas nuevas no coinciden');
        return;
      }
      if (_newPasswordController.text.length < 6) {
        _showError('La nueva contraseña debe tener al menos 6 caracteres');
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('No hay sesión activa');
        return;
      }

      final nuevoEmail  = _emailController.text.trim();
      final emailCambia = nuevoEmail != (user.email ?? '');

      if (wantsPasswordChange || emailCambia) {
        if (_currentPasswordController.text.isEmpty) {
          _showError('Ingresa tu contraseña actual para guardar los cambios');
          setState(() => _isSaving = false);
          return;
        }
        final credential = EmailAuthProvider.credential(
          email:    user.email!,
          password: _currentPasswordController.text,
        );
        await user.reauthenticateWithCredential(credential);
        debugPrint('✅ Reautenticación exitosa');
      }

      if (wantsPasswordChange) {
        await user.updatePassword(_newPasswordController.text);
        debugPrint('✅ Contraseña actualizada');
      }

      if (emailCambia) {
        await user.verifyBeforeUpdateEmail(nuevoEmail);
        _showSuccess(
          'Se envió un correo a $nuevoEmail para confirmar el cambio.',
        );
      }

      await FirebaseFirestore.instance
          .collection('superadmins')
          .doc(_adminUid)
          .update({
        'nombre':    _nameController.text.trim(),
        if (!emailCambia) 'email': nuevoEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await PrefsHelper.saveUserData(
        userType: 'superAdmin',
        userName: _nameController.text.trim(),
        userId:   _adminUid!,
      );

      if (mounted) {
        if (!emailCambia) _showSuccess('Datos actualizados exitosamente');
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
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

  String _mensajeErrorGuardar(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Contraseña actual incorrecta';
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

  String _formatDate(DateTime date) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}, '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    ));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: _success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 16),
            ),
          ),
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
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.only(
                      topLeft:  Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft:  Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          28,
                          20,
                          MediaQuery.of(context).viewInsets.bottom + 40,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildProfileHeader(),
                              const SizedBox(height: 28),
                              _buildCard(
                                title: 'Información personal',
                                icon: Icons.person_outline_rounded,
                                children: [
                                  _buildTextField(
                                    controller: _nameController,
                                    label:      'Nombre completo',
                                    icon:       Icons.badge_outlined,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'El nombre es obligatorio';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _buildTextField(
                                    controller:   _emailController,
                                    label:        'Correo electrónico',
                                    icon:         Icons.alternate_email_rounded,
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
                                title:    'Contraseña',
                                icon:     Icons.lock_outline_rounded,
                                subtitle: 'Rellena solo si deseas cambiarla',
                                children: [
                                  _buildPasswordField(
                                    controller: _currentPasswordController,
                                    label:      'Contraseña actual',
                                    obscure:    _obscureCurrent,
                                    onToggle:   () => setState(
                                        () => _obscureCurrent = !_obscureCurrent),
                                  ),
                                  const SizedBox(height: 14),
                                  _buildPasswordField(
                                    controller: _newPasswordController,
                                    label:      'Nueva contraseña',
                                    obscure:    _obscureNew,
                                    onToggle:   () => setState(
                                        () => _obscureNew = !_obscureNew),
                                  ),
                                  const SizedBox(height: 14),
                                  _buildPasswordField(
                                    controller: _confirmPasswordController,
                                    label:      'Confirmar nueva contraseña',
                                    obscure:    _obscureConfirm,
                                    onToggle:   () => setState(
                                        () => _obscureConfirm = !_obscureConfirm),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveChanges,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _navy,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        _navy.withValues(alpha: 0.5),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
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
      ),
    );
  }

  Widget _buildProfileHeader() {
    final name = _nameController.text.isNotEmpty
        ? _nameController.text
        : 'Super Admin';
    final email = _emailController.text;

    return Column(children: [
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
              color:      _navy.withValues(alpha: 0.25),
              blurRadius: 20,
              offset:     const Offset(0, 8),
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Icon(Icons.admin_panel_settings_rounded,
              size: 42, color: Colors.white),
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _navy,
            letterSpacing: -0.4,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(height: 2),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          email,
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
  }

  Widget _buildCard({
    required String       title,
    required IconData     icon,
    required List<Widget> children,
    String?               subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _navy.withValues(alpha: 0.08),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
    required String                label,
    required IconData              icon,
    TextInputType?                 keyboardType,
    String? Function(String?)?     validator,
  }) {
    return TextFormField(
      controller:    controller,
      keyboardType:  keyboardType,
      maxLines:      1,
      style: const TextStyle(
          fontSize: 14, color: _navy, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4),
          child:   Icon(icon, size: 18, color: _navy),
        ),
        filled:         true,
        fillColor:      const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _navy, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String                label,
    required bool                  obscure,
    required VoidCallback          onToggle,
  }) {
    return TextFormField(
      controller:  controller,
      obscureText: obscure,
      maxLines:    1,
      style: const TextStyle(
          fontSize: 14, color: _navy, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 4),
          child:   Icon(Icons.lock_outline_rounded, size: 18, color: _navy),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
            color: Colors.grey[500],
          ),
          onPressed: onToggle,
          padding:   const EdgeInsets.all(12),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
        filled:         true,
        fillColor:      const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _navy, width: 1.5)),
      ),
    );
  }

  Widget _buildInfoCard() {
    final createdAt = _adminData?['createdAt'] as Timestamp?;
    final updatedAt = _adminData?['updatedAt'] as Timestamp?;
    final rol       = (_adminData?['rol'] as String?) ?? 'superAdmin';

    return Container(
      decoration: BoxDecoration(
        color: _navy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _navy.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline_rounded,
                size: 14, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Detalles de la cuenta',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _buildInfoRow('Rol', rol),
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
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}