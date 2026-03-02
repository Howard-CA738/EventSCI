import 'package:flutter/material.dart';
import '/prefs_helper.dart';

class EstudiantesRegistradosScreen extends StatefulWidget {
  const EstudiantesRegistradosScreen({super.key});

  @override
  State<EstudiantesRegistradosScreen> createState() =>
      _EstudiantesRegistradosScreenState();
}

class _EstudiantesRegistradosScreenState
    extends State<EstudiantesRegistradosScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  String? _selectedFacultad;
  String? _selectedCarrera;
  final _searchController = TextEditingController();
  // Controladores para edición
  final TextEditingController _editNombreController = TextEditingController();
  final TextEditingController _editEmailController = TextEditingController();
  final TextEditingController _editCodigoController = TextEditingController();
  final TextEditingController _editDniController = TextEditingController();
  final TextEditingController _editCelularController = TextEditingController();
  final TextEditingController _editCorreoInstitucionalController =
      TextEditingController();
  Set<String> _expandedStudents = {};
  late AnimationController _fabAnimationController;
  late AnimationController _filterAnimationController;

  final Map<String, List<String>> _facultadesCarreras = {
    'Universidad Peruana Unión': [], // ✅ Nueva opción sin carreras
    'Facultad de Ciencias Empresariales': [
      'EP Administración',
      'EP Contabilidad',
      'EP Gestión Tributaria y Aduanera',
    ],
    'Facultad de Ciencias Humanas y Educación': [
      'EP Educación, Especialidad Inicial y Puericultura',
      'EP Educación, Especialidad Primaria y Pedagogía Terapéutica',
      'EP Educación, Especialidad Inglés y Español',
    ],
    'Facultad de Ciencias de la Salud': [
      'EP Enfermería',
      'EP Nutrición Humana',
      'EP Psicología',
    ],
    'Facultad de Ingeniería y Arquitectura': [
      'EP Ingeniería Civil',
      'EP Arquitectura y Urbanismo',
      'EP Ingeniería Ambiental',
      'EP Ingeniería de Industrias Alimentarias',
      'EP Ingeniería de Sistemas',
    ],
  };

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _filterAnimationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimationController.dispose();
    _filterAnimationController.dispose();
    // Agregar estos:
    _editNombreController.dispose();
    _editEmailController.dispose();
    _editCodigoController.dispose();
    _editDniController.dispose();
    _editCelularController.dispose();
    _editCorreoInstitucionalController.dispose();
    super.dispose();
  }

  // ✅ Verificar si la facultad requiere carrera
  bool _requiereCarrera(String? facultad) {
    if (facultad == null) return true;
    return facultad != 'Universidad Peruana Unión';
  }

  Future<void> _showEditDialog(
    Map<String, dynamic> student,
    String carreraPath,
    String studentId,
  ) async {
    // Inicializar controladores con datos actuales
    _editNombreController.text = student['name'] ?? '';
    _editEmailController.text = student['email'] ?? '';
    _editCodigoController.text = student['codigoUniversitario'] ?? '';
    _editDniController.text = student['dni'] ?? '';
    _editCelularController.text = student['celular'] ?? '';
    _editCorreoInstitucionalController.text =
        student['correoInstitucional'] ?? '';

    // Listas de opciones válidas
    final modoContratoOptions = ['Regular', 'Convenio', 'Especial'];
    final modalidadEstudioOptions = ['Presencial', 'Semipresencial', 'Virtual'];
    final cicloOptions = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'];
    final grupoOptions = ['Único', '1', '2', '3', '4'];

    // Variables para dropdowns - validar que existan en las opciones
    String? selectedModoContrato = student['modoContrato'];
    if (selectedModoContrato != null &&
        !modoContratoOptions.contains(selectedModoContrato)) {
      selectedModoContrato = null;
    }

    String? selectedModalidadEstudio = student['modalidadEstudio'];
    if (selectedModalidadEstudio != null &&
        !modalidadEstudioOptions.contains(selectedModalidadEstudio)) {
      selectedModalidadEstudio = null;
    }

    String? selectedCiclo = student['ciclo'];
    if (selectedCiclo != null && !cicloOptions.contains(selectedCiclo)) {
      selectedCiclo = null;
    }

    String? selectedGrupo = student['grupo'];
    if (selectedGrupo != null && !grupoOptions.contains(selectedGrupo)) {
      selectedGrupo = null;
    }

    String? selectedSede = student['sede'];

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: Color(0xFF1E3A5F)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Editar Estudiante',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nombre
                    TextFormField(
                      controller: _editNombreController,
                      decoration: InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El nombre es requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _editEmailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    // Código universitario
                    TextFormField(
                      controller: _editCodigoController,
                      decoration: InputDecoration(
                        labelText: 'Código universitario',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // DNI
                    TextFormField(
                      controller: _editDniController,
                      decoration: InputDecoration(
                        labelText: 'DNI',
                        prefixIcon: const Icon(Icons.credit_card),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Celular
                    TextFormField(
                      controller: _editCelularController,
                      decoration: InputDecoration(
                        labelText: 'Celular',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Correo institucional
                    TextFormField(
                      controller: _editCorreoInstitucionalController,
                      decoration: InputDecoration(
                        labelText: 'Correo institucional',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    // Modo Contrato
                    DropdownButtonFormField<String>(
                      value: selectedModoContrato,
                      decoration: InputDecoration(
                        labelText: 'Modo Contrato',
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Sin seleccionar'),
                        ),
                        ...modoContratoOptions.map(
                          (modo) =>
                              DropdownMenuItem(value: modo, child: Text(modo)),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedModoContrato = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Modalidad Estudio
                    DropdownButtonFormField<String>(
                      value: selectedModalidadEstudio,
                      decoration: InputDecoration(
                        labelText: 'Modalidad Estudio',
                        prefixIcon: const Icon(Icons.school),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Sin seleccionar'),
                        ),
                        ...modalidadEstudioOptions.map(
                          (modalidad) => DropdownMenuItem(
                            value: modalidad,
                            child: Text(modalidad),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedModalidadEstudio = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Ciclo
                    DropdownButtonFormField<String>(
                      value: selectedCiclo,
                      decoration: InputDecoration(
                        labelText: 'Ciclo',
                        prefixIcon: const Icon(Icons.layers),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Sin seleccionar'),
                        ),
                        ...cicloOptions.map(
                          (ciclo) => DropdownMenuItem(
                            value: ciclo,
                            child: Text('Ciclo $ciclo'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCiclo = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Grupo
                    DropdownButtonFormField<String>(
                      value: selectedGrupo,
                      decoration: InputDecoration(
                        labelText: 'Grupo',
                        prefixIcon: const Icon(Icons.groups),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Sin seleccionar'),
                        ),
                        ...grupoOptions.map(
                          (grupo) => DropdownMenuItem(
                            value: grupo,
                            child: Text('Grupo $grupo'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedGrupo = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop();
                  await _updateStudent(
                    carreraPath: carreraPath,
                    studentId: studentId,
                    name: _editNombreController.text.trim(),
                    email: _editEmailController.text.trim(),
                    codigoUniversitario: _editCodigoController.text.trim(),
                    dni: _editDniController.text.trim(),
                    celular: _editCelularController.text.trim(),
                    correoInstitucional: _editCorreoInstitucionalController.text
                        .trim(),
                    modoContrato: selectedModoContrato,
                    modalidadEstudio: selectedModalidadEstudio,
                    ciclo: selectedCiclo,
                    grupo: selectedGrupo,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStudent({
    required String carreraPath,
    required String studentId,
    String? name,
    String? email,
    String? codigoUniversitario,
    String? dni,
    String? celular,
    String? correoInstitucional,
    String? modoContrato,
    String? modalidadEstudio,
    String? ciclo,
    String? grupo,
  }) async {
    setState(() => _isLoading = true);

    try {
      final success = await PrefsHelper.updateStudent(
        carreraPath: carreraPath,
        studentId: studentId,
        name: name?.isNotEmpty == true ? name : null,
        email: email?.isNotEmpty == true ? email : null,
        codigoUniversitario: codigoUniversitario?.isNotEmpty == true
            ? codigoUniversitario
            : null,
        dni: dni?.isNotEmpty == true ? dni : null,
        celular: celular?.isNotEmpty == true ? celular : null,
        correoInstitucional: correoInstitucional?.isNotEmpty == true
            ? correoInstitucional
            : null,
        modoContrato: modoContrato,
        modalidadEstudio: modalidadEstudio,
        ciclo: ciclo,
        grupo: grupo,
      );

      if (success) {
        _showMessage('✅ Estudiante actualizado exitosamente');
        await _loadStudents();
      } else {
        _showMessage('❌ Error actualizando estudiante');
      }
    } catch (e) {
      _showMessage('❌ Error: $e');
      print('Error actualizando estudiante: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadStudents() async {
    // ✅ Para UPeU, no se requiere carrera
    if (_requiereCarrera(_selectedFacultad) && _selectedCarrera == null) {
      print('⚠️ No hay carrera seleccionada');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ Si es UPeU, usar la facultad como carrera
      final carreraPath = _requiereCarrera(_selectedFacultad)
          ? _selectedCarrera!
          : _selectedFacultad!;

      print('🔍 Cargando estudiantes de: $carreraPath');

      final students = await PrefsHelper.getStudentsByCarrera(carreraPath);

      print('📚 Estudiantes cargados de $carreraPath: ${students.length}');

      if (students.isNotEmpty) {
        print('📝 Primer estudiante: ${students.first['name']}');
      }

      setState(() {
        _allStudents = students;
        _filteredStudents = students;
      });

      if (_searchController.text.isNotEmpty) {
        _applyFilters();
      }
    } catch (e) {
      print('❌ Error cargando estudiantes: $e');
      _showMessage('Error cargando estudiantes: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _applyFilters() {
    // ✅ Validar según el tipo de facultad
    if (_selectedFacultad == null ||
        (_requiereCarrera(_selectedFacultad) && _selectedCarrera == null) ||
        _allStudents.isEmpty) {
      setState(() {
        _filteredStudents = [];
      });
      return;
    }

    final searchTerm = _searchController.text.toLowerCase().trim();
    List<Map<String, dynamic>> result = List.from(_allStudents);

    if (searchTerm.isNotEmpty) {
      result = result.where((student) {
        final name = (student['name'] ?? '').toString().toLowerCase();
        final codigo = (student['codigoUniversitario'] ?? '')
            .toString()
            .toLowerCase();
        final dni = (student['dni'] ?? '').toString().toLowerCase();
        return name.contains(searchTerm) ||
            codigo.contains(searchTerm) ||
            dni.contains(searchTerm);
      }).toList();

      print('🔍 Búsqueda "$searchTerm": ${result.length} resultados');
    }

    setState(() {
      _filteredStudents = result;
    });
  }

  void _onFacultadChanged(String? facultad) {
    setState(() {
      _selectedFacultad = facultad;
      _selectedCarrera = null;
      _searchController.clear();
      _expandedStudents.clear();
      _allStudents = [];
      _filteredStudents = [];
    });

    // ✅ Si es UPeU, cargar estudiantes automáticamente
    if (facultad == 'Universidad Peruana Unión') {
      _loadStudents();
    }
  }

  void _onCarreraChanged(String? carrera) {
    print('📌 Carrera seleccionada: $carrera');
    setState(() {
      _selectedCarrera = carrera;
      _searchController.clear();
      _expandedStudents.clear();
      _allStudents = [];
      _filteredStudents = [];
    });

    _loadStudents();
  }

  void _clearFilters() {
    setState(() {
      _selectedFacultad = null;
      _selectedCarrera = null;
      _searchController.clear();
      _expandedStudents.clear();
      _allStudents = [];
      _filteredStudents = [];
    });
  }

  Future<void> _deleteAllStudents() async {
    // ✅ Validar según el tipo de facultad
    if (_selectedFacultad == null ||
        (_requiereCarrera(_selectedFacultad) && _selectedCarrera == null) ||
        _filteredStudents.isEmpty) {
      _showMessage('No hay estudiantes para eliminar');
      return;
    }

    final displayName = _requiereCarrera(_selectedFacultad)
        ? _selectedCarrera!
        : _selectedFacultad!;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 32),
            SizedBox(width: 8),
            Text('ADVERTENCIA'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estás a punto de eliminar TODOS los estudiantes de $displayName.',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Total a eliminar: ${_filteredStudents.length} estudiantes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Esta acción NO se puede deshacer\n'
                    '• Se eliminarán de $displayName\n'
                    '• Los estudiantes no podrán iniciar sesión',
                    style: TextStyle(fontSize: 13, color: Colors.red.shade900),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('SÍ, ELIMINAR TODO'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Eliminando estudiantes...',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Esto puede tomar unos segundos',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    try {
      // ✅ Usar el path correcto según el tipo de facultad
      final carreraPath = _requiereCarrera(_selectedFacultad)
          ? _selectedCarrera!
          : _selectedFacultad!;

      // ✅ OPTIMIZACIÓN: Llamar al método batch en PrefsHelper
      print(
        '🗑️ Iniciando eliminación masiva de ${_filteredStudents.length} estudiantes...',
      );

      final studentsToDelete = _filteredStudents
          .map(
            (student) => {
              'carreraPath': carreraPath,
              'studentId': student['id'] as String,
            },
          )
          .toList();

      final result = await PrefsHelper.deleteMultipleStudents(studentsToDelete);

      final successCount = result['success'] ?? 0;
      final errorCount = result['errors'] ?? 0;

      Navigator.of(context).pop(); // Cerrar diálogo de progreso
      await _showDeleteResultsDialog(successCount, errorCount);

      // Recargar lista
      await _loadStudents();
    } catch (e) {
      Navigator.of(context).pop();
      _showMessage('Error durante la eliminación: $e');
      print('❌ Error en eliminación masiva: $e');
    }
  }

  Future<void> _showDeleteResultsDialog(int success, int errors) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              success > 0 && errors == 0 ? Icons.check_circle : Icons.info,
              color: success > 0 && errors == 0 ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Resultados'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildResultRow(
              'Eliminados:',
              '$success',
              Icons.check_circle,
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildResultRow('Errores:', '$errors', Icons.error, Colors.red),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  void _showFacultadSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.school,
                        color: Color(0xFF1E3A5F),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Seleccionar Facultad',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _facultadesCarreras.keys.length,
                    itemBuilder: (context, index) {
                      final facultad = _facultadesCarreras.keys.elementAt(
                        index,
                      );
                      final carreras = _facultadesCarreras[facultad]!;
                      final isSelected = _selectedFacultad == facultad;
                      // ✅ Verificar si es UPeU
                      final isUniversidad =
                          facultad == 'Universidad Peruana Unión';

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1E3A5F).withOpacity(0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1E3A5F)
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF1E3A5F)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isUniversidad
                                  ? Icons.account_balance
                                  : Icons.school,
                              color: isSelected ? Colors.white : Colors.grey,
                            ),
                          ),
                          title: Text(
                            facultad,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? const Color(0xFF1E3A5F)
                                  : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            isUniversidad
                                ? 'Toda la universidad'
                                : '${carreras.length} carreras disponibles',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? const Color(0xFF1E3A5F)
                                  : Colors.grey,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF1E3A5F),
                                )
                              : const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                          onTap: () {
                            _onFacultadChanged(facultad);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCarreraSelector() {
    if (_selectedFacultad == null) {
      _showMessage('⚠️ Debes seleccionar una Facultad primero');
      return;
    }

    // ✅ No mostrar selector si es UPeU
    if (!_requiereCarrera(_selectedFacultad)) {
      _showMessage('ℹ️ Esta opción no requiere seleccionar carrera');
      return;
    }

    final availableCarreras = _facultadesCarreras[_selectedFacultad]!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.8,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.book,
                        color: Color(0xFF1E3A5F),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Seleccionar Carrera',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _selectedFacultad!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E3A5F),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: availableCarreras.length,
                    itemBuilder: (context, index) {
                      final carrera = availableCarreras[index];
                      final isSelected = _selectedCarrera == carrera;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1E3A5F).withOpacity(0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1E3A5F)
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF1E3A5F)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.book,
                              color: isSelected ? Colors.white : Colors.grey,
                            ),
                          ),
                          title: Text(
                            carrera,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? const Color(0xFF1E3A5F)
                                  : Colors.black87,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF1E3A5F),
                                )
                              : null,
                          onTap: () {
                            _onCarreraChanged(carrera);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteStudent(
    String carreraPath,
    String studentId,
    String studentName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar a $studentName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        final success = await PrefsHelper.deleteStudent(carreraPath, studentId);
        if (success) {
          _showMessage('Estudiante eliminado exitosamente');
          await _loadStudents();
          if (_selectedFacultad != null &&
              (_selectedCarrera != null ||
                  !_requiereCarrera(_selectedFacultad))) {
            _applyFilters();
          }
        } else {
          _showMessage('Error eliminando estudiante');
        }
      } catch (e) {
        _showMessage('Error: $e');
      }

      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Widget _buildEstudianteCard(Map<String, dynamic> student, int index) {
    final studentId = student['id'];
    final isExpanded = _expandedStudents.contains(studentId);

    // ✅ Determinar el path correcto para eliminar
    final carreraPath = _requiereCarrera(_selectedFacultad)
        ? (student['carreraPath'] ?? _selectedCarrera ?? '')
        : _selectedFacultad ?? '';

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedStudents.remove(studentId);
                  } else {
                    _expandedStudents.add(studentId);
                  }
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Hero(
                      tag: 'student_avatar_$studentId',
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A5F), Color(0xFF2E4A6F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E3A5F).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            student['name']
                                    ?.toString()
                                    .substring(0, 1)
                                    .toUpperCase() ??
                                'E',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student['name'] ?? 'Sin nombre',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade100,
                                      Colors.blue.shade50,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.badge,
                                      size: 12,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      student['codigoUniversitario'] ??
                                          'Sin código',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green.shade100,
                                      Colors.green.shade50,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.credit_card,
                                      size: 12,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      student['dni'] ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Color(0xFF64748B),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Color(0xFF1E3A5F)),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Eliminar'),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditDialog(student, carreraPath, studentId);
                        } else if (value == 'delete') {
                          _deleteStudent(
                            carreraPath,
                            studentId,
                            student['name'] ?? 'Estudiante',
                          );
                        }
                      },
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: const Icon(
                        Icons.expand_more,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.grey.shade300,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(
                                'Email:',
                                student['email'] ?? 'Sin email',
                                Icons.email,
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Usuario:',
                                student['username'] ?? 'Sin usuario',
                                Icons.person,
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Facultad:',
                                student['facultad'] ?? 'Sin facultad',
                                Icons.school,
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Carrera:',
                                student['carrera'] ?? 'Sin carrera',
                                Icons.book,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF1E3A5F)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1E3A5F),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    if (_selectedFacultad == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school_outlined,
                  size: 80,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Selecciona una Facultad',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Usa los filtros de arriba para comenzar',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    } else if (_requiereCarrera(_selectedFacultad) &&
        _selectedCarrera == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.book_outlined,
                  size: 80,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Selecciona una Carrera',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Facultad: $_selectedFacultad',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1E3A5F),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off,
                  size: 80,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No se encontraron estudiantes',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No hay estudiantes registrados en ${_requiereCarrera(_selectedFacultad) ? _selectedCarrera : _selectedFacultad}',
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF2E4A6F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Estudiantes Registrados',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _allStudents.isEmpty
                          ? null
                          : _deleteAllStudents,
                      icon: const Icon(Icons.delete_sweep, color: Colors.white),
                      tooltip: 'Eliminar todos',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _loadStudents,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      tooltip: 'Actualizar',
                    ),
                  ),
                ],
              ),
            ),
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
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1E3A5F),
                        ),
                      )
                    : Column(
                        children: [
                          SlideTransition(
                            position:
                                Tween<Offset>(
                                  begin: const Offset(0, -1),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: _filterAnimationController,
                                    curve: Curves.easeOut,
                                  ),
                                ),
                            child: FadeTransition(
                              opacity: _filterAnimationController,
                              child: Container(
                                margin: const EdgeInsets.all(20),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF1E3A5F,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.filter_list,
                                            color: Color(0xFF1E3A5F),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Filtros',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E3A5F),
                                          ),
                                        ),
                                        const Spacer(),
                                        if (_selectedFacultad != null ||
                                            _selectedCarrera != null)
                                          TextButton.icon(
                                            onPressed: _clearFilters,
                                            icon: const Icon(
                                              Icons.clear_all,
                                              size: 18,
                                            ),
                                            label: const Text('Limpiar'),
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(
                                                0xFF1E3A5F,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _showFacultadSelector,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color:
                                                        _selectedFacultad !=
                                                            null
                                                        ? const Color(
                                                            0xFF1E3A5F,
                                                          )
                                                        : Colors.grey.shade300,
                                                    width:
                                                        _selectedFacultad !=
                                                            null
                                                        ? 2
                                                        : 1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  color:
                                                      _selectedFacultad != null
                                                      ? const Color(
                                                          0xFF1E3A5F,
                                                        ).withOpacity(0.05)
                                                      : Colors.white,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.school,
                                                      color:
                                                          _selectedFacultad !=
                                                              null
                                                          ? const Color(
                                                              0xFF1E3A5F,
                                                            )
                                                          : Colors.grey,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            'Facultad',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Color(
                                                                0xFF64748B,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Text(
                                                            _selectedFacultad ??
                                                                'Seleccionar',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  _selectedFacultad !=
                                                                      null
                                                                  ? const Color(
                                                                      0xFF1E3A5F,
                                                                    )
                                                                  : Colors.grey,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // ✅ Solo mostrar selector de carrera si se requiere
                                        if (_requiereCarrera(
                                          _selectedFacultad,
                                        )) ...[
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: _showCarreraSelector,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color:
                                                          _selectedCarrera !=
                                                              null
                                                          ? const Color(
                                                              0xFF1E3A5F,
                                                            )
                                                          : Colors
                                                                .grey
                                                                .shade300,
                                                      width:
                                                          _selectedCarrera !=
                                                              null
                                                          ? 2
                                                          : 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    color:
                                                        _selectedCarrera != null
                                                        ? const Color(
                                                            0xFF1E3A5F,
                                                          ).withOpacity(0.05)
                                                        : Colors.white,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.book,
                                                        color:
                                                            _selectedCarrera !=
                                                                null
                                                            ? const Color(
                                                                0xFF1E3A5F,
                                                              )
                                                            : Colors.grey,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            const Text(
                                                              'Carrera',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: Color(
                                                                  0xFF64748B,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              _selectedCarrera ??
                                                                  'Seleccionar',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color:
                                                                    _selectedCarrera !=
                                                                        null
                                                                    ? const Color(
                                                                        0xFF1E3A5F,
                                                                      )
                                                                    : Colors
                                                                          .grey,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    // ✅ Mostrar búsqueda si facultad está seleccionada y (no requiere carrera O carrera está seleccionada)
                                    if (_selectedFacultad != null &&
                                        (!_requiereCarrera(_selectedFacultad) ||
                                            _selectedCarrera != null)) ...[
                                      const SizedBox(height: 16),
                                      TextField(
                                        controller: _searchController,
                                        decoration: InputDecoration(
                                          labelText: 'Buscar estudiante',
                                          labelStyle: const TextStyle(
                                            color: Color(0xFF64748B),
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.search,
                                            color: Color(0xFF1E3A5F),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF1E3A5F),
                                              width: 2,
                                            ),
                                          ),
                                          hintText: 'Nombre, código o DNI',
                                          hintStyle: const TextStyle(
                                            color: Color(0xFF64748B),
                                          ),
                                          suffixIcon:
                                              _searchController.text.isNotEmpty
                                              ? IconButton(
                                                  onPressed: () {
                                                    _searchController.clear();
                                                    _applyFilters();
                                                  },
                                                  icon: const Icon(
                                                    Icons.clear,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                )
                                              : null,
                                        ),
                                        onChanged: (_) => _applyFilters(),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(
                                                0xFF1E3A5F,
                                              ).withOpacity(0.1),
                                              const Color(
                                                0xFF1E3A5F,
                                              ).withOpacity(0.05),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _filteredStudents.isEmpty
                                                  ? Icons.info_outline
                                                  : Icons.check_circle_outline,
                                              size: 18,
                                              color: const Color(0xFF1E3A5F),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _filteredStudents.isEmpty
                                                  ? 'No se encontraron estudiantes'
                                                  : 'Mostrando ${_filteredStudents.length} estudiante${_filteredStudents.length != 1 ? 's' : ''}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1E3A5F),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: _filteredStudents.isEmpty
                                ? _buildEmptyState()
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      0,
                                      20,
                                      20,
                                    ),
                                    itemCount: _filteredStudents.length,
                                    itemBuilder: (context, index) {
                                      return _buildEstudianteCard(
                                        _filteredStudents[index],
                                        index,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
