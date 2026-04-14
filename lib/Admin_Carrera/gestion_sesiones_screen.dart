import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';

class GestionSesionesScreen extends StatefulWidget {
  const GestionSesionesScreen({super.key});

  @override
  State<GestionSesionesScreen> createState() => _GestionSesionesScreenState();
}

class _GestionSesionesScreenState extends State<GestionSesionesScreen>
    with SingleTickerProviderStateMixin {
  String _carreraPath = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _estudiantes = [];
  List<Map<String, dynamic>> _filtrados = [];
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animController;

  // Filtro activo: 'todos', 'sin_sesion', 'bloqueado'
  String _filtroEstado = 'todos';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData == null) return;

      final filial = adminData['filial'] ?? '';
      final carrera = adminData['carrera'] ?? '';
      _carreraPath = '${filial}_$carrera';

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_carreraPath)
          .collection('students')
          .orderBy('nombre')
          .get();

      final lista = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'docId': doc.id,
          'nombre': data['nombre'] ?? data['name'] ?? data['usuario'] ?? 'Sin nombre',
          'usuario': data['usuario'] ?? data['username'] ?? '',
          'sessionActive': data['sessionActive'] ?? false,
          'sessionToken': data['sessionToken'] ?? '',
          'lastLogin': data['lastLogin'],
          'primeraVez': data['primeraVez'] ?? true,
        };
      }).toList();

      setState(() {
        _estudiantes = lista;
        _aplicarFiltro();
      });
      _animController.forward();
    } catch (e) {
      debugPrint('Error cargando sesiones: $e');
    }
    setState(() => _isLoading = false);
  }

  // ✅ CORREGIDO: lógica limpia sin casos duplicados
  void _aplicarFiltro() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtrados = _estudiantes.where((e) {
        final matchSearch =
            e['nombre'].toString().toLowerCase().contains(query) ||
            e['usuario'].toString().toLowerCase().contains(query);

        bool matchEstado = true;
        if (_filtroEstado == 'bloqueado') {
          matchEstado = e['sessionActive'] == true; // sessionActive:true → bloqueado
        } else if (_filtroEstado == 'sin_sesion') {
          matchEstado = e['sessionActive'] != true; // libre o reseteado
        }
        // 'todos' → matchEstado queda true

        return matchSearch && matchEstado;
      }).toList();
    });
  }

  /// Resetea la sesión del estudiante → puede volver a ingresar UNA VEZ más
  Future<void> _resetearSesion(Map<String, dynamic> estudiante) async {
    final confirm = await _showConfirmDialog(
      titulo: '¿Dar nueva oportunidad?',
      mensaje:
          'Se reseteará la sesión de ${estudiante['nombre']}.\n\nPodrá ingresar UNA VEZ más y recibirá nuevamente la advertencia de no cerrar sesión.',
      botonConfirmar: 'Sí, resetear',
      colorBoton: const Color(0xFF0EA5E9),
      icono: Icons.refresh_rounded,
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_carreraPath)
          .collection('students')
          .doc(estudiante['docId'])
          .update({
        'sessionActive': false,
        'sessionToken': null,
        'primeraVez': true,
        'lastLogin': null,
        'sessionResetAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSnack(
            '✅ Sesión reseteada. ${estudiante['nombre']} puede ingresar de nuevo.',
            Colors.green);
        await _loadData();
      }
    } catch (e) {
      _showSnack('Error al resetear: $e', Colors.red);
    }
  }

  /// Bloquea manualmente al estudiante
  Future<void> _bloquearSesion(Map<String, dynamic> estudiante) async {
    final confirm = await _showConfirmDialog(
      titulo: '¿Bloquear acceso?',
      mensaje:
          'Se bloqueará el acceso de ${estudiante['nombre']}.\n\nNo podrá iniciar sesión hasta que lo resetees manualmente.',
      botonConfirmar: 'Sí, bloquear',
      colorBoton: Colors.red,
      icono: Icons.block_rounded,
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_carreraPath)
          .collection('students')
          .doc(estudiante['docId'])
          .update({
        'sessionActive': true,
        'primeraVez': false,
        'sessionToken': 'BLOQUEADO_POR_ADMIN',
      });

      if (mounted) {
        _showSnack(
            '🔒 ${estudiante['nombre']} ha sido bloqueado.', Colors.orange);
        await _loadData();
      }
    } catch (e) {
      _showSnack('Error al bloquear: $e', Colors.red);
    }
  }

  Future<bool?> _showConfirmDialog({
    required String titulo,
    required String mensaje,
    required String botonConfirmar,
    required Color colorBoton,
    required IconData icono,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorBoton.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: colorBoton, size: 32),
              ),
              const SizedBox(height: 16),
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F))),
              const SizedBox(height: 12),
              Text(mensaje,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF64748B), height: 1.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancelar',
                          style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorBoton,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(botonConfirmar,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ✅ CORREGIDO: lógica de estado clara y sin contradicciones
  _EstadoSesion _getEstado(Map<String, dynamic> e) {
    final active = e['sessionActive'] == true;
    final primeraVez = e['primeraVez'] != false; // true o null = nunca ingresó

    if (active) return _EstadoSesion.bloqueado;               // sessionActive:true → bloqueado
    if (!active && primeraVez) return _EstadoSesion.sinSesion; // nunca entró o reseteado listo
    return _EstadoSesion.reseteado;                            // reseteado, esperando ingreso
  }

  @override
  Widget build(BuildContext context) {
    // Contadores para el resumen
    final totalSinSesion = _estudiantes
        .where((e) => _getEstado(e) == _EstadoSesion.sinSesion)
        .length;
    final totalBloqueados = _estudiantes
        .where((e) => _getEstado(e) == _EstadoSesion.bloqueado)
        .length;
    final totalReseteados = _estudiantes
        .where((e) => _getEstado(e) == _EstadoSesion.reseteado)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Control de Sesiones',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E3A5F)))
          : Column(
              children: [
                // ── Header ──────────────────────────────────────────────
                Container(
                  color: const Color(0xFF1E3A5F),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    children: [
                      // Buscador
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => _aplicarFiltro(),
                          decoration: InputDecoration(
                            hintText: 'Buscar estudiante...',
                            hintStyle: TextStyle(
                                color: Colors.grey[400], fontSize: 14),
                            prefixIcon: const Icon(Icons.search,
                                color: Color(0xFF1E3A5F)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Resumen de estadísticas
                      Row(
                        children: [
                          _buildStatChip('${_estudiantes.length}', 'Total',
                              Colors.white70),
                          const SizedBox(width: 8),
                          _buildStatChip('$totalSinSesion', 'Sin sesión',
                              Colors.green.shade300),
                          const SizedBox(width: 8),
                          _buildStatChip('$totalBloqueados', 'Bloqueados',
                              Colors.red.shade300),
                          const SizedBox(width: 8),
                          _buildStatChip('$totalReseteados', 'Reseteados',
                              Colors.blue.shade300),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Filtros rápidos
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('todos', 'Todos'),
                            const SizedBox(width: 8),
                            _buildFilterChip('sin_sesion', 'Sin sesión'),
                            const SizedBox(width: 8),
                            _buildFilterChip('bloqueado', 'Bloqueados'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Lista ────────────────────────────────────────────────
                Expanded(
                  child: _filtrados.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: _filtrados.length,
                          itemBuilder: (ctx, i) {
                            final e = _filtrados[i];
                            return _buildEstudianteCard(e, i);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatChip(String count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(count,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            Text(label,
                style:
                    const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _filtroEstado == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filtroEstado = value);
        _aplicarFiltro();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? Colors.white
                  : Colors.white.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1E3A5F) : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEstudianteCard(Map<String, dynamic> e, int index) {
    final estado = _getEstado(e);
    final lastLogin = e['lastLogin'] as Timestamp?;

    Color estadoColor;
    String estadoLabel;
    IconData estadoIcon;

    switch (estado) {
      case _EstadoSesion.sinSesion:
        estadoColor = Colors.green;
        estadoLabel = 'Sin sesión';
        estadoIcon = Icons.person_add_outlined;
        break;
      case _EstadoSesion.bloqueado:
        estadoColor = Colors.red;
        estadoLabel = 'Bloqueado';
        estadoIcon = Icons.lock_rounded;
        break;
      case _EstadoSesion.reseteado:
        estadoColor = Colors.blue;
        estadoLabel = 'Reseteado';
        estadoIcon = Icons.refresh_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: estadoColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: estadoColor.withOpacity(0.4), width: 1.5),
              ),
              child: Icon(Icons.person, color: estadoColor, size: 24),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e['nombre'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1E3A5F),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    e['usuario'],
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  if (lastLogin != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Último ingreso: ${_formatDate(lastLogin.toDate())}',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ],
              ),
            ),

            // Badge + botones
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: estadoColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(estadoIcon, size: 12, color: estadoColor),
                      const SizedBox(width: 4),
                      Text(estadoLabel,
                          style: TextStyle(
                              fontSize: 11,
                              color: estadoColor,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Botones de acción
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Resetear siempre disponible
                    _buildActionBtn(
                      icon: Icons.refresh_rounded,
                      color: const Color(0xFF0EA5E9),
                      tooltip: 'Dar nueva oportunidad',
                      onTap: () => _resetearSesion(e),
                    ),
                    // Bloquear solo si NO está ya bloqueado
                    if (estado != _EstadoSesion.bloqueado) ...[
                      const SizedBox(width: 6),
                      _buildActionBtn(
                        icon: Icons.block_rounded,
                        color: Colors.red,
                        tooltip: 'Bloquear acceso',
                        onTap: () => _bloquearSesion(e),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.manage_accounts_outlined,
              size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('No hay estudiantes',
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('Ajusta los filtros o la búsqueda',
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

enum _EstadoSesion { sinSesion, bloqueado, reseteado }