import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/shared/logica/gestion_criterios.dart';
import '/shared/logica/rubrica_validation.dart';
import '/shared/pantallas/widgets/seccion_rubrica_widget.dart';

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
  bool _cargandoJurados = true;

  @override
  void initState() {
    super.initState();
    _secciones = widget.rubrica.secciones.map((s) => s.copyWith()).toList();
    _juradosSeleccionados = List.from(widget.rubrica.juradosAsignados);
    _cargarJurados();
  }

  Future<void> _cargarJurados() async {
    try {
      final jurados = await _service.obtenerJurados(
        filial: widget.rubrica.filial,
        facultad: widget.rubrica.facultad,
        carrera: widget.rubrica.carrera,
      );
      if (mounted) setState(() => _juradosDisponibles = jurados);
    } catch (e) {
      debugPrint('Error cargando jurados: $e');
    } finally {
      if (mounted) setState(() => _cargandoJurados = false);
    }
  }

  Future<void> _actualizarRubrica() async {
    if (!_formKey.currentState!.validate()) return;
    if (_secciones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Agrega al menos una seccion'),
          backgroundColor: Colors.orange));
      return;
    }

    final puntajeMaximo =
        double.tryParse(_puntajeMaximoController.text) ?? 20.0;
    final errorPesos = validarPesosSecciones(
      secciones: _secciones,
      puntajeMaximo: puntajeMaximo,
    );
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
          Text('Actualizando rubrica...'),
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

    final ok = resultados[1];

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? juradosRemovidos.isNotEmpty
              ? 'Rubrica actualizada y ${juradosRemovidos.length} evaluacion(es) limpiada(s)'
              : 'Rubrica actualizada exitosamente'
          : 'Error al actualizar'),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));

    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final puntajeMaximo =
        double.tryParse(_puntajeMaximoController.text) ?? 20.0;
    final sumaSecciones =
        _secciones.fold<double>(0.0, (s, sec) => s + sec.pesoTotal);
    final hayDesbordamiento =
        _secciones.isNotEmpty && sumaSecciones > puntajeMaximo + 0.01;

    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF2),
      appBar: AppBar(
        title: const Text('Editar Rubrica',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                        const Text('Informacion Basica',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F))),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _nombreController,
                          label: 'Nombre de la Rubrica',
                          icon: Icons.title,
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _descripcionController,
                          label: 'Descripcion (opcional)',
                          icon: Icons.description,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _puntajeMaximoController,
                          label: 'Puntaje Maximo',
                          icon: Icons.stars,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          validator: (v) {
                            if (v?.isEmpty ?? true) return 'Requerido';
                            final val = double.tryParse(v!);
                            if (val == null || val <= 0) {
                              return 'Ingresa un puntaje valido mayor a 0';
                            }
                            return null;
                          },
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
                                    nombre: 'Nueva Seccion',
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
                                    'supera el puntaje maximo '
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
                          return SeccionRubricaWidget(
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
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Asignar Jurados',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A5F))),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18),
                              tooltip: 'Actualizar jurados',
                              onPressed: _cargarJurados,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 44, minHeight: 44),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_cargandoJurados)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFF1E3A5F))),
                          )
                        else if (_juradosDisponibles.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.people_outline,
                                    size: 28,
                                    color: Colors.orange.shade400),
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
                            final isSelected = _juradosSeleccionados
                                .contains(jurado['id']);
                            final eventoNombre =
                                (jurado['eventoNombre'] as String?) ?? '';
                            final nombre =
                                (jurado['nombre'] ?? '').toString();
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: isSelected
                                  ? Colors.green.shade50
                                  : Colors.white,
                              child: CheckboxListTile(
                                title: Text(nombre,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
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
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      )
                                    : null,
                                secondary: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? Colors.green
                                      : Colors.grey,
                                  child: Text(
                                    nombre.isNotEmpty
                                        ? nombre
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
                        : const Text('Actualizar Rubrica',
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[900],
                      fontWeight: FontWeight.w600),
                ),
                Text('Ubicacion no editable',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
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
