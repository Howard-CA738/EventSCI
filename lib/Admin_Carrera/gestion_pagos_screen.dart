import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';

class GestionPagosScreen extends StatefulWidget {
  const GestionPagosScreen({super.key});

  @override
  State<GestionPagosScreen> createState() => _GestionPagosScreenState();
}

class _GestionPagosScreenState extends State<GestionPagosScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'Todos'; // 'Todos', 'Si', 'Pendiente'

  String? _carreraPath; // "filial_carrera"
  String? _carreraNombre;
  String? _filialNombre;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  final TextEditingController _searchCtrl = TextEditingController();

  // Estadísticas
  int get _totalCount => _students.length;
  int get _pagadoCount =>
      _students.where((s) => (s['pago'] ?? '').toString().toLowerCase() == 'si').length;
  int get _pendienteCount =>
      _students.where((s) => (s['pago'] ?? '').toString().toLowerCase() != 'si').length;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _loadData();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Cargar datos del admin y sus estudiantes ──────────────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData == null) return;

      final filial  = adminData['filialNombre'] ?? '';
      final carrera = adminData['carrera']      ?? '';
      final docKey  = '${filial}_$carrera';

      _carreraPath  = docKey;
      _carreraNombre = carrera;
      _filialNombre  = filial;

      final snap = await _firestore
          .collection('users')
          .doc(docKey)
          .collection('students')
          .orderBy('name')
          .get();

      _students = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();

      _applyFilters();
      _animCtrl.forward();
    } catch (e) {
      debugPrint('Error cargando estudiantes: $e');
    }
    setState(() => _isLoading = false);
  }

  // ── Filtrar lista ─────────────────────────────────────────────────────────
  void _applyFilters() {
    List<Map<String, dynamic>> result = List.from(_students);

    // Filtro estado de pago
    if (_filterStatus == 'Si') {
      result = result
          .where((s) =>
              (s['pago'] ?? '').toString().toLowerCase() == 'si')
          .toList();
    } else if (_filterStatus == 'Pendiente') {
      result = result
          .where((s) =>
              (s['pago'] ?? '').toString().toLowerCase() != 'si')
          .toList();
    }

    // Filtro búsqueda
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final dni  = (s['dni']  ?? '').toString().toLowerCase();
        final cod  = (s['codigoUniversitario'] ?? '').toString().toLowerCase();
        return name.contains(q) || dni.contains(q) || cod.contains(q);
      }).toList();
    }

    setState(() => _filteredStudents = result);
  }

  // ── Cambiar estado de pago ────────────────────────────────────────────────
  Future<void> _togglePago(Map<String, dynamic> student) async {
    final currentPago = (student['pago'] ?? '').toString().toLowerCase();
    final isPagado    = currentPago == 'si';
    final newPago     = isPagado ? 'Pendiente' : 'Si';

    // Confirmación
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildConfirmDialog(
        student: student,
        newStatus: newPago,
        isPagado: isPagado,
      ),
    );
    if (confirm != true) return;

    try {
      await _firestore
          .collection('users')
          .doc(_carreraPath)
          .collection('students')
          .doc(student['id'])
          .update({
        'pago': newPago,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Actualizar local
      final idx = _students.indexWhere((s) => s['id'] == student['id']);
      if (idx != -1) {
        setState(() {
          _students[idx]['pago'] = newPago;
          _applyFilters();
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isPagado ? Icons.lock_outline : Icons.lock_open_outlined,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isPagado
                        ? '${student['name']} marcado como Pendiente'
                        : '${student['name']} marcado como Pagado ✓',
                  ),
                ),
              ],
            ),
            backgroundColor:
                isPagado ? const Color(0xFFE53E3E) : const Color(0xFF38A169),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error actualizando pago: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Cambiar estado masivo ─────────────────────────────────────────────────
  Future<void> _toggleAll(bool markAsPagado) async {
    final targetStudents = markAsPagado
        ? _students.where((s) =>
            (s['pago'] ?? '').toString().toLowerCase() != 'si')
        : _students.where((s) =>
            (s['pago'] ?? '').toString().toLowerCase() == 'si');

    final list = targetStudents.toList();
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(markAsPagado
              ? 'Todos los estudiantes ya están pagados'
              : 'No hay estudiantes pagados'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          markAsPagado
              ? 'Marcar todos como Pagado'
              : 'Marcar todos como Pendiente',
          style: const TextStyle(
              color: Color(0xFF1E3A5F), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Se actualizarán ${list.length} estudiantes. ¿Continuar?',
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final newPago = markAsPagado ? 'Si' : 'Pendiente';
      // Lotes de 500
      const batchSize = 450;
      for (int i = 0; i < list.length; i += batchSize) {
        final batch = _firestore.batch();
        final end   = (i + batchSize < list.length) ? i + batchSize : list.length;
        for (int j = i; j < end; j++) {
          final ref = _firestore
              .collection('users')
              .doc(_carreraPath)
              .collection('students')
              .doc(list[j]['id']);
          batch.update(ref, {'pago': newPago, 'updatedAt': FieldValue.serverTimestamp()});
        }
        await batch.commit();
      }

      for (var s in list) {
        final idx = _students.indexWhere((x) => x['id'] == s['id']);
        if (idx != -1) _students[idx]['pago'] = newPago;
      }
      _applyFilters();
    } catch (e) {
      debugPrint('Error en actualización masiva: $e');
    }
    setState(() => _isLoading = false);
  }

  // ── Widget de diálogo de confirmación ─────────────────────────────────────
  Widget _buildConfirmDialog({
    required Map<String, dynamic> student,
    required String newStatus,
    required bool isPagado,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPagado
                  ? Colors.red.shade50
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPagado ? Icons.lock_outline : Icons.lock_open_outlined,
              color: isPagado ? Colors.red.shade600 : Colors.green.shade600,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isPagado ? 'Revocar Acceso' : 'Habilitar Acceso',
              style: const TextStyle(
                  color: Color(0xFF1E3A5F), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF1E3A5F),
                  radius: 20,
                  child: Icon(Icons.person, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'] ?? 'Estudiante',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F)),
                      ),
                      Text(
                        'DNI: ${student['dni'] ?? '-'}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF475569), height: 1.5),
              children: [
                const TextSpan(text: 'El estado de pago cambiará a '),
                TextSpan(
                  text: '"$newStatus"',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isPagado
                        ? Colors.red.shade600
                        : Colors.green.shade600,
                  ),
                ),
                TextSpan(
                  text: isPagado
                      ? '. El estudiante no podrá ingresar a su panel.'
                      : '. El estudiante podrá ingresar normalmente.',
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar',
              style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isPagado ? Colors.red.shade600 : Colors.green.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(isPagado ? 'Revocar' : 'Habilitar'),
        ),
      ],
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.payments_outlined,
                            color: Color(0xFF1E3A5F), size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gestión de Pagos',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            Text(
                              'Control de acceso por pago',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Stats ──────────────────────────────────────────────
                  if (!_isLoading) ...[
                    Row(
                      children: [
                        _buildStatChip(
                          icon: Icons.people_outline,
                          label: 'Total',
                          value: '$_totalCount',
                          color: Colors.white,
                          bg: Colors.white.withOpacity(0.15),
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          icon: Icons.check_circle_outline,
                          label: 'Pagados',
                          value: '$_pagadoCount',
                          color: const Color(0xFF68D391),
                          bg: const Color(0xFF68D391).withOpacity(0.15),
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          icon: Icons.pending_outlined,
                          label: 'Pendientes',
                          value: '$_pendienteCount',
                          color: const Color(0xFFFBD38D),
                          bg: const Color(0xFFFBD38D).withOpacity(0.15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────
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
                          // ── Barra de búsqueda y filtros ──────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                            child: Column(
                              children: [
                                // Búsqueda
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller: _searchCtrl,
                                    onChanged: (v) {
                                      _searchQuery = v;
                                      _applyFilters();
                                    },
                                    decoration: InputDecoration(
                                      hintText:
                                          'Buscar por nombre, DNI o código...',
                                      hintStyle: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 14),
                                      prefixIcon: const Icon(Icons.search,
                                          color: Color(0xFF1E3A5F)),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear,
                                                  color: Colors.grey),
                                              onPressed: () {
                                                _searchCtrl.clear();
                                                _searchQuery = '';
                                                _applyFilters();
                                              },
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 14),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Filtros de estado
                                Row(
                                  children: [
                                    _buildFilterChip('Todos', Icons.list),
                                    const SizedBox(width: 8),
                                    _buildFilterChip(
                                        'Si', Icons.check_circle_outline),
                                    const SizedBox(width: 8),
                                    _buildFilterChip(
                                        'Pendiente', Icons.pending_outlined),
                                    const Spacer(),
                                    // Menú acciones masivas
                                    PopupMenuButton<String>(
                                      icon: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E3A5F),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.more_vert,
                                            color: Colors.white, size: 20),
                                      ),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                      onSelected: (val) {
                                        if (val == 'all_paid') {
                                          _toggleAll(true);
                                        } else if (val == 'all_pending') {
                                          _toggleAll(false);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'all_paid',
                                          child: Row(
                                            children: [
                                              Icon(Icons.check_circle,
                                                  color: Color(0xFF38A169),
                                                  size: 20),
                                              SizedBox(width: 10),
                                              Text('Marcar todos Pagados'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'all_pending',
                                          child: Row(
                                            children: [
                                              Icon(Icons.pending,
                                                  color: Color(0xFFD97706),
                                                  size: 20),
                                              SizedBox(width: 10),
                                              Text(
                                                  'Marcar todos Pendientes'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Carrera info
                          if (_carreraNombre != null)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF1E3A5F).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.school,
                                        size: 16, color: Color(0xFF1E3A5F)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '$_filialNombre • $_carreraNombre',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF1E3A5F),
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Text(
                                      '${_filteredStudents.length} estudiantes',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),

                          // ── Lista de estudiantes ─────────────────────────
                          Expanded(
                            child: _filteredStudents.isEmpty
                                ? _buildEmptyState()
                                : FadeTransition(
                                    opacity: _fadeAnim,
                                    child: ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 4, 16, 20),
                                      itemCount: _filteredStudents.length,
                                      itemBuilder: (ctx, i) =>
                                          _buildStudentCard(
                                              _filteredStudents[i]),
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

  // ── Tarjeta de estudiante ─────────────────────────────────────────────────
  Widget _buildStudentCard(Map<String, dynamic> student) {
    final pago      = (student['pago'] ?? '').toString().toLowerCase();
    final isPagado  = pago == 'si';
    final name      = student['name']     ?? 'Sin nombre';
    final dni       = student['dni']      ?? '-';
    final codigo    = student['codigoUniversitario'] ?? '-';
    final ciclo     = student['ciclo']    ?? '';
    final grupo     = student['grupo']    ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPagado
              ? const Color(0xFF68D391).withOpacity(0.4)
              : const Color(0xFFFBD38D).withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Avatar con inicial
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isPagado
                    ? const Color(0xFF38A169).withOpacity(0.12)
                    : const Color(0xFFD97706).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isPagado
                        ? const Color(0xFF38A169)
                        : const Color(0xFFD97706),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1E3A5F),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    children: [
                      _buildMiniChip('DNI: $dni', const Color(0xFF64748B)),
                      if (codigo != '-')
                        _buildMiniChip(codigo, const Color(0xFF64748B)),
                      if (ciclo.isNotEmpty)
                        _buildMiniChip('C$ciclo', const Color(0xFF1E3A5F)),
                      if (grupo.isNotEmpty)
                        _buildMiniChip('G:$grupo', const Color(0xFF1E3A5F)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Estado + botón toggle
            Column(
              children: [
                // Badge de estado
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPagado
                        ? const Color(0xFF38A169).withOpacity(0.12)
                        : const Color(0xFFD97706).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPagado
                          ? const Color(0xFF38A169).withOpacity(0.4)
                          : const Color(0xFFD97706).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPagado
                            ? Icons.check_circle
                            : Icons.pending_rounded,
                        size: 12,
                        color: isPagado
                            ? const Color(0xFF38A169)
                            : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPagado ? 'Si' : 'Pendiente',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPagado
                              ? const Color(0xFF38A169)
                              : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Botón de cambio
                GestureDetector(
                  onTap: () => _togglePago(student),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPagado
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPagado
                            ? Colors.red.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPagado ? Icons.lock_outline : Icons.lock_open,
                          size: 14,
                          color: isPagado
                              ? Colors.red.shade600
                              : Colors.green.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPagado ? 'Bloquear' : 'Desbloquear',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isPagado
                                ? Colors.red.shade600
                                : Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────
  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bg,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                Text(
                  label,
                  style: TextStyle(
                      color: color.withOpacity(0.8), fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = _filterStatus == label;
    Color chipColor;
    if (label == 'Si') {
      chipColor = const Color(0xFF38A169);
    } else if (label == 'Pendiente') {
      chipColor = const Color(0xFFD97706);
    } else {
      chipColor = const Color(0xFF1E3A5F);
    }

    return GestureDetector(
      onTap: () {
        setState(() => _filterStatus = label);
        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : Colors.grey.shade300,
            width: isSelected ? 0 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: chipColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 14, color: isSelected ? Colors.white : chipColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : chipColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No se encontraron resultados'
                : 'No hay estudiantes en esta carrera',
            style: const TextStyle(
                color: Color(0xFF64748B), fontSize: 16),
          ),
          if (_filterStatus != 'Todos') ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() => _filterStatus = 'Todos');
                _applyFilters();
              },
              child: const Text('Ver todos'),
            ),
          ],
        ],
      ),
    );
  }
}