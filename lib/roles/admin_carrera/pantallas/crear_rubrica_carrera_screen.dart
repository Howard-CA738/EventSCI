import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/shared/logica/gestion_criterios.dart';
import '/shared/logica/rubrica_validation.dart';
import '/shared/pantallas/widgets/seccion_rubrica_widget.dart';

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
  final _puntajeMaximoController = TextEditingController(text: '20');
  final RubricasService _service = RubricasService();

  List<SeccionRubrica> _secciones = [];
  List<Map<String, dynamic>> _juradosDisponibles = [];
  List<String> _juradosSeleccionados = [];
  bool _isLoading = false;
  bool _cargandoJurados = true;

  @override
  void initState() {
    super.initState();
    _cargarJurados();
  }

  Future<void> _cargarJurados() async {
    try {
      final jurados = await _service.obtenerJurados(
        filial: widget.filial,
        facultad: widget.facultad,
        carrera: widget.carrera,
      );
      if (mounted) setState(() => _juradosDisponibles = jurados);
    } catch (e) {
      debugPrint('Error cargando jurados: $e');
    } finally {
      if (mounted) setState(() => _cargandoJurados = false);
    }
  }

  void _agregarSeccion() {
    setState(() {
      _secciones.add(SeccionRubrica(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nombre: 'Nueva Seccion',
        criterios: [],
        pesoTotal: 10,
      ));
    });
  }

  Future<void> _guardarRubrica() async {
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
          Text(ok ? 'Rubrica creada exitosamente' : 'Error al guardar'),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));

    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF2),
      appBar: AppBar(
        title: const Text('Crear Rubrica',
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 3),
                Text(widget.facultad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(widget.filialNombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
                  v?.isEmpty ?? true ? 'Campo requerido' : null,
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
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,2}')),
              ],
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Campo requerido';
                final val = double.tryParse(v!);
                if (val == null || val <= 0) {
                  return 'Ingresa un puntaje valido mayor a 0';
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
                        'supera el puntaje maximo (${puntajeMaximo.toStringAsFixed(2)} pts).',
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
                Flexible(
                  child: Text('${_juradosSeleccionados.length} seleccionados',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600])),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Actualizar jurados',
                  onPressed: _cargarJurados,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
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
                final eventoNombre =
                    (jurado['eventoNombre'] as String?) ?? '';
                final nombre = (jurado['nombre'] ?? '').toString();
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected ? Colors.green.shade50 : Colors.white,
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
                        nombre.isNotEmpty
                            ? nombre.substring(0, 1).toUpperCase()
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
            : const Text('Guardar Rubrica',
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
