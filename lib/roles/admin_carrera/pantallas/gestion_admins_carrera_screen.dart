import 'package:flutter/material.dart';
import '/shared/logica/filiales_service.dart';
import '../logica/admin_carrera_service.dart';
import 'dialogo_crear_admin_carrera.dart';
import 'dialogo_editar_admin_carrera.dart';

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
      debugPrint('Error cargando datos: $e');
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
      builder: (context) => DialogoCrearAdminCarrera(
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
      builder: (context) => DialogoEditarAdminCarrera(
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
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Volver',
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
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
                      overflow: TextOverflow.ellipsis,
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
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: TextField(
                              onChanged: (value) =>
                                  setState(() => _searchTerm = value),
                              decoration: InputDecoration(
                                hintText: 'Buscar por usuario o carrera...',
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
    final usuario = (admin['usuario'] ?? '') as String;
    final inicial = usuario.isNotEmpty ? usuario[0].toUpperCase() : '?';

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
                    inicial,
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
                          '@$usuario',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!activo)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Inactivo',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Opciones para $usuario',
                  child: PopupMenuButton<String>(
                    tooltip: 'Opciones para $usuario',
                    onSelected: (value) async {
                      if (value == 'editar') {
                        await _mostrarDialogoEditarAdmin(admin);
                      } else if (value == 'eliminar') {
                        _confirmarEliminar(admin['id'], usuario);
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
                ),
              ],
            ),
            const Divider(height: 16),
            _buildInfoRow(Icons.location_city, admin['filialNombre'] ?? ''),
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
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
