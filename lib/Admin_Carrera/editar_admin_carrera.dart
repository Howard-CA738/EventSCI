import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import 'admin_carrera_service.dart';

class EditarAdminCarreraScreen extends StatefulWidget {
  const EditarAdminCarreraScreen({super.key});

  @override
  State<EditarAdminCarreraScreen> createState() =>
      _EditarAdminCarreraScreenState();
}

class _EditarAdminCarreraScreenState extends State<EditarAdminCarreraScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _passwordActualController = TextEditingController();
  final _passwordNuevaController = TextEditingController();
  final _passwordConfirmarController = TextEditingController();

  final AdminCarreraService _service = AdminCarreraService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscurePasswordActual = true;
  bool _obscurePasswordNueva = true;
  bool _obscurePasswordConfirmar = true;

  String _adminId = '';
  String _carrera = '';
  String _facultad = '';
  String _sede = '';
  String _passwordActual = '';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadAdminData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _usuarioController.dispose();
    _passwordActualController.dispose();
    _passwordNuevaController.dispose();
    _passwordConfirmarController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData != null) {
        final adminCompleto = await _service.getAdminById(adminData['userId']);
        if (adminCompleto != null) {
          setState(() {
            _adminId = adminCompleto['id'];
            _usuarioController.text = adminCompleto['usuario'] ?? '';
            _carrera = adminCompleto['carrera'] ?? '';
            _facultad = adminCompleto['facultad'] ?? '';
            _sede = adminCompleto['filialNombre'] ?? '';
            _passwordActual = adminCompleto['password'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      _showMessage('Error al cargar datos', isError: true);
    }
    setState(() => _isLoading = false);
    _fadeController.forward();
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordNuevaController.text.isNotEmpty) {
      if (_passwordActualController.text != _passwordActual) {
        _showMessage('La contraseña actual es incorrecta', isError: true);
        return;
      }
      if (_passwordNuevaController.text != _passwordConfirmarController.text) {
        _showMessage('Las contraseñas nuevas no coinciden', isError: true);
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final success = await _service.actualizarAdminCarrera(
        adminId: _adminId,
        usuario: _usuarioController.text.trim(),
        password: _passwordNuevaController.text.isNotEmpty
            ? _passwordNuevaController.text
            : null,
      );

      if (success) {
        await PrefsHelper.saveAdminCarreraData(
          userId: _adminId,
          userName: _usuarioController.text.trim(),
          filial: (await PrefsHelper.getAdminCarreraFilial())!,
          filialNombre: (await PrefsHelper.getAdminCarreraFilialNombre())!,
          facultad: (await PrefsHelper.getAdminCarreraFacultad())!,
          carrera: (await PrefsHelper.getAdminCarreraCarrera())!,
          carreraId: (await PrefsHelper.getAdminCarreraCarreraId())!,
          permisos: await PrefsHelper.getAdminCarreraPermisos(),
        );

        _showMessage('Datos actualizados correctamente');
        _passwordActualController.clear();
        _passwordNuevaController.clear();
        _passwordConfirmarController.clear();
        await _loadAdminData();
      } else {
        _showMessage('Ya existe otro admin con ese usuario', isError: true);
      }
    } catch (e) {
      debugPrint('Error guardando cambios: $e');
      _showMessage('Error: $e', isError: true);
    }

    setState(() => _isSaving = false);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFD4453B) : const Color(0xFF2E9E6E),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 6,
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2F7),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1E3A5F),
                          strokeWidth: 2.5,
                        ),
                      )
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: SingleChildScrollView(
                          padding:
                              const EdgeInsets.fromLTRB(16, 24, 16, 36),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                _buildCarreraCard(),
                                const SizedBox(height: 14),
                                _buildCuentaCard(),
                                const SizedBox(height: 14),
                                _buildPasswordCard(),
                                const SizedBox(height: 24),
                                _buildBotonGuardar(),
                              ],
                            ),
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

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.manage_accounts_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Editar Cuenta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                'Administrador de Carrera',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tarjeta carrera asignada (solo lectura) ──────────────────────────────
  Widget _buildCarreraCard() {
    return _buildCard(
      headerIcon: Icons.school_rounded,
      headerColor: const Color(0xFF3B6FD4),
      headerTitle: 'Carrera Asignada',
      headerSubtitle: 'Información de solo lectura',
      child: Column(
        children: [
          _buildInfoTile(
            icon: Icons.location_city_rounded,
            label: 'Sede',
            value: _sede,
            color: const Color(0xFF3B6FD4),
          ),
          _buildDivider(),
          _buildInfoTile(
            icon: Icons.business_rounded,
            label: 'Facultad',
            value: _facultad,
            color: const Color(0xFF3B6FD4),
          ),
          _buildDivider(),
          _buildInfoTile(
            icon: Icons.school_rounded,
            label: 'Carrera',
            value: _carrera,
            color: const Color(0xFF3B6FD4),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta datos de cuenta ──────────────────────────────────────────────
  Widget _buildCuentaCard() {
    return _buildCard(
      headerIcon: Icons.person_rounded,
      headerColor: const Color(0xFFD4863B),
      headerTitle: 'Datos de la Cuenta',
      headerSubtitle: 'Actualiza tu nombre de usuario',
      child: TextFormField(
        controller: _usuarioController,
        decoration: _inputDecoration(
          label: 'Usuario',
          icon: Icons.account_circle_rounded,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'El usuario es requerido';
          }
          if (value.trim().length < 4) return 'Mínimo 4 caracteres';
          return null;
        },
      ),
    );
  }

  // ── Tarjeta cambiar contraseña ───────────────────────────────────────────
  Widget _buildPasswordCard() {
    return _buildCard(
      headerIcon: Icons.lock_rounded,
      headerColor: const Color(0xFF8B4DC7),
      headerTitle: 'Cambiar Contraseña',
      headerSubtitle:
          'Deja los campos vacíos si no deseas cambiarla',
      child: Column(
        children: [
          // Contraseña actual
          TextFormField(
            controller: _passwordActualController,
            obscureText: _obscurePasswordActual,
            decoration: _inputDecoration(
              label: 'Contraseña actual',
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePasswordActual
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.grey[500],
                  size: 20,
                ),
                onPressed: () => setState(
                    () => _obscurePasswordActual = !_obscurePasswordActual),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Nueva contraseña
          TextFormField(
            controller: _passwordNuevaController,
            obscureText: _obscurePasswordNueva,
            decoration: _inputDecoration(
              label: 'Nueva contraseña',
              icon: Icons.lock_reset_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePasswordNueva
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.grey[500],
                  size: 20,
                ),
                onPressed: () => setState(
                    () => _obscurePasswordNueva = !_obscurePasswordNueva),
              ),
            ),
            validator: (value) {
              if (_passwordActualController.text.isNotEmpty) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa la nueva contraseña';
                }
                if (value.length < 6) return 'Mínimo 6 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Confirmar contraseña
          TextFormField(
            controller: _passwordConfirmarController,
            obscureText: _obscurePasswordConfirmar,
            decoration: _inputDecoration(
              label: 'Confirmar nueva contraseña',
              icon: Icons.check_circle_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePasswordConfirmar
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.grey[500],
                  size: 20,
                ),
                onPressed: () => setState(() =>
                    _obscurePasswordConfirmar = !_obscurePasswordConfirmar),
              ),
            ),
            validator: (value) {
              if (_passwordNuevaController.text.isNotEmpty) {
                if (value == null || value.isEmpty) {
                  return 'Confirma la contraseña';
                }
              }
              return null;
            },
          ),

          // Indicador de seguridad (visual)
          if (_passwordNuevaController.text.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildPasswordStrength(_passwordNuevaController.text),
          ],
        ],
      ),
    );
  }

  // ── Indicador fuerza de contraseña ───────────────────────────────────────
  Widget _buildPasswordStrength(String password) {
    int strength = 0;
    if (password.length >= 6) strength++;
    if (password.length >= 10) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#\$&*~]'))) strength++;

    final labels = ['Muy débil', 'Débil', 'Regular', 'Fuerte', 'Muy fuerte'];
    final colors = [
      const Color(0xFFD4453B),
      const Color(0xFFD4863B),
      const Color(0xFFD4C43B),
      const Color(0xFF2E9E6E),
      const Color(0xFF1E7A52),
    ];
    final idx = (strength - 1).clamp(0, 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i < strength
                      ? colors[idx]
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          'Seguridad: ${labels[idx]}',
          style: TextStyle(
            fontSize: 11,
            color: colors[idx],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── Botón guardar ─────────────────────────────────────────────────────────
  Widget _buildBotonGuardar() {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _guardarCambios,
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.save_rounded, size: 20),
        label: Text(
          _isSaving ? 'Guardando...' : 'Guardar Cambios',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFCBD5E1),
          disabledForegroundColor: Colors.white70,
          elevation: _isSaving ? 0 : 4,
          shadowColor: const Color(0xFF1E3A5F).withValues(alpha: 0.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────
  Widget _buildCard({
    required IconData headerIcon,
    required Color headerColor,
    required String headerTitle,
    required String headerSubtitle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de sección
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: headerColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(headerIcon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      Text(
                        headerSubtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value.isNotEmpty ? value : '—',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E3A5F),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(height: 1, color: const Color(0xFFE8EDF5)),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F), size: 20),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD4453B)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD4453B), width: 1.5),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}