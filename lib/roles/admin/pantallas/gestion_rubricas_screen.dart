import 'package:flutter/material.dart';
import '/shared/logica/gestion_criterios.dart';
import 'crear_rubrica_screen.dart';
import 'editar_rubrica_screen.dart';

class GestionCriteriosScreen extends StatefulWidget {
  const GestionCriteriosScreen({super.key});

  @override
  State<GestionCriteriosScreen> createState() => _GestionCriteriosScreenState();
}

class _GestionCriteriosScreenState extends State<GestionCriteriosScreen> {
  final RubricasService _service = RubricasService();
  List<Rubrica> _rubricas = [];
  List<Rubrica> _rubricasFiltradas = [];
  bool _isLoading = true;

  String? _filtroFilial;
  String? _filtroFacultad;
  String? _filtroCarrera;

  List<String> _filialesDisponibles = [];
  List<String> _facultadesDisponibles = [];
  List<Map<String, dynamic>> _carrerasDisponibles = [];

  final Map<String, String> _cacheNombresFiliales = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final filiales = await _service.getFiliales();
      final rubricas = await _service.obtenerRubricas();
      setState(() {
        _filialesDisponibles = filiales;
        _rubricas = rubricas;
        _rubricasFiltradas = rubricas;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<String> _getNombreFilialCached(String filialId) async {
    if (_cacheNombresFiliales.containsKey(filialId)) {
      return _cacheNombresFiliales[filialId]!;
    }
    final nombre = await _service.getNombreFilial(filialId);
    _cacheNombresFiliales[filialId] = nombre;
    return nombre;
  }

  Future<void> _onFilialChanged(String? filial) async {
    setState(() {
      _filtroFilial = filial;
      _filtroFacultad = null;
      _filtroCarrera = null;
      _facultadesDisponibles = [];
      _carrerasDisponibles = [];
    });
    if (filial != null) {
      final facultades = await _service.getFacultadesByFilial(filial);
      if (mounted) {
        setState(() {
          _facultadesDisponibles = facultades;
        });
      }
    }
    _aplicarFiltros();
  }

  Future<void> _onFacultadChanged(String? facultad) async {
    setState(() {
      _filtroFacultad = facultad;
      _filtroCarrera = null;
      _carrerasDisponibles = [];
    });
    if (_filtroFilial != null && facultad != null) {
      final carreras = await _service.getCarrerasByFacultad(
        _filtroFilial!,
        facultad,
      );
      if (mounted) {
        setState(() {
          _carrerasDisponibles = carreras;
        });
      }
    }
    _aplicarFiltros();
  }

  void _onCarreraChanged(String? carrera) {
    setState(() {
      _filtroCarrera = carrera;
    });
    _aplicarFiltros();
  }

  void _aplicarFiltros() {
    setState(() {
      _rubricasFiltradas = _service.filtrarRubricas(
        _rubricas,
        filial: _filtroFilial,
        facultad: _filtroFacultad,
        carrera: _filtroCarrera,
      );
    });
  }

  void _limpiarFiltros() {
    setState(() {
      _filtroFilial = null;
      _filtroFacultad = null;
      _filtroCarrera = null;
      _facultadesDisponibles = [];
      _carrerasDisponibles = [];
      _rubricasFiltradas = _rubricas;
    });
  }

  Future<void> _eliminarRubrica(String rubricaId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Está seguro que desea eliminar esta rúbrica?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final success = await _service.eliminarRubrica(rubricaId);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rúbrica eliminada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        _cargarDatos();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar la rúbrica'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navegarACrearRubrica() {
    if (_filtroFilial == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una filial primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_filtroFacultad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una facultad primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CrearRubricaScreen(
          filial: _filtroFilial!,
          facultad: _filtroFacultad!,
          carrera: _filtroCarrera,
        ),
      ),
    ).then((_) => _cargarDatos());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFiltros(),
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
                    : _rubricasFiltradas.isEmpty
                        ? _buildEmptyState()
                        : _buildRubricasList(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navegarACrearRubrica,
        backgroundColor: const Color(0xFF1A5490),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Rúbrica'),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Gestión de Rúbricas',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      color: const Color(0xFF1E3A5F),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDropdownContainer(
            hint: 'Seleccionar Filial',
            value: _filtroFilial,
            items: _filialesDisponibles.map((filialId) {
              return DropdownMenuItem<String>(
                value: filialId,
                child: _FilialDropdownItem(
                  filialId: filialId,
                  service: _service,
                  cache: _cacheNombresFiliales,
                ),
              );
            }).toList(),
            onChanged: _onFilialChanged,
          ),
          if (_filtroFilial != null) ...[
            const SizedBox(height: 8),
            _buildDropdownContainer(
              hint: 'Seleccionar Facultad',
              value: _filtroFacultad,
              items: _facultadesDisponibles.map((facultad) {
                return DropdownMenuItem<String>(
                  value: facultad,
                  child: Text(
                    facultad,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: _onFacultadChanged,
            ),
          ],
          if (_filtroFacultad != null && _carrerasDisponibles.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDropdownContainer(
              hint: 'Seleccionar Carrera (opcional)',
              value: _filtroCarrera,
              items: _carrerasDisponibles.map((carrera) {
                return DropdownMenuItem<String>(
                  value: carrera['nombre'] as String,
                  child: Text(
                    carrera['nombre'] as String,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: _onCarreraChanged,
            ),
          ],
          if (_filtroFilial != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mostrando ${_rubricasFiltradas.length} de ${_rubricas.length} rúbricas',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _limpiarFiltros,
                  icon: const Icon(Icons.clear, size: 16, color: Colors.white),
                  label: const Text(
                    'Limpiar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownContainer({
    required String hint,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint, overflow: TextOverflow.ellipsis),
          value: value,
          items: items,
          onChanged: onChanged,
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
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(20),
              child: const Icon(
                Icons.checklist,
                size: 50,
                color: Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _filtroFilial != null
                  ? 'No hay rúbricas con estos filtros'
                  : 'No hay rúbricas creadas',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _filtroFilial != null
                  ? 'Intenta con otros filtros'
                  : 'Selecciona una filial y facultad para crear tu primera rúbrica',
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRubricasList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: _rubricasFiltradas.length,
      itemBuilder: (context, index) {
        final rubrica = _rubricasFiltradas[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EditarRubricaScreen(rubrica: rubrica),
                ),
              );
              _cargarDatos();
            },
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A5490).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.assignment,
                          color: Color(0xFF1A5490),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rubrica.nombre,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            FutureBuilder<String>(
                              future:
                                  _getNombreFilialCached(rubrica.filial),
                              builder: (context, snapshot) {
                                final nombreFilial =
                                    snapshot.data ?? rubrica.filial;
                                final ubicacion = rubrica.carrera != null
                                    ? '$nombreFilial > ${rubrica.facultad} > ${rubrica.carrera}'
                                    : '$nombreFilial > ${rubrica.facultad}';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    ubicacion,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            ),
                            if (rubrica.descripcion.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  rubrica.descripcion,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _eliminarRubrica(rubrica.id),
                          borderRadius: BorderRadius.circular(22),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        Icons.format_list_numbered,
                        '${rubrica.secciones.length} secc.',
                        Colors.blue,
                      ),
                      _buildInfoChip(
                        Icons.check_circle_outline,
                        '${rubrica.totalCriterios} crit.',
                        Colors.green,
                      ),
                      _buildInfoChip(
                        Icons.people_outline,
                        '${rubrica.juradosAsignados.length} jurados',
                        Colors.orange,
                      ),
                      _buildInfoChip(
                        Icons.stars,
                        '${rubrica.puntajeMaximo.toStringAsFixed(0)} pts',
                        Colors.purple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilialDropdownItem extends StatefulWidget {
  final String filialId;
  final RubricasService service;
  final Map<String, String> cache;

  const _FilialDropdownItem({
    required this.filialId,
    required this.service,
    required this.cache,
  });

  @override
  State<_FilialDropdownItem> createState() => _FilialDropdownItemState();
}

class _FilialDropdownItemState extends State<_FilialDropdownItem> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    if (widget.cache.containsKey(widget.filialId)) {
      _future = Future.value(widget.cache[widget.filialId]);
    } else {
      _future = widget.service.getNombreFilial(widget.filialId).then((nombre) {
        widget.cache[widget.filialId] = nombre;
        return nombre;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _future,
      builder: (context, snapshot) {
        return Text(
          snapshot.data ?? widget.filialId,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        );
      },
    );
  }
}
