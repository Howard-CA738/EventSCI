import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import '/shared/logica/filiales_service.dart';
import 'estudiantes_registrados.dart';
import 'datos_excel.dart';
import 'importacion_selector_screen.dart';

class RegistroEstudiantesScreen extends StatefulWidget {
  const RegistroEstudiantesScreen({super.key});

  @override
  State<RegistroEstudiantesScreen> createState() =>
      _RegistroEstudiantesScreenState();
}

class _RegistroEstudiantesScreenState extends State<RegistroEstudiantesScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _codigoEstudianteController = TextEditingController();
  final _documentoController = TextEditingController();
  final _correoController = TextEditingController();
  final _celularController = TextEditingController();
  final _usernameController = TextEditingController();

  late AnimationController _headerAnimController;
  late AnimationController _formAnimController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _formFade;

  bool _isLoading = false;
  bool _isLoadingFiliales = true;

  String? _selectedModoContrato;
  String? _selectedModalidadEstudio;
  String? _selectedFilial;
  String? _selectedFacultad;
  String? _selectedCarrera;
  String? _selectedCiclo;
  String? _selectedGrupo;
  String? _selectedPago;

  final List<String> _modosContrato = ['Regular', 'Convenio', 'Especial'];
  final List<String> _modalidadesEstudio = [
    'Presencial',
    'Semipresencial',
    'Virtual'
  ];
  final List<String> _ciclos = [
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10'
  ];
  final List<String> _grupos = ['Único', '1', '2', '3', '4'];
  final List<Map<String, dynamic>> _opcionesPago = [
    {
      'valor': 'Si',
      'label': 'Pagado',
      'icon': Icons.check_circle,
      'color': const Color(0xFF16A34A)
    },
    {
      'valor': 'Pendiente',
      'label': 'Pendiente',
      'icon': Icons.schedule,
      'color': const Color(0xFFD97706)
    },
  ];

  final FilialesService _filialesService = FilialesService();
  Map<String, dynamic> _estructuraFiliales = {};
  List<String> _filiales = [];
  List<String> _facultadesDisponibles = [];
  List<Map<String, dynamic>> _carrerasDisponibles = [];

  @override
  void initState() {
    super.initState();

    _headerAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _formAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));

    _headerFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _headerAnimController, curve: Curves.easeOut));
    _headerSlide =
        Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _headerAnimController, curve: Curves.easeOutCubic));
    _formFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _formAnimController, curve: Curves.easeIn));

    _headerAnimController.forward();
    Future.delayed(const Duration(milliseconds: 300),
        () => _formAnimController.forward());

    _nombresController.addListener(_generateUsernameSuggestion);
    _apellidosController.addListener(_generateUsernameSuggestion);
    _correoController.addListener(_extractUsernameFromEmail);

    _loadFiliales();
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    _formAnimController.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _codigoEstudianteController.dispose();
    _documentoController.dispose();
    _correoController.dispose();
    _celularController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadFiliales() async {
    setState(() => _isLoadingFiliales = true);
    try {
      await _filialesService.inicializarSiEsNecesario();
      _estructuraFiliales = await _filialesService.getEstructuraCompleta();
      setState(() => _filiales = _estructuraFiliales.keys.toList());
    } catch (e) {
      _showMessage('Error cargando filiales: $e');
    }
    setState(() => _isLoadingFiliales = false);
  }

  void _onFilialChanged(String? filial) {
    setState(() {
      _selectedFilial = filial;
      _selectedFacultad = null;
      _selectedCarrera = null;
      _facultadesDisponibles = [];
      _carrerasDisponibles = [];

      if (filial != null && _estructuraFiliales.containsKey(filial)) {
        final facultades =
            _estructuraFiliales[filial]['facultades'] as Map<String, dynamic>?;
        if (facultades != null) {
          _facultadesDisponibles = facultades.keys.toList();
        }
      }
    });
  }

  void _onFacultadChanged(String? facultad) {
    setState(() {
      _selectedFacultad = facultad;
      _selectedCarrera = null;
      _carrerasDisponibles = [];

      if (_selectedFilial != null &&
          facultad != null &&
          _estructuraFiliales.containsKey(_selectedFilial)) {
        final facultades = _estructuraFiliales[_selectedFilial!]['facultades']
            as Map<String, dynamic>?;
        if (facultades != null && facultades.containsKey(facultad)) {
          _carrerasDisponibles = List<Map<String, dynamic>>.from(
              facultades[facultad]['carreras'] ?? []);
        }
      }
    });
  }

  void _extractUsernameFromEmail() {
    final correo = _correoController.text.trim();
    if (correo.contains('@upeu.edu.pe') && _usernameController.text.isEmpty) {
      final username = correo.split('@')[0];
      if (username.isNotEmpty) _usernameController.text = username;
    }
  }

  void _generateUsernameSuggestion() {
    if (_usernameController.text.isEmpty) {
      final suggestion = _buildUsername(
          _nombresController.text.trim(), _apellidosController.text.trim());
      if (suggestion.isNotEmpty) _usernameController.text = suggestion;
    }
  }

  String _buildUsername(String nombres, String apellidos) {
    if (nombres.isEmpty && apellidos.isEmpty) return '';
    final n =
        nombres.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();
    final a =
        apellidos.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();
    String u = n.isNotEmpty ? n[0] : '';
    if (a.isNotEmpty) u += u.isNotEmpty ? '.${a[0]}' : a[0];
    return _cleanUsername(u);
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
    String c = input.toLowerCase();
    accents.forEach((k, v) => c = c.replaceAll(k, v));
    return c.replaceAll(RegExp(r'[^a-z0-9.]'), '');
  }

  Future<void> _createStudent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFilial == null) {
      _showMessage('Por favor selecciona una filial');
      return;
    }
    if (_selectedFacultad == null) {
      _showMessage('Por favor selecciona una facultad');
      return;
    }
    if (_selectedCarrera == null) {
      _showMessage('Por favor selecciona una carrera');
      return;
    }
    if (_selectedPago == null) {
      _showMessage('Por favor selecciona el estado de pago');
      return;
    }

    final fullName =
        '${_nombresController.text.trim()} ${_apellidosController.text.trim()}';
    final username = _usernameController.text.trim().toLowerCase();
    final filialNombre = _filialesService.getNombreFilial(_selectedFilial!);

    setState(() => _isLoading = true);
    try {
      final success = await PrefsHelper.createStudentAccountWithUsername(
        email: _correoController.text.trim(),
        name: fullName,
        username: username,
        codigoUniversitario: _codigoEstudianteController.text.trim(),
        dni: _documentoController.text.trim(),
        facultad: _selectedFacultad!,
        carrera: _selectedCarrera!,
        filial: filialNombre,
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
        _showMessage('❌ Error: ya existe un usuario con esos datos');
      }
    } catch (e) {
      _showMessage('❌ Error creando estudiante: $e');
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
      _selectedFilial = null;
      _selectedFacultad = null;
      _selectedCarrera = null;
      _selectedCiclo = null;
      _selectedGrupo = null;
      _selectedPago = null;
      _facultadesDisponibles = [];
      _carrerasDisponibles = [];
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF1E3A5F),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
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
      maxLines: 1,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      items: items,
      onChanged: onChanged,
      validator: validator,
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(icon, color: const Color(0xFF1E3A5F), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F)),
                    maxLines: 1,
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
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: isPrimary
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 22),
              label: Text(
                label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor:
                    const Color(0xFF1E3A5F).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 22),
              label: Text(
                label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E3A5F),
                side: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
    );
  }

  Widget _buildPagoSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.payment, color: Color(0xFF1E3A5F), size: 20),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Estado de pago *',
                style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E3A5F),
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (int i = 0; i < _opcionesPago.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(
                      () => _selectedPago = _opcionesPago[i]['valor'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedPago == _opcionesPago[i]['valor']
                          ? (_opcionesPago[i]['color'] as Color)
                              .withValues(alpha: 0.12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedPago == _opcionesPago[i]['valor']
                            ? _opcionesPago[i]['color'] as Color
                            : Colors.grey.shade300,
                        width:
                            _selectedPago == _opcionesPago[i]['valor'] ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _opcionesPago[i]['icon'] as IconData,
                          color: _selectedPago == _opcionesPago[i]['valor']
                              ? _opcionesPago[i]['color'] as Color
                              : Colors.grey.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _opcionesPago[i]['label'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  _selectedPago == _opcionesPago[i]['valor']
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                              color:
                                  _selectedPago == _opcionesPago[i]['valor']
                                      ? _opcionesPago[i]['color'] as Color
                                      : Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            SlideTransition(
              position: _headerSlide,
              child: FadeTransition(
                opacity: _headerFade,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
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
                              size: 30),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registro de Estudiantes',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Crear nuevas cuentas',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.white70),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.file_upload,
                              color: Colors.white, size: 26),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ImportacionSelectorScreen())),
                          tooltip: 'Importar Excel',
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.list,
                              color: Colors.white, size: 26),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const EstudiantesRegistradosScreen())),
                          tooltip: 'Ver registrados',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: FadeTransition(
                opacity: _formFade,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8EDF2),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: _isLoading || _isLoadingFiliales
                      ? SafeArea(
                          top: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                    color: Color(0xFF1E3A5F)),
                                const SizedBox(height: 16),
                                Text(
                                  _isLoadingFiliales
                                      ? 'Cargando filiales...'
                                      : 'Creando estudiante...',
                                  style: const TextStyle(
                                      color: Color(0xFF1E3A5F), fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                              20, 20, 20, 20 + bottomPadding),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
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
                                            _cleanUsername(value);
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
                                      onChanged: (v) => setState(() =>
                                          _selectedModalidadEstudio = v),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDropdown<String>(
                                      label: 'Filial (Sede)',
                                      icon: Icons.location_city,
                                      value: _selectedFilial,
                                      items: _filiales.map((filial) {
                                        final nombre = _filialesService
                                            .getNombreFilial(filial);
                                        final ubicacion = _filialesService
                                            .getUbicacionFilial(filial);
                                        return DropdownMenuItem<String>(
                                          value: filial,
                                          child: Text(
                                            '$nombre - $ubicacion',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: _onFilialChanged,
                                      validator: (v) => v == null
                                          ? 'Selecciona una filial'
                                          : null,
                                    ),
                                    if (_selectedFilial != null) ...[
                                      const SizedBox(height: 16),
                                      _buildDropdown<String>(
                                        label: 'Facultad',
                                        icon: Icons.account_balance,
                                        value: _selectedFacultad,
                                        items: _facultadesDisponibles
                                            .map((f) =>
                                                DropdownMenuItem<String>(
                                                    value: f,
                                                    child: Text(f,
                                                        overflow: TextOverflow
                                                            .ellipsis)))
                                            .toList(),
                                        onChanged: _onFacultadChanged,
                                        validator: (v) => v == null
                                            ? 'Selecciona una facultad'
                                            : null,
                                      ),
                                    ],
                                    if (_selectedFacultad != null) ...[
                                      const SizedBox(height: 16),
                                      _buildDropdown<String>(
                                        label: 'Carrera',
                                        icon: Icons.menu_book,
                                        value: _selectedCarrera,
                                        items: _carrerasDisponibles
                                            .map((c) =>
                                                DropdownMenuItem<String>(
                                                  value: c['nombre'],
                                                  child: Text(
                                                    c['nombre'],
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ))
                                            .toList(),
                                        onChanged: (v) => setState(() {
                                          _selectedCarrera = v;
                                        }),
                                        validator: (v) => v == null
                                            ? 'Selecciona una carrera'
                                            : null,
                                      ),
                                    ],
                                    const SizedBox(height: 16),
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
                                                    child: Text(
                                                      'Ciclo $c',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    )))
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
                                                    child: Text(
                                                      'Grupo $g',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    )))
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
                                              const DatosExcelScreen())),
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
                                              const EstudiantesRegistradosScreen())),
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
}