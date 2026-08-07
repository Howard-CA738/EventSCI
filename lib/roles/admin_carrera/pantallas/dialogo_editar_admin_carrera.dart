import 'package:flutter/material.dart';
import '/shared/logica/filiales_service.dart';
import '../logica/admin_carrera_service.dart';
import '../logica/estructura_filiales_helper.dart';

class DialogoEditarAdminCarrera extends StatefulWidget {
  final Map<String, dynamic> admin;
  final Map<String, dynamic> estructuraFiliales;
  final VoidCallback onSuccess;

  const DialogoEditarAdminCarrera({
    super.key,
    required this.admin,
    required this.estructuraFiliales,
    required this.onSuccess,
  });

  @override
  State<DialogoEditarAdminCarrera> createState() =>
      _DialogoEditarAdminCarreraState();
}

class _DialogoEditarAdminCarreraState
    extends State<DialogoEditarAdminCarrera> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usuarioController;
  final TextEditingController _passwordController = TextEditingController();
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

    _facultadesDisponibles =
        facultadesDisponibles(widget.estructuraFiliales, _selectedFilial);
    _carrerasDisponibles = carrerasDisponibles(
        widget.estructuraFiliales, _selectedFilial, _selectedFacultad);
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
      _facultadesDisponibles =
          facultadesDisponibles(widget.estructuraFiliales, filial);
      _carrerasDisponibles = [];
    });
  }

  void _onFacultadChanged(String? facultad) {
    setState(() {
      _selectedFacultad = facultad;
      _selectedCarrera = null;
      _selectedCarreraId = null;
      _carrerasDisponibles = carrerasDisponibles(
          widget.estructuraFiliales, _selectedFilial, facultad);
    });
  }

  void _onCarreraChanged(String? nombreCarrera) {
    if (nombreCarrera == null) return;
    final carreraData = _carrerasDisponibles.firstWhere(
      (c) => c['nombre'] == nombreCarrera,
      orElse: () => {},
    );
    setState(() {
      _selectedCarrera = nombreCarrera;
      _selectedCarreraId =
          carreraData.isNotEmpty ? carreraData['id'] as String? : null;
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
          content: Text('Por favor selecciona filial, facultad y carrera'),
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
        filialNombre: _filialesService.getNombreFilial(_selectedFilial!),
        facultad: _selectedFacultad,
        carrera: _selectedCarrera,
        carreraId: _selectedCarreraId,
        activo: _activo,
      );

      if (success) {
        if (mounted) Navigator.pop(context);
        widget.onSuccess();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ya existe otro admin con ese usuario'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height
        - mediaQuery.viewInsets.bottom
        - mediaQuery.padding.top
        - mediaQuery.padding.bottom
        - 48;
    final maxDialogHeight = availableHeight.clamp(380.0, 640.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: maxDialogHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
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
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _activo
                                  ? Colors.green.withValues(alpha: 0.08)
                                  : Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _activo
                                    ? Colors.green.withValues(alpha: 0.3)
                                    : Colors.red.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _activo
                                      ? Icons.check_circle
                                      : Icons.block,
                                  color:
                                      _activo ? Colors.green : Colors.red,
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
                                Semantics(
                                  label: _activo
                                      ? 'Desactivar cuenta'
                                      : 'Activar cuenta',
                                  child: Switch(
                                    value: _activo,
                                    onChanged: (v) =>
                                        setState(() => _activo = v),
                                    activeThumbColor: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _usuarioController,
                            textInputAction: TextInputAction.next,
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
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
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
                                tooltip: _obscurePassword
                                    ? 'Mostrar contraseña'
                                    : 'Ocultar contraseña',
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
                          DropdownButtonFormField<String>(
                            initialValue: _selectedFilial,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Filial (Sede)',
                              prefixIcon:
                                  const Icon(Icons.location_city),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            items: widget.estructuraFiliales.keys
                                .map((filial) {
                              return DropdownMenuItem<String>(
                                value: filial,
                                child: Text(
                                  _filialesService
                                      .getNombreFilial(filial),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: _onFilialChanged,
                            validator: (v) =>
                                v == null ? 'Requerido' : null,
                          ),
                          if (_selectedFilial != null) ...[
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedFacultad,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Facultad',
                                prefixIcon: const Icon(Icons.business),
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              items: _facultadesDisponibles.map((f) {
                                return DropdownMenuItem<String>(
                                  value: f,
                                  child: Text(
                                    f,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: _onFacultadChanged,
                              validator: (v) =>
                                  v == null ? 'Requerido' : null,
                            ),
                          ],
                          if (_selectedFacultad != null) ...[
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCarrera,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Carrera',
                                prefixIcon: const Icon(Icons.school),
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              items: _carrerasDisponibles.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c['nombre'] as String,
                                  child: Text(
                                    c['nombre'] as String,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: _onCarreraChanged,
                              validator: (v) =>
                                  v == null ? 'Requerido' : null,
                            ),
                          ],
                          const SizedBox(height: 8),
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
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
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
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2),
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
        ),
    );
  }
}
