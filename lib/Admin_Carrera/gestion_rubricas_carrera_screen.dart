import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/prefs_helper.dart';
import '/admin/logica/gestion_criterios.dart';
import 'package:flutter/foundation.dart';

class GestionRubricasCarreraScreen extends StatefulWidget {
  const GestionRubricasCarreraScreen({super.key});

  @override
  State<GestionRubricasCarreraScreen> createState() =>
      _GestionRubricasCarreraScreenState();
}

class _GestionRubricasCarreraScreenState
    extends State<GestionRubricasCarreraScreen> {
  final RubricasService _service = RubricasService();

  String? _filialId;
  String? _filialNombre;
  String? _facultad;
  String? _carreraId;
  String? _carreraNombre;

  List<Rubrica> _rubricas = [];
  bool _isLoadingSession = true;
  bool _isLoadingRubricas = false;

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
        // FIX C2 (aplicado por consistencia con gestion_jurados_carrera):
        // _carreraId y _carreraNombre se asignan por separado.
        _carreraId = adminData['carreraId']; // puede ser null
        _carreraNombre = adminData['carrera'];
      }
    } catch (e) {
      debugPrint('Error cargando sesión: $e');
    } finally {
      setState(() => _isLoadingSession = false);
    }
    await _cargarRubricas();
  }

  Future<void> _cargarRubricas() async {
    if (_filialId == null) return;
    setState(() => _isLoadingRubricas = true);
    try {
      final todas = await _service.obtenerRubricas();

      final filtradas = todas.where((r) {
        if (r.filial != _filialId) return false;
        if (r.facultad.trim().toLowerCase() !=
            (_facultad ?? '').trim().toLowerCase()) return false;
        if (_carreraNombre != null && _carreraNombre!.isNotEmpty) {
          if (r.carrera == null || r.carrera!.trim().isEmpty) return false;
          return r.carrera!.trim().toLowerCase() ==
              _carreraNombre!.trim().toLowerCase();
        }
        return true;
      }).toList();

      if (mounted) setState(() => _rubricas = filtradas);
    } catch (e) {
      debugPrint('Error cargando rúbricas: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRubricas = false);
    }
  }

  Future<void> _eliminarRubrica(String rubricaId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Eliminar esta rúbrica?'),
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

    if (confirmar == true) {
      final ok = await _service.eliminarRubrica(rubricaId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Rúbrica eliminada' : 'Error al eliminar'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) _cargarRubricas();
    }
  }

  void _navegarACrearRubrica() {
    if (_filialId == null || _facultad == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CrearRubricaCarreraScreen(
          filial: _filialId!,
          filialNombre: _filialNombre ?? _filialId!,
          facultad: _facultad!,
          carrera: _carreraNombre,
        ),
      ),
    ).then((_) => _cargarRubricas());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF2),
      appBar: AppBar(
        title: const Text('Gestión de Rúbricas',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarRubricas,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoadingSession ? null : _navegarACrearRubrica,
        backgroundColor: const Color(0xFF1E3A5F),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Rúbrica'),
      ),
      body: _isLoadingSession
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E3A5F)))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _buildContextCard(),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoadingRubricas
                      ? const Center(child: CircularProgressIndicator())
                      : _rubricas.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 0, 20, 80),
                              itemCount: _rubricas.length,
                              itemBuilder: (context, index) =>
                                  _buildRubricaCard(_rubricas[index]),
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
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 22),
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
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    Text(_filialNombre ?? '—',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30),
            ),
            child: Text(
              '${_rubricas.length} rúbrica(s)',
              style:
                  const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRubricaCard(Rubrica rubrica) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditarRubricaCarreraScreen(
                rubrica: rubrica,
                filialNombre: _filialNombre ?? rubrica.filial,
              ),
            ),
          );
          _cargarRubricas();
        },
        borderRadius: BorderRadius.circular(16),
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
                      color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment,
                        color: Color(0xFF1E3A5F), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rubrica.nombre,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A5F)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (rubrica.descripcion.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              rubrica.descripcion,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red),
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
                  _infoChip(Icons.format_list_numbered,
                      '${rubrica.secciones.length} secc.', Colors.blue),
                  _infoChip(Icons.check_circle_outline,
                      '${rubrica.totalCriterios} crit.', Colors.green),
                  _infoChip(Icons.people_outline,
                      '${rubrica.juradosAsignados.length} jurados',
                      Colors.orange),
                  _infoChip(Icons.stars,
                      '${rubrica.puntajeMaximo.toStringAsFixed(rubrica.puntajeMaximo.truncateToDouble() == rubrica.puntajeMaximo ? 0 : 1)} pts',
                      Colors.purple),
                ],
              ),
            ],
          ),
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
            child: const Icon(Icons.checklist,
                size: 56, color: Color(0xFF1E3A5F)),
          ),
          const SizedBox(height: 20),
          const Text('No hay rúbricas',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F))),
          const SizedBox(height: 8),
          Text('Crea la primera rúbrica para esta carrera',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ============================================================================
// CREAR RÚBRICA (versión Admin Carrera)
// ============================================================================

class CrearRubricaCarreraScreen extends StatefulWidget {
  final String filial;
  final String filialNombre;
  final String facultad;
  final String? carrera;

  const CrearRubricaCarreraScreen({
    super.key,
    required this.filial,
    required this.filialNombre,
    required this.facultad,
    this.carrera,
  });

  @override
  State<CrearRubricaCarreraScreen> createState() =>
      _CrearRubricaCarreraScreenState();
}

class _CrearRubricaCarreraScreenState
    extends State<CrearRubricaCarreraScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  // FIX M7: valor inicial sigue siendo entero para compatibilidad,
  // pero el campo ahora acepta decimales.
  final _puntajeMaximoController = TextEditingController(text: '20');
  final RubricasService _service = RubricasService();

  List<SeccionRubrica> _secciones = [];
  List<Map<String, dynamic>> _juradosDisponibles = [];
  List<String> _juradosSeleccionados = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarJurados();
  }

  Future<void> _cargarJurados() async {
    final jurados = await _service.obtenerJurados(
      filial: widget.filial,
      facultad: widget.facultad,
      carrera: widget.carrera,
    );
    if (mounted) setState(() => _juradosDisponibles = jurados);
  }

  void _agregarSeccion() {
    setState(() {
      _secciones.add(SeccionRubrica(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nombre: 'Nueva Sección',
        criterios: [],
        pesoTotal: 10,
      ));
    });
  }

  // FIX M8: validar que la suma de pesoTotal de secciones no supere
  // el puntajeMaximo antes de guardar.
  String? _validarPesosSecciones() {
    final puntajeMaximo =
        double.tryParse(_puntajeMaximoController.text) ?? 20.0;
    final sumaSeciones =
        _secciones.fold<double>(0.0, (s, sec) => s + sec.pesoTotal);

    if (sumaSeciones > puntajeMaximo + 0.01) {
      return 'La suma de pesos de secciones (${sumaSeciones.toStringAsFixed(2)} pts) '
          'supera el puntaje máximo (${puntajeMaximo.toStringAsFixed(2)} pts). '
          'Ajusta los pesos antes de guardar.';
    }
    return null;
  }

  Future<void> _guardarRubrica() async {
    if (!_formKey.currentState!.validate()) return;
    if (_secciones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Agrega al menos una sección'),
          backgroundColor: Colors.orange));
      return;
    }

    // FIX M8: validar pesos antes de guardar
    final errorPesos = _validarPesosSecciones();
    if (errorPesos != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorPesos),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5)));
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

    final ok = await _service.crearRubrica(rubrica);
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(ok ? 'Rúbrica creada exitosamente' : 'Error al guardar'),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));

    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF2),
      appBar: AppBar(
        title: const Text('Crear Rúbrica',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildUbicacionCard(),
              const SizedBox(height: 20),
              _buildInfoBasicaCard(),
              const SizedBox(height: 20),
              _buildSeccionesCard(),
              const SizedBox(height: 20),
              _buildJuradosCard(),
              const SizedBox(height: 30),
              _buildBotonGuardar(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUbicacionCard() {
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
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_outline,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.carrera ?? widget.facultad,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 3),
                Text(widget.facultad,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    Text(widget.filialNombre,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30),
            ),
            child: const Text('Fijado',
                style: TextStyle(color: Colors.white60, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBasicaCard() {
    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Información Básica',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F))),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nombreController,
              label: 'Nombre de la Rúbrica',
              icon: Icons.title,
              validator: (v) =>
                  v?.isEmpty ?? true ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _descripcionController,
              label: 'Descripción (opcional)',
              icon: Icons.description,
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            // FIX M7: campo ahora acepta decimales (ej. 18.5)
            _buildTextField(
              controller: _puntajeMaximoController,
              label: 'Puntaje Máximo',
              icon: Icons.stars,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Campo requerido';
                final val = double.tryParse(v!);
                if (val == null || val <= 0) {
                  return 'Ingresa un puntaje válido mayor a 0';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionesCard() {
    // FIX M8: mostrar advertencia si la suma supera el puntaje máximo
    final puntajeMaximo =
        double.tryParse(_puntajeMaximoController.text) ?? 20.0;
    final sumaSecciones =
        _secciones.fold<double>(0.0, (s, sec) => s + sec.pesoTotal);
    final hayDesbordamiento =
        _secciones.isNotEmpty && sumaSecciones > puntajeMaximo + 0.01;

    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('Secciones y Criterios',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F))),
                ),
                ElevatedButton.icon(
                  onPressed: _agregarSeccion,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            // FIX M8: banner de advertencia de desbordamiento de pesos
            if (hayDesbordamiento) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'La suma de secciones (${sumaSecciones.toStringAsFixed(2)} pts) '
                        'supera el puntaje máximo (${puntajeMaximo.toStringAsFixed(2)} pts).',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Indicador de suma de secciones vs puntaje máximo
            if (_secciones.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Total secciones: ${sumaSecciones.toStringAsFixed(2)} / ${puntajeMaximo.toStringAsFixed(2)} pts',
                style: TextStyle(
                  fontSize: 12,
                  color: hayDesbordamiento
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ..._secciones.asMap().entries.map((entry) {
              return _SeccionWidget(
                key: ValueKey(entry.value.id),
                seccion: entry.value,
                onEliminar: () =>
                    setState(() => _secciones.removeAt(entry.key)),
                onActualizar: () => setState(() {}),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildJuradosCard() {
    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Asignar Jurados',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F))),
                ),
                Text('${_juradosSeleccionados.length} seleccionados',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[600])),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: _cargarJurados,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
                child: Row(
                  children: [
                    Icon(Icons.people_outline,
                        size: 28, color: Colors.orange.shade400),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No hay jurados disponibles para esta carrera',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._juradosDisponibles.map((jurado) {
                final isSelected =
                    _juradosSeleccionados.contains(jurado['id']);
                // FIX M3: eventoNombre ahora viene del servicio
                final eventoNombre =
                    (jurado['eventoNombre'] as String?) ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected ? Colors.green.shade50 : Colors.white,
                  child: CheckboxListTile(
                    title: Text(jurado['nombre'],
                        style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 14)),
                    subtitle: eventoNombre.isNotEmpty
                        ? Row(
                            children: [
                              Icon(Icons.event,
                                  size: 11, color: Colors.blue[400]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  eventoNombre,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue[600]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        : null,
                    secondary: CircleAvatar(
                      backgroundColor:
                          isSelected ? Colors.green : Colors.grey,
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
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _juradosSeleccionados.add(jurado['id']);
                        } else {
                          _juradosSeleccionados.remove(jurado['id']);
                        }
                      });
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonGuardar() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _guardarRubrica,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 4,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : const Text('Guardar Rúbrica',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
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
// EDITAR RÚBRICA (versión Admin Carrera)
// ============================================================================

class EditarRubricaCarreraScreen extends StatefulWidget {
  final Rubrica rubrica;
  final String filialNombre;

  const EditarRubricaCarreraScreen({
    super.key,
    required this.rubrica,
    required this.filialNombre,
  });

  @override
  State<EditarRubricaCarreraScreen> createState() =>
      _EditarRubricaCarreraScreenState();
}

class _EditarRubricaCarreraScreenState
    extends State<EditarRubricaCarreraScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nombreController =
      TextEditingController(text: widget.rubrica.nombre);
  late final _descripcionController =
      TextEditingController(text: widget.rubrica.descripcion);
  late final _puntajeMaximoController =
      TextEditingController(text: widget.rubrica.puntajeMaximo.toString());
  final RubricasService _service = RubricasService();

  late List<SeccionRubrica> _secciones;
  List<Map<String, dynamic>> _juradosDisponibles = [];
  late List<String> _juradosSeleccionados;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _secciones = widget.rubrica.secciones.map((s) => s.copyWith()).toList();
    _juradosSeleccionados = List.from(widget.rubrica.juradosAsignados);
    _cargarJurados();
  }

  Future<void> _cargarJurados() async {
    final jurados = await _service.obtenerJurados(
      filial: widget.rubrica.filial,
      facultad: widget.rubrica.facultad,
      carrera: widget.rubrica.carrera,
    );
    if (mounted) setState(() => _juradosDisponibles = jurados);
  }

  // FIX M8: también validar pesos en edición
  String? _validarPesosSecciones() {
    final puntajeMaximo =
        double.tryParse(_puntajeMaximoController.text) ?? 20.0;
    final sumaSecciones =
        _secciones.fold<double>(0.0, (s, sec) => s + sec.pesoTotal);

    if (sumaSecciones > puntajeMaximo + 0.01) {
      return 'La suma de pesos de secciones (${sumaSecciones.toStringAsFixed(2)} pts) '
          'supera el puntaje máximo (${puntajeMaximo.toStringAsFixed(2)} pts). '
          'Ajusta los pesos antes de guardar.';
    }
    return null;
  }

  Future<void> _actualizarRubrica() async {
    if (!_formKey.currentState!.validate()) return;
    if (_secciones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Agrega al menos una sección'),
          backgroundColor: Colors.orange));
      return;
    }

    // FIX M8: validar pesos antes de actualizar
    final errorPesos = _validarPesosSecciones();
    if (errorPesos != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorPesos),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5)));
      return;
    }

    setState(() => _isLoading = true);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Actualizando rúbrica...'),
        ],
      ),
      duration: Duration(seconds: 30),
      backgroundColor: Color(0xFF1E3A5F),
    ));

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

    final resultados = await Future.wait([
      juradosRemovidos.isNotEmpty
          ? _service
              .eliminarEvaluacionesDeJurados(
                rubricaId: widget.rubrica.id,
                juradosIds: juradosRemovidos,
              )
              .then((_) => true)
              .catchError((_) => false)
          : Future.value(true),
      _service.actualizarRubrica(rubricaActualizada),
    ]);

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final ok = resultados[1] as bool;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? juradosRemovidos.isNotEmpty
              ? 'Rúbrica actualizada y ${juradosRemovidos.length} evaluación(es) limpiada(s)'
              : 'Rúbrica actualizada exitosamente'
          : 'Error al actualizar'),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));

    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // FIX M8: calcular estado de pesos para el banner en edición también
    final puntajeMaximo =
        double.tryParse(_puntajeMaximoController.text) ?? 20.0;
    final sumaSecciones =
        _secciones.fold<double>(0.0, (s, sec) => s + sec.pesoTotal);
    final hayDesbordamiento =
        _secciones.isNotEmpty && sumaSecciones > puntajeMaximo + 0.01;

    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF2),
      appBar: AppBar(
        title: const Text('Editar Rúbrica',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildUbicacionCard(),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Información Básica',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A5F))),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _nombreController,
                        label: 'Nombre de la Rúbrica',
                        icon: Icons.title,
                        validator: (v) =>
                            v?.isEmpty ?? true ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _descripcionController,
                        label: 'Descripción (opcional)',
                        icon: Icons.description,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      // FIX M7: campo ahora acepta decimales también en edición
                      _buildTextField(
                        controller: _puntajeMaximoController,
                        label: 'Puntaje Máximo',
                        icon: Icons.stars,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        validator: (v) {
                          if (v?.isEmpty ?? true) return 'Requerido';
                          final val = double.tryParse(v!);
                          if (val == null || val <= 0) {
                            return 'Ingresa un puntaje válido mayor a 0';
                          }
                          return null;
                        },
                        // Reconstruir para que el banner de advertencia se actualice
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Secciones y Criterios',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A5F))),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _secciones.add(SeccionRubrica(
                                  id: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                  nombre: 'Nueva Sección',
                                  criterios: [],
                                  pesoTotal: 10,
                                ));
                              });
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Agregar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A5F),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                      // FIX M8: banner de advertencia en edición
                      if (hayDesbordamiento) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.orange.shade700,
                                  size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'La suma de secciones '
                                  '(${sumaSecciones.toStringAsFixed(2)} pts) '
                                  'supera el puntaje máximo '
                                  '(${puntajeMaximo.toStringAsFixed(2)} pts).',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_secciones.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Total secciones: ${sumaSecciones.toStringAsFixed(2)} / ${puntajeMaximo.toStringAsFixed(2)} pts',
                          style: TextStyle(
                            fontSize: 12,
                            color: hayDesbordamiento
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ..._secciones.asMap().entries.map((entry) {
                        return _SeccionWidget(
                          key: ValueKey(entry.value.id),
                          seccion: entry.value,
                          onEliminar: () => setState(
                              () => _secciones.removeAt(entry.key)),
                          onActualizar: () => setState(() {}),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Asignar Jurados',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A5F))),
                      const SizedBox(height: 12),
                      ..._juradosDisponibles.map((jurado) {
                        final isSelected =
                            _juradosSeleccionados.contains(jurado['id']);
                        // FIX M3: eventoNombre ahora viene del servicio
                        final eventoNombre =
                            (jurado['eventoNombre'] as String?) ?? '';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isSelected
                              ? Colors.green.shade50
                              : Colors.white,
                          child: CheckboxListTile(
                            title: Text(jurado['nombre'],
                                style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 14)),
                            subtitle: eventoNombre.isNotEmpty
                                ? Row(
                                    children: [
                                      Icon(Icons.event,
                                          size: 11,
                                          color: Colors.blue[400]),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          eventoNombre,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue[600]),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                            secondary: CircleAvatar(
                              backgroundColor:
                                  isSelected ? Colors.green : Colors.grey,
                              child: Text(
                                jurado['nombre'].toString().isNotEmpty
                                    ? jurado['nombre']
                                        .toString()
                                        .substring(0, 1)
                                        .toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white),
                              ),
                            ),
                            value: isSelected,
                            activeColor: Colors.green,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _juradosSeleccionados
                                      .add(jurado['id']);
                                } else {
                                  _juradosSeleccionados
                                      .remove(jurado['id']);
                                }
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _actualizarRubrica,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Actualizar Rúbrica',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUbicacionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.amber[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.filialNombre} › ${widget.rubrica.facultad}'
                  '${widget.rubrica.carrera != null ? ' › ${widget.rubrica.carrera}' : ''}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[900],
                      fontWeight: FontWeight.w600),
                ),
                Text('Ubicación no editable',
                    style: TextStyle(
                        fontSize: 11, color: Colors.amber[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    // Callback extra para poder reconstruir el widget desde _buildTextField
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
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
// WIDGETS INTERNOS
// ============================================================================

// FIX 3.1: _SeccionWidget ahora usa TextEditingController en lugar de
// initialValue para evitar la pérdida de texto al colapsar/expandir el
// ExpansionTile. Los controllers se crean en initState y se disponen
// en dispose() para evitar memory leaks.
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
  // FIX 3.1: controllers con dispose adecuado en lugar de initialValue
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _pesoCtrl;

  @override
  void initState() {
    super.initState();
    _nombreCtrl =
        TextEditingController(text: widget.seccion.nombre);
    _pesoCtrl =
        TextEditingController(text: widget.seccion.pesoTotal.toString());
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _pesoCtrl.dispose();
    super.dispose();
  }

  void _agregarCriterio() {
    widget.seccion.criterios.add(Criterio(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      descripcion: 'Nuevo criterio',
      peso: 2.5,
    ));
    widget.onActualizar();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.blue.shade50,
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.all(12),
        title: Text(widget.seccion.nombre,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14),
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${widget.seccion.criterios.length} criterios · ${widget.seccion.pesoTotal} pts',
            style: const TextStyle(fontSize: 12)),
        trailing: SizedBox(
          width: 36,
          child: IconButton(
            icon:
                const Icon(Icons.delete, color: Colors.red, size: 18),
            onPressed: widget.onEliminar,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
        children: [
          Column(
            children: [
              // FIX 3.1: usar controller en lugar de initialValue
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nombre de la sección',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.all(12)),
                onChanged: (v) {
                  widget.seccion.nombre = v;
                  widget.onActualizar();
                },
              ),
              const SizedBox(height: 8),
              // FIX 3.1: usar controller en lugar de initialValue
              TextFormField(
                controller: _pesoCtrl,
                decoration: const InputDecoration(
                    labelText: 'Peso total (pts)',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.all(12)),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
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
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _agregarCriterio,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Agregar Criterio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
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

// FIX 3.1 (mismo fix): _CriterioWidget también usa controllers
// para evitar la pérdida de texto en rebuilds.
class _CriterioWidget extends StatefulWidget {
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
  State<_CriterioWidget> createState() => _CriterioWidgetState();
}

class _CriterioWidgetState extends State<_CriterioWidget> {
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _pesoCtrl;

  @override
  void initState() {
    super.initState();
    _descripcionCtrl =
        TextEditingController(text: widget.criterio.descripcion);
    _pesoCtrl =
        TextEditingController(text: widget.criterio.peso.toString());
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _pesoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // FIX 3.1: controller en lugar de initialValue
            TextFormField(
              controller: _descripcionCtrl,
              decoration: const InputDecoration(
                  labelText: 'Criterio de Evaluación',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.all(12)),
              maxLines: 2,
              onChanged: (v) {
                widget.criterio.descripcion = v;
                widget.onActualizar();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  // FIX 3.1: controller en lugar de initialValue
                  child: TextFormField(
                    controller: _pesoCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Peso (pts)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.all(12)),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: (v) {
                      widget.criterio.peso = double.tryParse(v) ?? 0;
                      widget.onActualizar();
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
                    icon: const Icon(Icons.delete,
                        color: Colors.red, size: 18),
                    onPressed: widget.onEliminar,
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