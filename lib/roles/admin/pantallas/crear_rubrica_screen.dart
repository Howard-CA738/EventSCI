import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/shared/logica/gestion_criterios.dart';
import '/shared/logica/rubrica_validation.dart';
import '/shared/pantallas/widgets/seccion_rubrica_widget.dart';

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
  final _scrollController = ScrollController();
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
    final nombre = await _service.getNombreFilial(widget.filial);
    if (mounted) {
      setState(() {
        _nombreFilial = nombre;
      });
    }
    _cargarJurados();
  }

  Future<void> _cargarJurados() async {
    final jurados = await _service.obtenerJurados(
      filial: widget.filial,
      facultad: widget.facultad,
      carrera: widget.carrera,
    );
    if (mounted) {
      setState(() => _juradosDisponibles = jurados);
    }
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

    final puntajeMaximo =
        double.tryParse(_puntajeMaximoController.text) ?? 20.0;
    final errorPesos = validarPesosSecciones(
      secciones: _secciones,
      puntajeMaximo: puntajeMaximo,
    );
    if (errorPesos != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorPesos),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
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
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
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
                        const SizedBox(height: 40),
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
              overflow: TextOverflow.ellipsis,
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
                Expanded(
                  child: Text(
                    'Ubicación de la Rúbrica',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                    overflow: TextOverflow.ellipsis,
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
      crossAxisAlignment: CrossAxisAlignment.start,
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
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
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
              textInputAction: TextInputAction.next,
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
              textInputAction: TextInputAction.next,
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
              textInputAction: TextInputAction.done,
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
              children: [
                const Expanded(
                  child: Text(
                    'Secciones y Criterios',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                    overflow: TextOverflow.ellipsis,
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
              return SeccionRubricaWidget(
                key: ValueKey(entry.value.id),
                seccion: entry.value,
                onEliminar: () {
                  setState(() => _secciones.removeAt(entry.key));
                },
                onActualizar: () => setState(() {}),
              );
            }),
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
              children: [
                const Expanded(
                  child: Text(
                    'Asignar Jurados',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${_juradosSeleccionados.length} seleccionados',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _cargarJurados,
                  tooltip: 'Recargar jurados',
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
                final isSelected =
                    _juradosSeleccionados.contains(jurado['id']);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected ? Colors.green.shade50 : Colors.white,
                  child: CheckboxListTile(
                    title: Text(
                      jurado['nombre'] as String? ?? '',
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    subtitle: Text(
                      '${jurado['carrera']}\n${jurado['facultad']}',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    secondary: CircleAvatar(
                      backgroundColor:
                          isSelected ? Colors.green : Colors.grey,
                      child: Text(
                        (jurado['nombre'] as String? ?? '').isNotEmpty
                            ? (jurado['nombre'] as String)
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
                          _juradosSeleccionados.add(jurado['id'] as String);
                        } else {
                          _juradosSeleccionados
                              .remove(jurado['id'] as String);
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
    return ElevatedButton(
      onPressed: _isLoading ? null : _guardarRubrica,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A5490),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 4,
        minimumSize: const Size(double.infinity, 52),
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
    _scrollController.dispose();
    super.dispose();
  }
}
