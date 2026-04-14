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
  // ── Estado de sesión ────────────────────────────────────────────
  bool _isAdminCarrera = false;
  String? _adminCarreraPath; // path directo: "Lima_EP Ingeniería de Sistemas"

  bool _isLoading = false;
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];

  // Filtros (solo para admin general)
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
    'Universidad Peruana Unión': [],
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

  // ── Lifecycle ───────────────────────────────────────────────────
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

    _initSession();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimationController.dispose();
    _filterAnimationController.dispose();
    _editNombreController.dispose();
    _editEmailController.dispose();
    _editCodigoController.dispose();
    _editDniController.dispose();
    _editCelularController.dispose();
    _editCorreoInstitucionalController.dispose();
    super.dispose();
  }

  // ── Detectar sesión y cargar automáticamente si es admin carrera ─
  Future<void> _initSession() async {
    final isAdminCarrera = await PrefsHelper.isAdminCarrera();

    if (isAdminCarrera) {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData != null) {
        final filial = adminData['filialNombre'] ?? '';
        final carrera = adminData['carrera'] ?? '';
        // El path en Firestore se guarda como "filialNombre_carrera"
        final path = '${filial}_$carrera';

        setState(() {
          _isAdminCarrera = true;
          _adminCarreraPath = path;
        });

        print('✅ Admin carrera detectado. Path: $path');
        await _loadStudentsForPath(path);
      }
    }
  }

  // ── Helpers de filtros (solo admin general) ─────────────────────
  bool _requiereCarrera(String? facultad) {
    if (facultad == null) return true;
    return facultad != 'Universidad Peruana Unión';
  }

  // ── Carga de estudiantes ────────────────────────────────────────

  /// Carga directa por path (usado por admin carrera)
  Future<void> _loadStudentsForPath(String path) async {
    setState(() => _isLoading = true);
    try {
      final students = await PrefsHelper.getStudentsByCarrera(path);
      setState(() {
        _allStudents = students;
        _filteredStudents = students;
      });
      if (_searchController.text.isNotEmpty) _applyFilters();
    } catch (e) {
      _showMessage('Error cargando estudiantes: $e');
    }
    setState(() => _isLoading = false);
  }

  /// Carga usando los filtros seleccionados (admin general)
  Future<void> _loadStudents() async {
    if (_isAdminCarrera) {
      // Admin carrera siempre usa su propio path
      await _loadStudentsForPath(_adminCarreraPath!);
      return;
    }

    if (_requiereCarrera(_selectedFacultad) && _selectedCarrera == null) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final carreraPath = _requiereCarrera(_selectedFacultad)
          ? _selectedCarrera!
          : _selectedFacultad!;

      final students = await PrefsHelper.getStudentsByCarrera(carreraPath);
      setState(() {
        _allStudents = students;
        _filteredStudents = students;
      });
      if (_searchController.text.isNotEmpty) _applyFilters();
    } catch (e) {
      _showMessage('Error cargando estudiantes: $e');
    }
    setState(() => _isLoading = false);
  }

  // ── Filtros ─────────────────────────────────────────────────────
  void _applyFilters() {
    if (_isAdminCarrera) {
      // Admin carrera: solo filtro de búsqueda, sin filtros de carrera
      _applySearchOnly();
      return;
    }

    if (_selectedFacultad == null ||
        (_requiereCarrera(_selectedFacultad) && _selectedCarrera == null) ||
        _allStudents.isEmpty) {
      setState(() => _filteredStudents = []);
      return;
    }

    _applySearchOnly();
  }

  void _applySearchOnly() {
    final searchTerm = _searchController.text.toLowerCase().trim();
    if (searchTerm.isEmpty) {
      setState(() => _filteredStudents = List.from(_allStudents));
      return;
    }

    final result = _allStudents.where((student) {
      final name = (student['name'] ?? '').toString().toLowerCase();
      final codigo =
          (student['codigoUniversitario'] ?? '').toString().toLowerCase();
      final dni = (student['dni'] ?? '').toString().toLowerCase();
      return name.contains(searchTerm) ||
          codigo.contains(searchTerm) ||
          dni.contains(searchTerm);
    }).toList();

    setState(() => _filteredStudents = result);
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
    if (facultad == 'Universidad Peruana Unión') _loadStudents();
  }

  void _onCarreraChanged(String? carrera) {
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

  // ── path activo (para editar/eliminar) ──────────────────────────
  String _activeCarreraPath(Map<String, dynamic> student) {
    if (_isAdminCarrera) return _adminCarreraPath!;
    return _requiereCarrera(_selectedFacultad)
        ? (student['carreraPath'] ?? _selectedCarrera ?? '')
        : _selectedFacultad ?? '';
  }

  // ── Edición ─────────────────────────────────────────────────────
  Future<void> _showEditDialog(
    Map<String, dynamic> student,
    String carreraPath,
    String studentId,
  ) async {
    _editNombreController.text = student['name'] ?? '';
    _editEmailController.text = student['email'] ?? '';
    _editCodigoController.text = student['codigoUniversitario'] ?? '';
    _editDniController.text = student['dni'] ?? '';
    _editCelularController.text = student['celular'] ?? '';
    _editCorreoInstitucionalController.text =
        student['correoInstitucional'] ?? '';

    final modoContratoOptions = ['Regular', 'Convenio', 'Especial'];
    final modalidadEstudioOptions = ['Presencial', 'Semipresencial', 'Virtual'];
    final cicloOptions = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'];
    final grupoOptions = ['Único', '1', '2', '3', '4'];

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

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  child: Text('Editar Estudiante',
                      style: TextStyle(fontSize: 18))),
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
                    _editField(_editNombreController, 'Nombre completo',
                        Icons.person,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'El nombre es requerido'
                            : null),
                    const SizedBox(height: 16),
                    _editField(_editEmailController, 'Email', Icons.email,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    _editField(_editCodigoController, 'Código universitario',
                        Icons.badge),
                    const SizedBox(height: 16),
                    _editField(_editDniController, 'DNI', Icons.credit_card,
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    _editField(
                        _editCelularController, 'Celular', Icons.phone,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _editField(_editCorreoInstitucionalController,
                        'Correo institucional', Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Modo Contrato',
                      icon: Icons.description,
                      value: selectedModoContrato,
                      options: modoContratoOptions,
                      onChanged: (v) =>
                          setDialogState(() => selectedModoContrato = v),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Modalidad Estudio',
                      icon: Icons.school,
                      value: selectedModalidadEstudio,
                      options: modalidadEstudioOptions,
                      onChanged: (v) =>
                          setDialogState(() => selectedModalidadEstudio = v),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Ciclo',
                      icon: Icons.layers,
                      value: selectedCiclo,
                      options: cicloOptions,
                      itemLabel: (v) => 'Ciclo $v',
                      onChanged: (v) =>
                          setDialogState(() => selectedCiclo = v),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Grupo',
                      icon: Icons.groups,
                      value: selectedGrupo,
                      options: grupoOptions,
                      itemLabel: (v) => 'Grupo $v',
                      onChanged: (v) =>
                          setDialogState(() => selectedGrupo = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar')),
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
                    correoInstitucional:
                        _editCorreoInstitucionalController.text.trim(),
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
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    String Function(String)? itemLabel,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: [
        const DropdownMenuItem<String>(
            value: null, child: Text('Sin seleccionar')),
        ...options.map((o) => DropdownMenuItem(
            value: o, child: Text(itemLabel != null ? itemLabel(o) : o))),
      ],
      onChanged: onChanged,
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
        codigoUniversitario:
            codigoUniversitario?.isNotEmpty == true ? codigoUniversitario : null,
        dni: dni?.isNotEmpty == true ? dni : null,
        celular: celular?.isNotEmpty == true ? celular : null,
        correoInstitucional:
            correoInstitucional?.isNotEmpty == true ? correoInstitucional : null,
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
    }
    setState(() => _isLoading = false);
  }

  // ── Eliminación individual ──────────────────────────────────────
  Future<void> _deleteStudent(
    String carreraPath,
    String studentId,
    String studentName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar eliminación'),
        content:
            Text('¿Estás seguro de que quieres eliminar a $studentName?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final success =
            await PrefsHelper.deleteStudent(carreraPath, studentId);
        if (success) {
          _showMessage('Estudiante eliminado exitosamente');
          await _loadStudents();
        } else {
          _showMessage('Error eliminando estudiante');
        }
      } catch (e) {
        _showMessage('Error: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  // ── Eliminación masiva ──────────────────────────────────────────
  Future<void> _deleteAllStudents() async {
    if (_filteredStudents.isEmpty) {
      _showMessage('No hay estudiantes para eliminar');
      return;
    }

    // Nombre para mostrar en el diálogo
    String displayName;
    if (_isAdminCarrera) {
      displayName = _adminCarreraPath!;
    } else if (_requiereCarrera(_selectedFacultad)) {
      displayName = _selectedCarrera!;
    } else {
      displayName = _selectedFacultad!;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
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
                      Icon(Icons.delete_forever,
                          color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Total a eliminar: ${_filteredStudents.length} estudiantes',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Esta acción NO se puede deshacer\n'
                    '• Se eliminarán de $displayName\n'
                    '• Los estudiantes no podrán iniciar sesión',
                    style: TextStyle(
                        fontSize: 13, color: Colors.red.shade900),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('SÍ, ELIMINAR TODO'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Diálogo de progreso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Eliminando estudiantes...',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Esto puede tomar unos segundos',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );

    try {
      // Determinar el carreraPath correcto
      final carreraPath = _isAdminCarrera
          ? _adminCarreraPath!
          : (_requiereCarrera(_selectedFacultad)
              ? _selectedCarrera!
              : _selectedFacultad!);

      final studentsToDelete = _filteredStudents
          .map((s) => {
                'carreraPath': carreraPath,
                'studentId': s['id'] as String,
              })
          .toList();

      final result =
          await PrefsHelper.deleteMultipleStudents(studentsToDelete);

      Navigator.of(context).pop(); // Cerrar progreso
      await _showDeleteResultsDialog(
          result['success'] ?? 0, result['errors'] ?? 0);
      await _loadStudents();
    } catch (e) {
      Navigator.of(context).pop();
      _showMessage('Error durante la eliminación: $e');
    }
  }

  Future<void> _showDeleteResultsDialog(int success, int errors) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              success > 0 && errors == 0
                  ? Icons.check_circle
                  : Icons.info,
              color: success > 0 && errors == 0
                  ? Colors.green
                  : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Resultados'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildResultRow(
                'Eliminados:', '$success', Icons.check_circle, Colors.green),
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
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(
      String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 16)),
      ],
    );
  }

  // ── Selectores de filtro (solo admin general) ───────────────────
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
          builder: (context, scrollController) => Padding(
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
                        color:
                            const Color(0xFF1E3A5F).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.school,
                          color: Color(0xFF1E3A5F), size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Seleccionar Facultad',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _facultadesCarreras.keys.length,
                    itemBuilder: (context, index) {
                      final facultad =
                          _facultadesCarreras.keys.elementAt(index);
                      final carreras = _facultadesCarreras[facultad]!;
                      final isSelected = _selectedFacultad == facultad;
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
                              horizontal: 16, vertical: 8),
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
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey,
                            ),
                          ),
                          title: Text(facultad,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? const Color(0xFF1E3A5F)
                                      : Colors.black87)),
                          subtitle: Text(
                            isUniversidad
                                ? 'Toda la universidad'
                                : '${carreras.length} carreras disponibles',
                            style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? const Color(0xFF1E3A5F)
                                    : Colors.grey),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle,
                                  color: Color(0xFF1E3A5F))
                              : const Icon(Icons.arrow_forward_ios,
                                  size: 16, color: Colors.grey),
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
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10)),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF1E3A5F).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.book,
                          color: Color(0xFF1E3A5F), size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Text('Seleccionar Carrera',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F))),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_selectedFacultad!,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E3A5F),
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center),
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
                              horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF1E3A5F)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.book,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey),
                          ),
                          title: Text(carrera,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? const Color(0xFF1E3A5F)
                                      : Colors.black87)),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle,
                                  color: Color(0xFF1E3A5F))
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

  // ── Utilidades de UI ────────────────────────────────────────────
  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // ── Card de estudiante ──────────────────────────────────────────
  Widget _buildEstudianteCard(Map<String, dynamic> student, int index) {
    final studentId = student['id'];
    final isExpanded = _expandedStudents.contains(studentId);
    final carreraPath = _activeCarreraPath(student);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 50 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
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
              onTap: () => setState(() {
                if (isExpanded) {
                  _expandedStudents.remove(studentId);
                } else {
                  _expandedStudents.add(studentId);
                }
              }),
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
                            colors: [
                              Color(0xFF1E3A5F),
                              Color(0xFF2E4A6F)
                            ],
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
                                fontSize: 24),
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
                                color: Color(0xFF1E3A5F)),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _badge(
                                student['codigoUniversitario'] ??
                                    'Sin código',
                                Icons.badge,
                                Colors.blue,
                              ),
                              _badge(
                                student['dni'] ?? 'N/A',
                                Icons.credit_card,
                                Colors.green,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          color: Color(0xFF64748B)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit, color: Color(0xFF1E3A5F)),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Eliminar'),
                          ]),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditDialog(student, carreraPath, studentId);
                        } else if (value == 'delete') {
                          _deleteStudent(carreraPath, studentId,
                              student['name'] ?? 'Estudiante');
                        }
                      },
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: const Icon(Icons.expand_more,
                          color: Color(0xFF64748B)),
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
                          margin:
                              const EdgeInsets.symmetric(horizontal: 16),
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              Colors.grey.shade300,
                              Colors.transparent,
                            ]),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow('Email:',
                                  student['email'] ?? 'Sin email', Icons.email),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                  'Usuario:',
                                  student['username'] ?? 'Sin usuario',
                                  Icons.person),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                  'Facultad:',
                                  student['facultad'] ?? 'Sin facultad',
                                  Icons.school),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                  'Carrera:',
                                  student['carrera'] ?? 'Sin carrera',
                                  Icons.book),
                              if (student['ciclo'] != null) ...[
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                    'Ciclo:', student['ciclo'], Icons.layers),
                              ],
                              if (student['grupo'] != null) ...[
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                    'Grupo:', student['grupo'], Icons.groups),
                              ],
                              if (student['sede'] != null) ...[
                                const SizedBox(height: 12),
                                _buildInfoRow('Sede:', student['sede'],
                                    Icons.location_on),
                              ],
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

  Widget _badge(String text, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color.shade100, color.shade50]),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.shade700),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11,
                  color: color.shade700,
                  fontWeight: FontWeight.w600)),
        ],
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
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E3A5F),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Empty state ─────────────────────────────────────────────────
  Widget _buildEmptyState() {
    // Admin carrera: solo puede haber "sin estudiantes"
    if (_isAdminCarrera) {
      return _emptyStateWidget(
        Icons.search_off,
        'No se encontraron estudiantes',
        'No hay estudiantes registrados en tu carrera',
      );
    }

    if (_selectedFacultad == null) {
      return _emptyStateWidget(
        Icons.school_outlined,
        'Selecciona una Facultad',
        'Usa los filtros de arriba para comenzar',
      );
    }
    if (_requiereCarrera(_selectedFacultad) && _selectedCarrera == null) {
      return _emptyStateWidget(
        Icons.book_outlined,
        'Selecciona una Carrera',
        'Facultad: $_selectedFacultad',
      );
    }
    return _emptyStateWidget(
      Icons.search_off,
      'No se encontraron estudiantes',
      'No hay estudiantes registrados en ${_requiereCarrera(_selectedFacultad) ? _selectedCarrera : _selectedFacultad}',
    );
  }

  Widget _emptyStateWidget(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: Opacity(opacity: value, child: child),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 80, color: const Color(0xFF1E3A5F)),
            ),
          ),
          const SizedBox(height: 24),
          Text(title,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F))),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(subtitle,
                style:
                    const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  // ── BUILD ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                          color: Colors.white),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed:
                          _allStudents.isEmpty ? null : _deleteAllStudents,
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

            // Body
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
                            color: Color(0xFF1E3A5F)))
                    : Column(
                        children: [
                          SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -1),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: _filterAnimationController,
                              curve: Curves.easeOut,
                            )),
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
                                    // ── Banner info para admin carrera ──
                                    if (_isAdminCarrera) ...[
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E3A5F)
                                              .withOpacity(0.07),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFF1E3A5F)
                                                .withOpacity(0.2),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.lock_outline,
                                                color: Color(0xFF1E3A5F),
                                                size: 20),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _adminCarreraPath ?? '',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1E3A5F),
                                                ),
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    // ── Filtros solo para admin general ─
                                    if (!_isAdminCarrera) ...[
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E3A5F)
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                                Icons.filter_list,
                                                color: Color(0xFF1E3A5F),
                                                size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text('Filtros',
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      Color(0xFF1E3A5F))),
                                          const Spacer(),
                                          if (_selectedFacultad != null ||
                                              _selectedCarrera != null)
                                            TextButton.icon(
                                              onPressed: _clearFilters,
                                              icon: const Icon(
                                                  Icons.clear_all,
                                                  size: 18),
                                              label:
                                                  const Text('Limpiar'),
                                              style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      const Color(
                                                          0xFF1E3A5F)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _filterButton(
                                              label: 'Facultad',
                                              value: _selectedFacultad,
                                              icon: Icons.school,
                                              onTap: _showFacultadSelector,
                                            ),
                                          ),
                                          if (_requiereCarrera(
                                              _selectedFacultad)) ...[
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _filterButton(
                                                label: 'Carrera',
                                                value: _selectedCarrera,
                                                icon: Icons.book,
                                                onTap: _showCarreraSelector,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    // ── Búsqueda (siempre visible cuando hay datos) ──
                                    if (_isAdminCarrera ||
                                        (_selectedFacultad != null &&
                                            (!_requiereCarrera(
                                                    _selectedFacultad) ||
                                                _selectedCarrera !=
                                                    null))) ...[
                                      TextField(
                                        controller: _searchController,
                                        decoration: InputDecoration(
                                          labelText: 'Buscar estudiante',
                                          labelStyle: const TextStyle(
                                              color: Color(0xFF64748B)),
                                          prefixIcon: const Icon(Icons.search,
                                              color: Color(0xFF1E3A5F)),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                  color:
                                                      Colors.grey.shade300)),
                                          enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                  color:
                                                      Colors.grey.shade300)),
                                          focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                  color: Color(0xFF1E3A5F),
                                                  width: 2)),
                                          hintText: 'Nombre, código o DNI',
                                          hintStyle: const TextStyle(
                                              color: Color(0xFF64748B)),
                                          suffixIcon:
                                              _searchController.text.isNotEmpty
                                                  ? IconButton(
                                                      onPressed: () {
                                                        _searchController
                                                            .clear();
                                                        _applyFilters();
                                                      },
                                                      icon: const Icon(
                                                          Icons.clear,
                                                          color: Color(
                                                              0xFF64748B)),
                                                    )
                                                  : null,
                                        ),
                                        onChanged: (_) => _applyFilters(),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [
                                            const Color(0xFF1E3A5F)
                                                .withOpacity(0.1),
                                            const Color(0xFF1E3A5F)
                                                .withOpacity(0.05),
                                          ]),
                                          borderRadius:
                                              BorderRadius.circular(12),
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
                                                  fontSize: 14),
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
                                        20, 0, 20, 20),
                                    itemCount: _filteredStudents.length,
                                    itemBuilder: (context, index) =>
                                        _buildEstudianteCard(
                                            _filteredStudents[index], index),
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

  // ── Botón de filtro genérico ────────────────────────────────────
  Widget _filterButton({
    required String label,
    required String? value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isSelected = value != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF1E3A5F)
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? const Color(0xFF1E3A5F).withOpacity(0.05)
                : Colors.white,
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: isSelected
                      ? const Color(0xFF1E3A5F)
                      : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text(
                      value ?? 'Seleccionar',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFF1E3A5F)
                              : Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}