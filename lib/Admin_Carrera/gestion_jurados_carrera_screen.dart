import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';

/// Gestión de Jurados para Admin de Carrera.
/// Carga filial/facultad/carrera automáticamente desde la sesión.
/// Permite ver, crear y editar jurados de su carrera.
class GestionJuradosCarreraScreen extends StatefulWidget {
  const GestionJuradosCarreraScreen({super.key});

  @override
  State<GestionJuradosCarreraScreen> createState() =>
      _GestionJuradosCarreraScreenState();
}

class _GestionJuradosCarreraScreenState
    extends State<GestionJuradosCarreraScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Datos de sesión ───────────────────────────────────────────────────────
  String? _filialId;
  String? _filialNombre;
  String? _facultad;
  String? _carreraId;
  String? _carreraNombre;

  List<Map<String, dynamic>> _jurados = [];
  bool _isLoadingSession = true;
  bool _isLoadingJurados = false;

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    setState(() => _isLoadingSession = true);
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData != null) {
        _filialId = adminData['filial'];
        _filialNombre = adminData['filialNombre'];
        _facultad = adminData['facultad'];
        _carreraId = adminData['carreraId'] ?? adminData['carrera'];
        _carreraNombre = adminData['carrera'];
      }
    } catch (e) {
      debugPrint('Error cargando sesión: $e');
    } finally {
      setState(() => _isLoadingSession = false);
    }
    await _cargarJurados();
  }

  Future<void> _cargarJurados() async {
    if (_filialId == null || _facultad == null || _carreraNombre == null) return;
    setState(() => _isLoadingJurados = true);
    try {
      final snap = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'jurado')
          .where('filial', isEqualTo: _filialId)
          .where('facultad', isEqualTo: _facultad)
          .where('carrera', isEqualTo: _carreraNombre)
          .get();

      final list = snap.docs.map((doc) {
        final d = doc.data();
        List<String> categorias = [];
        if (d['categorias'] != null) {
          categorias = List<String>.from(d['categorias']);
        } else if (d['categoria'] != null) {
          categorias = [d['categoria']];
        }
        return {
          'id': doc.id,
          'nombre': d['name'] ?? '',
          'usuario': d['usuario'] ?? '',
          'password': d['password'] ?? '',
          'categorias': categorias,
        };
      }).toList();

      if (mounted) setState(() => _jurados = list);
    } catch (e) {
      debugPrint('Error cargando jurados: $e');
      _showSnackBar('Error al cargar jurados', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingJurados = false);
    }
  }

  // ── Cargar categorías disponibles desde eventos de la carrera ─────────────
  Future<List<String>> _cargarCategorias() async {
    if (_filialId == null || _facultad == null || _carreraNombre == null) {
      return [];
    }
    try {
      final eventsSnap = await _firestore
          .collection('events')
          .where('filialId', isEqualTo: _filialId)
          .where('facultad', isEqualTo: _facultad)
          .where('carreraNombre', isEqualTo: _carreraNombre)
          .get();

      final Set<String> cats = {};
      for (final eventDoc in eventsSnap.docs) {
        final proySnap = await _firestore
            .collection('events')
            .doc(eventDoc.id)
            .collection('proyectos')
            .get();
        for (final p in proySnap.docs) {
          final clasificacion = p.data()['Clasificación'] as String?;
          if (clasificacion != null && clasificacion.isNotEmpty) {
            cats.add(clasificacion);
          }
        }
      }
      return cats.toList()..sort();
    } catch (e) {
      debugPrint('Error cargando categorías: $e');
      return [];
    }
  }

  // ── Crear jurado ──────────────────────────────────────────────────────────
  Future<void> _crearJurado({
    required String nombre,
    required String usuario,
    required String password,
    required List<String> categorias,
  }) async {
    // Verificar usuario duplicado
    final existing = await _firestore
        .collection('users')
        .where('usuario', isEqualTo: usuario.trim())
        .get();
    if (existing.docs.isNotEmpty) {
      _showSnackBar('El usuario "$usuario" ya está registrado', isError: true);
      return;
    }

    await _firestore.collection('users').add({
      'name': nombre.trim(),
      'usuario': usuario.trim(),
      'password': password,
      'filial': _filialId,
      'facultad': _facultad,
      'carrera': _carreraNombre,
      'categorias': categorias,
      'userType': 'jurado',
      'createdAt': FieldValue.serverTimestamp(),
    });

    _showSnackBar('Jurado creado exitosamente');
    await _cargarJurados();
  }

  // ── Actualizar jurado ─────────────────────────────────────────────────────
  Future<void> _actualizarJurado({
    required String id,
    required String nombre,
    required String usuario,
    required String password,
    required List<String> categorias,
  }) async {
    await _firestore.collection('users').doc(id).update({
      'name': nombre.trim(),
      'usuario': usuario.trim(),
      'password': password,
      'categorias': categorias,
    });
    _showSnackBar('Jurado actualizado exitosamente');
    await _cargarJurados();
  }

  // ── Eliminar jurado ───────────────────────────────────────────────────────
  Future<void> _eliminarJurado(String id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_rounded, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Confirmar eliminación',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text(
          '¿Eliminar al jurado "$nombre"?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
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

    if (confirmar == true) {
      await _firestore.collection('users').doc(id).delete();
      _showSnackBar('Jurado eliminado');
      await _cargarJurados();
    }
  }

  // ── Mostrar diálogo de crear/editar ───────────────────────────────────────
  void _mostrarDialogoJurado({Map<String, dynamic>? jurado}) async {
    final isEditing = jurado != null;
    final categorias = await _cargarCategorias();

    if (!mounted) return;

    final nombreCtrl = TextEditingController(text: jurado?['nombre'] ?? '');
    final usuarioCtrl = TextEditingController(text: jurado?['usuario'] ?? '');
    final passwordCtrl = TextEditingController(text: jurado?['password'] ?? '');
    List<String> categoriasSeleccionadas =
        List<String>.from(jurado?['categorias'] ?? []);
    bool obscurePass = true;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Título ──────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEditing ? Icons.edit : Icons.person_add,
                        color: const Color(0xFF1E3A5F),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEditing ? 'Editar Jurado' : 'Nuevo Jurado',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Ubicación (solo lectura) ─────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF1E3A5F).withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          color: Color(0xFF1E3A5F), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$_carreraNombre\n$_facultad • $_filialNombre',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1E3A5F),
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Campos ──────────────────────────────────────────────
                _buildDialogTextField(
                  controller: nombreCtrl,
                  label: 'Nombre completo',
                  icon: Icons.person,
                ),
                const SizedBox(height: 14),
                _buildDialogTextField(
                  controller: usuarioCtrl,
                  label: 'Usuario',
                  icon: Icons.account_circle,
                  enabled: !isEditing,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon:
                        const Icon(Icons.lock, color: Color(0xFF1E3A5F)),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscurePass
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey),
                      onPressed: () =>
                          setDialogState(() => obscurePass = !obscurePass),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 18),

                // ── Categorías ──────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF8FAFC),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.category,
                                color: Color(0xFF1E3A5F), size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('Categorías',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E3A5F))),
                            ),
                            if (categoriasSeleccionadas.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E3A5F),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${categoriasSeleccionadas.length}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      if (categorias.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No hay categorías disponibles en los eventos de esta carrera.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: categorias.length,
                            itemBuilder: (_, i) {
                              final cat = categorias[i];
                              final sel =
                                  categoriasSeleccionadas.contains(cat);
                              return CheckboxListTile(
                                dense: true,
                                title: Text(cat,
                                    style: const TextStyle(fontSize: 13)),
                                value: sel,
                                activeColor: const Color(0xFF1E3A5F),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (v) => setDialogState(() {
                                  if (v == true) {
                                    categoriasSeleccionadas.add(cat);
                                  } else {
                                    categoriasSeleccionadas.remove(cat);
                                  }
                                }),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                // Chips de categorías seleccionadas
                if (categoriasSeleccionadas.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: categoriasSeleccionadas
                        .map((cat) => Chip(
                              label: Text(cat,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white)),
                              backgroundColor: const Color(0xFF1E3A5F),
                              deleteIcon: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                              onDeleted: () => setDialogState(
                                  () => categoriasSeleccionadas.remove(cat)),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 24),

                // ── Botones ─────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: const Text('Cancelar',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                final nombre = nombreCtrl.text.trim();
                                final usuario = usuarioCtrl.text.trim();
                                final password = passwordCtrl.text;

                                if (nombre.isEmpty ||
                                    usuario.isEmpty ||
                                    password.isEmpty) {
                                  _showSnackBar(
                                      'Completa todos los campos',
                                      isWarning: true);
                                  return;
                                }
                                if (categoriasSeleccionadas.isEmpty) {
                                  _showSnackBar(
                                      'Selecciona al menos una categoría',
                                      isWarning: true);
                                  return;
                                }

                                setDialogState(() => isLoading = true);
                                try {
                                  if (isEditing) {
                                    await _actualizarJurado(
                                      id: jurado!['id'],
                                      nombre: nombre,
                                      usuario: usuario,
                                      password: password,
                                      categorias: categoriasSeleccionadas,
                                    );
                                  } else {
                                    await _crearJurado(
                                      nombre: nombre,
                                      usuario: usuario,
                                      password: password,
                                      categorias: categoriasSeleccionadas,
                                    );
                                  }
                                  if (mounted) Navigator.pop(ctx);
                                } catch (e) {
                                  _showSnackBar('Error: $e', isError: true);
                                } finally {
                                  setDialogState(() => isLoading = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(
                                isEditing ? 'Guardar' : 'Crear Jurado',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String msg,
      {bool isError = false, bool isWarning = false}) {
    final color = isError
        ? const Color(0xFFE53935)
        : isWarning
            ? Colors.orange
            : const Color(0xFF43A047);
    final icon = isError
        ? Icons.error_outline
        : isWarning
            ? Icons.warning_amber
            : Icons.check_circle_outline;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF2),
      appBar: AppBar(
        title: const Text('Gestión de Jurados',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarJurados,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: _isLoadingSession
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _mostrarDialogoJurado(),
              backgroundColor: const Color(0xFF1E3A5F),
              icon: const Icon(Icons.person_add),
              label: const Text('Nuevo Jurado'),
            ),
      body: _isLoadingSession
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E3A5F)))
          : Column(
              children: [
                // ── Tarjeta de contexto ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _buildContextCard(),
                ),
                const SizedBox(height: 12),

                // ── Lista de jurados ─────────────────────────────────
                Expanded(
                  child: _isLoadingJurados
                      ? const Center(child: CircularProgressIndicator())
                      : _jurados.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 4, 20, 80),
                              itemCount: _jurados.length,
                              itemBuilder: (_, i) =>
                                  _buildJuradoCard(_jurados[i]),
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildContextCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.school, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_carreraNombre ?? '—',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 3),
                Text(_facultad ?? '—',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on,
                      color: Colors.white54, size: 12),
                  const SizedBox(width: 4),
                  Text(_filialNombre ?? '—',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
                ]),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30),
            ),
            child: Text(
              '${_jurados.length} jurado(s)',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJuradoCard(Map<String, dynamic> jurado) {
    final categorias = jurado['categorias'] as List<String>;
    final nombre = jurado['nombre'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF1E3A5F),
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1E3A5F))),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.account_circle,
                        size: 13, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(jurado['usuario'] as String,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600])),
                  ]),
                  if (categorias.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: categorias
                          .map((cat) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E3A5F)
                                      .withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF1E3A5F)
                                          .withOpacity(0.2)),
                                ),
                                child: Text(
                                  cat,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF1E3A5F),
                                      fontWeight: FontWeight.w500),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Acciones
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: Color(0xFF1E3A5F), size: 22),
                  onPressed: () => _mostrarDialogoJurado(jurado: jurado),
                  tooltip: 'Editar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 22),
                  onPressed: () =>
                      _eliminarJurado(jurado['id'], nombre),
                  tooltip: 'Eliminar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
                color: Color(0xFFF0F4FF), shape: BoxShape.circle),
            child: const Icon(Icons.people_outline,
                size: 56, color: Color(0xFF1E3A5F)),
          ),
          const SizedBox(height: 20),
          const Text('No hay jurados',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F))),
          const SizedBox(height: 8),
          Text('Crea el primer jurado para esta carrera',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        filled: true,
        fillColor:
            enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF0F0F0),
      ),
    );
  }
}