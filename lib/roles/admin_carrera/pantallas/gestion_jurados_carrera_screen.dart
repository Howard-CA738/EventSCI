import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import '/jurado_security_service.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '/shared/logica/jurados_service.dart';

class GestionJuradosCarreraScreen extends StatefulWidget {
  const GestionJuradosCarreraScreen({super.key});

  @override
  State<GestionJuradosCarreraScreen> createState() =>
      _GestionJuradosCarreraScreenState();
}

class _GestionJuradosCarreraScreenState
    extends State<GestionJuradosCarreraScreen>
    with SingleTickerProviderStateMixin {
  final JuradosService _service = JuradosService();

  String? _filialId;
  String? _filialNombre;
  String? _facultad;
  String? _carreraId;
  String? _carreraNombre;
final TextEditingController _searchController = TextEditingController();

List<Map<String, dynamic>> get _juradosFiltrados {
  final q = _searchController.text.trim().toLowerCase();
  if (q.isEmpty) return _jurados;
  return _jurados
      .where((j) => (j['nombre'] as String).toLowerCase().contains(q))
      .toList();
}
  List<Map<String, dynamic>> _jurados = [];
  bool _isLoadingSession = true;
  bool _isLoadingJurados = false;


  List<Map<String, dynamic>>? _eventosCache;

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
  _searchController.addListener(() => setState(() {}));
  _loadSessionData();
}

 @override
void dispose() {
  _fadeController.dispose();
  _searchController.dispose();
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
        _carreraId = adminData['carreraId'];
        _carreraNombre = adminData['carrera'];
      }
    } catch (e) {
      debugPrint('Error cargando sesión: $e');
    } finally {
      setState(() => _isLoadingSession = false);
    }

    await Future.wait([
      _cargarJurados(),
      _cargarEventosConCache(),
    ]);
  }

  Future<void> _cargarJurados() async {
    if (_filialId == null || _facultad == null || _carreraNombre == null) return;
    setState(() => _isLoadingJurados = true);
    try {
      final list = await _service.obtenerJurados(
        filialId: _filialId!,
        facultad: _facultad!,
        carreraNombre: _carreraNombre!,
      );

      if (mounted) {
        setState(() => _jurados = list);
        try {
          _fadeController.forward(from: 0);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error cargando jurados: $e');
      if (mounted) _showSnackBar('Error al cargar jurados', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingJurados = false);
    }
  }


  Future<List<Map<String, dynamic>>> _cargarEventosConCache() async {
    if (_eventosCache != null) return _eventosCache!;
    _eventosCache = await _cargarEventos();
    return _eventosCache!;
  }

  Future<List<String>> _cargarCategoriasPorEvento(String eventoId) async {
    try {
      return await _service.obtenerCategoriasPorEvento(eventoId);
    } catch (e) {
      debugPrint('Error cargando categorías: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _cargarEventos() async {
    try {
      return await _service.obtenerEventos(
        filialId: _filialId,
        facultad: _facultad,
        carreraId: _carreraId,
        carreraNombre: _carreraNombre,
      );
    } catch (e) {
      debugPrint('Error cargando eventos: $e');
      return [];
    }
  }

  Future<String> _crearJurado({
    required String nombre,
    required String usuario,
    required String password,
    required List<String> categorias,
    required String eventoId,
    required String eventoNombre,
  }) {
    return _service.crearJurado(
      nombre: nombre,
      usuario: usuario,
      password: password,
      categorias: categorias,
      eventoId: eventoId,
      eventoNombre: eventoNombre,
      filialId: _filialId,
      filialNombre: _filialNombre,
      facultad: _facultad,
      carreraNombre: _carreraNombre,
      carreraId: _carreraId,
    );
  }

  Future<bool> _actualizarJurado({
    required String id,
    required String nombre,
    required String usuario,
    required String password,
    required List<String> categorias,
    required String eventoId,
    required String eventoNombre,
  }) {
    return _service.actualizarJurado(
      id: id,
      nombre: nombre,
      usuario: usuario,
      password: password,
      categorias: categorias,
      eventoId: eventoId,
      eventoNombre: eventoNombre,
    );
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
                  const Expanded(
                    child: Text(
                      'Confirmar eliminación',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E3A5F),
                      ),
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
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
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
      await _service.eliminarJurado(id);
      _showSnackBar('Jurado eliminado');
      await _cargarJurados();
    }
  }



  void _mostrarDialogoJurado({Map<String, dynamic>? jurado}) {
    final isEditing = jurado != null;

    final nombreCtrl = TextEditingController(text: jurado?['nombre'] ?? '');
    final usuarioCtrl = TextEditingController(text: jurado?['usuario'] ?? '');
    final passwordCtrl = TextEditingController();

    List<String> categoriasSeleccionadas =
        List<String>.from(jurado?['categorias'] ?? []);
    String? eventoSeleccionado =
        isEditing && (jurado['eventoId'] as String).isNotEmpty
            ? jurado['eventoId'] as String
            : null;

    List<Map<String, dynamic>> eventos = _eventosCache ?? [];
    List<String> categorias = [];
    bool obscurePass = true;
    bool isLoading = false;
    bool isLoadingCategorias = false;

    bool isLoadingInitial = isEditing;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {


          if (isEditing && isLoadingInitial) {
            isLoadingInitial = false;
            Future(() async {

              final results = await Future.wait([
                JuradoSecurityService.decryptPassword(juradoId: jurado['id']),
                if (eventoSeleccionado != null)
                  _cargarCategoriasPorEvento(eventoSeleccionado!)
                else
                  Future.value(<String>[]),
                _cargarEventosConCache(),
              ]);

              final passwordActual = results[0] as String;
              final cats = results[1] as List<String>;
              final eventosActualizados =
                  results[2] as List<Map<String, dynamic>>;

              if (!ctx.mounted) return;
              setDialogState(() {
                passwordCtrl.text = passwordActual;
                categorias = cats;
                eventos = eventosActualizados;
              });
            });
          } else if (!isEditing && eventos.isEmpty) {

            Future(() async {
              final eventosActualizados = await _cargarEventosConCache();
              if (!ctx.mounted) return;
              setDialogState(() => eventos = eventosActualizados);
            });
          }

          return Dialog(
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(
                    left: 22,
                    right: 22,
                    top: 22,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 22,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

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
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close_rounded,
                                  color: Color(0xFF94A3B8), size: 20),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),


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
                                '${_carreraNombre ?? ''} · ${_facultad ?? ''} · ${_filialNombre ?? ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E3A5F),
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),


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
                      ),
                      const SizedBox(height: 12),

                      isEditing && passwordCtrl.text.isEmpty
                          ? _buildPasswordFieldLoading()
                          : _buildPasswordField(
                              controller: passwordCtrl,
                              obscure: obscurePass,
                              isEditing: isEditing,
                              onToggle: () => setDialogState(
                                  () => obscurePass = !obscurePass),
                            ),
                      const SizedBox(height: 18),


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
                            if (!isEditing || value != jurado['eventoId']) {
                              categoriasSeleccionadas = [];
                            }
                            isLoadingCategorias = true;
                          });
                          final cats =
                              await _cargarCategoriasPorEvento(value!);
                          if (ctx.mounted) {
                            setDialogState(() {
                              categorias = cats;
                              isLoadingCategorias = false;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 18),


                      if (eventoSeleccionado != null) ...[
                        _buildDialogSectionLabel('Categorías',
                            Icons.category_rounded, const Color(0xFF8B4DC7)),
                        const SizedBox(height: 10),
                        _buildCategoriasPanel(
                          categorias: categorias,
                          seleccionadas: categoriasSeleccionadas,
                          isLoading: isLoadingCategorias,
                          onChanged: (cat, selected) =>
                              setDialogState(() {
                            if (selected) {
                              categoriasSeleccionadas.add(cat);
                            } else {
                              categoriasSeleccionadas.remove(cat);
                            }
                          }),
                        ),
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
                              return Chip(
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
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 18),
                      ],


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
                                        _showSnackBar(
                                            'Completa todos los campos',
                                            isWarning: true);
                                        return;
                                      }
                                      if (!isEditing && password.isEmpty) {
                                        _showSnackBar(
                                            'La contraseña es obligatoria',
                                            isWarning: true);
                                        return;
                                      }
                                      if (eventoSeleccionado == null) {
                                        _showSnackBar(
                                            'Selecciona un evento',
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
                                            id: jurado['id'],
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
                                      } catch (e) {
                                        _showSnackBar('Error: $e',
                                            isError: true);
                                        setDialogState(
                                            () => isLoading = false);
                                        return;
                                      }

                                      setDialogState(() => isLoading = false);
                                      if (mounted) Navigator.pop(ctx);

                                      _showSnackBar(isEditing
                                          ? 'Jurado actualizado exitosamente'
                                          : 'Jurado creado exitosamente');

                                      _eventosCache = null;
                                      await _cargarJurados();
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
          );
        },
      ),
    );
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
          onPressed: () {
            _eventosCache = null;
            _cargarJurados();
          },
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar jurado por nombre...',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF1E3A5F), size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Color(0xFF94A3B8), size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF1E3A5F), width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoadingJurados
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1E3A5F),
                          strokeWidth: 2.5,
                        ),
                      )
                    : _juradosFiltrados.isEmpty
                        ? _buildEmptyState()
                        : FadeTransition(
                            opacity: _fadeAnimation,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 100),
                              itemCount: _juradosFiltrados.length,
                              itemBuilder: (_, i) =>
                                  _buildJuradoCard(_juradosFiltrados[i]),
                            ),
                          ),
              ),
            ],
          ),
  );
}

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
        crossAxisAlignment: CrossAxisAlignment.center,
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
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 3),
                Text(
                  _facultad ?? '—',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _filialNombre ?? '—',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.account_circle_outlined,
                        size: 12, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        usuario,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
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
                          maxLines: 2,
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
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(icon, color: color, size: 19),
          ),
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
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Crea el primer jurado para esta carrera',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

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
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E3A5F),
            ),
            overflow: TextOverflow.ellipsis,
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


  Widget _buildPasswordFieldLoading() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.lock_outline_rounded,
              color: Color(0xFF1E3A5F), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cargando contraseña...',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 14),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF1E3A5F)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool obscure,
    required bool isEditing,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isEditing) ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Color(0xFFD4863B), size: 15),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Esta es la contraseña actual del jurado. '
                    'Puedes copiarla o escribir una nueva.',
                    style:
                        TextStyle(fontSize: 11, color: Color(0xFF7D5A00)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            labelText: isEditing ? 'Contraseña actual' : 'Contraseña',
            labelStyle:
                const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                color: Color(0xFF1E3A5F), size: 20),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    icon: const Icon(Icons.copy_rounded,
                        color: Color(0xFF3B6FD4), size: 19),
                    tooltip: 'Copiar contraseña',
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (controller.text.isNotEmpty) {
                        Clipboard.setData(
                            ClipboardData(text: controller.text));
                        _showSnackBar(
                            'Contraseña copiada al portapapeles');
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: onToggle,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
            helperText: isEditing
                ? 'Dejar vacío para no cambiar la contraseña'
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
        ),
      ],
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
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          subtitle: eventoSeleccionado != null
              ? const Text(
                  'Toca para cambiar',
                  style: TextStyle(fontSize: 11, color: Color(0xFF3B6FD4)),
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
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500]),
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
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
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
        physics: const ClampingScrollPhysics(),
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
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            onChanged: (v) => onChanged(cat, v == true),
          );
        },
      ),
    );
  }
}
