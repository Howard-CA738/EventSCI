import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import 'estudiantes_registrados_carrera_screen.dart';
import '/shared/pantallas/datos_excel_screen.dart';
import '../logica/estudiante_username_helper.dart';

class RegistroEstudiantesCarreraScreen extends StatefulWidget {
  const RegistroEstudiantesCarreraScreen({super.key});

  @override
  State<RegistroEstudiantesCarreraScreen> createState() =>
      _RegistroEstudiantesCarreraScreenState();
}

class _RegistroEstudiantesCarreraScreenState
    extends State<RegistroEstudiantesCarreraScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _codigoEstudianteController = TextEditingController();
  final _documentoController = TextEditingController();
  final _correoController = TextEditingController();
  final _celularController = TextEditingController();
  final _usernameController = TextEditingController();

  late AnimationController _headerAnimationController;
  late AnimationController _formAnimationController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<double> _formFadeAnimation;

  String _adminCarreraFilialNombre = '';
  String _adminCarreraFacultad = '';
  String _adminCarreraCarrera = '';

  bool _isLoading = false;
  bool _isLoadingAdminData = true;

  String? _selectedCiclo;
  String? _selectedGrupo;

  final List<String> _ciclos = [
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10'
  ];
  final List<String> _grupos = ['Único', '1', '2', '3', '4'];

  static const Color _primaryColor = Color(0xFF1E3A5F);

  @override
  void initState() {
    super.initState();

    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _formAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeOut,
      ),
    );
    _headerSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _headerAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _formFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _formAnimationController, curve: Curves.easeIn),
    );

    _headerAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _formAnimationController.forward();
    });

    _nombresController.addListener(_generateUsernameSuggestion);
    _apellidosController.addListener(_generateUsernameSuggestion);
    _correoController.addListener(_extractUsernameFromEmail);

    _loadAdminCarreraData();
  }

  Future<void> _loadAdminCarreraData() async {
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData != null && mounted) {
        setState(() {
          _adminCarreraFilialNombre =
              adminData['filialNombre'] ?? adminData['filial'] ?? '';
          _adminCarreraFacultad = adminData['facultad'] ?? '';
          _adminCarreraCarrera = adminData['carrera'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos admin carrera: $e');
    }
    if (mounted) setState(() => _isLoadingAdminData = false);
  }

  void _extractUsernameFromEmail() {
    if (_usernameController.text.isEmpty) {
      final username =
          extraerUsernameDeCorreo(_correoController.text.trim());
      if (username.isNotEmpty) _usernameController.text = username;
    }
  }

  void _generateUsernameSuggestion() {
    if (_usernameController.text.isEmpty) {
      final suggestion = generarUsernameDesdeNombres(
        _nombresController.text.trim(),
        _apellidosController.text.trim(),
      );
      if (suggestion.isNotEmpty) _usernameController.text = suggestion;
    }
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _formAnimationController.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _codigoEstudianteController.dispose();
    _documentoController.dispose();
    _correoController.dispose();
    _celularController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _createStudent() async {
    if (!_formKey.currentState!.validate()) return;

    final fullName =
        '${_nombresController.text.trim()} ${_apellidosController.text.trim()}';
    final username = _usernameController.text.trim().toLowerCase();

    setState(() => _isLoading = true);

    try {
      final success = await PrefsHelper.createStudentAccountWithUsername(
        email: _correoController.text.trim(),
        name: fullName,
        username: username,
        codigoUniversitario: _codigoEstudianteController.text.trim(),
        dni: _documentoController.text.trim(),
        facultad: _adminCarreraFacultad,
        carrera: _adminCarreraCarrera,
        filial: _adminCarreraFilialNombre,
        ciclo: _selectedCiclo,
        grupo: _selectedGrupo,
        celular: _celularController.text.trim(),
      );

      if (success) {
        _showMessage('✅ Estudiante $fullName creado exitosamente');
        _clearForm();
      } else {
        _showMessage('Error: ya existe un usuario con esos datos');
      }
    } catch (e) {
      _showMessage('Error creando estudiante: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _clearForm() {
    _nombresController.clear();
    _apellidosController.clear();
    _codigoEstudianteController.clear();
    _documentoController.clear();
    _correoController.clear();
    _celularController.clear();
    _usernameController.clear();
    if (mounted) {
      setState(() {
        _selectedCiclo = null;
        _selectedGrupo = null;
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? hintText,
    bool readOnly = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: Icon(icon, color: _primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: readOnly ? Colors.grey.shade200 : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: readOnly ? Colors.grey.shade300 : _primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: _fieldDecoration(label: label, icon: icon, hintText: hintText),
      validator: validator,
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return AbsorbPointer(
      child: TextFormField(
        key: ValueKey('$label:$value'),
        initialValue: value.isNotEmpty ? value : '—',
        readOnly: true,
        decoration: _fieldDecoration(label: label, icon: icon, readOnly: true),
        style: TextStyle(color: Colors.grey.shade600),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      items: items,
      onChanged: onChanged,
      dropdownColor: Colors.white,
      menuMaxHeight: 300,
      icon: const Icon(Icons.arrow_drop_down, color: _primaryColor),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: _primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    final buttonStyle = isPrimary
        ? ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            elevation: 3,
            shadowColor: _primaryColor.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size(double.infinity, 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          )
        : null;

    final outlinedStyle = OutlinedButton.styleFrom(
      foregroundColor: _primaryColor,
      side: const BorderSide(color: _primaryColor, width: 2),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      minimumSize: const Size(double.infinity, 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );

    final labelWidget = Text(
      label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );

    if (isPrimary) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 22),
          label: labelWidget,
          style: buttonStyle,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: labelWidget,
        style: outlinedStyle,
      ),
    );
  }

  Widget _buildHeader() {
    return SlideTransition(
      position: _headerSlideAnimation,
      child: FadeTransition(
        opacity: _headerFadeAnimation,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Hero(
                tag: 'logo',
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person_add,
                      color: _primaryColor,
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Registro de Estudiantes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      _adminCarreraCarrera.isNotEmpty
                          ? _adminCarreraCarrera
                          : 'Cargando...',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Semantics(
                label: 'Importar Excel',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.file_upload,
                      color: Colors.white, size: 24),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DatosExcelScreen()),
                  ),
                  tooltip: 'Importar Excel',
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
              ),
              Semantics(
                label: 'Ver estudiantes registrados',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.list, color: Colors.white, size: 24),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const EstudiantesRegistradosCarreraScreen()),
                  ),
                  tooltip: 'Ver registrados',
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.blue.shade50,
          Colors.blue.shade100,
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade300, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Registrando para: $_adminCarreraCarrera',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$_adminCarreraFacultad · $_adminCarreraFilialNombre',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCicloGrupoRow(double availableWidth) {
    final useColumn = availableWidth < 340;

    final cicloDropdown = _buildDropdown<String>(
      label: 'Ciclo',
      icon: Icons.layers,
      value: _selectedCiclo,
      items: _ciclos
          .map((c) => DropdownMenuItem(value: c, child: Text('Ciclo $c')))
          .toList(),
      onChanged: (v) => setState(() => _selectedCiclo = v),
    );

    final grupoDropdown = _buildDropdown<String>(
      label: 'Grupo',
      icon: Icons.groups,
      value: _selectedGrupo,
      items: _grupos
          .map((g) => DropdownMenuItem(value: g, child: Text('Grupo $g')))
          .toList(),
      onChanged: (v) => setState(() => _selectedGrupo = v),
    );

    if (useColumn) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          cicloDropdown,
          const SizedBox(height: 16),
          grupoDropdown,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: cicloDropdown),
        const SizedBox(width: 16),
        Expanded(child: grupoDropdown),
      ],
    );
  }

  Widget _buildLoadingBody(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _primaryColor),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: _primaryColor, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FadeTransition(
                opacity: _formFadeAnimation,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8EDF2),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: _isLoading || _isLoadingAdminData
                      ? _buildLoadingBody(
                          _isLoading ? 'Creando estudiante...' : 'Cargando...')
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                MediaQuery.of(context).viewInsets.bottom + 24,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildInfoBanner(),
                                    const SizedBox(height: 20),
                                    _buildSectionCard(
                                      title: 'Información Personal',
                                      icon: Icons.person,
                                      children: [
                                        _buildTextField(
                                          controller: _nombresController,
                                          label: 'Nombres',
                                          icon: Icons.person,
                                          validator: (v) =>
                                              (v == null || v.trim().isEmpty)
                                                  ? 'Los nombres son requeridos'
                                                  : null,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _apellidosController,
                                          label: 'Apellidos',
                                          icon: Icons.person_outline,
                                          validator: (v) =>
                                              (v == null || v.trim().isEmpty)
                                                  ? 'Los apellidos son requeridos'
                                                  : null,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _usernameController,
                                          label: 'Usuario',
                                          icon: Icons.account_circle,
                                          hintText: 'Ej: juan.perez',
                                          onChanged: (value) {
                                            final cleaned =
                                                limpiarUsername(value);
                                            if (cleaned != value) {
                                              _usernameController.value =
                                                  TextEditingValue(
                                                text: cleaned,
                                                selection:
                                                    TextSelection.collapsed(
                                                        offset:
                                                            cleaned.length),
                                              );
                                            }
                                          },
                                          validator: (v) {
                                            if (v == null ||
                                                v.trim().isEmpty) {
                                              return 'El usuario es requerido';
                                            }
                                            if (v.trim().length < 3) {
                                              return 'Mínimo 3 caracteres';
                                            }
                                            if (!RegExp(r'^[a-z0-9.]+$')
                                                .hasMatch(v.trim())) {
                                              return 'Solo letras minúsculas, números y puntos';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _documentoController,
                                          label: 'Documento (DNI)',
                                          icon: Icons.credit_card,
                                          keyboardType: TextInputType.number,
                                          validator: (v) => (v == null ||
                                                  v.trim().isEmpty)
                                              ? 'El documento es requerido'
                                              : null,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    _buildSectionCard(
                                      title: 'Información de Contacto',
                                      icon: Icons.contact_phone,
                                      children: [
                                        _buildTextField(
                                          controller: _correoController,
                                          label: 'Correo electrónico',
                                          icon: Icons.email,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          validator: (v) {
                                            if (v != null &&
                                                v.trim().isNotEmpty) {
                                              if (!RegExp(
                                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                                  .hasMatch(v)) {
                                                return 'Ingresa un correo válido';
                                              }
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _celularController,
                                          label: 'Celular',
                                          icon: Icons.phone,
                                          keyboardType: TextInputType.phone,
                                          validator: (v) {
                                            if (v != null &&
                                                v.trim().isNotEmpty) {
                                              if (v.trim().length != 9) {
                                                return 'El celular debe tener 9 dígitos';
                                              }
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    _buildSectionCard(
                                      title: 'Información Académica',
                                      icon: Icons.school,
                                      children: [
                                        _buildTextField(
                                          controller:
                                              _codigoEstudianteController,
                                          label: 'Código estudiante',
                                          icon: Icons.badge,
                                          hintText: 'Ej: 202320800',
                                          validator: (_) => null,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildReadOnlyField(
                                          label: 'Sede',
                                          value: _adminCarreraFilialNombre,
                                          icon: Icons.location_city,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildReadOnlyField(
                                          label: 'Facultad',
                                          value: _adminCarreraFacultad,
                                          icon: Icons.account_balance,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildReadOnlyField(
                                          label: 'Carrera',
                                          value: _adminCarreraCarrera,
                                          icon: Icons.menu_book,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildCicloGrupoRow(
                                            constraints.maxWidth - 40),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    _buildActionButton(
                                      label: 'Crear Estudiante',
                                      icon: Icons.person_add,
                                      onPressed: _createStudent,
                                      isPrimary: true,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildActionButton(
                                      label: 'Importar desde Excel',
                                      icon: Icons.file_upload,
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const DatosExcelScreen()),
                                      ),
                                      isPrimary: false,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildActionButton(
                                      label: 'Ver Estudiantes Registrados',
                                      icon: Icons.list,
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const EstudiantesRegistradosCarreraScreen()),
                                      ),
                                      isPrimary: false,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
