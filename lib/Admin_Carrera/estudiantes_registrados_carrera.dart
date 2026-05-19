import 'package:flutter/material.dart';
import '/prefs_helper.dart';

class EstudiantesRegistradosCarreraScreen extends StatefulWidget {
  const EstudiantesRegistradosCarreraScreen({super.key});

  @override
  State<EstudiantesRegistradosCarreraScreen> createState() =>
      _EstudiantesRegistradosCarreraScreenState();
}

class _EstudiantesRegistradosCarreraScreenState
    extends State<EstudiantesRegistradosCarreraScreen>
    with TickerProviderStateMixin {
  // ── Datos del admin (desde prefs locales, sin Firebase) ─────────
  String _carreraPath = '';
  String _carreraNombre = '';
  String _facultadNombre = '';
  String _sedeNombre = '';

  bool _isLoading = true;

  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];

  final _searchController = TextEditingController();
  Set<String> _expandedStudents = {};

  // Controladores de edición
  final TextEditingController _editNombreController = TextEditingController();
  final TextEditingController _editEmailController = TextEditingController();
  final TextEditingController _editCodigoController = TextEditingController();
  final TextEditingController _editDniController = TextEditingController();
  final TextEditingController _editCelularController = TextEditingController();
  final TextEditingController _editCorreoInstitucionalController =
      TextEditingController();

  late AnimationController _filterAnimController;

  // ── Lifecycle ────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _filterAnimController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..forward();

    _initSession();
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

  // ── Inicialización ───────────────────────────────────────────────
  Future<void> _initSession() async {
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData != null) {
        final filialNombre = adminData['filialNombre'] ?? adminData['filial'] ?? '';
        final carrera = adminData['carrera'] ?? '';
        final path = '${filialNombre}_$carrera';

        setState(() {
          _carreraPath = path;
          _carreraNombre = carrera;
          _facultadNombre = adminData['facultad'] ?? '';
          _sedeNombre = filialNombre;
        });

        await _loadStudents();
      } else {
        setState(() => _isLoading = false);
        _showMessage('⚠️ No se encontraron datos del administrador');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('Error cargando sesión: $e');
    }
  }

  // ── Carga y filtros ──────────────────────────────────────────────
  Future<void> _loadStudents() async {
    if (_carreraPath.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final students = await PrefsHelper.getStudentsByCarrera(_carreraPath);
      setState(() {
        _allStudents = students;
        _filteredStudents = students;
      });
      if (_searchController.text.isNotEmpty) _applySearch();
    } catch (e) {
      _showMessage('Error cargando estudiantes: $e');
    }
    setState(() => _isLoading = false);
  }

  void _applySearch() {
    final term = _searchController.text.toLowerCase().trim();
    if (term.isEmpty) {
      setState(() => _filteredStudents = List.from(_allStudents));
      return;
    }
    setState(() {
      _filteredStudents = _allStudents.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final codigo = (s['codigoUniversitario'] ?? '').toString().toLowerCase();
        final dni = (s['dni'] ?? '').toString().toLowerCase();
        return name.contains(term) || codigo.contains(term) || dni.contains(term);
      }).toList();
    });
  }

  // ── Edición ──────────────────────────────────────────────────────
  Future<void> _showEditDialog(Map<String, dynamic> student, String studentId) async {
    _editNombreController.text = student['name'] ?? '';
    _editEmailController.text = student['email'] ?? '';
    _editCodigoController.text = student['codigoUniversitario'] ?? '';
    _editDniController.text = student['dni'] ?? '';
    _editCelularController.text = student['celular'] ?? '';
    _editCorreoInstitucionalController.text = student['correoInstitucional'] ?? '';

    final modoContratoOptions = ['Regular', 'Convenio', 'Especial'];
    final modalidadEstudioOptions = ['Presencial', 'Semipresencial', 'Virtual'];
    final cicloOptions = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'];
    final grupoOptions = ['Único', '1', '2', '3', '4'];

    String? selectedModoContrato = _safeOption(student['modoContrato'], modoContratoOptions);
    String? selectedModalidad = _safeOption(student['modalidadEstudio'], modalidadEstudioOptions);
    String? selectedCiclo = _safeOption(student['ciclo'], cicloOptions);
    String? selectedGrupo = _safeOption(student['grupo'], grupoOptions);

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: Color(0xFF1E3A5F)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Editar Estudiante', style: TextStyle(fontSize: 18)),
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
                    _editField(_editNombreController, 'Nombre completo', Icons.person,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'El nombre es requerido'
                            : null),
                    const SizedBox(height: 16),
                    _editField(_editEmailController, 'Email', Icons.email,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    _editField(_editCodigoController, 'Código universitario', Icons.badge),
                    const SizedBox(height: 16),
                    _editField(_editDniController, 'DNI', Icons.credit_card,
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    _editField(_editCelularController, 'Celular', Icons.phone,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _editField(_editCorreoInstitucionalController,
                        'Correo institucional', Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    _dropdownField(
                      label: 'Modo Contrato',
                      icon: Icons.description,
                      value: selectedModoContrato,
                      options: modoContratoOptions,
                      onChanged: (v) => setDialogState(() => selectedModoContrato = v),
                    ),
                    const SizedBox(height: 16),
                    _dropdownField(
                      label: 'Modalidad Estudio',
                      icon: Icons.school,
                      value: selectedModalidad,
                      options: modalidadEstudioOptions,
                      onChanged: (v) => setDialogState(() => selectedModalidad = v),
                    ),
                    const SizedBox(height: 16),
                    _dropdownField(
                      label: 'Ciclo',
                      icon: Icons.layers,
                      value: selectedCiclo,
                      options: cicloOptions,
                      itemLabel: (v) => 'Ciclo $v',
                      onChanged: (v) => setDialogState(() => selectedCiclo = v),
                    ),
                    const SizedBox(height: 16),
                    _dropdownField(
                      label: 'Grupo',
                      icon: Icons.groups,
                      value: selectedGrupo,
                      options: grupoOptions,
                      itemLabel: (v) => 'Grupo $v',
                      onChanged: (v) => setDialogState(() => selectedGrupo = v),
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
                    studentId: studentId,
                    name: _editNombreController.text.trim(),
                    email: _editEmailController.text.trim(),
                    codigoUniversitario: _editCodigoController.text.trim(),
                    dni: _editDniController.text.trim(),
                    celular: _editCelularController.text.trim(),
                    correoInstitucional:
                        _editCorreoInstitucionalController.text.trim(),
                    modoContrato: selectedModoContrato,
                    modalidadEstudio: selectedModalidad,
                    ciclo: selectedCiclo,
                    grupo: selectedGrupo,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
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

  Widget _dropdownField({
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
        const DropdownMenuItem<String>(value: null, child: Text('Sin seleccionar')),
        ...options.map((o) => DropdownMenuItem(
            value: o, child: Text(itemLabel != null ? itemLabel(o) : o))),
      ],
      onChanged: onChanged,
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
    String? modoContrato,
    String? modalidadEstudio,
    String? ciclo,
    String? grupo,
  }) async {
    setState(() => _isLoading = true);
    try {
      final success = await PrefsHelper.updateStudent(
        carreraPath: _carreraPath,
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

  // ── Eliminación individual ───────────────────────────────────────
  Future<void> _deleteStudent(String studentId, String studentName) async {
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final success = await PrefsHelper.deleteStudent(_carreraPath, studentId);
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

  // ── Eliminación masiva ───────────────────────────────────────────
  Future<void> _deleteAllStudents() async {
    if (_filteredStudents.isEmpty) {
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
              'Estás a punto de eliminar TODOS los estudiantes de $_carreraNombre.',
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
                              color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Esta acción NO se puede deshacer\n'
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      final studentsToDelete = _filteredStudents
          .map((s) => {'carreraPath': _carreraPath, 'studentId': s['id'] as String})
          .toList();

      final result = await PrefsHelper.deleteMultipleStudents(studentsToDelete);
      Navigator.of(context).pop();
      await _showDeleteResultsDialog(result['success'] ?? 0, result['errors'] ?? 0);
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
            _resultRow('Eliminados:', '$success', Icons.check_circle, Colors.green),
            const SizedBox(height: 8),
            _resultRow('Errores:', '$errors', Icons.error, Colors.red),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
      ],
    );
  }

  // ── Utilidades ───────────────────────────────────────────────────
  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // ── Card de estudiante ───────────────────────────────────────────
  Widget _buildEstudianteCard(Map<String, dynamic> student, int index) {
    final studentId = student['id'];
    final isExpanded = _expandedStudents.contains(studentId);

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
              color: Colors.black.withValues(alpha:0.05),
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
                    // Avatar con inicial
                    Container(
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
                            color: const Color(0xFF1E3A5F).withValues(alpha:0.3),
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
                    const SizedBox(width: 16),
                    // Nombre y badges
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
                                student['codigoUniversitario'] ?? 'Sin código',
                                Icons.badge,
                                Colors.blue,
                              ),
                              _badge(
                                student['dni'] ?? 'N/A',
                                Icons.credit_card,
                                Colors.green,
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
                    // Menú de acciones
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
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
                          _showEditDialog(student, studentId);
                        } else if (value == 'delete') {
                          _deleteStudent(studentId, student['name'] ?? 'Estudiante');
                        }
                      },
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: const Icon(Icons.expand_more, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
            // Detalle expandido
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
                              _infoRow('Email:',
                                  student['email'] ?? 'Sin email', Icons.email),
                              const SizedBox(height: 12),
                              _infoRow('Usuario:',
                                  student['username'] ?? 'Sin usuario', Icons.person),
                              const SizedBox(height: 12),
                              _infoRow('Celular:',
                                  student['celular'] ?? 'Sin celular', Icons.phone),
                              if (student['modoContrato'] != null) ...[
                                const SizedBox(height: 12),
                                _infoRow('Contrato:', student['modoContrato'],
                                    Icons.description),
                              ],
                              if (student['modalidadEstudio'] != null) ...[
                                const SizedBox(height: 12),
                                _infoRow('Modalidad:', student['modalidadEstudio'],
                                    Icons.school),
                              ],
                              if (student['grupo'] != null) ...[
                                const SizedBox(height: 12),
                                _infoRow('Grupo:', 'Grupo ${student['grupo']}',
                                    Icons.groups),
                              ],
                              if (student['pago'] != null) ...[
                                const SizedBox(height: 12),
                                _infoRow('Pago:', student['pago'], Icons.payment),
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
        gradient: LinearGradient(colors: [color.shade100, color.shade50]),
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

  Widget _infoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withValues(alpha:0.1),
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

  // ── Empty state ──────────────────────────────────────────────────
  Widget _buildEmptyState() {
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
                color: const Color(0xFF1E3A5F).withValues(alpha:0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off,
                  size: 80, color: Color(0xFF1E3A5F)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No se encontraron estudiantes',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F)),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _searchController.text.isNotEmpty
                  ? 'No hay resultados para "${_searchController.text}"'
                  : 'No hay estudiantes registrados en esta carrera',
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF2E4A6F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Estudiantes Registrados',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha:0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: _allStudents.isEmpty ? null : _deleteAllStudents,
                          icon: const Icon(Icons.delete_sweep, color: Colors.white),
                          tooltip: 'Eliminar todos',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha:0.2),
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
                  // ── Banner de carrera ──────────────────────────────
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha:0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha:0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.school, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _carreraNombre,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$_facultadNombre · $_sedeNombre',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha:0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_allStudents.length} total',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────
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
                        child: CircularProgressIndicator(color: Color(0xFF1E3A5F)))
                    : Column(
                        children: [
                          // ── Barra de búsqueda y contador ────────────
                          SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -1),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: _filterAnimController,
                              curve: Curves.easeOut,
                            )),
                            child: FadeTransition(
                              opacity: _filterAnimController,
                              child: Container(
                                margin: const EdgeInsets.all(20),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha:0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: _searchController,
                                      decoration: InputDecoration(
                                        labelText: 'Buscar estudiante',
                                        labelStyle:
                                            const TextStyle(color: Color(0xFF64748B)),
                                        prefixIcon: const Icon(Icons.search,
                                            color: Color(0xFF1E3A5F)),
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: Colors.grey.shade300)),
                                        enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: Colors.grey.shade300)),
                                        focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: Color(0xFF1E3A5F), width: 2)),
                                        hintText: 'Nombre, código o DNI',
                                        hintStyle: const TextStyle(
                                            color: Color(0xFF64748B)),
                                        suffixIcon:
                                            _searchController.text.isNotEmpty
                                                ? IconButton(
                                                    onPressed: () {
                                                      _searchController.clear();
                                                      _applySearch();
                                                    },
                                                    icon: const Icon(Icons.clear,
                                                        color: Color(0xFF64748B)),
                                                  )
                                                : null,
                                      ),
                                      onChanged: (_) => _applySearch(),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [
                                          const Color(0xFF1E3A5F).withValues(alpha:0.1),
                                          const Color(0xFF1E3A5F).withValues(alpha:0.05),
                                        ]),
                                        borderRadius: BorderRadius.circular(12),
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
                                                : 'Mostrando ${_filteredStudents.length} de ${_allStudents.length} estudiante${_allStudents.length != 1 ? 's' : ''}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1E3A5F),
                                                fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // ── Lista de estudiantes ─────────────────────
                          Expanded(
                            child: _filteredStudents.isEmpty
                                ? _buildEmptyState()
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
}