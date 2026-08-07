import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import '../logica/gestion_roles_service.dart';

class GestionRolesScreen extends StatefulWidget {
  const GestionRolesScreen({super.key});

  @override
  State<GestionRolesScreen> createState() => _GestionRolesScreenState();
}

class _GestionRolesScreenState extends State<GestionRolesScreen> {
  final GestionRolesService _service = GestionRolesService();

  String _carreraPath = '';
  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  final TextEditingController _searchController = TextEditingController();

  static const String rolEstudiante = GestionRolesService.rolEstudiante;
  static const String rolAsistente = GestionRolesService.rolAsistente;

  static const Map<String, Map<String, dynamic>> _rolesInfo = {
    rolEstudiante: {
      'label': 'Estudiante',
      'icon': Icons.school,
      'color': Color(0xFF1E3A5F),
      'bgColor': Color(0xFFE8EDF2),
    },
    rolAsistente: {
      'label': 'Asistente QR',
      'icon': Icons.qr_code_scanner,
      'color': Color(0xFF0D7377),
      'bgColor': Color(0xFFE0F7F7),
    },
  };

  @override
  void initState() {
    super.initState();
    _init();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final adminData = await PrefsHelper.getAdminCarreraData();
    if (adminData == null) {
      _showSnack('No se encontró información del administrador', isError: true);
      setState(() => _isLoading = false);
      return;
    }

    final filialNombre = adminData['filialNombre'] ?? adminData['filial'] ?? '';
    final carrera = adminData['carrera'] ?? '';

    try {
      final carreraPath = await _service.localizarCarreraPath(
        filialNombre: filialNombre,
        carrera: carrera,
      );

      if (carreraPath == null) {
        _showSnack('No se encontró la carrera en Firestore', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      _carreraPath = carreraPath;
    } catch (e) {
      _showSnack('Error al localizar la carrera: $e', isError: true);
      setState(() => _isLoading = false);
      return;
    }

    await _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      _students = await _service.obtenerEstudiantes(_carreraPath);
      _applyFilter(_searchController.text);
    } catch (e) {
      _showSnack('Error cargando estudiantes: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  void _onSearch() => _applyFilter(_searchController.text);

  void _applyFilter(String term) {
    final q = term.toLowerCase().trim();
    setState(() {
      _filteredStudents = q.isEmpty
          ? List.from(_students)
          : _students.where((s) {
              final name = (s['name'] ?? '').toString().toLowerCase();
              final user = (s['username'] ?? '').toString().toLowerCase();
              final cod =
                  (s['codigoUniversitario'] ?? '').toString().toLowerCase();
              return name.contains(q) || user.contains(q) || cod.contains(q);
            }).toList();
    });
  }

  Future<void> _changeRole(
      Map<String, dynamic> student, String newRole) async {
    final studentId = student['id'] as String;
    final currentRole = student['rol'] as String;

    if (currentRole == newRole) return;

    final confirm = await _showConfirmDialog(student, newRole);
    if (!confirm) return;

    setState(() => _isSaving = true);
    try {
      final bool asignarAsistente = newRole == rolAsistente;

      await _service.cambiarRol(
        carreraPath: _carreraPath,
        studentId: studentId,
        asignarAsistente: asignarAsistente,
      );

      final idx = _students.indexWhere((s) => s['id'] == studentId);
      if (idx != -1) {
        _students[idx]['rol'] = newRole;
        _students[idx]['esAsisteQR'] = asignarAsistente;
        _applyFilter(_searchController.text);
      }

      _showSnack(
        asignarAsistente
            ? 'Rol Asistente QR agregado correctamente'
            : 'Rol Asistente QR removido correctamente',
      );
    } catch (e) {
      _showSnack('Error actualizando rol: $e', isError: true);
    }
    setState(() => _isSaving = false);
  }

  Future<bool> _showConfirmDialog(
      Map<String, dynamic> student, String newRole) async {
    final roleInfo = _rolesInfo[newRole]!;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(roleInfo['icon'] as IconData,
                color: roleInfo['color'] as Color),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Cambiar Rol',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F)),
              ),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
                fontSize: 14, color: Color(0xFF334155), height: 1.5),
            children: [
              const TextSpan(text: '¿Asignar el rol '),
              TextSpan(
                text: roleInfo['label'] as String,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: roleInfo['color'] as Color),
              ),
              const TextSpan(text: ' a '),
              TextSpan(
                text: student['name'] ?? 'este estudiante',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: roleInfo['color'] as Color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? Colors.red.shade600 : const Color(0xFF0D7377),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Gestión de Roles',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isSaving ? null : _loadStudents,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                _buildBanner(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _buildSearchBar(),
                ),
                if (!_isLoading)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: _buildCountRow(),
                  ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF1E3A5F)),
                        )
                      : _filteredStudents.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: _filteredStudents.length,
                              itemBuilder: (_, i) =>
                                  _buildStudentCard(_filteredStudents[i]),
                            ),
                ),
              ],
            ),
            if (_isSaving)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.15),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1E3A5F),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.manage_accounts_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asignar Roles a Estudiantes',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                SizedBox(height: 3),
                Text(
                  'El rol Asistente QR permite generar QR de asistencia',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
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

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, usuario o código...',
          hintStyle:
              const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          prefixIcon:
              const Icon(Icons.search_rounded, color: Color(0xFF1E3A5F)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilter('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCountRow() {
    final asistentes =
        _students.where((s) => s['rol'] == rolAsistente).length;
    return Row(
      children: [
        Flexible(
          child: Text(
            '${_filteredStudents.length} estudiante(s)',
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (asistentes > 0) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F7F7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF0D7377)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_scanner,
                      size: 13, color: Color(0xFF0D7377)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '$asistentes Asistente(s) QR',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0D7377),
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final String currentRole = student['rol'] ?? rolEstudiante;
    final roleInfo = _rolesInfo[currentRole] ?? _rolesInfo[rolEstudiante]!;
    final isAsistente = currentRole == rolAsistente;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isAsistente
            ? Border.all(color: const Color(0xFF0D7377), width: 1.5)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: roleInfo['bgColor'] as Color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    roleInfo['icon'] as IconData,
                    color: roleInfo['color'] as Color,
                    size: 22,
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
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${student['username'] ?? '—'}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: roleInfo['bgColor'] as Color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(roleInfo['icon'] as IconData,
                            size: 12,
                            color: roleInfo['color'] as Color),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            roleInfo['label'] as String,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: roleInfo['color'] as Color),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            Row(
              children: [
                const Text(
                  'Cambiar a:',
                  style:
                      TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: _rolesInfo.entries.map((entry) {
                      final rKey = entry.key;
                      final rInfo = entry.value;
                      final isActive = currentRole == rKey;
                      return Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 3),
                          child: Semantics(
                            label:
                                'Asignar rol ${rInfo['label']} a ${student['name'] ?? 'estudiante'}',
                            button: true,
                            child: GestureDetector(
                              onTap: (isActive || _isSaving)
                                  ? null
                                  : () => _changeRole(student, rKey),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                constraints:
                                    const BoxConstraints(minHeight: 44),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? rInfo['color'] as Color
                                      : rInfo['bgColor'] as Color,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isActive
                                        ? rInfo['color'] as Color
                                        : (rInfo['color'] as Color)
                                            .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      rInfo['icon'] as IconData,
                                      size: 13,
                                      color: isActive
                                          ? Colors.white
                                          : rInfo['color'] as Color,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        rInfo['label'] as String,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isActive
                                              ? Colors.white
                                              : rInfo['color'] as Color,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 12)
                ],
              ),
              child: const Icon(Icons.person_search_rounded,
                  size: 48, color: Color(0xFF1E3A5F)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No se encontraron estudiantes',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A5F)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Intenta con otro término de búsqueda',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
