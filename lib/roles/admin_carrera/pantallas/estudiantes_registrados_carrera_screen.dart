import 'package:flutter/material.dart';
import '../logica/estudiantes_registrados_carrera_service.dart';
import 'estudiante_edit_dialog.dart';

class EstudiantesRegistradosCarreraScreen extends StatefulWidget {
  const EstudiantesRegistradosCarreraScreen({super.key});

  @override
  State<EstudiantesRegistradosCarreraScreen> createState() =>
      _EstudiantesRegistradosCarreraScreenState();
}

class _EstudiantesRegistradosCarreraScreenState
    extends State<EstudiantesRegistradosCarreraScreen>
    with TickerProviderStateMixin {
  final EstudiantesRegistradosCarreraService _service =
      EstudiantesRegistradosCarreraService();

  String _carreraPath = '';
  String _carreraNombre = '';
  String _facultadNombre = '';
  String _sedeNombre = '';

  bool _isLoading = true;

  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];

  final _searchController = TextEditingController();
  final Set<String> _expandedStudents = {};
  final Map<String, String> _dniCache = {};

  late AnimationController _filterAnimController;

  @override
  void initState() {
    super.initState();
    _filterAnimController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _initSession();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filterAnimController.dispose();
    super.dispose();
  }

  Future<void> _initSession() async {
    try {
      final adminData = await _service.obtenerDatosAdminCarrera();
      if (adminData != null) {
        final filialNombre =
            adminData['filialNombre'] ?? adminData['filial'] ?? '';
        final carrera = adminData['carrera'] ?? '';
        final path = '${filialNombre}_$carrera';
        if (mounted) {
          setState(() {
            _carreraPath = path;
            _carreraNombre = carrera;
            _facultadNombre = adminData['facultad'] ?? '';
            _sedeNombre = filialNombre;
          });
        }
        await _loadStudents();
      } else {
        if (mounted) setState(() => _isLoading = false);
        _showMessage('⚠️ No se encontraron datos del administrador');
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showMessage('Error cargando sesión: $e');
    }
  }

  Future<void> _loadStudents() async {
    if (_carreraPath.isEmpty) return;
    if (mounted) setState(() => _isLoading = true);
    _dniCache.clear();
    try {
      final students = await _service.obtenerEstudiantes(_carreraPath);
      if (mounted) {
        setState(() {
          _allStudents = students;
          _filteredStudents = students;
        });
      }
      await _precargarTodosDnis(students);
      if (_searchController.text.isNotEmpty) _applySearch();
    } catch (e) {
      _showMessage('Error cargando estudiantes: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _precargarTodosDnis(
      List<Map<String, dynamic>> students) async {
    if (students.isEmpty) return;
    try {
      await Future.wait(
        students.map((s) => _decryptDni(s)),
        eagerError: false,
      );
      if (mounted) {
        setState(() {});
        _filterAnimController.forward();
      }
    } catch (e) {
      debugPrint('Error precargando DNIs: $e');
      if (mounted) _filterAnimController.forward();
    }
  }

  void _applySearch() {
    final term = _searchController.text.toLowerCase().trim();
    if (term.isEmpty) {
      if (mounted) setState(() => _filteredStudents = List.from(_allStudents));
      return;
    }
    if (mounted) {
      setState(() {
        _filteredStudents = _allStudents.where((s) {
          final name = (s['name'] ?? '').toString().toLowerCase();
          final codigo =
              (s['codigoUniversitario'] ?? '').toString().toLowerCase();
          final studentId = s['id'] as String? ?? '';
          final dniCached = (_dniCache[studentId] ?? '').toLowerCase();
          return name.contains(term) ||
              codigo.contains(term) ||
              dniCached.contains(term);
        }).toList();
      });
    }
  }

  Future<String> _decryptDni(Map<String, dynamic> student) async {
    final studentId = student['id'] as String? ?? '';
    if (studentId.isEmpty) return 'Sin DNI';
    if (_dniCache.containsKey(studentId)) return _dniCache[studentId]!;
    final result = await _service.descifrarDni(
      carreraPath: _carreraPath,
      studentId: studentId,
      studentData: student,
    );
    _dniCache[studentId] = result;
    return result;
  }

  Future<void> _showEditDialog(
      Map<String, dynamic> student, String studentId) async {
    final dniActual = await _decryptDni(student);
    if (!mounted) return;

    await mostrarDialogoEditarEstudiante(
      context,
      student: student,
      dniActual: dniActual,
      onGuardar: ({
        required name,
        required email,
        required codigoUniversitario,
        dni,
        required celular,
        required correoInstitucional,
        ciclo,
        grupo,
      }) {
        return _updateStudent(
          studentId: studentId,
          name: name,
          email: email,
          codigoUniversitario: codigoUniversitario,
          dni: dni,
          celular: celular,
          correoInstitucional: correoInstitucional,
          ciclo: ciclo,
          grupo: grupo,
        );
      },
      onMessage: _showMessage,
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
    if (mounted) setState(() => _isLoading = true);
    try {
      final success = await _service.actualizarEstudiante(
        carreraPath: _carreraPath,
        studentId: studentId,
        name: name,
        email: email,
        codigoUniversitario: codigoUniversitario,
        dni: dni,
        celular: celular,
        correoInstitucional: correoInstitucional,
        ciclo: ciclo,
        grupo: grupo,
      );

      if (success) {
        if (dni != null && dni.isNotEmpty) {
          _dniCache.remove(studentId);
        }
        _showMessage('✅ Estudiante actualizado exitosamente');
        await _loadStudents();
      } else {
        _showMessage('❌ Error actualizando estudiante');
      }
    } catch (e) {
      _showMessage('❌ Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _deleteStudent(
      String studentId, String studentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirmar eliminación',
          style: TextStyle(
              color: Color(0xFF1E3A5F), fontWeight: FontWeight.bold),
        ),
        content: Text(
            '¿Estás seguro de que quieres eliminar a $studentName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B)),
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
      if (mounted) setState(() => _isLoading = true);
      try {
        final success = await _service.eliminarEstudiante(
          carreraPath: _carreraPath,
          studentId: studentId,
        );
        if (success) {
          _dniCache.remove(studentId);
          _showMessage('✅ Estudiante eliminado exitosamente');
          await _loadStudents();
        } else {
          _showMessage('❌ Error eliminando estudiante');
        }
      } catch (e) {
        _showMessage('❌ Error: $e');
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAllStudents() async {
    if (_filteredStudents.isEmpty) {
      _showMessage('No hay estudiantes para eliminar');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ADVERTENCIA',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estás a punto de eliminar TODOS los estudiantes de $_carreraNombre.',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
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
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Total a eliminar: ${_filteredStudents.length} estudiantes',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                                fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Esta acción NO se puede deshacer\n'
                      '• Los estudiantes no podrán iniciar sesión',
                      style: TextStyle(
                          fontSize: 12, color: Colors.red.shade900),
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
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B)),
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

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF1E3A5F)),
              SizedBox(height: 16),
              Text(
                'Eliminando estudiantes...',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Esto puede tomar unos segundos',
                style: TextStyle(
                    fontSize: 12, color: Color(0xFF64748B)),
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
                'carreraPath': _carreraPath,
                'studentId': s['id'] as String,
              })
          .toList();

      final result = await _service.eliminarEstudiantes(studentsToDelete);
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
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
            const Text('Resultados',
                style: TextStyle(
                    color: Color(0xFF1E3A5F),
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _resultRow('Eliminados:', '$success',
                Icons.check_circle, Colors.green),
            const SizedBox(height: 8),
            _resultRow(
                'Errores:', '$errors', Icons.error, Colors.red),
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

  Widget _resultRow(
      String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 14))),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16)),
      ],
    );
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message,
            overflow: TextOverflow.ellipsis, maxLines: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Widget _buildEstudianteCard(
      Map<String, dynamic> student, int index) {
    final studentId = student['id'] as String? ?? '';
    final isExpanded = _expandedStudents.contains(studentId);
    final animDuration = Duration(
      milliseconds: 200 + (index * 30).clamp(0, 400),
    );

    return TweenAnimationBuilder<double>(
      duration: animDuration,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 30 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
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
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E3A5F),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              (student['name']?.toString() ?? 'E')
                                  .characters
                                  .first
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                student['name'] ?? 'Sin nombre',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A5F),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                                  Builder(builder: (context) {
                                    final cached =
                                        _dniCache[studentId];
                                    if (cached != null) {
                                      return _badge(cached,
                                          Icons.credit_card,
                                          Colors.green);
                                    }
                                    return FutureBuilder<String>(
                                      future: _decryptDni(student),
                                      builder: (context, snapshot) {
                                        final dni = snapshot
                                                    .connectionState ==
                                                ConnectionState.waiting
                                            ? '...'
                                            : (snapshot.data
                                                    ?.isNotEmpty ==
                                                true
                                                ? snapshot.data!
                                                : 'Sin DNI');
                                        return _badge(
                                            dni,
                                            Icons.credit_card,
                                            Colors.green);
                                      },
                                    );
                                  }),
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
                              width: 44,
                              height: 44,
                              child: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    color: Color(0xFF64748B),
                                    size: 20),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(children: [
                                      Icon(Icons.edit,
                                          color: Color(0xFF1E3A5F),
                                          size: 18),
                                      SizedBox(width: 8),
                                      Text('Editar',
                                          style:
                                              TextStyle(fontSize: 14)),
                                    ]),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(children: [
                                      Icon(Icons.delete,
                                          color: Colors.red, size: 18),
                                      SizedBox(width: 8),
                                      Text('Eliminar',
                                          style:
                                              TextStyle(fontSize: 14)),
                                    ]),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditDialog(
                                        student, studentId);
                                  } else if (value == 'delete') {
                                    _deleteStudent(
                                        studentId,
                                        student['name'] ??
                                            'Estudiante');
                                  }
                                },
                              ),
                            ),
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                child: AnimatedRotation(
                                  turns: isExpanded ? 0.5 : 0,
                                  duration:
                                      const Duration(milliseconds: 250),
                                  child: const Icon(Icons.expand_more,
                                      color: Color(0xFF64748B),
                                      size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: isExpanded
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Divider(
                              height: 1,
                              color: Colors.grey.shade200,
                              indent: 16,
                              endIndent: 16),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                16, 12, 16, 16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _infoRow(
                                    'Usuario:',
                                    student['username'] ??
                                        'Sin usuario',
                                    Icons.person),
                                const SizedBox(height: 10),
                                _dniInfoRow(student),
                                const SizedBox(height: 10),
                                _infoRow(
                                    'Celular:',
                                    student['celular'] ??
                                        'Sin celular',
                                    Icons.phone),
                                if (student['email'] != null &&
                                    (student['email'] as String)
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  _infoRow('Email:',
                                      student['email'], Icons.email),
                                ],
                                if (student['grupo'] != null) ...[
                                  const SizedBox(height: 10),
                                  _infoRow(
                                      'Grupo:',
                                      'Grupo ${student['grupo']}',
                                      Icons.groups),
                                ],
                                if (student['pago'] != null) ...[
                                  const SizedBox(height: 10),
                                  _infoRow('Pago:',
                                      student['pago'], Icons.payment),
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
    final dni = _dniCache[studentId];

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
      onCopy:
          dni != 'Sin DNI' ? () => _copyToClipboard(dni) : null,
    );
  }

  void _copyToClipboard(String text) {
    _showMessage('✅ DNI copiado al portapapeles');
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
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color:
                const Color(0xFF1E3A5F).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              Icon(icon, size: 16, color: const Color(0xFF1E3A5F)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Color(0xFF64748B))),
              const SizedBox(height: 2),
              isLoading
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const SizedBox(
                        height: 4,
                        width: 80,
                        child: LinearProgressIndicator(
                          backgroundColor: Color(0xFFE2E8F0),
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                    )
                  : Text(value,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E3A5F),
                          fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (onCopy != null)
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              icon: const Icon(Icons.copy_rounded,
                  color: Color(0xFF3B6FD4), size: 17),
              tooltip: 'Copiar DNI',
              onPressed: onCopy,
              padding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  Widget _badge(String text, IconData icon, MaterialColor color) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color.shade700),
            const SizedBox(width: 4),
            Flexible(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 11,
                      color: color.shade700,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color:
                const Color(0xFF1E3A5F).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              Icon(icon, size: 16, color: const Color(0xFF1E3A5F)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E3A5F),
                      fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off,
                  size: 64, color: Color(0xFF1E3A5F)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No se encontraron estudiantes',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F)),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No hay resultados para "${_searchController.text}"'
                  : 'No hay estudiantes registrados en esta carrera',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Volver',
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Estudiantes Registrados',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      _headerIconBtn(
                        icon: Icons.delete_sweep,
                        tooltip: 'Eliminar todos',
                        onTap: _allStudents.isEmpty
                            ? null
                            : _deleteAllStudents,
                      ),
                      const SizedBox(width: 6),
                      _headerIconBtn(
                        icon: Icons.refresh,
                        tooltip: 'Actualizar',
                        onTap: _loadStudents,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.school,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                _carreraNombre.isNotEmpty
                                    ? _carreraNombre
                                    : 'Cargando...',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                '$_facultadNombre · $_sedeNombre',
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11),
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
                            color: Colors.white
                                .withValues(alpha: 0.2),
                            borderRadius:
                                BorderRadius.circular(20),
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
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
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
                              parent: _filterAnimController,
                              curve: Curves.easeOut,
                            )),
                            child: FadeTransition(
                              opacity: _filterAnimController,
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(
                                    16, 16, 16, 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: _searchController,
                                      decoration: InputDecoration(
                                        labelText: 'Buscar estudiante',
                                        labelStyle: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 14),
                                        prefixIcon: const Icon(
                                            Icons.search,
                                            color: Color(0xFF1E3A5F)),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  12),
                                          borderSide: BorderSide(
                                              color:
                                                  Colors.grey.shade300),
                                        ),
                                        enabledBorder:
                                            OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  12),
                                          borderSide: BorderSide(
                                              color:
                                                  Colors.grey.shade300),
                                        ),
                                        focusedBorder:
                                            OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  12),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF1E3A5F),
                                              width: 2),
                                        ),
                                        hintText: 'Nombre o código',
                                        hintStyle: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 14),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12),
                                        suffixIcon: _searchController
                                                .text.isNotEmpty
                                            ? SizedBox(
                                                width: 44,
                                                height: 44,
                                                child: IconButton(
                                                  onPressed: () {
                                                    _searchController
                                                        .clear();
                                                    _applySearch();
                                                  },
                                                  icon: const Icon(
                                                      Icons.clear,
                                                      color: Color(
                                                          0xFF64748B),
                                                      size: 18),
                                                ),
                                              )
                                            : null,
                                      ),
                                      onChanged: (_) => _applySearch(),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E3A5F)
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
                                            size: 16,
                                            color:
                                                const Color(0xFF1E3A5F),
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              _filteredStudents.isEmpty
                                                  ? 'No se encontraron estudiantes'
                                                  : 'Mostrando ${_filteredStudents.length} de ${_allStudents.length} estudiante${_allStudents.length != 1 ? 's' : ''}',
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  color: Color(
                                                      0xFF1E3A5F),
                                                  fontSize: 13),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
                                        16, 4, 16, 20),
                                    itemCount: _filteredStudents.length,
                                    itemBuilder: (context, index) =>
                                        _buildEstudianteCard(
                                            _filteredStudents[index],
                                            index),
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

  Widget _headerIconBtn({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              color: onTap == null
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: onTap == null
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white,
                size: 20),
          ),
        ),
      ),
    );
  }
}
