import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import '/admin/logica/filiales_service.dart';
import 'estudiantes_registrados.dart';
import 'datos_excel.dart';

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

  late AnimationController _headerAnimationController;
  late AnimationController _formAnimationController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<double> _formFadeAnimation;

  bool _isAdminCarrera = false;
  String? _adminCarreraFilial;
  String? _adminCarreraFacultad;
  String? _adminCarreraCarrera;
  bool _isLoading = false;
  bool _isLoadingFiliales = true;
  String? _selectedModoContrato;
  String? _selectedModalidadEstudio;
  String? _selectedFilial;
  String? _selectedFacultad;
  String? _selectedCarrera;
  String? _selectedCiclo;
  String? _selectedGrupo;

  final List<String> _modosContrato = ['Regular', 'Convenio', 'Especial'];
  final List<String> _modalidadesEstudio = [
    'Presencial',
    'Semipresencial',
    'Virtual',
  ];
  final List<String> _ciclos = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
  ];
  final List<String> _grupos = ['Único', '1', '2', '3', '4'];

  // ═══════════════════════════════════════════════════════════════
  // ✅ ESTRUCTURA DE FILIALES DESDE FIREBASE
  // ═══════════════════════════════════════════════════════════════
  final FilialesService _filialesService = FilialesService();
  Map<String, dynamic> _estructuraFiliales = {};
  List<String> _filiales = [];
  List<String> _facultadesDisponibles = [];
  List<Map<String, dynamic>> _carrerasDisponibles = [];

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
    _checkIfAdminCarrera();

    // ✅ Cargar estructura de filiales
    _loadFiliales();
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ CARGAR ESTRUCTURA DE FILIALES
  // ═══════════════════════════════════════════════════════════════
  Future<void> _loadFiliales() async {
    setState(() {
      _isLoadingFiliales = true;
    });

    try {
      await _filialesService.inicializarSiEsNecesario();
      _estructuraFiliales = await _filialesService.getEstructuraCompleta();
      _filiales = _estructuraFiliales.keys.toList();

      // ✅ Si es admin de carrera, preseleccionar y bloquear su carrera
      if (_isAdminCarrera) {
        setState(() {
          _selectedFilial = _adminCarreraFilial;
          _onFilialChanged(_selectedFilial);

          // Esperar un frame para que se carguen las facultades
          Future.delayed(const Duration(milliseconds: 100), () {
            setState(() {
              _selectedFacultad = _adminCarreraFacultad;
              _onFacultadChanged(_selectedFacultad);

              // Esperar otro frame para que se carguen las carreras
              Future.delayed(const Duration(milliseconds: 100), () {
                setState(() {
                  _selectedCarrera = _adminCarreraCarrera;
                });
              });
            });
          });
        });
      }

      print('✅ Filiales cargadas: $_filiales');
    } catch (e) {
      print('❌ Error cargando filiales: $e');
      _showMessage('Error cargando filiales: $e');
    }

    setState(() {
      _isLoadingFiliales = false;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ ACTUALIZAR FACULTADES SEGÚN FILIAL
  // ═══════════════════════════════════════════════════════════════
  void _onFilialChanged(String? filial) {
    setState(() {
      _selectedFilial = filial;
      _selectedFacultad = null;
      _selectedCarrera = null;
      _facultadesDisponibles = [];
      _carrerasDisponibles = [];

      if (filial != null && _estructuraFiliales.containsKey(filial)) {
        final filialData = _estructuraFiliales[filial];
        final facultades = filialData['facultades'] as Map<String, dynamic>?;

        if (facultades != null) {
          _facultadesDisponibles = facultades.keys.toList();
        }
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ ACTUALIZAR CARRERAS SEGÚN FACULTAD
  // ═══════════════════════════════════════════════════════════════
  void _onFacultadChanged(String? facultad) {
    setState(() {
      _selectedFacultad = facultad;
      _selectedCarrera = null;
      _carrerasDisponibles = [];

      if (_selectedFilial != null &&
          facultad != null &&
          _estructuraFiliales.containsKey(_selectedFilial)) {
        final filialData = _estructuraFiliales[_selectedFilial!];
        final facultades = filialData['facultades'] as Map<String, dynamic>?;

        if (facultades != null && facultades.containsKey(facultad)) {
          final facultadData = facultades[facultad];
          _carrerasDisponibles = List<Map<String, dynamic>>.from(
            facultadData['carreras'] ?? [],
          );
        }
      }
    });
  }

  void _extractUsernameFromEmail() {
    final correo = _correoController.text.trim();
    if (correo.contains('@upeu.edu.pe') && _usernameController.text.isEmpty) {
      final username = correo.split('@')[0];
      if (username.isNotEmpty) {
        _usernameController.text = username;
      }
    }
  }

  void _generateUsernameSuggestion() {
    if (_usernameController.text.isEmpty) {
      final nombres = _nombresController.text.trim();
      final apellidos = _apellidosController.text.trim();
      final suggestion = _generateUsernameFromNamesAndSurnames(
        nombres,
        apellidos,
      );
      if (suggestion.isNotEmpty) {
        _usernameController.text = suggestion;
      }
    }
  }

  String _generateUsernameFromNamesAndSurnames(
    String nombres,
    String apellidos,
  ) {
    if (nombres.isEmpty && apellidos.isEmpty) return '';

    final nombresList = nombres
        .toLowerCase()
        .split(' ')
        .where((name) => name.isNotEmpty)
        .toList();
    final apellidosList = apellidos
        .toLowerCase()
        .split(' ')
        .where((surname) => surname.isNotEmpty)
        .toList();

    String username = '';
    if (nombresList.isNotEmpty) {
      username = nombresList[0];
    }
    if (apellidosList.isNotEmpty) {
      if (username.isNotEmpty) {
        username += '.${apellidosList[0]}';
      } else {
        username = apellidosList[0];
      }
    }
    return _cleanUsername(username);
  }

  String _cleanUsername(String input) {
    const accents = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
      'ç': 'c',
    };

    String cleaned = input.toLowerCase();
    accents.forEach((accent, replacement) {
      cleaned = cleaned.replaceAll(accent, replacement);
    });
    cleaned = cleaned.replaceAll(RegExp(r'[^a-z0-9.]'), '');
    return cleaned;
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // ✅ Validaciones con filiales
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

    final fullName =
        '${_nombresController.text.trim()} ${_apellidosController.text.trim()}';
    final username = _usernameController.text.trim().toLowerCase();

    // ✅ Obtener nombre de la sede desde FilialesService
    final nombreSede = _filialesService.getNombreFilial(_selectedFilial!);

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔍 Creando estudiante:');
      print('   Filial: $_selectedFilial ($nombreSede)');
      print('   Facultad: $_selectedFacultad');
      print('   Carrera: $_selectedCarrera');
      print('   Username: $username');

      final success = await PrefsHelper.createStudentAccountWithUsername(
        email: _correoController.text.trim(),
        name: fullName,
        username: username,
        codigoUniversitario: _codigoEstudianteController.text.trim(),
        dni: _documentoController.text.trim(),
        facultad: _selectedFacultad!,
        carrera: _selectedCarrera!,
        modoContrato: _selectedModoContrato,
        modalidadEstudio: _selectedModalidadEstudio,
        sede: nombreSede, // ✅ Guardar nombre de la sede
        ciclo: _selectedCiclo,
        grupo: _selectedGrupo,
        celular: _celularController.text.trim(),
      );

      if (success) {
        _showSuccessDialog(
          username,
          _documentoController.text.trim(),
          fullName,
        );
        _clearForm();
      } else {
        _showMessage('Error: Ya existe un usuario con esos datos');
      }
    } catch (e) {
      print('❌ Error creando estudiante: $e');
      _showMessage('Error creando estudiante: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _checkIfAdminCarrera() async {
    final isAdminCarrera = await PrefsHelper.isAdminCarrera();

    if (isAdminCarrera) {
      final adminData = await PrefsHelper.getAdminCarreraData();

      if (adminData != null) {
        setState(() {
          _isAdminCarrera = true;
          _adminCarreraFilial = adminData['filial'];
          _adminCarreraFacultad = adminData['facultad'];
          _adminCarreraCarrera = adminData['carrera'];
        });

        print('✅ Admin de carrera detectado');
        print('   Filial: $_adminCarreraFilial');
        print('   Facultad: $_adminCarreraFacultad');
        print('   Carrera: $_adminCarreraCarrera');
      }
    }
  }

  void _showSuccessDialog(
    String username,
    String password,
    String studentName,
  ) {
    _showMessage('✅ Estudiante $studentName creado exitosamente');
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
      _facultadesDisponibles = [];
      _carrerasDisponibles = [];
    });
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF1E3A5F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? helperText,
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
        helperText: helperText,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      items: items,
      onChanged: onChanged,
      dropdownColor: Colors.white,
      menuMaxHeight: 300,
      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1E3A5F)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // Header animado
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
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.person_add,
                                color: Color(0xFF1E3A5F),
                                size: 30,
                              );
                            },
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
                              _isAdminCarrera
                                  ? 'Carrera: $_adminCarreraCarrera'
                                  : 'Crear nuevas cuentas',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.file_upload,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DatosExcelScreen(),
                            ),
                          );
                        },
                        tooltip: 'Importar Excel',
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.list,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const EstudiantesRegistradosScreen(),
                            ),
                          );
                        },
                        tooltip: 'Ver registrados',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Content Area con animación
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
                  child: _isLoading || _isLoadingFiliales
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                color: Color(0xFF1E3A5F),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isLoadingFiliales
                                    ? 'Cargando filiales...'
                                    : 'Creando estudiante...',
                                style: const TextStyle(
                                  color: Color(0xFF1E3A5F),
                                  fontSize: 16,
                                ),
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
                                // ✅ Banner informativo para admin de carrera (más compacto)
                                if (_isAdminCarrera) ...[
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.shade50,
                                          Colors.blue.shade100,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.blue.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade700,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.school,
                                            color: Colors.white,
                                            size: 20,
                                          ),
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
                                                '$_adminCarreraFacultad - $_adminCarreraFilial',
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
                                ],

                                // Información personal
                                _buildSectionCard(
                                  title: 'Información Personal',
                                  icon: Icons.person,
                                  children: [
                                    _buildTextField(
                                      controller: _nombresController,
                                      label: 'Nombres',
                                      icon: Icons.person,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Los nombres son requeridos';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      controller: _apellidosController,
                                      label: 'Apellidos',
                                      icon: Icons.person_outline,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Los apellidos son requeridos';
                                        }
                                        return null;
                                      },
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
                                          _usernameController
                                              .value = TextEditingValue(
                                            text: cleaned,
                                            selection: TextSelection.collapsed(
                                              offset: cleaned.length,
                                            ),
                                          );
                                        }
                                      },
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'El usuario es requerido';
                                        }
                                        if (value.trim().length < 3) {
                                          return 'El usuario debe tener al menos 3 caracteres';
                                        }
                                        if (!RegExp(
                                          r'^[a-z0-9.]+$',
                                        ).hasMatch(value.trim())) {
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
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'El documento es requerido';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Información de contacto
                                _buildSectionCard(
                                  title: 'Información de Contacto',
                                  icon: Icons.contact_phone,
                                  children: [
                                    _buildTextField(
                                      controller: _correoController,
                                      label: 'Correo electrónico',
                                      icon: Icons.email,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (value) {
                                        if (value != null &&
                                            value.trim().isNotEmpty) {
                                          if (!RegExp(
                                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                          ).hasMatch(value)) {
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
                                      validator: (value) {
                                        if (value != null &&
                                            value.trim().isNotEmpty) {
                                          if (value.trim().length != 9) {
                                            return 'El celular debe tener 9 dígitos';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Información académica
                                _buildSectionCard(
                                  title: 'Información Académica',
                                  icon: Icons.school,
                                  children: [
                                    _buildTextField(
                                      controller: _codigoEstudianteController,
                                      label: 'Código estudiante',
                                      icon: Icons.badge,
                                      hintText: 'Ej: 202320800',
                                      validator: (value) {
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDropdown<String>(
                                      label: 'Modo contrato',
                                      icon: Icons.description,
                                      value: _selectedModoContrato,
                                      items: _modosContrato.map((modo) {
                                        return DropdownMenuItem<String>(
                                          value: modo,
                                          child: Text(modo),
                                        );
                                      }).toList(),
                                      onChanged: (value) => setState(
                                        () => _selectedModoContrato = value,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDropdown<String>(
                                      label: 'Modalidad estudio',
                                      icon: Icons.book,
                                      value: _selectedModalidadEstudio,
                                      items: _modalidadesEstudio.map((
                                        modalidad,
                                      ) {
                                        return DropdownMenuItem<String>(
                                          value: modalidad,
                                          child: Text(modalidad),
                                        );
                                      }).toList(),
                                      onChanged: (value) => setState(
                                        () => _selectedModalidadEstudio = value,
                                      ),
                                    ),

                                    // ✅ OCULTAR COMPLETAMENTE SI ES ADMIN DE CARRERA
                                    if (!_isAdminCarrera) ...[
                                      const SizedBox(height: 16),
                                      // Selector de Filial (solo super admin)
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
                                      ),

                                      // Selector de Facultad (solo super admin)
                                      if (_selectedFilial != null) ...[
                                        const SizedBox(height: 16),
                                        _buildDropdown<String>(
                                          label: 'Unidad académica (Facultad)',
                                          icon: Icons.account_balance,
                                          value: _selectedFacultad,
                                          items: _facultadesDisponibles.map((
                                            facultad,
                                          ) {
                                            return DropdownMenuItem<String>(
                                              value: facultad,
                                              child: Text(
                                                facultad,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: _onFacultadChanged,
                                        ),
                                      ],

                                      // Selector de Carrera (solo super admin)
                                      if (_selectedFacultad != null) ...[
                                        const SizedBox(height: 16),
                                        _buildDropdown<String>(
                                          label: 'Programa estudio (Carrera)',
                                          icon: Icons.menu_book,
                                          value: _selectedCarrera,
                                          items: _carrerasDisponibles.map((
                                            carrera,
                                          ) {
                                            return DropdownMenuItem<String>(
                                              value: carrera['nombre'],
                                              child: Text(
                                                carrera['nombre'],
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (value) => setState(
                                            () => _selectedCarrera = value,
                                          ),
                                        ),
                                      ],
                                    ],

                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDropdown<String>(
                                            label: 'Ciclo',
                                            icon: Icons.layers,
                                            value: _selectedCiclo,
                                            items: _ciclos.map((ciclo) {
                                              return DropdownMenuItem<String>(
                                                value: ciclo,
                                                child: Text('Ciclo $ciclo'),
                                              );
                                            }).toList(),
                                            onChanged: (value) => setState(
                                              () => _selectedCiclo = value,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildDropdown<String>(
                                            label: 'Grupo',
                                            icon: Icons.groups,
                                            value: _selectedGrupo,
                                            items: _grupos.map((grupo) {
                                              return DropdownMenuItem<String>(
                                                value: grupo,
                                                child: Text('Grupo $grupo'),
                                              );
                                            }).toList(),
                                            onChanged: (value) => setState(
                                              () => _selectedGrupo = value,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Botones de acción
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
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const DatosExcelScreen(),
                                      ),
                                    );
                                  },
                                  isPrimary: false,
                                ),
                                const SizedBox(height: 12),
                                _buildActionButton(
                                  label: 'Ver Estudiantes Registrados',
                                  icon: Icons.list,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const EstudiantesRegistradosScreen(),
                                      ),
                                    );
                                  },
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
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: const Color(0xFF1E3A5F).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 22),
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E3A5F),
                side: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
    );
  }
}
