import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import '/password_helper.dart';

class GestionJuradosCarreraScreen extends StatefulWidget {
  const GestionJuradosCarreraScreen({super.key});

  @override
  State<GestionJuradosCarreraScreen> createState() =>
      _GestionJuradosCarreraScreenState();
}

class _GestionJuradosCarreraScreenState
    extends State<GestionJuradosCarreraScreen>
    with SingleTickerProviderStateMixin {
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

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const _categoryColors = [
    Color(0xFF3B6FD4),
    Color(0xFF2E9E6E),
    Color(0xFFD4863B),
    Color(0xFF8B4DC7),
    Color(0xFFD4453B),
    Color(0xFF2B9EA8),
    Color(0xFF4B63D4),
    Color(0xFFD44B87),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadSessionData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    setState(() => _isLoadingSession = true);
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData != null) {
        _filialId = adminData['filial'];
        _filialNombre = adminData['filialNombre'];
        _facultad = adminData['facultad'];
        // FIX C2: _carreraId y _carreraNombre se asignan por separado
        // para evitar que _carreraId reciba el nombre de la carrera.
        _carreraId = adminData['carreraId']; // puede ser null
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
          // FIX M4 (seguridad): NO incluir el hash de contraseña en el estado de UI.
          // El campo 'password' no se necesita en el listado.
          'categorias': categorias,
          'eventoId': d['eventoId'] ?? '',
          'eventoNombre': d['eventoNombre'] ?? '',
        };
      }).toList();

      if (mounted) {
        setState(() => _jurados = list);
        // FIX m1: proteger el AnimationController contra dispose previo
        if (!_fadeController.isDismissed || _fadeController.isAnimating) {
          _fadeController.forward(from: 0);
        } else {
          _fadeController.forward(from: 0);
        }
      }
    } catch (e) {
      debugPrint('Error cargando jurados: $e');
      if (mounted) _showSnackBar('Error al cargar jurados', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingJurados = false);
    }
  }

  Future<List<String>> _cargarCategoriasPorEvento(String eventoId) async {
    try {
      final proySnap = await _firestore
          .collection('events')
          .doc(eventoId)
          .collection('proyectos')
          .get();
      final Set<String> cats = {};
      for (final p in proySnap.docs) {
        final clasificacion = p.data()['Clasificación'] as String?;
        if (clasificacion != null && clasificacion.isNotEmpty) {
          cats.add(clasificacion);
        }
      }
      return cats.toList()..sort();
    } catch (e) {
      debugPrint('Error cargando categorías: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _cargarEventos() async {
    if (_filialId == null || _facultad == null) return [];
    try {
      final snap = await _firestore
          .collection('events')
          .where('filialId', isEqualTo: _filialId)
          .where('facultad', isEqualTo: _facultad)
          .get();

      // FIX C2: lógica de filtro mejorada.
      // Si tenemos carreraId, lo usamos como criterio principal.
      // Si no, hacemos fallback al nombre de carrera.
      final docs = snap.docs.where((doc) {
        final data = doc.data();
        if (_carreraId != null && _carreraId!.isNotEmpty) {
          return data['carreraId'] == _carreraId;
        }
        // Fallback por nombre
        return data['carreraNombre'] == _carreraNombre ||
            data['carrera'] == _carreraNombre;
      }).toList();

      return docs
          .map((doc) => {
                'id': doc.id,
                'name': doc.data()['name'] ?? 'Sin nombre',
              })
          .toList();
    } catch (e) {
      debugPrint('Error cargando eventos: $e');
      return [];
    }
  }

  Future<void> _crearJurado({
    required String nombre,
    required String usuario,
    required String password,
    required List<String> categorias,
    required String eventoId,
    required String eventoNombre,
  }) async {
    // FIX m3: validar que el usuario no tenga espacios internos ni caracteres inválidos
    if (usuario.contains(' ')) {
      _showSnackBar('El usuario no puede contener espacios', isError: true);
      return;
    }
    final usuarioRegex = RegExp(r'^[a-zA-Z0-9._\-]+$');
    if (!usuarioRegex.hasMatch(usuario)) {
      _showSnackBar(
          'El usuario solo puede contener letras, números, puntos, guiones y guiones bajos',
          isError: true);
      return;
    }

    final existing = await _firestore
        .collection('users')
        .where('usuario', isEqualTo: usuario.trim())
        .get();
    if (existing.docs.isNotEmpty) {
      _showSnackBar('El usuario "$usuario" ya está registrado', isError: true);
      return;
    }
    final passwordHash = PasswordHelper.hashPassword(password);
    await _firestore.collection('users').add({
      'name': nombre.trim(),
      'usuario': usuario.trim(),
      'password': passwordHash,
      'filial': _filialId,
      'filialNombre': _filialNombre,
      'facultad': _facultad,
      'carrera': _carreraNombre,
      'carreraId': _carreraId,
      'categorias': categorias,
      'eventoId': eventoId,
      'eventoNombre': eventoNombre,
      'userType': 'jurado',
      'createdAt': FieldValue.serverTimestamp(),
    });
    _showSnackBar('Jurado creado exitosamente');
    await _cargarJurados();
  }

  Future<void> _actualizarJurado({
    required String id,
    required String nombre,
    required String usuario,
    required String password, // puede venir vacío
    required List<String> categorias,
    required String eventoId,
    required String eventoNombre,
  }) async {
    final Map<String, dynamic> updateData = {
      'name': nombre.trim(),
      'usuario': usuario.trim(),
      'categorias': categorias,
      'eventoId': eventoId,
      'eventoNombre': eventoNombre,
    };

    // Solo actualizar contraseña si el admin escribió una nueva
    if (password.isNotEmpty) {
      updateData['password'] = _isSha256(password)
          ? password
          : PasswordHelper.hashPassword(password);
    }

    await _firestore.collection('users').doc(id).update(updateData);
    _showSnackBar('Jurado actualizado exitosamente');
    await _cargarJurados();
  }

  // Helper para detectar si ya es hash SHA-256
  bool _isSha256(String value) {
    return value.length == 64 && RegExp(r'^[a-f0-9]+$').hasMatch(value);
  }

  Future<void> _eliminarJurado(String id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4453B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_rounded,
                        color: Color(0xFFD4453B), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Confirmar eliminación',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFEC5C5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_rounded,
                        color: Color(0xFFD4453B), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9B1C1C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Esta acción eliminará permanentemente al jurado y no se puede deshacer.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.delete_rounded, size: 17),
                      label: const Text('Eliminar',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4453B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmar == true) {
      await _firestore.collection('users').doc(id).delete();
      _showSnackBar('Jurado eliminado');
      await _cargarJurados();
    }
  }

  // ── Diálogo crear/editar ──────────────────────────────────────────────────
  void _mostrarDialogoJurado({Map<String, dynamic>? jurado}) async {
    final isEditing = jurado != null;
    final eventos = await _cargarEventos();
    if (!mounted) return;

    final nombreCtrl = TextEditingController(text: jurado?['nombre'] ?? '');
    final usuarioCtrl = TextEditingController(text: jurado?['usuario'] ?? '');
    // FIX M2: contraseña siempre vacía al abrir — se muestra hint explicativo
    final passwordCtrl = TextEditingController(text: '');
    List<String> categoriasSeleccionadas =
        List<String>.from(jurado?['categorias'] ?? []);

    String? eventoSeleccionado =
        isEditing && (jurado!['eventoId'] as String).isNotEmpty
            ? jurado['eventoId'] as String
            : null;
    List<String> categorias = [];
    bool obscurePass = true;
    bool isLoading = false;
    bool isLoadingCategorias = false;

    if (eventoSeleccionado != null) {
      categorias = await _cargarCategoriasPorEvento(eventoSeleccionado);
    }
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header del diálogo ──────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEditing
                              ? Icons.edit_rounded
                              : Icons.person_add_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Editar Jurado' : 'Nuevo Jurado',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                            const Text(
                              'Completa los datos del jurado',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFF94A3B8), size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Chip de ubicación ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F5FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD9F5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.school_rounded,
                            color: Color(0xFF3B6FD4), size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$_carreraNombre · $_facultad · $_filialNombre',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1E3A5F),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Sección: Datos personales ────────────────────────
                  _buildDialogSectionLabel('Datos personales',
                      Icons.person_rounded, const Color(0xFFD4863B)),
                  const SizedBox(height: 10),
                  _buildDialogTextField(
                    controller: nombreCtrl,
                    label: 'Nombre completo',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildDialogTextField(
                    controller: usuarioCtrl,
                    label: 'Usuario',
                    icon: Icons.account_circle_outlined,
                    enabled: !isEditing,
                  ),
                  const SizedBox(height: 12),

                  // FIX M2: campo contraseña con hint explicativo al editar
                  _buildPasswordField(
                    controller: passwordCtrl,
                    obscure: obscurePass,
                    isEditing: isEditing,
                    onToggle: () =>
                        setDialogState(() => obscurePass = !obscurePass),
                  ),
                  const SizedBox(height: 18),

                  // ── Sección: Evento ──────────────────────────────────
                  _buildDialogSectionLabel('Evento asignado',
                      Icons.event_rounded, const Color(0xFF3B6FD4)),
                  const SizedBox(height: 10),
                  _buildEventoDropdown(
                    eventos: eventos,
                    eventoSeleccionado: eventoSeleccionado,
                    isEditing: isEditing,
                    jurado: jurado,
                    onChanged: (value) async {
                      setDialogState(() {
                        eventoSeleccionado = value;
                        categorias = [];
                        if (!isEditing || value != jurado?['eventoId']) {
                          categoriasSeleccionadas = [];
                        }
                        isLoadingCategorias = true;
                      });
                      final cats =
                          await _cargarCategoriasPorEvento(value!);
                      setDialogState(() {
                        categorias = cats;
                        isLoadingCategorias = false;
                      });
                    },
                  ),
                  const SizedBox(height: 18),

                  // ── Sección: Categorías ──────────────────────────────
                  if (eventoSeleccionado != null) ...[
                    _buildDialogSectionLabel('Categorías',
                        Icons.category_rounded, const Color(0xFF8B4DC7)),
                    const SizedBox(height: 10),
                    _buildCategoriasPanel(
                      categorias: categorias,
                      seleccionadas: categoriasSeleccionadas,
                      isLoading: isLoadingCategorias,
                      onChanged: (cat, selected) => setDialogState(() {
                        if (selected) {
                          categoriasSeleccionadas.add(cat);
                        } else {
                          categoriasSeleccionadas.remove(cat);
                        }
                      }),
                    ),

                    // Chips de seleccionadas
                    if (categoriasSeleccionadas.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: categoriasSeleccionadas
                            .asMap()
                            .entries
                            .map((e) {
                          final color = _categoryColors[
                              e.key % _categoryColors.length];
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: Chip(
                              label: Text(
                                e.value,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: color,
                              deleteIcon: const Icon(Icons.close_rounded,
                                  size: 14, color: Colors.white),
                              onDeleted: () => setDialogState(() =>
                                  categoriasSeleccionadas.remove(e.value)),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide.none,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 18),
                  ],

                  // ── Botones ──────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                  color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  final nombre = nombreCtrl.text.trim();
                                  final usuario = usuarioCtrl.text.trim();
                                  final password = passwordCtrl.text;

                                  if (nombre.isEmpty || usuario.isEmpty) {
                                    _showSnackBar('Completa todos los campos',
                                        isWarning: true);
                                    return;
                                  }

                                  // Contraseña obligatoria solo al crear
                                  if (!isEditing && password.isEmpty) {
                                    _showSnackBar(
                                        'La contraseña es obligatoria',
                                        isWarning: true);
                                    return;
                                  }
                                  if (eventoSeleccionado == null) {
                                    _showSnackBar('Selecciona un evento',
                                        isWarning: true);
                                    return;
                                  }
                                  if (categoriasSeleccionadas.isEmpty) {
                                    _showSnackBar(
                                        'Selecciona al menos una categoría',
                                        isWarning: true);
                                    return;
                                  }
                                  final eventoNombre = eventos.firstWhere(
                                    (e) => e['id'] == eventoSeleccionado,
                                    orElse: () => {'name': ''},
                                  )['name'] as String;

                                  setDialogState(() => isLoading = true);
                                  try {
                                    if (isEditing) {
                                      await _actualizarJurado(
                                        id: jurado!['id'],
                                        nombre: nombre,
                                        usuario: usuario,
                                        password: password,
                                        categorias: categoriasSeleccionadas,
                                        eventoId: eventoSeleccionado!,
                                        eventoNombre: eventoNombre,
                                      );
                                    } else {
                                      await _crearJurado(
                                        nombre: nombre,
                                        usuario: usuario,
                                        password: password,
                                        categorias: categoriasSeleccionadas,
                                        eventoId: eventoSeleccionado!,
                                        eventoNombre: eventoNombre,
                                      );
                                    }
                                    if (mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    _showSnackBar('Error: $e', isError: true);
                                  } finally {
                                    setDialogState(() => isLoading = false);
                                  }
                                },
                          icon: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : Icon(
                                  isEditing
                                      ? Icons.save_rounded
                                      : Icons.person_add_rounded,
                                  size: 18),
                          label: Text(
                            isLoading
                                ? 'Guardando...'
                                : isEditing
                                    ? 'Guardar cambios'
                                    : 'Crear Jurado',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A5F),
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
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
      ),
    );

    // Liberar controllers al cerrar el diálogo
    nombreCtrl.dispose();
    usuarioCtrl.dispose();
    passwordCtrl.dispose();
  }

  void _showSnackBar(String msg,
      {bool isError = false, bool isWarning = false}) {
    final color = isError
        ? const Color(0xFFD4453B)
        : isWarning
            ? const Color(0xFFD4863B)
            : const Color(0xFF2E9E6E);
    final icon = isError
        ? Icons.error_outline_rounded
        : isWarning
            ? Icons.warning_amber_rounded
            : Icons.check_circle_outline_rounded;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 6,
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F7),
      appBar: AppBar(
        title: const Text(
          'Gestión de Jurados',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _cargarJurados,
            tooltip: 'Actualizar',
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      floatingActionButton: _isLoadingSession
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _mostrarDialogoJurado(),
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.person_add_rounded, size: 20),
              label: const Text(
                'Nuevo Jurado',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
      body: _isLoadingSession
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1E3A5F),
                strokeWidth: 2.5,
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildContextCard(),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _isLoadingJurados
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF1E3A5F),
                            strokeWidth: 2.5,
                          ),
                        )
                      : _jurados.isEmpty
                          ? _buildEmptyState()
                          : FadeTransition(
                              opacity: _fadeAnimation,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 4, 16, 100),
                                itemCount: _jurados.length,
                                itemBuilder: (_, i) =>
                                    _buildJuradoCard(_jurados[i]),
                              ),
                            ),
                ),
              ],
            ),
    );
  }

  // ── Tarjeta de contexto ───────────────────────────────────────────────────
  Widget _buildContextCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2D5480)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.school_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _carreraNombre ?? '—',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.2),
                ),
                const SizedBox(height: 3),
                Text(
                  _facultad ?? '—',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on_rounded,
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
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Text(
              '${_jurados.length} jurado${_jurados.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta de jurado ─────────────────────────────────────────────────────
  Widget _buildJuradoCard(Map<String, dynamic> jurado) {
    final categorias = jurado['categorias'] as List<String>;
    final nombre = jurado['nombre'] as String;
    final usuario = jurado['usuario'] as String;
    final eventoNombre = jurado['eventoNombre'] as String;
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF2E5A8D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  inicial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Contenido principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.account_circle_outlined,
                        size: 12, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      usuario,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ]),
                  if (eventoNombre.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.event_rounded,
                          size: 12, color: Colors.blue[400]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          eventoNombre,
                          style: TextStyle(
                              fontSize: 12, color: Colors.blue[400]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ],
                  if (categorias.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: categorias.asMap().entries.map((e) {
                        final color =
                            _categoryColors[e.key % _categoryColors.length];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: color.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Acciones
            Column(
              children: [
                _buildActionButton(
                  icon: Icons.edit_rounded,
                  color: const Color(0xFF1E3A5F),
                  bgColor: const Color(0xFFF0F5FF),
                  onTap: () => _mostrarDialogoJurado(jurado: jurado),
                  tooltip: 'Editar',
                ),
                const SizedBox(height: 6),
                _buildActionButton(
                  icon: Icons.delete_rounded,
                  color: const Color(0xFFD4453B),
                  bgColor: const Color(0xFFFFF5F5),
                  onTap: () => _eliminarJurado(jurado['id'], nombre),
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      ),
    );
  }

  // ── Estado vacío ──────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFF0F5FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline_rounded,
                size: 40, color: Color(0xFF1E3A5F)),
          ),
          const SizedBox(height: 20),
          const Text(
            'No hay jurados',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea el primer jurado para esta carrera',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ── Helpers del diálogo ───────────────────────────────────────────────────
  Widget _buildDialogSectionLabel(
      String label, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 15),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E3A5F),
          ),
        ),
      ],
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
        labelStyle:
            const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        prefixIcon:
            Icon(icon, color: const Color(0xFF1E3A5F), size: 20),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8EDF5)),
        ),
        filled: true,
        fillColor:
            enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  // FIX M2: parámetro isEditing para mostrar hint de contraseña
  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool obscure,
    required bool isEditing,
    required VoidCallback onToggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: 'Contraseña',
        labelStyle:
            const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: Color(0xFF1E3A5F), size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: Colors.grey[400],
            size: 20,
          ),
          onPressed: onToggle,
        ),
        // FIX M2: hint explicativo cuando se está editando
        helperText: isEditing
            ? 'Dejar vacío para no cambiar la contraseña actual'
            : null,
        helperStyle:
            const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildEventoDropdown({
    required List<Map<String, dynamic>> eventos,
    required String? eventoSeleccionado,
    required bool isEditing,
    required Map<String, dynamic>? jurado,
    required ValueChanged<String?> onChanged,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: eventoSeleccionado != null
              ? const Color(0xFFF0F5FF)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: eventoSeleccionado != null
                ? const Color(0xFF3B6FD4)
                : const Color(0xFFE2E8F0),
            width: eventoSeleccionado != null ? 1.5 : 1,
          ),
        ),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: eventoSeleccionado != null
                  ? const Color(0xFF3B6FD4).withValues(alpha: 0.15)
                  : const Color(0xFF3B6FD4).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.event_rounded,
                color: Color(0xFF3B6FD4), size: 18),
          ),
          title: Text(
            eventoSeleccionado != null
                ? (eventos.firstWhere(
                      (e) => e['id'] == eventoSeleccionado,
                      orElse: () => {'name': 'Evento seleccionado'},
                    )['name'] as String)
                : (eventos.isEmpty
                    ? 'No hay eventos disponibles'
                    : 'Seleccionar evento'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: eventoSeleccionado != null
                  ? FontWeight.w700
                  : FontWeight.w400,
              color: eventoSeleccionado != null
                  ? const Color(0xFF1E3A5F)
                  : const Color(0xFF94A3B8),
            ),
          ),
          subtitle: eventoSeleccionado != null
              ? const Text(
                  'Toca para cambiar',
                  style:
                      TextStyle(fontSize: 11, color: Color(0xFF3B6FD4)),
                )
              : null,
          iconColor: const Color(0xFF3B6FD4),
          collapsedIconColor: const Color(0xFF94A3B8),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          children: eventos.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'No hay eventos para esta carrera.',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                ]
              : eventos.map((e) {
                  final isSelected = eventoSeleccionado == e['id'];
                  return GestureDetector(
                    onTap: () => onChanged(e['id'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFF0F5FF)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF3B6FD4)
                              : const Color(0xFFE8EDF5),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_rounded,
                              size: 16, color: Color(0xFF3B6FD4)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e['name'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF1E3A5F)
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF3B6FD4), size: 18),
                        ],
                      ),
                    ),
                  );
                }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoriasPanel({
    required List<String> categorias,
    required List<String> seleccionadas,
    required bool isLoading,
    required void Function(String, bool) onChanged,
  }) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF8B4DC7)),
        ),
      );
    }

    if (categorias.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF5FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE9D5FF)),
        ),
        child: const Text(
          'No hay categorías en este evento.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B21A8)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: categorias.length,
        itemBuilder: (_, i) {
          final cat = categorias[i];
          final isSelected = seleccionadas.contains(cat);
          final color = _categoryColors[i % _categoryColors.length];

          return CheckboxListTile(
            dense: true,
            value: isSelected,
            activeColor: color,
            checkColor: Colors.white,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14),
            title: Text(
              cat,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color:
                    isSelected ? color : const Color(0xFF334155),
              ),
            ),
            onChanged: (v) => onChanged(cat, v == true),
          );
        },
      ),
    );
  }
}