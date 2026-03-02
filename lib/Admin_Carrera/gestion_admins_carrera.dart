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
      final nombre = (admin['nombre'] ?? '').toString().toLowerCase();
      final usuario = (admin['usuario'] ?? '').toString().toLowerCase();
      final carrera = (admin['carrera'] ?? '').toString().toLowerCase();
      final search = _searchTerm.toLowerCase();

      return nombre.contains(search) ||
          usuario.contains(search) ||
          carrera.contains(search);
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

  Future<void> _confirmarEliminar(String adminId, String nombre) async {
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
          '¿Estás seguro de que deseas eliminar a "$nombre"?\n\nEsta acción no se puede deshacer.',
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
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 24,
                    ),
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
                              onChanged: (value) {
                                setState(() => _searchTerm = value);
                              },
                              decoration: InputDecoration(
                                hintText:
                                    'Buscar por nombre, usuario o carrera...',
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

                          // Lista de admins
                          Expanded(
                            child: _adminsFiltrados.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.inbox,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _searchTerm.isEmpty
                                              ? 'No hay admins de carrera'
                                              : 'No se encontraron resultados',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    itemCount: _adminsFiltrados.length,
                                    itemBuilder: (context, index) {
                                      final admin = _adminsFiltrados[index];
                                      return _buildAdminCard(admin);
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
    final permisos = List<String>.from(admin['permisos'] ?? []);
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
                  backgroundColor: activo
                      ? const Color(0xFF1E3A5F)
                      : Colors.grey,
                  child: Text(
                    admin['nombre'][0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              admin['nombre'],
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
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Inactivo',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${admin['usuario']}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'eliminar') {
                      _confirmarEliminar(admin['id'], admin['nombre']);
                    } else if (value == 'activar') {
                      _adminService.actualizarAdminCarrera(
                        adminId: admin['id'],
                        activo: !activo,
                      );
                      _loadData();
                    }
                  },
                  itemBuilder: (context) => [
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
            _buildInfoRow(Icons.location_city, admin['filialNombre']),
            const SizedBox(height: 6),
            _buildInfoRow(Icons.business, admin['facultad']),
            const SizedBox(height: 6),
            _buildInfoRow(Icons.school, admin['carrera']),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: permisos.map((permiso) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    permiso,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1E3A5F),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
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
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ✅ DIÁLOGO PARA CREAR ADMIN
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
  final _nombreController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();

  final AdminCarreraService _service = AdminCarreraService();
  final FilialesService _filialesService = FilialesService();

  String? _selectedFilial;
  String? _selectedFacultad;
  String? _selectedCarrera;
  String? _selectedCarreraId;

  List<String> _facultadesDisponibles = [];
  List<Map<String, dynamic>> _carrerasDisponibles = [];

  final List<String> _permisosDisponibles = [
    'estudiantes',
    'grupos',
    'proyectos',
    'evaluaciones',
    'reportes',
  ];

  final Set<String> _permisosSeleccionados = {
    'estudiantes',
    'grupos',
    'proyectos',
    'evaluaciones',
    'reportes',
  };

  bool _isCreating = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _usuarioController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
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

      if (filial != null && widget.estructuraFiliales.containsKey(filial)) {
        final filialData = widget.estructuraFiliales[filial];
        final facultades = filialData['facultades'] as Map<String, dynamic>?;

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
        final facultades = filialData['facultades'] as Map<String, dynamic>?;

        if (facultades != null && facultades.containsKey(facultad)) {
          final facultadData = facultades[facultad];
          _carrerasDisponibles = List<Map<String, dynamic>>.from(
            facultadData['carreras'] ?? [],
          );
        }
      }
    });
  }

  Future<void> _crearAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFilial == null ||
        _selectedFacultad == null ||
        _selectedCarrera == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa todos los campos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final success = await _service.crearAdminCarrera(
        nombre: _nombreController.text.trim(),
        usuario: _usuarioController.text.trim(),
        password: _passwordController.text,
        email: _emailController.text.trim(),
        filial: _selectedFilial!,
        filialNombre: _filialesService.getNombreFilial(_selectedFilial!),
        facultad: _selectedFacultad!,
        carrera: _selectedCarrera!,
        carreraId: _selectedCarreraId!,
        permisos: _permisosSeleccionados.toList(),
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
      print('Error creando admin: $e');
    }

    setState(() => _isCreating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Crear Admin de Carrera',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _usuarioController,
                        decoration: const InputDecoration(
                          labelText: 'Usuario',
                          prefixIcon: Icon(Icons.account_circle),
                        ),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                        validator: (v) =>
                            v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            !RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(v!)
                            ? 'Correo inválido'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedFilial,
                        decoration: const InputDecoration(
                          labelText: 'Filial (Sede)',
                          prefixIcon: Icon(Icons.location_city),
                        ),
                        items: widget.estructuraFiliales.keys.map((filial) {
                          final nombre = _filialesService.getNombreFilial(
                            filial,
                          );
                          return DropdownMenuItem<String>(
                            value: filial,
                            child: Text(nombre),
                          );
                        }).toList(),
                        onChanged: _onFilialChanged,
                        validator: (v) => v == null ? 'Requerido' : null,
                      ),
                      if (_selectedFilial != null) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedFacultad,
                          decoration: const InputDecoration(
                            labelText: 'Facultad',
                            prefixIcon: Icon(Icons.business),
                          ),
                          items: _facultadesDisponibles.map((f) {
                            return DropdownMenuItem<String>(
                              value: f,
                              child: Text(f),
                            );
                          }).toList(),
                          onChanged: _onFacultadChanged,
                          validator: (v) => v == null ? 'Requerido' : null,
                        ),
                      ],
                      if (_selectedFacultad != null) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedCarrera,
                          decoration: const InputDecoration(
                            labelText: 'Carrera',
                            prefixIcon: Icon(Icons.school),
                          ),
                          items: _carrerasDisponibles.map((c) {
                            return DropdownMenuItem<String>(
                              value: c['nombre'],
                              onTap: () => _selectedCarreraId = c['id'],
                              child: Text(c['nombre']),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedCarrera = v),
                          validator: (v) => v == null ? 'Requerido' : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Permisos:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._permisosDisponibles.map((permiso) {
                        return CheckboxListTile(
                          title: Text(permiso),
                          value: _permisosSeleccionados.contains(permiso),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _permisosSeleccionados.add(permiso);
                              } else {
                                _permisosSeleccionados.remove(permiso);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _crearAdmin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Crear'),
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
