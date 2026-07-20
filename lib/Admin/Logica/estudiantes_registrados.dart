import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/prefs_helper.dart';
import '/student_security_service.dart';
import '/admin/logica/filiales_service.dart';

class EstudiantesRegistradosScreen extends StatefulWidget {
  const EstudiantesRegistradosScreen({super.key});

  @override
  State<EstudiantesRegistradosScreen> createState() =>
      _EstudiantesRegistradosScreenState();
}

class _EstudiantesRegistradosScreenState
    extends State<EstudiantesRegistradosScreen>
    with TickerProviderStateMixin {

  final FilialesService _filialesService = FilialesService();
  Map<String, dynamic> _estructuraFiliales = {};
  bool _estructuraCargada = false;

  String? _selectedFilialId;
  String? _selectedFilialNombre;
  String? _selectedFacultad;
  String? _selectedCarrera;
  String? _carreraPath;

  bool _isLoading = false;
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  final Set<String> _expandedStudents = {};

  final Map<String, String> _dniCache = {};

  final _searchController = TextEditingController();

  final _editNombreController              = TextEditingController();
  final _editEmailController               = TextEditingController();
  final _editCodigoController              = TextEditingController();
  final _editDniController                 = TextEditingController();
  final _editCelularController             = TextEditingController();
  final _editCorreoInstitucionalController = TextEditingController();

  late AnimationController _filterAnimController;

  static const _primaryColor  = Color(0xFF1E3A5F);
  static const _surfaceColor  = Color(0xFFE8EDF2);
  static const _subtextColor  = Color(0xFF64748B);
  static const _borderColor   = Color(0xFFE2E8F0);
  static const _minTapTarget  = 44.0;

  @override
  void initState() {
    super.initState();
    _filterAnimController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..forward();
    _loadEstructura();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filterAnimController.dispose();
    _editNombreController.dispose();
    _editEmailController.dispose();
    _editCodigoController.dispose();
    _editDniController.dispose();
    _editCelularController.dispose();
    _editCorreoInstitucionalController.dispose();
    super.dispose();
  }

  Future<void> _loadEstructura() async {
    setState(() => _isLoading = true);
    try {
      await _filialesService.inicializarSiEsNecesario();
      final estructura = await _filialesService.getEstructuraCompleta();
      setState(() {
        _estructuraFiliales = estructura;
        _estructuraCargada  = true;
      });
    } catch (e) {
      _showMessage('Error cargando estructura: $e');
    }
    setState(() => _isLoading = false);
  }

  List<String> get _filialesDisponibles => _estructuraFiliales.keys.toList();

  List<String> _getFacultades(String filialId) {
    final filial = _estructuraFiliales[filialId];
    if (filial == null) return [];
    return (filial['facultades'] as Map<String, dynamic>).keys.toList();
  }

  List<Map<String, dynamic>> _getCarreras(String filialId, String facultad) {
    final filial = _estructuraFiliales[filialId];
    if (filial == null) return [];
    final facultades  = filial['facultades'] as Map<String, dynamic>;
    final facultadData = facultades[facultad];
    if (facultadData == null) return [];
    return List<Map<String, dynamic>>.from(facultadData['carreras'] ?? []);
  }

  String _getNombreFilial(String filialId) =>
      _estructuraFiliales[filialId]?['nombre'] ?? filialId;

  void _onFilialChanged(String? filialId) {
    setState(() {
      _selectedFilialId     = filialId;
      _selectedFilialNombre = filialId != null ? _getNombreFilial(filialId) : null;
      _selectedFacultad     = null;
      _selectedCarrera      = null;
      _carreraPath          = null;
      _allStudents          = [];
      _filteredStudents     = [];
      _expandedStudents.clear();
      _dniCache.clear();
      _searchController.clear();
    });
  }

  void _onFacultadChanged(String? facultad) {
    setState(() {
      _selectedFacultad = facultad;
      _selectedCarrera  = null;
      _carreraPath      = null;
      _allStudents      = [];
      _filteredStudents = [];
      _expandedStudents.clear();
      _dniCache.clear();
      _searchController.clear();
    });
  }

  void _onCarreraChanged(String? carrera) {
    setState(() {
      _selectedCarrera = carrera;
      _expandedStudents.clear();
      _dniCache.clear();
      _searchController.clear();
    });
    if (carrera != null && _selectedFilialNombre != null) {
      _carreraPath = '${_selectedFilialNombre}_$carrera';
      _loadStudents();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedFilialId     = null;
      _selectedFilialNombre = null;
      _selectedFacultad     = null;
      _selectedCarrera      = null;
      _carreraPath          = null;
      _allStudents          = [];
      _filteredStudents     = [];
      _expandedStudents.clear();
      _dniCache.clear();
      _searchController.clear();
    });
  }

  Future<void> _loadStudents() async {
    if (_carreraPath == null) return;
    setState(() => _isLoading = true);
    _dniCache.clear();
    try {
      final students = await PrefsHelper.getStudentsByCarrera(_carreraPath!);
      setState(() {
        _allStudents      = students;
        _filteredStudents = students;
      });
      await _precargarTodosDnis(students);
      if (_searchController.text.isNotEmpty) _applySearch();
    } catch (e) {
      _showMessage('Error cargando estudiantes: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _precargarTodosDnis(List<Map<String, dynamic>> students) async {
    if (students.isEmpty) return;
    try {
      await Future.wait(
        students.map((s) => _decryptDni(s)),
        eagerError: false,
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error precargando DNIs: $e');
    }
  }

  Future<String> _decryptDni(Map<String, dynamic> student) async {
    if (_carreraPath == null) return 'Sin DNI';
    final studentId = student['id'] as String? ?? '';
    if (studentId.isEmpty) return 'Sin DNI';
    if (_dniCache.containsKey(studentId)) return _dniCache[studentId]!;

    final dni = await StudentSecurityService.decryptDni(
      carreraPath: _carreraPath!,
      studentId:   studentId,
      studentData: student,
    );
    final result = dni.isNotEmpty ? dni : 'Sin DNI';
    _dniCache[studentId] = result;
    return result;
  }

  void _applySearch() {
    final term = _searchController.text.toLowerCase().trim();
    if (term.isEmpty) {
      setState(() => _filteredStudents = List.from(_allStudents));
      return;
    }
    setState(() {
      _filteredStudents = _allStudents.where((s) {
        final name      = (s['name']                ?? '').toString().toLowerCase();
        final codigo    = (s['codigoUniversitario'] ?? '').toString().toLowerCase();
        final studentId = s['id'] as String? ?? '';
        final dniCached = (_dniCache[studentId]     ?? '').toLowerCase();
        return name.contains(term) ||
            codigo.contains(term) ||
            dniCached.contains(term);
      }).toList();
    });
  }

  Future<void> _showEditDialog(
      Map<String, dynamic> student, String studentId) async {
    final dniActual = await _decryptDni(student);

    _editNombreController.text              = student['name']                ?? '';
    _editEmailController.text               = student['email']               ?? '';
    _editCodigoController.text              = student['codigoUniversitario'] ?? '';
    _editDniController.text                 = dniActual == 'Sin DNI' ? '' : dniActual;
    _editCelularController.text             = student['celular']             ?? '';
    _editCorreoInstitucionalController.text = student['correoInstitucional'] ?? '';

    final cicloOptions = ['1','2','3','4','5','6','7','8','9','10'];
    final grupoOptions = ['Único','1','2','3','4'];

    String? selectedCiclo = _safeOption(student['ciclo'], cicloOptions);
    String? selectedGrupo = _safeOption(student['grupo'], grupoOptions);
    bool obscureDni       = true;
    final formKey         = GlobalKey<FormState>();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final screenHeight = MediaQuery.of(context).size.height;
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final availableHeight = screenHeight - keyboardHeight;

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: availableHeight * 0.88,
                maxWidth:  560,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
                    child: Row(
                      children: [
                        Container(
                          width:  40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.edit, color: _primaryColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Editar Estudiante',
                            style: TextStyle(
                              fontSize:   18,
                              fontWeight: FontWeight.bold,
                              color:      _primaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        SizedBox(
                          width:  _minTapTarget,
                          height: _minTapTarget,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, size: 20),
                            tooltip: 'Cerrar',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _editField(
                              _editNombreController,
                              'Nombre completo',
                              Icons.person,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'El nombre es requerido'
                                      : null,
                            ),
                            const SizedBox(height: 14),
                            _editField(
                              _editEmailController,
                              'Email',
                              Icons.email,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 14),
                            _editField(
                              _editCodigoController,
                              'Código universitario',
                              Icons.badge,
                            ),
                            const SizedBox(height: 14),
                            _buildDniField(
                              obscure:   obscureDni,
                              dniActual: dniActual,
                              onToggle:  () =>
                                  setDialogState(() => obscureDni = !obscureDni),
                            ),
                            const SizedBox(height: 14),
                            _editField(
                              _editCelularController,
                              'Celular',
                              Icons.phone,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 14),
                            _editField(
                              _editCorreoInstitucionalController,
                              'Correo institucional',
                              Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _dropdownField(
                                    label:     'Ciclo',
                                    icon:      Icons.layers,
                                    value:     selectedCiclo,
                                    options:   cicloOptions,
                                    itemLabel: (v) => 'Ciclo $v',
                                    onChanged: (v) =>
                                        setDialogState(() => selectedCiclo = v),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _dropdownField(
                                    label:     'Grupo',
                                    icon:      Icons.groups,
                                    value:     selectedGrupo,
                                    options:   grupoOptions,
                                    itemLabel: (v) => 'Grupo $v',
                                    onChanged: (v) =>
                                        setDialogState(() => selectedGrupo = v),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: _minTapTarget,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _subtextColor,
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: _minTapTarget,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (formKey.currentState!.validate()) {
                                  final nuevoDni = _editDniController.text.trim();
                                  final dniParaActualizar = (nuevoDni.isNotEmpty &&
                                          nuevoDni != dniActual &&
                                          nuevoDni != 'Sin DNI')
                                      ? nuevoDni
                                      : null;
                                  Navigator.of(context).pop();
                                  await _updateStudent(
                                    studentId:           studentId,
                                    name:                _editNombreController.text.trim(),
                                    email:               _editEmailController.text.trim(),
                                    codigoUniversitario: _editCodigoController.text.trim(),
                                    dni:                 dniParaActualizar,
                                    celular:             _editCelularController.text.trim(),
                                    correoInstitucional: _editCorreoInstitucionalController.text.trim(),
                                    ciclo: selectedCiclo,
                                    grupo: selectedGrupo,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Guardar'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDniField({
    required bool obscure,
    required String dniActual,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:        const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border:       Border.all(color: const Color(0xFFFFE082)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Color(0xFFD4863B), size: 15),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Este es el DNI actual del estudiante. '
                  'Puedes copiarlo o escribir uno nuevo.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF7D5A00)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller:   _editDniController,
          obscureText:  obscure,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'DNI actual',
            labelStyle: const TextStyle(fontSize: 13, color: _subtextColor),
            prefixIcon: const Icon(Icons.credit_card,
                color: _primaryColor, size: 20),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width:  _minTapTarget,
                  height: _minTapTarget,
                  child: IconButton(
                    icon: const Icon(Icons.copy_rounded,
                        color: Color(0xFF3B6FD4), size: 19),
                    tooltip:   'Copiar DNI',
                    onPressed: () {
                      if (_editDniController.text.isNotEmpty) {
                        _copyToClipboard(_editDniController.text);
                      }
                    },
                  ),
                ),
                SizedBox(
                  width:  _minTapTarget,
                  height: _minTapTarget,
                  child: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.grey[400],
                      size:  20,
                    ),
                    onPressed: onToggle,
                  ),
                ),
              ],
            ),
            helperText:  'Dejar vacío para no cambiar el DNI',
            helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(color: _primaryColor, width: 1.5),
            ),
            filled:         true,
            fillColor:      const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showMessage('DNI copiado al portapapeles');
  }

  String? _safeOption(dynamic value, List<String> options) {
    if (value == null) return null;
    final v = value.toString();
    return options.contains(v) ? v : null;
  }

  Widget _editField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:   controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText:  label,
        prefixIcon: Icon(icon, color: _primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: _primaryColor, width: 2),
        ),
        filled:         true,
        fillColor:      Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }

  Widget _dropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    String Function(String)? itemLabel,
  }) {
    return DropdownButtonFormField<String>(
      initialValue:      value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText:  label,
        prefixIcon: Icon(icon, color: _primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: _primaryColor, width: 2),
        ),
        filled:         true,
        fillColor:      Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Sin seleccionar', overflow: TextOverflow.ellipsis),
        ),
        ...options.map((o) => DropdownMenuItem(
              value: o,
              child: Text(
                itemLabel != null ? itemLabel(o) : o,
                overflow: TextOverflow.ellipsis,
              ),
            )),
      ],
      onChanged:     onChanged,
      dropdownColor: Colors.white,
      menuMaxHeight: 260,
      icon: const Icon(Icons.arrow_drop_down, color: _primaryColor),
    );
  }

  Future<void> _updateStudent({
    required String studentId,
    String? name,
    String? email,
    String? codigoUniversitario,
    String? dni,
    String? celular,
    String? correoInstitucional,
    String? ciclo,
    String? grupo,
  }) async {
    if (_carreraPath == null) return;
    setState(() => _isLoading = true);
    try {
      final success = await PrefsHelper.updateStudent(
        carreraPath:         _carreraPath!,
        studentId:           studentId,
        name:                name?.isNotEmpty                == true ? name                : null,
        email:               email?.isNotEmpty               == true ? email               : null,
        codigoUniversitario: codigoUniversitario?.isNotEmpty == true ? codigoUniversitario : null,
        dni:                 dni?.isNotEmpty                 == true ? dni                 : null,
        celular:             celular?.isNotEmpty             == true ? celular             : null,
        correoInstitucional: correoInstitucional?.isNotEmpty == true ? correoInstitucional : null,
        ciclo: ciclo,
        grupo: grupo,
      );
      if (success) {
        if (dni != null && dni.isNotEmpty) {
          await StudentSecurityService.encryptAndSaveDni(
            carreraPath: _carreraPath!,
            studentId:   studentId,
            dni:         dni,
          );
          _dniCache.remove(studentId);
        }
        _showMessage('Estudiante actualizado exitosamente');
        await _loadStudents();
      } else {
        _showMessage('Error actualizando estudiante');
      }
    } catch (e) {
      _showMessage('Error: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _deleteStudent(String studentId, String studentName) async {
    if (_carreraPath == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirmar eliminación',
          style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
        ),
        content: Text('¿Estás seguro de que quieres eliminar a $studentName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: _subtextColor),
            child: const Text('Cancelar'),
          ),
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
        final success = await PrefsHelper.deleteStudent(_carreraPath!, studentId);
        if (success) {
          _dniCache.remove(studentId);
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

  Future<void> _deleteAllStudents() async {
    if (_filteredStudents.isEmpty || _carreraPath == null) {
      _showMessage('No hay estudiantes para eliminar');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ADVERTENCIA',
                style: TextStyle(
                  color:      Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize:   18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize:      MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estás a punto de eliminar TODOS los estudiantes de $_selectedCarrera.',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:        Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: Colors.red.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.delete_forever,
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Total a eliminar: ${_filteredStudents.length} estudiantes',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:      Colors.red.shade700,
                              fontSize:   13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Esta acción NO se puede deshacer\n'
                      '• Los estudiantes no podrán iniciar sesión',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: _subtextColor),
            child: const Text('Cancelar'),
          ),
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _primaryColor),
              SizedBox(height: 16),
              Text(
                'Eliminando estudiantes...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Esto puede tomar unos segundos',
                style: TextStyle(fontSize: 12, color: _subtextColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final studentsToDelete = _filteredStudents
          .map((s) => {
                'carreraPath': _carreraPath!,
                'studentId':   s['id'] as String,
              })
          .toList();
      final result = await PrefsHelper.deleteMultipleStudents(studentsToDelete);
      if (mounted) Navigator.of(context).pop();
      await _showDeleteResultsDialog(
          result['success'] ?? 0, result['errors'] ?? 0);
      await _loadStudents();
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showMessage('Error durante la eliminación: $e');
    }
  }

  Future<void> _showDeleteResultsDialog(int success, int errors) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              success > 0 && errors == 0
                  ? Icons.check_circle
                  : Icons.info,
              color: success > 0 && errors == 0
                  ? Colors.green
                  : Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'Resultados',
              style: TextStyle(
                  color: _primaryColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _resultRow('Eliminados:', '$success',
                Icons.check_circle, Colors.green),
            const SizedBox(height: 8),
            _resultRow('Errores:', '$errors',
                Icons.error, Colors.red),
          ],
        ),
        actions: [
          SizedBox(
            height: _minTapTarget,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(
      String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color:      color,
                fontSize:   16)),
      ],
    );
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message,
              overflow: TextOverflow.ellipsis, maxLines: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showFilialSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (context) => _buildSelectorSheet(
        title: 'Seleccionar Sede',
        icon:  Icons.location_city,
        items: _filialesDisponibles.map((id) {
          return _SelectorItem(
            value:      id,
            label:      _getNombreFilial(id),
            subtitle:   _estructuraFiliales[id]?['ubicacion'] ?? '',
            isSelected: _selectedFilialId == id,
          );
        }).toList(),
        onSelected: (value) {
          _onFilialChanged(value);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showFacultadSelector() {
    if (_selectedFilialId == null) {
      _showMessage('Debes seleccionar una Sede primero');
      return;
    }
    final facultades = _getFacultades(_selectedFilialId!);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (context) => _buildSelectorSheet(
        title: 'Seleccionar Facultad',
        icon:  Icons.business,
        items: facultades.map((f) {
          final carreras = _getCarreras(_selectedFilialId!, f);
          return _SelectorItem(
            value:      f,
            label:      f,
            subtitle:   '${carreras.length} carreras',
            isSelected: _selectedFacultad == f,
          );
        }).toList(),
        onSelected: (value) {
          _onFacultadChanged(value);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showCarreraSelector() {
    if (_selectedFilialId == null || _selectedFacultad == null) {
      _showMessage('Debes seleccionar una Facultad primero');
      return;
    }
    final carreras = _getCarreras(_selectedFilialId!, _selectedFacultad!);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (context) => _buildSelectorSheet(
        title: 'Seleccionar Carrera',
        icon:  Icons.school,
        items: carreras.map((c) {
          return _SelectorItem(
            value:      c['nombre'] as String,
            label:      c['nombre'] as String,
            subtitle:   '',
            isSelected: _selectedCarrera == c['nombre'],
          );
        }).toList(),
        onSelected: (value) {
          _onCarreraChanged(value);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildSelectorSheet({
    required String title,
    required IconData icon,
    required List<_SelectorItem> items,
    required ValueChanged<String> onSelected,
  }) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize:     0.92,
          minChildSize:     0.4,
          expand: false,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              children: [
                Container(
                  width:  50,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color:        Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width:  44,
                      height: 44,
                      decoration: BoxDecoration(
                        color:        _primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: _primaryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize:   20,
                          fontWeight: FontWeight.bold,
                          color:      _primaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount:  items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Semantics(
                        button:   true,
                        selected: item.isSelected,
                        label:    item.label,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: item.isSelected
                                ? _primaryColor.withValues(alpha: 0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: item.isSelected
                                  ? _primaryColor
                                  : Colors.grey.shade300,
                              width: item.isSelected ? 2 : 1,
                            ),
                          ),
                          child: ListTile(
                            minVerticalPadding: 12,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            title: Text(
                              item.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: item.isSelected
                                    ? _primaryColor
                                    : Colors.black87,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            subtitle: item.subtitle.isNotEmpty
                                ? Text(
                                    item.subtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: item.isSelected
                                          ? _primaryColor.withValues(alpha: 0.7)
                                          : Colors.grey,
                                    ),
                                  )
                                : null,
                            trailing: item.isSelected
                                ? const Icon(Icons.check_circle,
                                    color: _primaryColor)
                                : const Icon(Icons.arrow_forward_ios,
                                    size: 14, color: Colors.grey),
                            onTap: () => onSelected(item.value),
                          ),
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

  Widget _buildEstudianteCard(Map<String, dynamic> student, int index) {
    final studentId  = student['id'] as String? ?? '';
    final isExpanded = _expandedStudents.contains(studentId);
    final animDuration =
        Duration(milliseconds: 200 + (index * 30).clamp(0, 400));

    return TweenAnimationBuilder<double>(
      duration: animDuration,
      tween:    Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 30 * (1 - value)),
        child:  Opacity(opacity: value, child: child),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
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
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width:  50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: _primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            (student['name']?.toString() ?? 'E')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              color:      Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize:   20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student['name'] ?? 'Sin nombre',
                              style: const TextStyle(
                                fontSize:   15,
                                fontWeight: FontWeight.bold,
                                color:      _primaryColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing:    6,
                              runSpacing: 4,
                              children: [
                                _badge(
                                  student['codigoUniversitario'] ?? 'Sin código',
                                  Icons.badge,
                                  Colors.blue,
                                ),
                                FutureBuilder<String>(
                                  future: _decryptDni(student),
                                  builder: (context, snapshot) {
                                    final dni =
                                        snapshot.connectionState ==
                                                ConnectionState.waiting
                                            ? '...'
                                            : (snapshot.data?.isNotEmpty == true
                                                ? snapshot.data!
                                                : 'Sin DNI');
                                    return _badge(
                                        dni, Icons.credit_card, Colors.green);
                                  },
                                ),
                                if (student['ciclo'] != null)
                                  _badge(
                                    'Ciclo ${student['ciclo']}',
                                    Icons.layers,
                                    Colors.purple,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width:  _minTapTarget,
                            height: _minTapTarget,
                            child: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert,
                                  color: _subtextColor, size: 22),
                              tooltip: 'Opciones',
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value:  'edit',
                                  height: _minTapTarget,
                                  child: Row(children: [
                                    Icon(Icons.edit,
                                        color: _primaryColor, size: 18),
                                    SizedBox(width: 8),
                                    Text('Editar',
                                        style: TextStyle(fontSize: 14)),
                                  ]),
                                ),
                                const PopupMenuItem(
                                  value:  'delete',
                                  height: _minTapTarget,
                                  child: Row(children: [
                                    Icon(Icons.delete,
                                        color: Colors.red, size: 18),
                                    SizedBox(width: 8),
                                    Text('Eliminar',
                                        style: TextStyle(fontSize: 14)),
                                  ]),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditDialog(student, studentId);
                                } else if (value == 'delete') {
                                  _deleteStudent(
                                      studentId,
                                      student['name'] ?? 'Estudiante');
                                }
                              },
                            ),
                          ),
                          SizedBox(
                            width:  _minTapTarget,
                            height: _minTapTarget,
                            child: Center(
                              child: AnimatedRotation(
                                turns:    isExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 250),
                                child: const Icon(Icons.expand_more,
                                    color: _subtextColor, size: 22),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve:    Curves.easeInOut,
                child: isExpanded
                    ? Column(
                        children: [
                          Divider(
                            height:    1,
                            color:     Colors.grey.shade200,
                            indent:    16,
                            endIndent: 16,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _infoRow(
                                  'Usuario:',
                                  student['username'] ?? 'Sin usuario',
                                  Icons.person,
                                ),
                                const SizedBox(height: 10),
                                _dniInfoRow(student),
                                const SizedBox(height: 10),
                                _infoRow(
                                  'Celular:',
                                  student['celular'] ?? 'Sin celular',
                                  Icons.phone,
                                ),
                                if (student['email'] != null &&
                                    (student['email'] as String).isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  _infoRow(
                                    'Email:',
                                    student['email'],
                                    Icons.email,
                                  ),
                                ],
                                if (student['grupo'] != null) ...[
                                  const SizedBox(height: 10),
                                  _infoRow(
                                    'Grupo:',
                                    'Grupo ${student['grupo']}',
                                    Icons.groups,
                                  ),
                                ],
                                if (student['facultad'] != null) ...[
                                  const SizedBox(height: 10),
                                  _infoRow(
                                    'Facultad:',
                                    student['facultad'],
                                    Icons.business,
                                  ),
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
      ),
    );
  }

  Widget _dniInfoRow(Map<String, dynamic> student) {
    final studentId = student['id'] as String? ?? '';
    final dni       = _dniCache[studentId];

    if (dni == null) {
      return FutureBuilder<String>(
        future: _decryptDni(student),
        builder: (context, snapshot) {
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting;
          final dniText = isLoading
              ? 'Descifrando...'
              : (snapshot.hasError
                  ? '(error)'
                  : (snapshot.data ?? 'Sin DNI'));
          return _infoRowWithCopy(
            'DNI:',
            dniText,
            Icons.credit_card,
            isLoading: isLoading,
            onCopy: !isLoading &&
                    dniText != 'Sin DNI' &&
                    dniText != '(error)'
                ? () => _copyToClipboard(dniText)
                : null,
          );
        },
      );
    }
    return _infoRowWithCopy(
      'DNI:',
      dni,
      Icons.credit_card,
      onCopy: dni != 'Sin DNI' ? () => _copyToClipboard(dni) : null,
    );
  }

  Widget _infoRowWithCopy(
    String label,
    String value,
    IconData icon, {
    bool isLoading = false,
    VoidCallback? onCopy,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width:  34,
          height: 34,
          decoration: BoxDecoration(
            color:        _primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: _primaryColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize:   12,
                  color:      _subtextColor,
                ),
              ),
              const SizedBox(height: 2),
              isLoading
                  ? const SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(
                        backgroundColor: _borderColor,
                        color:           _primaryColor,
                      ),
                    )
                  : Text(
                      value,
                      style: const TextStyle(
                        fontSize:   13,
                        color:      _primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
            ],
          ),
        ),
        if (onCopy != null)
          SizedBox(
            width:  _minTapTarget,
            height: _minTapTarget,
            child: IconButton(
              icon:    const Icon(Icons.copy_rounded,
                  color: Color(0xFF3B6FD4), size: 17),
              tooltip: 'Copiar DNI',
              onPressed: onCopy,
            ),
          ),
      ],
    );
  }

  Widget _badge(String text, IconData icon, MaterialColor color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:        color.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.shade700),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize:   11,
                color:      color.shade700,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width:  34,
          height: 34,
          decoration: BoxDecoration(
            color:        _primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: _primaryColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize:   12,
                  color:      _subtextColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize:   13,
                  color:      _primaryColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    IconData icon;
    String title, subtitle;

    if (_selectedFilialId == null) {
      icon     = Icons.location_city_outlined;
      title    = 'Selecciona una Sede';
      subtitle = 'Usa los filtros de arriba para comenzar';
    } else if (_selectedFacultad == null) {
      icon     = Icons.business_outlined;
      title    = 'Selecciona una Facultad';
      subtitle = _getNombreFilial(_selectedFilialId!);
    } else if (_selectedCarrera == null) {
      icon     = Icons.school_outlined;
      title    = 'Selecciona una Carrera';
      subtitle = _selectedFacultad!;
    } else {
      icon     = Icons.search_off;
      title    = 'No se encontraron estudiantes';
      subtitle = _searchController.text.isNotEmpty
          ? 'No hay resultados para "${_searchController.text}"'
          : 'No hay estudiantes registrados en esta carrera';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width:  100,
              height: 100,
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: _primaryColor),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize:   20,
                fontWeight: FontWeight.bold,
                color:      _primaryColor,
              ),
              textAlign: TextAlign.center,
              maxLines:  2,
              overflow:  TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: _subtextColor),
              textAlign: TextAlign.center,
              maxLines:  3,
              overflow:  TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width:  _minTapTarget,
                        height: _minTapTarget,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Volver',
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Estudiantes Registrados',
                          style: TextStyle(
                            fontSize:   18,
                            fontWeight: FontWeight.bold,
                            color:      Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      _headerIconBtn(
                        icon:    Icons.delete_sweep,
                        tooltip: 'Eliminar todos',
                        onTap:
                            _allStudents.isEmpty ? null : _deleteAllStudents,
                      ),
                      const SizedBox(width: 6),
                      _headerIconBtn(
                        icon:    Icons.refresh,
                        tooltip: 'Actualizar',
                        onTap:   _carreraPath != null ? _loadStudents : null,
                      ),
                    ],
                  ),
                  if (_selectedCarrera != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.school,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedCarrera!,
                                  style: const TextStyle(
                                    color:      Colors.white,
                                    fontSize:   13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                Text(
                                  '${_selectedFacultad ?? ''} · ${_selectedFilialNombre ?? ''}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color:        Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_allStudents.length} total',
                              style: const TextStyle(
                                color:      Colors.white,
                                fontSize:   12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.only(
                    topLeft:  Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: _isLoading && !_estructuraCargada
                    ? const Center(
                        child: CircularProgressIndicator(color: _primaryColor))
                    : Column(
                        children: [
                          SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -1),
                              end:   Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: _filterAnimController,
                              curve:  Curves.easeOut,
                            )),
                            child: FadeTransition(
                              opacity: _filterAnimController,
                              child: Container(
                                margin:  const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:        Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color:      Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset:     const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width:  36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: _primaryColor.withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.filter_list,
                                              color: _primaryColor, size: 18),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Filtros',
                                          style: TextStyle(
                                            fontSize:   16,
                                            fontWeight: FontWeight.bold,
                                            color:      _primaryColor,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (_selectedFilialId != null)
                                          TextButton.icon(
                                            onPressed: _clearFilters,
                                            icon: const Icon(Icons.clear_all,
                                                size: 16),
                                            label: const Text('Limpiar',
                                                style:
                                                    TextStyle(fontSize: 13)),
                                            style: TextButton.styleFrom(
                                                foregroundColor: _primaryColor),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: _filterButton(
                                            label: 'Sede',
                                            value: _selectedFilialNombre,
                                            icon:  Icons.location_city,
                                            onTap: _showFilialSelector,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _filterButton(
                                            label: 'Facultad',
                                            value: _selectedFacultad != null
                                                ? _selectedFacultad!
                                                    .replaceFirst(
                                                        'Facultad de ', '')
                                                : null,
                                            icon:    Icons.business,
                                            onTap:   _showFacultadSelector,
                                            enabled: _selectedFilialId != null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    _filterButton(
                                      label:     'Carrera',
                                      value:     _selectedCarrera,
                                      icon:      Icons.school,
                                      onTap:     _showCarreraSelector,
                                      enabled:   _selectedFacultad != null,
                                      fullWidth: true,
                                    ),

                                    if (_selectedCarrera != null) ...[
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _searchController,
                                        decoration: InputDecoration(
                                          labelText: 'Buscar estudiante',
                                          labelStyle: const TextStyle(
                                            color:    _subtextColor,
                                            fontSize: 14,
                                          ),
                                          prefixIcon: const Icon(
                                              Icons.search,
                                              color: _primaryColor),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: Colors.grey.shade300),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                              color: _primaryColor,
                                              width: 2,
                                            ),
                                          ),
                                          hintText: 'Nombre, código o DNI',
                                          hintStyle: const TextStyle(
                                            color:    _subtextColor,
                                            fontSize: 14,
                                          ),
                                          filled:    true,
                                          fillColor: Colors.grey.shade50,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12),
                                          suffixIcon:
                                              _searchController.text.isNotEmpty
                                                  ? SizedBox(
                                                      width:  _minTapTarget,
                                                      height: _minTapTarget,
                                                      child: IconButton(
                                                        onPressed: () {
                                                          _searchController.clear();
                                                          _applySearch();
                                                        },
                                                        icon: const Icon(
                                                          Icons.clear,
                                                          color: _subtextColor,
                                                          size: 18,
                                                        ),
                                                      ),
                                                    )
                                                  : null,
                                        ),
                                        onChanged: (_) => _applySearch(),
                                      ),
                                      const SizedBox(height: 10),
                                      if (!_isLoading)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _primaryColor
                                                .withValues(alpha: 0.07),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _filteredStudents.isEmpty
                                                    ? Icons.info_outline
                                                    : Icons
                                                        .check_circle_outline,
                                                size:  16,
                                                color: _primaryColor,
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  _filteredStudents.isEmpty
                                                      ? 'No se encontraron estudiantes'
                                                      : 'Mostrando ${_filteredStudents.length} de ${_allStudents.length} estudiante${_allStudents.length != 1 ? 's' : ''}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color:      _primaryColor,
                                                    fontSize:   13,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: _primaryColor))
                                : _filteredStudents.isEmpty
                                    ? _buildEmptyState()
                                    : ListView.builder(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 4, 16, 20),
                                        itemCount: _filteredStudents.length,
                                        itemBuilder: (context, index) =>
                                            _buildEstudianteCard(
                                          _filteredStudents[index],
                                          index,
                                        ),
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

  Widget _filterButton({
    required String label,
    required String? value,
    required IconData icon,
    required VoidCallback onTap,
    bool enabled   = true,
    bool fullWidth = false,
  }) {
    final isSelected     = value != null;
    final effectiveColor = enabled ? _primaryColor : Colors.grey.shade400;

    final Widget content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:        enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Semantics(
          button: true,
          label:  '$label: ${value ?? 'Seleccionar'}',
          child: Container(
            constraints: const BoxConstraints(minHeight: _minTapTarget),
            padding:     const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected && enabled
                    ? _primaryColor
                    : Colors.grey.shade300,
                width: isSelected && enabled ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: isSelected && enabled
                  ? _primaryColor.withValues(alpha: 0.05)
                  : enabled
                      ? Colors.white
                      : Colors.grey.shade50,
            ),
            child: Row(
              children: [
                Icon(icon, color: effectiveColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment:  MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value ?? 'Seleccionar',
                        style: TextStyle(
                          fontSize:   12,
                          fontWeight: FontWeight.w600,
                          color: isSelected && enabled
                              ? _primaryColor
                              : enabled
                                  ? Colors.grey
                                  : Colors.grey.shade400,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: effectiveColor, size: 18),
              ],
            ),
          ),
        ),
      ),
    );

    return fullWidth
        ? SizedBox(width: double.infinity, child: content)
        : content;
  }

  Widget _headerIconBtn({
    required IconData icon,
    required String   tooltip,
    VoidCallback?     onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width:  _minTapTarget,
        height: _minTapTarget,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap:        onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: onTap == null
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: onTap == null
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectorItem {
  final String value;
  final String label;
  final String subtitle;
  final bool   isSelected;

  const _SelectorItem({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.isSelected,
  });
}