import 'package:flutter/material.dart';
import 'admin_carrera_service.dart';
import '/admin/logica/filiales_service.dart';

class GestionAdminsCarreraScreen extends StatefulWidget {
  const GestionAdminsCarreraScreen({super.key});

  @override
  State<GestionAdminsCarreraScreen> createState() =>
      _GestionAdminsCarreraScreenState();
}

class _GestionAdminsCarreraScreenState
    extends State<GestionAdminsCarreraScreen> {
  final AdminCarreraService _adminService = AdminCarreraService();
  final FilialesService _filialesService = FilialesService();

  List<Map<String, dynamic>> _admins = [];
  Map<String, dynamic> _estructuraFiliales = {};
  bool _isLoading = true;
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _filialesService.inicializarSiEsNecesario();
      _estructuraFiliales = await _filialesService.getEstructuraCompleta();
      _admins = await _adminService.getAdminsCarrera();
    } catch (e) {
      print('Error cargando datos: $e');
      _showMessage('Error al cargar datos', isError: true);
    }
    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _adminsFiltrados {
    if (_searchTerm.isEmpty) return _admins;
    return _admins.where((admin) {
      final usuario = (admin['usuario'] ?? '').toString().toLowerCase();
      final carrera = (admin['carrera'] ?? '').toString().toLowerCase();
      final search = _searchTerm.toLowerCase();
      return usuario.contains(search) || carrera.contains(search);
    }).toList();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _mostrarDialogoCrearAdmin() async {
    await showDialog(
      context: context,
      builder: (context) => _DialogoCrearAdmin(
        estructuraFiliales: _estructuraFiliales,
        onSuccess: () {
          _loadData();
          _showMessage('Admin de carrera creado exitosamente');
        },
      ),
    );
  }

  Future<void> _mostrarDialogoEditarAdmin(
      Map<String, dynamic> admin) async {
    await showDialog(
      context: context,
      builder: (context) => _DialogoEditarAdmin(
        admin: admin,
        estructuraFiliales: _estructuraFiliales,
        onSuccess: () {
          _loadData();
          _showMessage('Admin actualizado exitosamente');
        },
      ),
    );
  }

  Future<void> _confirmarEliminar(String adminId, String usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Confirmar eliminación'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar al admin "@$usuario"?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final success = await _adminService.eliminarAdminCarrera(adminId);
      if (success) {
        _showMessage('Admin eliminado exitosamente');
        _loadData();
      } else {
        _showMessage('Error al eliminar', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.admin_panel_settings,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Admins de Carrera',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadData,
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
            ),

            // Content Area
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
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          // Barra de búsqueda
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: TextField(
                              onChanged: (value) =>
                                  setState(() => _searchTerm = value),
                              decoration: InputDecoration(
                                hintText:
                                    'Buscar por usuario o carrera...',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),

                          // Lista
                          Expanded(
                            child: _adminsFiltrados.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.inbox,
                                            size: 64,
                                            color: Colors.grey[400]),
                                        const SizedBox(height: 16),
                                        Text(
                                          _searchTerm.isEmpty
                                              ? 'No hay admins de carrera'
                                              : 'No se encontraron resultados',
                                          style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    itemCount: _adminsFiltrados.length,
                                    itemBuilder: (context, index) {
                                      return _buildAdminCard(
                                          _adminsFiltrados[index]);
                                    },
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoCrearAdmin,
        backgroundColor: const Color(0xFF1E3A5F),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Admin'),
      ),
    );
  }

  Widget _buildAdminCard(Map<String, dynamic> admin) {
    final activo = admin['activo'] ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      activo ? const Color(0xFF1E3A5F) : Colors.grey,
                  child: Text(
                    (admin['usuario'] as String)[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '@${admin['usuario']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                      ),
                      if (!activo)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Inactivo',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.red,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'editar') {
                      await _mostrarDialogoEditarAdmin(admin);
                    } else if (value == 'eliminar') {
                      _confirmarEliminar(
                          admin['id'], admin['usuario']);
                    } else if (value == 'activar') {
                      await _adminService.actualizarAdminCarrera(
                        adminId: admin['id'],
                        activo: !activo,
                      );
                      _loadData();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'editar',
                      child: Row(
                        children: [
                          Icon(Icons.edit,
                              size: 18, color: Color(0xFF1E3A5F)),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'activar',
                      child: Row(
                        children: [
                          Icon(
                            activo ? Icons.block : Icons.check_circle,
                            size: 18,
                            color: activo ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(activo ? 'Desactivar' : 'Activar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Eliminar'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            _buildInfoRow(
                Icons.location_city, admin['filialNombre'] ?? ''),
            const SizedBox(height: 6),
            _buildInfoRow(Icons.business, admin['facultad'] ?? ''),
            const SizedBox(height: 6),
            _buildInfoRow(Icons.school, admin['carrera'] ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DIÁLOGO CREAR ADMIN
// ═══════════════════════════════════════════════════════════════
class _DialogoCrearAdmin extends StatefulWidget {
  final Map<String, dynamic> estructuraFiliales;
  final VoidCallback onSuccess;

  const _DialogoCrearAdmin({
    required this.estructuraFiliales,
    required this.onSuccess,
  });

  @override
  State<_DialogoCrearAdmin> createState() => __DialogoCrearAdminState();
}

class __DialogoCrearAdminState extends State<_DialogoCrearAdmin> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  final AdminCarreraService _service = AdminCarreraService();
  final FilialesService _filialesService = FilialesService();

  String? _selectedFilial;
  String? _selectedFacultad;
  String? _selectedCarrera;
  String? _selectedCarreraId;

  List<String> _facultadesDisponibles = [];
  List<Map<String, dynamic>> _carrerasDisponibles = [];

  bool _isCreating = false;

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onFilialChanged(String? filial) {
    setState(() {
      _selectedFilial = filial;
      _selectedFacultad = null;
      _selectedCarrera = null;
      _selectedCarreraId = null;
      _facultadesDisponibles = [];
      _carrerasDisponibles = [];

      if (filial != null &&
          widget.estructuraFiliales.containsKey(filial)) {
        final filialData = widget.estructuraFiliales[filial];
        final facultades =
            filialData['facultades'] as Map<String, dynamic>?;
        if (facultades != null) {
          _facultadesDisponibles = facultades.keys.toList();
        }
      }
    });
  }

  void _onFacultadChanged(String? facultad) {
    setState(() {
      _selectedFacultad = facultad;
      _selectedCarrera = null;
      _selectedCarreraId = null;
      _carrerasDisponibles = [];

      if (_selectedFilial != null &&
          facultad != null &&
          widget.estructuraFiliales.containsKey(_selectedFilial)) {
        final filialData = widget.estructuraFiliales[_selectedFilial!];
        final facultades =
            filialData['facultades'] as Map<String, dynamic>?;
        if (facultades != null && facultades.containsKey(facultad)) {
          final facultadData = facultades[facultad];
          _carrerasDisponibles = List<Map<String, dynamic>>.from(
              facultadData['carreras'] ?? []);
        }
      }
    });
  }

  Future<void> _crearAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFilial == null ||
        _selectedFacultad == null ||
        _selectedCarrera == null ||
        _selectedCarreraId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Por favor selecciona filial, facultad y carrera'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final success = await _service.crearAdminCarrera(
        usuario: _usuarioController.text.trim(),
        password: _passwordController.text,
        filial: _selectedFilial!,
        filialNombre:
            _filialesService.getNombreFilial(_selectedFilial!),
        facultad: _selectedFacultad!,
        carrera: _selectedCarrera!,
        carreraId: _selectedCarreraId!,
      );

      if (success) {
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ya existe un admin con ese usuario'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red),
      );
    }

    setState(() => _isCreating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints:
            const BoxConstraints(maxWidth: 500, maxHeight: 540),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Título
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.admin_panel_settings,
                        color: Color(0xFF1E3A5F), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crear Admin de Carrera',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                        Text(
                          'Tendrá acceso a todas las funciones',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Usuario
                      TextFormField(
                        controller: _usuarioController,
                        decoration: InputDecoration(
                          labelText: 'Usuario',
                          prefixIcon: const Icon(Icons.account_circle),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) =>
                            v!.trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 14),

                      // Contraseña
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(() =>
                                _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v!.length < 6
                            ? 'Mínimo 6 caracteres'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Filial
                      DropdownButtonFormField<String>(
                        value: _selectedFilial,
                        decoration: InputDecoration(
                          labelText: 'Filial (Sede)',
                          prefixIcon: const Icon(Icons.location_city),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: widget.estructuraFiliales.keys
                            .map((filial) {
                          return DropdownMenuItem<String>(
                            value: filial,
                            child: Text(
                                _filialesService.getNombreFilial(filial)),
                          );
                        }).toList(),
                        onChanged: _onFilialChanged,
                        validator: (v) => v == null ? 'Requerido' : null,
                      ),

                      if (_selectedFilial != null) ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _selectedFacultad,
                          decoration: InputDecoration(
                            labelText: 'Facultad',
                            prefixIcon: const Icon(Icons.business),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _facultadesDisponibles.map((f) {
                            return DropdownMenuItem<String>(
                                value: f, child: Text(f));
                          }).toList(),
                          onChanged: _onFacultadChanged,
                          validator: (v) => v == null ? 'Requerido' : null,
                        ),
                      ],

                      if (_selectedFacultad != null) ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _selectedCarrera,
                          decoration: InputDecoration(
                            labelText: 'Carrera',
                            prefixIcon: const Icon(Icons.school),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _carrerasDisponibles.map((c) {
                            return DropdownMenuItem<String>(
                              value: c['nombre'],
                              onTap: () =>
                                  _selectedCarreraId = c['id'],
                              child: Text(c['nombre']),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedCarrera = v),
                          validator: (v) => v == null ? 'Requerido' : null,
                        ),
                      ],

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _crearAdmin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Crear',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold)),
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
}

// ═══════════════════════════════════════════════════════════════
// DIÁLOGO EDITAR ADMIN
// ═══════════════════════════════════════════════════════════════
class _DialogoEditarAdmin extends StatefulWidget {
  final Map<String, dynamic> admin;
  final Map<String, dynamic> estructuraFiliales;
  final VoidCallback onSuccess;

  const _DialogoEditarAdmin({
    required this.admin,
    required this.estructuraFiliales,
    required this.onSuccess,
  });

  @override
  State<_DialogoEditarAdmin> createState() => __DialogoEditarAdminState();
}

class __DialogoEditarAdminState extends State<_DialogoEditarAdmin> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usuarioController;
  final TextEditingController _passwordController =
      TextEditingController();
  bool _obscurePassword = true;
  bool _activo = true;

  final AdminCarreraService _service = AdminCarreraService();
  final FilialesService _filialesService = FilialesService();

  String? _selectedFilial;
  String? _selectedFacultad;
  String? _selectedCarrera;
  String? _selectedCarreraId;

  List<String> _facultadesDisponibles = [];
  List<Map<String, dynamic>> _carrerasDisponibles = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usuarioController =
        TextEditingController(text: widget.admin['usuario'] ?? '');
    _activo = widget.admin['activo'] ?? true;

    _selectedFilial = widget.admin['filial'];
    _selectedFacultad = widget.admin['facultad'];
    _selectedCarrera = widget.admin['carrera'];
    _selectedCarreraId = widget.admin['carreraId'];

    if (_selectedFilial != null &&
        widget.estructuraFiliales.containsKey(_selectedFilial)) {
      final filialData = widget.estructuraFiliales[_selectedFilial!];
      final facultades =
          filialData['facultades'] as Map<String, dynamic>?;
      if (facultades != null) {
        _facultadesDisponibles = facultades.keys.toList();

        if (_selectedFacultad != null &&
            facultades.containsKey(_selectedFacultad)) {
          final facultadData = facultades[_selectedFacultad!];
          _carrerasDisponibles = List<Map<String, dynamic>>.from(
              facultadData['carreras'] ?? []);
        }
      }
    }
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onFilialChanged(String? filial) {
    setState(() {
      _selectedFilial = filial;
      _selectedFacultad = null;
      _selectedCarrera = null;
      _selectedCarreraId = null;
      _facultadesDisponibles = [];
      _carrerasDisponibles = [];

      if (filial != null &&
          widget.estructuraFiliales.containsKey(filial)) {
        final filialData = widget.estructuraFiliales[filial];
        final facultades =
            filialData['facultades'] as Map<String, dynamic>?;
        if (facultades != null) {
          _facultadesDisponibles = facultades.keys.toList();
        }
      }
    });
  }

  void _onFacultadChanged(String? facultad) {
    setState(() {
      _selectedFacultad = facultad;
      _selectedCarrera = null;
      _selectedCarreraId = null;
      _carrerasDisponibles = [];

      if (_selectedFilial != null &&
          facultad != null &&
          widget.estructuraFiliales.containsKey(_selectedFilial)) {
        final filialData = widget.estructuraFiliales[_selectedFilial!];
        final facultades =
            filialData['facultades'] as Map<String, dynamic>?;
        if (facultades != null && facultades.containsKey(facultad)) {
          final facultadData = facultades[facultad];
          _carrerasDisponibles = List<Map<String, dynamic>>.from(
              facultadData['carreras'] ?? []);
        }
      }
    });
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFilial == null ||
        _selectedFacultad == null ||
        _selectedCarrera == null ||
        _selectedCarreraId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Por favor selecciona filial, facultad y carrera'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final success = await _service.actualizarAdminCarrera(
        adminId: widget.admin['id'],
        usuario: _usuarioController.text.trim(),
        password: _passwordController.text.isNotEmpty
            ? _passwordController.text
            : null,
        filial: _selectedFilial,
        filialNombre:
            _filialesService.getNombreFilial(_selectedFilial!),
        facultad: _selectedFacultad,
        carrera: _selectedCarrera,
        carreraId: _selectedCarreraId,
        activo: _activo,
      );

      if (success) {
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ya existe otro admin con ese usuario'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints:
            const BoxConstraints(maxWidth: 500, maxHeight: 620),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Título
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit,
                        color: Color(0xFF1E3A5F), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Editar Admin de Carrera',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Toggle activo/inactivo
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _activo
                              ? Colors.green.withOpacity(0.08)
                              : Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _activo
                                ? Colors.green.withOpacity(0.3)
                                : Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _activo
                                  ? Icons.check_circle
                                  : Icons.block,
                              color: _activo ? Colors.green : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _activo
                                    ? 'Cuenta activa'
                                    : 'Cuenta inactiva',
                                style: TextStyle(
                                  color: _activo
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Switch(
                              value: _activo,
                              onChanged: (v) =>
                                  setState(() => _activo = v),
                              activeColor: Colors.green,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Usuario
                      TextFormField(
                        controller: _usuarioController,
                        decoration: InputDecoration(
                          labelText: 'Usuario',
                          prefixIcon:
                              const Icon(Icons.account_circle),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) =>
                            v!.trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 14),

                      // Contraseña opcional
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Nueva contraseña (opcional)',
                          hintText: 'Dejar vacío para no cambiar',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(() =>
                                _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          if (v != null &&
                              v.isNotEmpty &&
                              v.length < 6) {
                            return 'Mínimo 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Filial
                      DropdownButtonFormField<String>(
                        value: _selectedFilial,
                        decoration: InputDecoration(
                          labelText: 'Filial (Sede)',
                          prefixIcon: const Icon(Icons.location_city),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: widget.estructuraFiliales.keys
                            .map((filial) {
                          return DropdownMenuItem<String>(
                            value: filial,
                            child: Text(
                                _filialesService.getNombreFilial(filial)),
                          );
                        }).toList(),
                        onChanged: _onFilialChanged,
                        validator: (v) => v == null ? 'Requerido' : null,
                      ),

                      if (_selectedFilial != null) ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _selectedFacultad,
                          decoration: InputDecoration(
                            labelText: 'Facultad',
                            prefixIcon: const Icon(Icons.business),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _facultadesDisponibles.map((f) {
                            return DropdownMenuItem<String>(
                                value: f, child: Text(f));
                          }).toList(),
                          onChanged: _onFacultadChanged,
                          validator: (v) => v == null ? 'Requerido' : null,
                        ),
                      ],

                      if (_selectedFacultad != null) ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _selectedCarrera,
                          decoration: InputDecoration(
                            labelText: 'Carrera',
                            prefixIcon: const Icon(Icons.school),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _carrerasDisponibles.map((c) {
                            return DropdownMenuItem<String>(
                              value: c['nombre'],
                              onTap: () =>
                                  _selectedCarreraId = c['id'],
                              child: Text(c['nombre']),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedCarrera = v),
                          validator: (v) => v == null ? 'Requerido' : null,
                        ),
                      ],

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _guardarCambios,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Guardar',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold)),
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
}