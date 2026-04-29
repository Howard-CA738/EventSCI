import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import 'estudiantes_registrados_carrera.dart';
import '/admin/logica/datos_excel.dart';

/// Pantalla de registro de estudiantes exclusiva para el Admin de Carrera.
/// No consulta Firebase para cargar filiales — usa directamente los datos
/// del admin ya almacenados en PrefsHelper, por lo que carga de forma instantánea.
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

  // ── Datos del admin (ya disponibles sin llamadas a Firebase) ──────────────
  String _adminCarreraFilial = '';
  String _adminCarreraFilialNombre = '';
  String _adminCarreraFacultad = '';
  String _adminCarreraCarrera = '';

  bool _isLoading = false;
  bool _isLoadingAdminData = true; // Solo carga los prefs locales (muy rápido)

  String? _selectedModoContrato;
  String? _selectedModalidadEstudio;
  String? _selectedCiclo;
  String? _selectedGrupo;
  String? _selectedPago;

  final List<String> _modosContrato = ['Regular', 'Convenio', 'Especial'];
  final List<String> _modalidadesEstudio = [
    'Presencial',
    'Semipresencial',
    'Virtual',
  ];
  final List<String> _ciclos = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'];
  final List<String> _grupos = ['Único', '1', '2', '3', '4'];
  final List<Map<String, dynamic>> _opcionesPago = [
    {'valor': 'Si', 'label': 'Pagado', 'icon': Icons.check_circle, 'color': Color(0xFF16A34A)},
    {'valor': 'Pendiente', 'label': 'Pendiente', 'icon': Icons.schedule, 'color': Color(0xFFD97706)},
  ];

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
      _formAnimationController.forward();
    });

    _nombresController.addListener(_generateUsernameSuggestion);
    _apellidosController.addListener(_generateUsernameSuggestion);
    _correoController.addListener(_extractUsernameFromEmail);

    // Carga solo desde SharedPreferences — sin Firebase, sin demora
    _loadAdminCarreraData();
  }

  // ═══════════════════════════════════════════════════════════════
  // Carga los datos del admin desde prefs locales (sin red)
  // ═══════════════════════════════════════════════════════════════
  Future<void> _loadAdminCarreraData() async {
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData != null) {
        setState(() {
          _adminCarreraFilial = adminData['filial'] ?? '';
          _adminCarreraFilialNombre = adminData['filialNombre'] ?? adminData['filial'] ?? '';
          _adminCarreraFacultad = adminData['facultad'] ?? '';
          _adminCarreraCarrera = adminData['carrera'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos admin carrera: $e');
    }
    setState(() => _isLoadingAdminData = false);
  }

  // ── Username helpers ──────────────────────────────────────────────────────

  void _extractUsernameFromEmail() {
    final correo = _correoController.text.trim();
    if (correo.contains('@upeu.edu.pe') && _usernameController.text.isEmpty) {
      final username = correo.split('@')[0];
      if (username.isNotEmpty) _usernameController.text = username;
    }
  }

  void _generateUsernameSuggestion() {
    if (_usernameController.text.isEmpty) {
      final suggestion = _generateUsernameFromNamesAndSurnames(
        _nombresController.text.trim(),
        _apellidosController.text.trim(),
      );
      if (suggestion.isNotEmpty) _usernameController.text = suggestion;
    }
  }

  String _generateUsernameFromNamesAndSurnames(String nombres, String apellidos) {
    if (nombres.isEmpty && apellidos.isEmpty) return '';
    final n = nombres.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();
    final a = apellidos.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();
    String username = n.isNotEmpty ? n[0] : '';
    if (a.isNotEmpty) username += username.isNotEmpty ? '.${a[0]}' : a[0];
    return _cleanUsername(username);
  }

  String _cleanUsername(String input) {
    const accents = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n', 'ç': 'c',
    };
    String cleaned = input.toLowerCase();
    accents.forEach((k, v) => cleaned = cleaned.replaceAll(k, v));
    return cleaned.replaceAll(RegExp(r'[^a-z0-9.]'), '');
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

  // ═══════════════════════════════════════════════════════════════
  // Crear estudiante — usa los datos fijos del admin sin consultas adicionales
  // ═══════════════════════════════════════════════════════════════
  Future<void> _createStudent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPago == null) {
      _showMessage('Por favor selecciona el estado de pago');
      return;
    }

    final fullName =
        '${_nombresController.text.trim()} ${_apellidosController.text.trim()}';
    final username = _usernameController.text.trim().toLowerCase();

    setState(() => _isLoading = true);

    try {
      debugPrint('🔍 Creando estudiante (admin carrera):');
      debugPrint('   Filial: $_adminCarreraFilial ($_adminCarreraFilialNombre)');
      debugPrint('   Facultad: $_adminCarreraFacultad');
      debugPrint('   Carrera: $_adminCarreraCarrera');
      debugPrint('   Username: $username');

      final success = await PrefsHelper.createStudentAccountWithUsername(
        email: _correoController.text.trim(),
        name: fullName,
        username: username,
        codigoUniversitario: _codigoEstudianteController.text.trim(),
        dni: _documentoController.text.trim(),
        facultad: _adminCarreraFacultad,
        carrera: _adminCarreraCarrera,
        filial: _adminCarreraFilialNombre, 
        modoContrato: _selectedModoContrato,
        modalidadEstudio: _selectedModalidadEstudio,
        ciclo: _selectedCiclo,
        grupo: _selectedGrupo,
        celular: _celularController.text.trim(),
        pago: _selectedPago,
      );

      if (success) {
        _showMessage('✅ Estudiante $fullName creado exitosamente');
        _clearForm();
      } else {
        _showMessage('Error: ya existe un usuario con esos datos');
      }
    } catch (e) {
      debugPrint('❌ Error creando estudiante: $e');
      _showMessage('Error creando estudiante: $e');
    }

    setState(() => _isLoading = false);
  }

  void _clearForm() {
    _nombresController.clear();
    _apellidosController.clear();
    _codigoEstudianteController.clear();
    _documentoController.clear();
    _correoController.clear();
    _celularController.clear();
    _usernameController.clear();
    setState(() {
      _selectedModoContrato = null;
      _selectedModalidadEstudio = null;
      _selectedCiclo = null;
      _selectedGrupo = null;
      _selectedPago = null;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1E3A5F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Widgets reutilizables ─────────────────────────────────────────────────

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
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
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
          borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
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
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
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
          borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      items: items,
      onChanged: onChanged,
      dropdownColor: Colors.white,
      menuMaxHeight: 300,
      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1E3A5F)),
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
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF1E3A5F), size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
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
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: isPrimary
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 22),
              label: Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: const Color(0xFF1E3A5F).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 22),
              label: Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E3A5F),
                side: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header animado ──────────────────────────────────────────
            SlideTransition(
              position: _headerSlideAnimation,
              child: FadeTransition(
                opacity: _headerFadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'logo',
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person_add,
                              color: Color(0xFF1E3A5F),
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Registro de Estudiantes',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _adminCarreraCarrera.isNotEmpty
                                  ? _adminCarreraCarrera
                                  : 'Cargando...',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white70),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.file_upload,
                            color: Colors.white, size: 26),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DatosExcelScreen()),
                        ),
                        tooltip: 'Importar Excel',
                      ),
                      IconButton(
                        icon: const Icon(Icons.list,
                            color: Colors.white, size: 26),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const EstudiantesRegistradosCarreraScreen()),
                        ),
                        tooltip: 'Ver registrados',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Área de contenido ───────────────────────────────────────
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
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                  color: Color(0xFF1E3A5F)),
                              const SizedBox(height: 16),
                              Text(
                                _isLoading
                                    ? 'Creando estudiante...'
                                    : 'Cargando...',
                                style: const TextStyle(
                                    color: Color(0xFF1E3A5F), fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ── Banner de carrera (siempre visible) ──
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                      Colors.blue.shade50,
                                      Colors.blue.shade100,
                                    ]),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Colors.blue.shade300,
                                        width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade700,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.school,
                                            color: Colors.white, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Registrando para: $_adminCarreraCarrera',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade900,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$_adminCarreraFacultad · $_adminCarreraFilialNombre',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // ── Información personal ──────────────────
                                _buildSectionCard(
                                  title: 'Información Personal',
                                  icon: Icons.person,
                                  children: [
                                    _buildTextField(
                                      controller: _nombresController,
                                      label: 'Nombres',
                                      icon: Icons.person,
                                      validator: (v) => (v == null ||
                                              v.trim().isEmpty)
                                          ? 'Los nombres son requeridos'
                                          : null,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      controller: _apellidosController,
                                      label: 'Apellidos',
                                      icon: Icons.person_outline,
                                      validator: (v) => (v == null ||
                                              v.trim().isEmpty)
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
                                        final cleaned = _cleanUsername(value);
                                        if (cleaned != value) {
                                          _usernameController.value =
                                              TextEditingValue(
                                            text: cleaned,
                                            selection:
                                                TextSelection.collapsed(
                                                    offset: cleaned.length),
                                          );
                                        }
                                      },
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
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
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'El documento es requerido'
                                              : null,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // ── Información de contacto ───────────────
                                _buildSectionCard(
                                  title: 'Información de Contacto',
                                  icon: Icons.contact_phone,
                                  children: [
                                    _buildTextField(
                                      controller: _correoController,
                                      label: 'Correo electrónico',
                                      icon: Icons.email,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (v) {
                                        if (v != null && v.trim().isNotEmpty) {
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
                                        if (v != null && v.trim().isNotEmpty) {
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

                                // ── Información académica ─────────────────
                                _buildSectionCard(
                                  title: 'Información Académica',
                                  icon: Icons.school,
                                  children: [
                                    _buildTextField(
                                      controller: _codigoEstudianteController,
                                      label: 'Código estudiante',
                                      icon: Icons.badge,
                                      hintText: 'Ej: 202320800',
                                      validator: (_) => null,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDropdown<String>(
                                      label: 'Modo contrato',
                                      icon: Icons.description,
                                      value: _selectedModoContrato,
                                      items: _modosContrato
                                          .map((m) => DropdownMenuItem(
                                              value: m, child: Text(m)))
                                          .toList(),
                                      onChanged: (v) => setState(
                                          () => _selectedModoContrato = v),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDropdown<String>(
                                      label: 'Modalidad estudio',
                                      icon: Icons.book,
                                      value: _selectedModalidadEstudio,
                                      items: _modalidadesEstudio
                                          .map((m) => DropdownMenuItem(
                                              value: m, child: Text(m)))
                                          .toList(),
                                      onChanged: (v) => setState(
                                          () => _selectedModalidadEstudio = v),
                                    ),
                                    const SizedBox(height: 16),

                                    // Filial, facultad y carrera — solo lectura
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

                                    // ── Estado de pago ────────────────────
                                    _buildPagoSelector(),
                                    const SizedBox(height: 16),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDropdown<String>(
                                            label: 'Ciclo',
                                            icon: Icons.layers,
                                            value: _selectedCiclo,
                                            items: _ciclos
                                                .map((c) => DropdownMenuItem(
                                                    value: c,
                                                    child: Text('Ciclo $c')))
                                                .toList(),
                                            onChanged: (v) => setState(
                                                () => _selectedCiclo = v),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildDropdown<String>(
                                            label: 'Grupo',
                                            icon: Icons.groups,
                                            value: _selectedGrupo,
                                            items: _grupos
                                                .map((g) => DropdownMenuItem(
                                                    value: g,
                                                    child: Text('Grupo $g')))
                                                .toList(),
                                            onChanged: (v) => setState(
                                                () => _selectedGrupo = v),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // ── Botones ───────────────────────────────
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
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Selector visual de estado de pago con dos botones tipo chip.
  Widget _buildPagoSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.payment, color: const Color(0xFF1E3A5F), size: 20),
            const SizedBox(width: 8),
            const Text(
              'Estado de pago *',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF1E3A5F),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: _opcionesPago.map((opcion) {
            final isSelected = _selectedPago == opcion['valor'];
            final color = opcion['color'] as Color;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedPago = opcion['valor'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(
                    right: opcion == _opcionesPago.first ? 10 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        opcion['icon'] as IconData,
                        color: isSelected ? color : Colors.grey.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        opcion['label'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? color : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Campo de solo lectura con estilo igual al resto del formulario.
  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      style: TextStyle(color: Colors.grey.shade600),
    );
  }
}