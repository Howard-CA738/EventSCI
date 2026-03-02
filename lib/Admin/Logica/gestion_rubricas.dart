// gestion_rubricas.dart
// Pantallas UI actualizadas para usar sistema de filiales

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gestion_criterios.dart';
import 'filiales_service.dart';

// ============================================================================
// PANTALLA PRINCIPAL - CON FILTROS DE FILIAL
// ============================================================================

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

  // ✅ NUEVO: Variables de filtros con filiales
  String? _filtroFilial;
  String? _filtroFacultad;
  String? _filtroCarrera;

  // ✅ NUEVO: Listas dinámicas
  List<String> _filialesDisponibles = [];
  List<String> _facultadesDisponibles = [];
  List<Map<String, dynamic>> _carrerasDisponibles = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

    try {
      // Cargar filiales y rúbricas
      final filiales = await _service.getFiliales();
      final rubricas = await _service.obtenerRubricas();

      setState(() {
        _filialesDisponibles = filiales;
        _rubricas = rubricas;
        _rubricasFiltradas = rubricas;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error cargando datos: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ NUEVO: Cuando cambia la filial
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
      setState(() {
        _facultadesDisponibles = facultades;
      });
    }

    _aplicarFiltros();
  }

  // ✅ NUEVO: Cuando cambia la facultad
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
      setState(() {
        _carrerasDisponibles = carreras;
      });
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
    // Validar que se haya seleccionado filial y facultad
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
        children: [
          // ✅ Filial
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Seleccionar Filial'),
                value: _filtroFilial,
                items: _filialesDisponibles.map((filialId) {
                  return DropdownMenuItem(
                    value: filialId,
                    child: FutureBuilder<String>(
                      future: _service.getNombreFilial(filialId),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? filialId,
                          style: const TextStyle(fontSize: 14),
                        );
                      },
                    ),
                  );
                }).toList(),
                onChanged: _onFilialChanged,
              ),
            ),
          ),

          // ✅ Facultad
          if (_filtroFilial != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Seleccionar Facultad'),
                  value: _filtroFacultad,
                  items: _facultadesDisponibles.map((facultad) {
                    return DropdownMenuItem(
                      value: facultad,
                      child: Text(
                        facultad,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _onFacultadChanged,
                ),
              ),
            ),

          // ✅ Carrera
          if (_filtroFacultad != null && _carrerasDisponibles.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Seleccionar Carrera (opcional)'),
                  value: _filtroCarrera,
                  items: _carrerasDisponibles.map((carrera) {
                    return DropdownMenuItem(
                      value: carrera['nombre'] as String,
                      child: Text(
                        carrera['nombre'] as String,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _onCarreraChanged,
                ),
              ),
            ),

          // Info y limpiar
          if (_filtroFilial != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
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
                    icon: const Icon(
                      Icons.clear,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Limpiar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
    );
  }

  Widget _buildRubricasList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
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
                  builder: (context) => EditarRubricaScreen(rubrica: rubrica),
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
                          color: const Color(0xFF1A5490).withOpacity(0.1),
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
                            // ✅ Mostrar filial, facultad y carrera
                            FutureBuilder<String>(
                              future: _service.getNombreFilial(rubrica.filial),
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
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _eliminarRubrica(rubrica.id),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PANTALLA CREAR RÚBRICA - RECIBE FILIAL, FACULTAD, CARRERA
// ============================================================================

class CrearRubricaScreen extends StatefulWidget {
  final String filial;
  final String facultad;
  final String? carrera;

  const CrearRubricaScreen({
    super.key,
    required this.filial,
    required this.facultad,
    this.carrera,
  });

  @override
  State<CrearRubricaScreen> createState() => _CrearRubricaScreenState();
}

class _CrearRubricaScreenState extends State<CrearRubricaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _puntajeMaximoController = TextEditingController(text: '20');
  final RubricasService _service = RubricasService();

  List<SeccionRubrica> _secciones = [];
  List<Map<String, dynamic>> _juradosDisponibles = [];
  List<String> _juradosSeleccionados = [];
  bool _isLoading = false;
  String _nombreFilial = '';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    _nombreFilial = await _service.getNombreFilial(widget.filial);
    _cargarJurados();
  }

  Future<void> _cargarJurados() async {
    final jurados = await _service.obtenerJurados(
      filial: widget.filial,
      facultad: widget.facultad,
      carrera: widget.carrera,
    );
    setState(() => _juradosDisponibles = jurados);
  }

  void _agregarSeccion() {
    setState(() {
      _secciones.add(
        SeccionRubrica(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          nombre: 'Nueva Sección',
          criterios: [],
          pesoTotal: 10,
        ),
      );
    });
  }

  Future<void> _guardarRubrica() async {
    if (!_formKey.currentState!.validate()) return;

    if (_secciones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe agregar al menos una sección'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final rubrica = Rubrica(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: _nombreController.text.trim(),
      descripcion: _descripcionController.text.trim(),
      secciones: _secciones,
      juradosAsignados: _juradosSeleccionados,
      fechaCreacion: DateTime.now(),
      puntajeMaximo: double.tryParse(_puntajeMaximoController.text) ?? 20,
      filial: widget.filial,
      facultad: widget.facultad,
      carrera: widget.carrera,
    );

    final success = await _service.crearRubrica(rubrica);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rúbrica creada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al guardar la rúbrica'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildUbicacionInfo(),
                        const SizedBox(height: 20),
                        _buildInfoBasica(),
                        const SizedBox(height: 20),
                        _buildSeccionSecciones(),
                        const SizedBox(height: 20),
                        _buildSeccionJurados(),
                        const SizedBox(height: 30),
                        _buildBotonGuardar(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Crear Rúbrica',
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

  Widget _buildUbicacionInfo() {
    return Card(
      elevation: 2,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Ubicación de la Rúbrica',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_city, 'Filial', _nombreFilial),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.school, 'Facultad', widget.facultad),
            if (widget.carrera != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.menu_book, 'Carrera', widget.carrera!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade900,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBasica() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información Básica',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombreController,
              decoration: InputDecoration(
                labelText: 'Nombre de la Rúbrica',
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.all(12),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcionController,
              decoration: InputDecoration(
                labelText: 'Descripción (opcional)',
                prefixIcon: const Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _puntajeMaximoController,
              decoration: InputDecoration(
                labelText: 'Puntaje Máximo',
                prefixIcon: const Icon(Icons.stars),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.all(12),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => v?.isEmpty ?? true ? 'Campo requerido' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionSecciones() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Secciones y Criterios',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _agregarSeccion,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A5490),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._secciones.asMap().entries.map((entry) {
              return _SeccionWidget(
                key: ValueKey(entry.value.id),
                seccion: entry.value,
                onEliminar: () {
                  setState(() => _secciones.removeAt(entry.key));
                },
                onActualizar: () => setState(() {}),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionJurados() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Asignar Jurados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${_juradosSeleccionados.length} seleccionados',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _cargarJurados,
                      tooltip: 'Recargar jurados',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_juradosDisponibles.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: Colors.orange.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No hay jurados disponibles',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No hay jurados para $_nombreFilial - ${widget.facultad}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._juradosDisponibles.map((jurado) {
                final isSelected = _juradosSeleccionados.contains(jurado['id']);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected ? Colors.green.shade50 : Colors.white,
                  child: CheckboxListTile(
                    title: Text(
                      jurado['nombre'],
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      '${jurado['carrera']}\n${jurado['facultad']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    secondary: CircleAvatar(
                      backgroundColor: isSelected ? Colors.green : Colors.grey,
                      child: Text(
                        jurado['nombre'].toString().isNotEmpty
                            ? jurado['nombre']
                                  .toString()
                                  .substring(0, 1)
                                  .toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    value: isSelected,
                    activeColor: Colors.green,
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _juradosSeleccionados.add(jurado['id']);
                        } else {
                          _juradosSeleccionados.remove(jurado['id']);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonGuardar() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _guardarRubrica,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A5490),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 4,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : const Text(
              'Guardar Rúbrica',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _puntajeMaximoController.dispose();
    super.dispose();
  }
}

// ============================================================================
// WIDGETS REUTILIZABLES (igual que antes)
// ============================================================================

class _SeccionWidget extends StatefulWidget {
  final SeccionRubrica seccion;
  final VoidCallback onEliminar;
  final VoidCallback onActualizar;

  const _SeccionWidget({
    super.key,
    required this.seccion,
    required this.onEliminar,
    required this.onActualizar,
  });

  @override
  State<_SeccionWidget> createState() => _SeccionWidgetState();
}

class _SeccionWidgetState extends State<_SeccionWidget> {
  void _agregarCriterio() {
    widget.seccion.criterios.add(
      Criterio(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        descripcion: 'Nuevo criterio',
        peso: 2.5,
      ),
    );
    widget.onActualizar();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.blue.shade50,
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.all(12),
        title: Text(
          widget.seccion.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Text(
          '${widget.seccion.criterios.length} criterios - ${widget.seccion.pesoTotal} pts',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: SizedBox(
          width: 40,
          child: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: widget.onEliminar,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
        children: [
          Column(
            children: [
              TextFormField(
                initialValue: widget.seccion.nombre,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la sección',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.all(12),
                ),
                onChanged: (v) {
                  widget.seccion.nombre = v;
                  widget.onActualizar();
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: widget.seccion.pesoTotal.toString(),
                decoration: const InputDecoration(
                  labelText: 'Peso Total (pts)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.all(12),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (v) {
                  widget.seccion.pesoTotal = double.tryParse(v) ?? 10;
                  widget.onActualizar();
                },
              ),
              const SizedBox(height: 12),
              ...widget.seccion.criterios.asMap().entries.map((e) {
                return _CriterioWidget(
                  key: ValueKey(e.value.id),
                  criterio: e.value,
                  onEliminar: () {
                    widget.seccion.criterios.removeAt(e.key);
                    widget.onActualizar();
                  },
                  onActualizar: widget.onActualizar,
                );
              }).toList(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _agregarCriterio,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar Criterio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CriterioWidget extends StatelessWidget {
  final Criterio criterio;
  final VoidCallback onEliminar;
  final VoidCallback onActualizar;

  const _CriterioWidget({
    super.key,
    required this.criterio,
    required this.onEliminar,
    required this.onActualizar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextFormField(
              initialValue: criterio.descripcion,
              decoration: const InputDecoration(
                labelText: 'Criterio de Evaluación',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.all(12),
              ),
              maxLines: 2,
              onChanged: (v) {
                criterio.descripcion = v;
                onActualizar();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: criterio.peso.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Peso (pts)',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.all(12),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) {
                      criterio.peso = double.tryParse(v) ?? 0;
                      onActualizar();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: onEliminar,
                    tooltip: 'Eliminar',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PANTALLA EDITAR RÚBRICA (Similar a CrearRubricaScreen)
// ============================================================================

class EditarRubricaScreen extends StatefulWidget {
  final Rubrica rubrica;

  const EditarRubricaScreen({super.key, required this.rubrica});

  @override
  State<EditarRubricaScreen> createState() => _EditarRubricaScreenState();
}

class _EditarRubricaScreenState extends State<EditarRubricaScreen> {
  late final _formKey = GlobalKey<FormState>();
  late final _nombreController = TextEditingController(
    text: widget.rubrica.nombre,
  );
  late final _descripcionController = TextEditingController(
    text: widget.rubrica.descripcion,
  );
  late final _puntajeMaximoController = TextEditingController(
    text: widget.rubrica.puntajeMaximo.toString(),
  );
  final RubricasService _service = RubricasService();

  late List<SeccionRubrica> _secciones;
  List<Map<String, dynamic>> _juradosDisponibles = [];
  late List<String> _juradosSeleccionados;
  bool _isLoading = false;
  String _nombreFilial = '';

  @override
  void initState() {
    super.initState();
    _secciones = widget.rubrica.secciones.map((s) => s.copyWith()).toList();
    _juradosSeleccionados = List.from(widget.rubrica.juradosAsignados);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    _nombreFilial = await _service.getNombreFilial(widget.rubrica.filial);
    _cargarJurados();
  }

  Future<void> _cargarJurados() async {
    final jurados = await _service.obtenerJurados(
      filial: widget.rubrica.filial,
      facultad: widget.rubrica.facultad,
      carrera: widget.rubrica.carrera,
    );
    setState(() => _juradosDisponibles = jurados);
  }

  void _agregarSeccion() {
    setState(() {
      _secciones.add(
        SeccionRubrica(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          nombre: 'Nueva Sección',
          criterios: [],
          pesoTotal: 10,
        ),
      );
    });
  }

  Future<void> _actualizarRubrica() async {
    if (!_formKey.currentState!.validate()) return;

    if (_secciones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe agregar al menos una sección'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final rubricaActualizada = Rubrica(
      id: widget.rubrica.id,
      nombre: _nombreController.text.trim(),
      descripcion: _descripcionController.text.trim(),
      secciones: _secciones,
      juradosAsignados: _juradosSeleccionados,
      fechaCreacion: widget.rubrica.fechaCreacion,
      puntajeMaximo: double.tryParse(_puntajeMaximoController.text) ?? 20,
      filial: widget.rubrica.filial,
      facultad: widget.rubrica.facultad,
      carrera: widget.rubrica.carrera,
    );

    final juradosRemovidos = widget.rubrica.juradosAsignados
        .where((id) => !_juradosSeleccionados.contains(id))
        .toList();

    if (juradosRemovidos.isNotEmpty) {
      await _service.eliminarEvaluacionesDeJurados(
        rubricaId: widget.rubrica.id,
        juradosIds: juradosRemovidos,
      );
    }

    final success = await _service.actualizarRubrica(rubricaActualizada);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            juradosRemovidos.isNotEmpty
                ? 'Rúbrica actualizada y ${juradosRemovidos.length} evaluación(es) eliminada(s)'
                : 'Rúbrica actualizada exitosamente',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al actualizar la rúbrica'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildUbicacionInfo(),
                        const SizedBox(height: 20),
                        _buildInfoBasica(),
                        const SizedBox(height: 20),
                        _buildSeccionSecciones(),
                        const SizedBox(height: 20),
                        _buildSeccionJurados(),
                        const SizedBox(height: 30),
                        _buildBotonGuardar(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Editar Rúbrica',
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

  Widget _buildUbicacionInfo() {
    return Card(
      elevation: 2,
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text(
                  'Ubicación (No editable)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.location_city,
              'Filial',
              _nombreFilial,
              Colors.amber,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.school,
              'Facultad',
              widget.rubrica.facultad,
              Colors.amber,
            ),
            if (widget.rubrica.carrera != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.menu_book,
                'Carrera',
                widget.rubrica.carrera!,
                Colors.amber,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    MaterialColor color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color.shade700),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color.shade900,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: color.shade800),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBasica() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información Básica',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombreController,
              decoration: InputDecoration(
                labelText: 'Nombre de la Rúbrica',
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.all(12),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcionController,
              decoration: InputDecoration(
                labelText: 'Descripción (opcional)',
                prefixIcon: const Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _puntajeMaximoController,
              decoration: InputDecoration(
                labelText: 'Puntaje Máximo',
                prefixIcon: const Icon(Icons.stars),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.all(12),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => v?.isEmpty ?? true ? 'Campo requerido' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionSecciones() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Secciones y Criterios',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _agregarSeccion,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A5490),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._secciones.asMap().entries.map((entry) {
              return _SeccionWidget(
                key: ValueKey(entry.value.id),
                seccion: entry.value,
                onEliminar: () {
                  setState(() => _secciones.removeAt(entry.key));
                },
                onActualizar: () => setState(() {}),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionJurados() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Asignar Jurados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 12),
            if (_juradosDisponibles.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: Colors.orange.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No hay jurados disponibles',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._juradosDisponibles.map((jurado) {
                final isSelected = _juradosSeleccionados.contains(jurado['id']);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected ? Colors.green.shade50 : Colors.white,
                  child: CheckboxListTile(
                    title: Text(
                      jurado['nombre'],
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      '${jurado['carrera']}\n${jurado['facultad']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    secondary: CircleAvatar(
                      backgroundColor: isSelected ? Colors.green : Colors.grey,
                      child: Text(
                        jurado['nombre'].toString().isNotEmpty
                            ? jurado['nombre']
                                  .toString()
                                  .substring(0, 1)
                                  .toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    value: isSelected,
                    activeColor: Colors.green,
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _juradosSeleccionados.add(jurado['id']);
                        } else {
                          _juradosSeleccionados.remove(jurado['id']);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonGuardar() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _actualizarRubrica,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A5490),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 4,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : const Text(
              'Actualizar Rúbrica',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _puntajeMaximoController.dispose();
    super.dispose();
  }
}
