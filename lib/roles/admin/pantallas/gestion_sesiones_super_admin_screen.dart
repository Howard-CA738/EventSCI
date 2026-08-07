import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/shared/logica/filiales_service.dart';
import '/shared/logica/gestion_sesiones_service.dart';

class GestionSesionesSuperAdminScreen extends StatefulWidget {
  const GestionSesionesSuperAdminScreen({super.key});

  @override
  State<GestionSesionesSuperAdminScreen> createState() =>
      _GestionSesionesSuperAdminScreenState();
}

class _GestionSesionesSuperAdminScreenState
    extends State<GestionSesionesSuperAdminScreen> {
  static const Color _primaryColor = Color(0xFF1E3A5F);
  static const Color _accentColor = Color(0xFF0EA5E9);

  final FilialesService _filialesService = FilialesService();
  final _service = GestionSesionesService();

  Map<String, dynamic> _estructura = {};
  bool _isLoadingEstructura = true;

  String? _selectedFilial;
  String? _selectedFacultad;
  String? _selectedCarrera;

  List<String> _facultadesDisponibles = [];
  List<Map<String, dynamic>> _carrerasDisponibles = [];

  String _carreraPath = '';
  bool _isLoadingEstudiantes = false;
  bool _yaConsultado = false;
  List<Map<String, dynamic>> _estudiantes = [];
  List<Map<String, dynamic>> _filtrados = [];
  final TextEditingController _searchController = TextEditingController();
  String _filtroEstado = 'todos';

  bool _modoSeleccion = false;
  final Set<String> _seleccionados = {};

  @override
  void initState() {
    super.initState();
    _cargarEstructura();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarEstructura() async {
    setState(() => _isLoadingEstructura = true);
    try {
      await _filialesService.inicializarSiEsNecesario();
      final estructura = await _filialesService.getEstructuraCompleta();
      if (mounted) {
        setState(() {
          _estructura = estructura;
          _isLoadingEstructura = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEstructura = false);
        _showSnack('Error al cargar filiales: $e', Colors.red);
      }
    }
  }

  void _onFilialChanged(String? filial) {
    setState(() {
      _selectedFilial = filial;
      _selectedFacultad = null;
      _selectedCarrera = null;
      _facultadesDisponibles = [];
      _carrerasDisponibles = [];
      _resetEstudiantes();

      if (filial != null && _estructura.containsKey(filial)) {
        final facultades = (_estructura[filial]
            as Map<String, dynamic>?)?['facultades'] as Map<String, dynamic>?;

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
      _carrerasDisponibles = [];
      _resetEstudiantes();

      if (_selectedFilial != null &&
          facultad != null &&
          _estructura.containsKey(_selectedFilial)) {
        final facultades = (_estructura[_selectedFilial!]
            as Map<String, dynamic>?)?['facultades'] as Map<String, dynamic>?;
        if (facultades != null && facultades.containsKey(facultad)) {
          _carrerasDisponibles = List<Map<String, dynamic>>.from(
              (facultades[facultad] as Map<String, dynamic>?)?['carreras'] ??
                  []);
        }
      }
    });
  }

  void _onCarreraChanged(String? carrera) {
    setState(() {
      _selectedCarrera = carrera;
      _resetEstudiantes();
    });
    if (carrera != null) {
      _loadEstudiantes();
    }
  }

  void _resetEstudiantes() {
    _carreraPath = '';
    _yaConsultado = false;
    _estudiantes = [];
    _filtrados = [];
    _seleccionados.clear();
    _modoSeleccion = false;
    _searchController.clear();
    _filtroEstado = 'todos';
  }

  Future<void> _loadEstudiantes() async {
    if (_selectedFilial == null || _selectedCarrera == null) return;

    setState(() {
      _isLoadingEstudiantes = true;
      _yaConsultado = true;
    });

    try {
      final filialNombre = ((_estructura[_selectedFilial]
              as Map<String, dynamic>?)?['nombre'] as String?) ??
          '';

      final carreraPath = await _service.localizarCarreraPath(
        filialNombre: filialNombre,
        carrera: _selectedCarrera!,
      );

      if (carreraPath == null) {
        if (mounted) {
          setState(() {
            _carreraPath = '';
            _estudiantes = [];
            _filtrados = [];
            _isLoadingEstudiantes = false;
          });
        }
        return;
      }

      _carreraPath = carreraPath;

      final lista = await _service.obtenerEstudiantes(_carreraPath);

      if (mounted) {
        setState(() {
          _estudiantes = lista;
          final idsValidos = lista.map((e) => e['docId'].toString()).toSet();
          _seleccionados.removeWhere((id) => !idsValidos.contains(id));
          _isLoadingEstudiantes = false;
          _aplicarFiltro();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEstudiantes = false);
        _showSnack('Error al cargar datos: $e', Colors.red);
      }
    }
  }

  void _aplicarFiltro() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtrados = _estudiantes.where((e) {
        final matchSearch =
            e['nombre'].toString().toLowerCase().contains(query) ||
                e['usuario'].toString().toLowerCase().contains(query);

        bool matchEstado = true;
        if (_filtroEstado == 'bloqueado') {
          matchEstado =
              e['bloqueadoPermanente'] == true || e['sessionActive'] == true;
        } else if (_filtroEstado == 'sin_sesion') {
          matchEstado =
              e['bloqueadoPermanente'] != true && e['sessionActive'] != true;
        }
        return matchSearch && matchEstado;
      }).toList();
    });
  }

  void _toggleModoSeleccion() {
    setState(() {
      _modoSeleccion = !_modoSeleccion;
      _seleccionados.clear();
    });
  }

  void _toggleSeleccion(String docId) {
    setState(() {
      if (_seleccionados.contains(docId)) {
        _seleccionados.remove(docId);
      } else {
        _seleccionados.add(docId);
      }
    });
  }

  bool _todosSeleccionados() {
    if (_filtrados.isEmpty) return false;
    return _filtrados
        .every((e) => _seleccionados.contains(e['docId'].toString()));
  }

  void _toggleSeleccionarTodos() {
    setState(() {
      final idsVisibles = _filtrados.map((e) => e['docId'].toString()).toSet();
      if (_todosSeleccionados()) {
        _seleccionados.removeAll(idsVisibles);
      } else {
        _seleccionados.addAll(idsVisibles);
      }
    });
  }

  Future<void> _desbloquearSeleccionados() async {
    if (_seleccionados.isEmpty) return;
    final count = _seleccionados.length;

    final confirm = await _showConfirmDialog(
      titulo: '¿Desbloquear $count estudiante(s)?',
      mensaje: 'Se reseteará la sesión de $count estudiante(s) seleccionado(s).\n\n'
          'Todos podrán ingresar UNA VEZ más desde cualquier dispositivo.',
      botonConfirmar: 'Sí, desbloquear todos',
      colorBoton: _accentColor,
      icono: Icons.lock_open_rounded,
    );
    if (confirm != true) return;

    setState(() => _isLoadingEstudiantes = true);

    try {
      final seleccionadosList = _estudiantes
          .where((e) => _seleccionados.contains(e['docId'].toString()))
          .toList();

      await _service.desbloquearEstudiantes(
        carreraPath: _carreraPath,
        estudiantes: seleccionadosList,
      );

      if (mounted) {
        setState(() {
          _modoSeleccion = false;
          _seleccionados.clear();
        });
        _showSnack(
            '$count estudiante(s) desbloqueado(s) correctamente.', Colors.green);
        await _loadEstudiantes();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEstudiantes = false);
        _showSnack('Error al desbloquear: $e', Colors.red);
      }
    }
  }

  Future<void> _resetearSesion(Map<String, dynamic> estudiante) async {
    final confirm = await _showConfirmDialog(
      titulo: '¿Dar nueva oportunidad?',
      mensaje: 'Se reseteará la sesión de ${estudiante['nombre']}.\n\n'
          'Podrá ingresar UNA VEZ más desde cualquier dispositivo.',
      botonConfirmar: 'Sí, resetear',
      colorBoton: _accentColor,
      icono: Icons.refresh_rounded,
    );
    if (confirm != true) return;

    try {
      await _service.resetearSesion(
        carreraPath: _carreraPath,
        estudiante: estudiante,
      );

      if (mounted) {
        _showSnack(
            'Sesión reseteada. ${estudiante['nombre']} puede ingresar de nuevo.',
            Colors.green);
        await _loadEstudiantes();
      }
    } catch (e) {
      if (mounted) _showSnack('Error al resetear: $e', Colors.red);
    }
  }

  Future<void> _bloquearSesion(Map<String, dynamic> estudiante) async {
    final confirm = await _showConfirmDialog(
      titulo: '¿Bloquear acceso?',
      mensaje: 'Se bloqueará el acceso de ${estudiante['nombre']}.\n\n'
          'No podrá iniciar sesión hasta que lo resetees manualmente.',
      botonConfirmar: 'Sí, bloquear',
      colorBoton: Colors.red,
      icono: Icons.block_rounded,
    );
    if (confirm != true) return;

    try {
      await _service.bloquearSesion(
        carreraPath: _carreraPath,
        studentId: estudiante['docId'] as String,
      );

      if (mounted) {
        _showSnack('${estudiante['nombre']} ha sido bloqueado.', Colors.orange);
        await _loadEstudiantes();
      }
    } catch (e) {
      if (mounted) _showSnack('Error al bloquear: $e', Colors.red);
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
                  color: colorBoton.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: colorBoton, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                titulo,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                mensaje,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF64748B), height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 48),
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
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        botonConfirmar,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
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
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  _EstadoSesion _getEstado(Map<String, dynamic> e) {
    final bloqueadoPermanente = e['bloqueadoPermanente'] == true;
    final active = e['sessionActive'] == true;
    final primeraVez = e['primeraVez'] != false;

    if (bloqueadoPermanente) return _EstadoSesion.bloqueado;
    if (active) return _EstadoSesion.bloqueado;
    if (primeraVez) return _EstadoSesion.sinSesion;
    return _EstadoSesion.reseteado;
  }

  @override
  Widget build(BuildContext context) {
    final bool carreraElegida = _selectedCarrera != null;

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
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _modoSeleccion ? 'Seleccionar estudiantes' : 'Sesiones (Global)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (carreraElegida && !_isLoadingEstudiantes) ...[
            IconButton(
              icon: Icon(
                  _modoSeleccion ? Icons.close_rounded : Icons.checklist_rtl_rounded),
              onPressed: _toggleModoSeleccion,
              tooltip: _modoSeleccion ? 'Cancelar selección' : 'Seleccionar varios',
            ),
            if (!_modoSeleccion)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loadEstudiantes,
                tooltip: 'Actualizar',
              ),
          ],
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isLoadingEstructura
            ? const Center(child: CircularProgressIndicator(color: _primaryColor))
            : Column(
                children: [
                  _buildSelectores(),
                  if (carreraElegida)
                    _buildHeaderEstudiantes(
                      totalSinSesion: totalSinSesion,
                      totalBloqueados: totalBloqueados,
                      totalReseteados: totalReseteados,
                    ),
                  Expanded(child: _buildBodyEstudiantes()),
                  if (_modoSeleccion && _seleccionados.isNotEmpty)
                    _buildBottomActionBar(),
                ],
              ),
      ),
    );
  }

  Widget _buildSelectores() {
    return Container(
      color: _primaryColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          _buildDropdown<String>(
            label: 'Filial (Sede)',
            icon: Icons.location_city,
            value: _selectedFilial,
            items: _estructura.keys.map((filialId) {
              final nombre = ((_estructura[filialId]
                      as Map<String, dynamic>?)?['nombre'] as String?) ??
                  filialId;
              return DropdownMenuItem<String>(
                value: filialId,
                child: Text(nombre, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: _onFilialChanged,
          ),
          if (_selectedFilial != null) ...[
            const SizedBox(height: 10),
            _buildDropdown<String>(
              label: 'Facultad',
              icon: Icons.business,
              value: _selectedFacultad,
              items: _facultadesDisponibles
                  .map((f) => DropdownMenuItem<String>(
                        value: f,
                        child: Text(f, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _onFacultadChanged,
            ),
          ],
          if (_selectedFacultad != null) ...[
            const SizedBox(height: 10),
            _buildDropdown<String>(
              label: 'Carrera',
              icon: Icons.school,
              value: _selectedCarrera,
              items: _carrerasDisponibles
                  .map((c) => DropdownMenuItem<String>(
                        value: c['nombre'] as String,
                        child: Text(c['nombre'] as String,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _onCarreraChanged,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _primaryColor),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildHeaderEstudiantes({
    required int totalSinSesion,
    required int totalBloqueados,
    required int totalReseteados,
  }) {
    if (_isLoadingEstudiantes) return const SizedBox.shrink();

    return Container(
      color: _primaryColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _aplicarFiltro(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar estudiante...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: _primaryColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchController.clear();
                          _aplicarFiltro();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatChip('${_estudiantes.length}', 'Total', Colors.white70),
              const SizedBox(width: 8),
              _buildStatChip(
                  '$totalSinSesion', 'Sin sesión', Colors.green.shade300),
              const SizedBox(width: 8),
              _buildStatChip(
                  '$totalBloqueados', 'Bloqueados', Colors.red.shade300),
              const SizedBox(width: 8),
              _buildStatChip(
                  '$totalReseteados', 'Reseteados', Colors.blue.shade300),
            ],
          ),
          const SizedBox(height: 14),
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
          if (_modoSeleccion) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                GestureDetector(
                  onTap: _toggleSeleccionarTodos,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(38),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withAlpha(76)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _todosSeleccionados()
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _todosSeleccionados() ? 'Quitar todos' : 'Marcar todos',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_seleccionados.length} seleccionado(s)',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBodyEstudiantes() {
    if (_selectedCarrera == null) {
      return _buildPrompt(
        icon: Icons.touch_app_outlined,
        titulo: 'Selecciona una carrera',
        subtitulo:
            'Elige filial, facultad y carrera para ver las sesiones de sus estudiantes.',
      );
    }
    if (_isLoadingEstudiantes) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryColor),
      );
    }
    if (_estudiantes.isEmpty) {
      return _buildPrompt(
        icon: Icons.person_off_outlined,
        titulo: 'Sin estudiantes',
        subtitulo: _yaConsultado
            ? 'No se encontraron estudiantes registrados para esta carrera.'
            : 'Selecciona una carrera para comenzar.',
      );
    }
    if (_filtrados.isEmpty) {
      return _buildPrompt(
        icon: Icons.search_off_rounded,
        titulo: 'Sin resultados',
        subtitulo: 'Ajusta los filtros o la búsqueda.',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      itemCount: _filtrados.length,
      itemBuilder: (ctx, i) => _buildEstudianteCard(_filtrados[i]),
    );
  }

  Widget _buildPrompt({
    required IconData icon,
    required String titulo,
    required String subtitulo,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitulo,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withAlpha(51)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                count,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _filtroEstado == value;
    return Semantics(
      label: 'Filtrar por $label',
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          setState(() => _filtroEstado = value);
          _aplicarFiltro();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white.withAlpha(38),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? Colors.white : Colors.white.withAlpha(76)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _primaryColor : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _desbloquearSeleccionados,
          icon: const Icon(Icons.lock_open_rounded),
          label: Text(
            'Desbloquear ${_seleccionados.length} seleccionado(s)',
            overflow: TextOverflow.ellipsis,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildEstudianteCard(Map<String, dynamic> e) {
    final estado = _getEstado(e);
    final lastLogin = e['lastLogin'] as Timestamp?;
    final bloqueadoEn = e['bloqueadoEn'] as Timestamp?;
    final docId = e['docId'].toString();
    final seleccionado = _seleccionados.contains(docId);

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

    return GestureDetector(
      onTap: _modoSeleccion ? () => _toggleSeleccion(docId) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: _modoSeleccion && seleccionado
              ? Border.all(color: _accentColor, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_modoSeleccion) ...[
                Icon(
                  seleccionado
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: seleccionado ? _accentColor : Colors.grey[400],
                  size: 26,
                ),
                const SizedBox(width: 12),
              ],
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: estadoColor.withAlpha(30),
                  shape: BoxShape.circle,
                  border: Border.all(color: estadoColor.withAlpha(102), width: 1.5),
                ),
                child: Icon(Icons.person, color: estadoColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e['nombre'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      e['usuario'],
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lastLogin != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Último ingreso: ${_formatDate(lastLogin.toDate())}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (bloqueadoEn != null &&
                        estado == _EstadoSesion.bloqueado) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Bloqueado: ${_formatDate(bloqueadoEn.toDate())}',
                        style: TextStyle(fontSize: 11, color: Colors.red[300]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: estadoColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: estadoColor.withAlpha(76)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(estadoIcon, size: 12, color: estadoColor),
                        const SizedBox(width: 4),
                        Text(
                          estadoLabel,
                          style: TextStyle(
                              fontSize: 11,
                              color: estadoColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  if (!_modoSeleccion) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionBtn(
                          icon: Icons.refresh_rounded,
                          color: _accentColor,
                          tooltip: 'Dar nueva oportunidad',
                          onTap: () => _resetearSesion(e),
                        ),
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
                ],
              ),
            ],
          ),
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
    return Semantics(
      label: tooltip,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withAlpha(76)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

enum _EstadoSesion { sinSesion, bloqueado, reseteado }
