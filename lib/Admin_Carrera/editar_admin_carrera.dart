import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import 'admin_carrera_service.dart';

class EditarAdminCarreraScreen extends StatefulWidget {
  const EditarAdminCarreraScreen({super.key});

  @override
  State<EditarAdminCarreraScreen> createState() =>
      _EditarAdminCarreraScreenState();
}

class _EditarAdminCarreraScreenState extends State<EditarAdminCarreraScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);

    try {
      final adminData = await PrefsHelper.getAdminCarreraData();

      if (adminData != null) {
        final adminCompleto =
            await _service.getAdminById(adminData['userId']);

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
      print('Error cargando datos: $e');
      _showMessage('Error al cargar datos', isError: true);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordNuevaController.text.isNotEmpty) {
      if (_passwordActualController.text != _passwordActual) {
        _showMessage('La contraseña actual es incorrecta', isError: true);
        return;
      }
      if (_passwordNuevaController.text !=
          _passwordConfirmarController.text) {
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
          filialNombre:
              (await PrefsHelper.getAdminCarreraFilialNombre())!,
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
        _showMessage('Ya existe otro admin con ese usuario',
            isError: true);
      }
    } catch (e) {
      print('Error guardando cambios: $e');
      _showMessage('Error: $e', isError: true);
    }

    setState(() => _isSaving = false);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordActualController.dispose();
    _passwordNuevaController.dispose();
    _passwordConfirmarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Editar Cuenta',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Info carrera (solo lectura)
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.info_outline,
                                              color: Colors.blue[700],
                                              size: 20),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Carrera Asignada',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E3A5F),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildInfoRow(
                                          Icons.location_city, 'Sede', _sede),
                                      const Divider(height: 16),
                                      _buildInfoRow(Icons.business,
                                          'Facultad', _facultad),
                                      const Divider(height: 16),
                                      _buildInfoRow(
                                          Icons.school, 'Carrera', _carrera),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Datos de la cuenta
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.manage_accounts,
                                              color: Color(0xFF1E3A5F),
                                              size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Datos de la Cuenta',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E3A5F),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Usuario
                                      TextFormField(
                                        controller: _usuarioController,
                                        decoration: InputDecoration(
                                          labelText: 'Usuario',
                                          prefixIcon: const Icon(
                                              Icons.account_circle),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'El usuario es requerido';
                                          }
                                          if (value.trim().length < 4) {
                                            return 'Mínimo 4 caracteres';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Cambiar contraseña
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.lock,
                                              color: Color(0xFF1E3A5F),
                                              size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Cambiar Contraseña',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E3A5F),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Deja los campos vacíos si no deseas cambiar la contraseña',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                      ),
                                      const SizedBox(height: 16),

                                      // Contraseña actual
                                      TextFormField(
                                        controller:
                                            _passwordActualController,
                                        obscureText: _obscurePasswordActual,
                                        decoration: InputDecoration(
                                          labelText: 'Contraseña actual',
                                          prefixIcon:
                                              const Icon(Icons.lock),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePasswordActual
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                            ),
                                            onPressed: () => setState(() {
                                              _obscurePasswordActual =
                                                  !_obscurePasswordActual;
                                            }),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // Nueva contraseña
                                      TextFormField(
                                        controller: _passwordNuevaController,
                                        obscureText: _obscurePasswordNueva,
                                        decoration: InputDecoration(
                                          labelText: 'Nueva contraseña',
                                          prefixIcon: const Icon(
                                              Icons.lock_outline),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePasswordNueva
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                            ),
                                            onPressed: () => setState(() {
                                              _obscurePasswordNueva =
                                                  !_obscurePasswordNueva;
                                            }),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (_passwordActualController
                                              .text.isNotEmpty) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Ingresa la nueva contraseña';
                                            }
                                            if (value.length < 6) {
                                              return 'Mínimo 6 caracteres';
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),

                                      // Confirmar contraseña
                                      TextFormField(
                                        controller:
                                            _passwordConfirmarController,
                                        obscureText:
                                            _obscurePasswordConfirmar,
                                        decoration: InputDecoration(
                                          labelText:
                                              'Confirmar nueva contraseña',
                                          prefixIcon: const Icon(
                                              Icons.lock_outline),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePasswordConfirmar
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                            ),
                                            onPressed: () => setState(() {
                                              _obscurePasswordConfirmar =
                                                  !_obscurePasswordConfirmar;
                                            }),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (_passwordNuevaController
                                              .text.isNotEmpty) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Confirma la contraseña';
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Botón guardar
                              SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed:
                                      _isSaving ? null : _guardarCambios,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF1E3A5F),
                                    foregroundColor: Colors.white,
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.save, size: 22),
                                            SizedBox(width: 8),
                                            Text(
                                              'Guardar Cambios',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A5F),
            ),
          ),
        ),
      ],
    );
  }
}