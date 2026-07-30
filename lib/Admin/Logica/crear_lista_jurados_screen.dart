import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/logica/filiales_service.dart';

const _kPrimario       = Color(0xFF1E3A5F);
const _kTextoGris      = Color(0xFF64748B);
const _kTextoGrisClaro = Color(0xFF94A3B8);
const _kFondo          = Color(0xFFE8EDF2);
const _kCampoFondo     = Color(0xFFF8FAFC);
const _kVerde          = Color(0xFF16A34A);
const _kJurado         = Color(0xFF0F6E56);

class CrearListaJuradosScreen extends StatefulWidget {
  const CrearListaJuradosScreen({super.key});

  @override
  State<CrearListaJuradosScreen> createState() => _CrearListaJuradosScreenState();
}

class _CrearListaJuradosScreenState extends State<CrearListaJuradosScreen> {
  final FilialesService _filialesService = FilialesService();
  Map<String, dynamic> _estructura = {};
  bool _cargandoEstructura = true;
  bool _guardando = false;

  String? _filialId;
  String? _filialNombre;
  String? _facultad;
  String? _carrera;
  String? _carreraId;

  List<Map<String, dynamic>> _eventos = [];
  Map<String, dynamic>? _evento;
  bool _cargandoEventos = false;

  List<_JuradoOpcion> _jurados = [];
  bool _cargandoJurados = false;

  bool get _destinoListo => _filialNombre != null && _facultad != null && _carrera != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _filialesService.inicializarSiEsNecesario();
      final estructura = await _filialesService.getEstructuraCompleta();
      if (mounted) setState(() { _estructura = estructura; _cargandoEstructura = false; });
    } catch (e) {
      if (mounted) setState(() => _cargandoEstructura = false);
    }
  }

  List<String> get _filiales => _estructura.keys.toList();
  String _nombreFilial(String id) => _estructura[id]?['nombre'] ?? id;

  List<String> _facultades(String filialId) {
    final f = _estructura[filialId];
    if (f == null) return [];
    return (f['facultades'] as Map<String, dynamic>).keys.toList();
  }

  List<Map<String, dynamic>> _carreras(String filialId, String facultad) {
    final f = _estructura[filialId];
    if (f == null) return [];
    final facs = f['facultades'] as Map<String, dynamic>;
    final data = facs[facultad];
    if (data == null) return [];
    return List<Map<String, dynamic>>.from(data['carreras'] ?? []);
  }

  void _onFilial(String? id) {
    setState(() {
      _filialId = id;
      _filialNombre = id != null ? _nombreFilial(id) : null;
      _facultad = null; _carrera = null; _carreraId = null;
      _eventos = []; _evento = null; _jurados = [];
    });
  }

  void _onFacultad(String? f) {
    setState(() {
      _facultad = f;
      _carrera = null; _carreraId = null;
      _eventos = []; _evento = null; _jurados = [];
    });
  }

  void _onCarrera(String? nombre) {
    if (nombre == null || _filialId == null || _facultad == null) return;
    final carreras = _carreras(_filialId!, _facultad!);
    final data = carreras.firstWhere((c) => c['nombre'] == nombre, orElse: () => {});
    setState(() {
      _carrera   = nombre;
      _carreraId = data.isNotEmpty ? data['id'] as String? : null;
      _eventos = []; _evento = null; _jurados = [];
    });
    _cargarEventos();
    _cargarJurados();
  }

  Future<void> _cargarEventos() async {
    if (_filialId == null || _facultad == null || _carreraId == null) return;
    setState(() => _cargandoEventos = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .where('filialId', isEqualTo: _filialId)
          .where('facultad', isEqualTo: _facultad)
          .where('carreraId', isEqualTo: _carreraId)
          .orderBy('createdAt', descending: true)
          .get();
      if (mounted) {
        setState(() => _eventos = snap.docs
            .map((d) => {'id': d.id, 'name': d.data()['name'] ?? 'Sin nombre'})
            .toList());
      }
    } catch (e) {
      debugPrint('Error cargando eventos: $e');
    }
    if (mounted) setState(() => _cargandoEventos = false);
  }

  // Mismo criterio que _cargarJurados() de GenerarCertificadosScreen.
  Future<void> _cargarJurados() async {
    if (_filialId == null || _facultad == null || _carrera == null) return;
    setState(() => _cargandoJurados = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'jurado')
          .where('filial', isEqualTo: _filialId)
          .where('facultad', isEqualTo: _facultad)
          .where('carrera', isEqualTo: _carrera)
          .get();
      final lista = snap.docs.map((doc) {
        final d = doc.data();
        return _JuradoOpcion(
          id: doc.id,
          nombre: d['name'] as String? ?? 'Sin nombre',
          dni: d['dni'] as String? ?? '',
          usuario: d['usuario'] as String? ?? '',
        );
      }).toList()
        ..sort((a, b) => a.nombre.compareTo(b.nombre));
      if (mounted) setState(() => _jurados = lista);
    } catch (e) {
      debugPrint('Error cargando jurados: $e');
    }
    if (mounted) setState(() => _cargandoJurados = false);
  }

  int get _seleccionados => _jurados.where((j) => j.seleccionado).length;

  Future<void> _crearLista() async {
    if (_evento == null) { _snack('Selecciona un evento', color: Colors.orange); return; }
    final elegidos = _jurados.where((j) => j.seleccionado).toList();
    if (elegidos.isEmpty) { _snack('Selecciona al menos un jurado', color: Colors.orange); return; }

    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance.collection('listas_certificados').add({
        'filialId': _filialId,
        'filialNombre': _filialNombre,
        'facultad': _facultad,
        'carrera': _carrera,
        'carreraId': _carreraId,
        'eventoId': _evento!['id'],
        'evento': _evento!['name'],
        'rol': 'JURADO',
        'fecha': Timestamp.now(),
        'totalEstudiantes': elegidos.length,
        'estudiantes': elegidos.map((j) => {
              'estudianteId': j.id,
              'nombre': j.nombre,
              'dni': j.dni,
              'codigoEstudiante': j.usuario,   // "usuario" del jurado, no codigoUniversitario
              'codigoCertificado': '',
              'certId': null,                  // se crea recién al enviar
              'generadoCompleto': false,
              'esJurado': true,
              'seleccionadoEnvio': true,        // se puede desmarcar antes de enviar
            }).toList(),
      });
      if (mounted) {
        _snack('✅ Lista de jurados creada', color: _kVerde);
        Navigator.pop(context, true);
      }
    } catch (e) {
      _snack('Error creando la lista: $e', color: const Color(0xFFDC2626));
    }
    if (mounted) setState(() => _guardando = false);
  }

  void _snack(String msg, {Color color = _kPrimario}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kJurado,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _kFondo,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: _cargandoEstructura
                  ? const Center(child: CircularProgressIndicator(color: _kJurado))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        _buildDestinoCard(),
                        const SizedBox(height: 14),
                        if (_destinoListo) _buildEventoCard(),
                        if (_destinoListo) ...[
                          const SizedBox(height: 14),
                          _buildJuradosCard(),
                        ],
                      ],
                    ),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: (_destinoListo && _evento != null)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton.icon(
                    onPressed: (_guardando || _seleccionados == 0) ? null : _crearLista,
                    icon: _guardando
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.gavel_rounded),
                    label: Text(_guardando
                        ? 'Creando...'
                        : 'Crear lista con $_seleccionados jurado(s)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kJurado, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.gavel_rounded, color: _kJurado, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nueva lista de Jurados',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              Text('Selecciona jurados y asígnales sus códigos',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ]),
      );

  Widget _card({required Widget child}) => Card(
        elevation: 2, shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );

  Widget _buildDestinoCard() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Sede, facultad y carrera',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kJurado)),
        const SizedBox(height: 14),
        _dropdown('Sede (Filial)', _filialId,
            _filiales.map((id) => DropdownMenuItem(value: id, child: Text(_nombreFilial(id)))).toList(),
            _onFilial),
        const SizedBox(height: 12),
        _dropdown('Facultad', _facultad,
            _filialId != null
                ? _facultades(_filialId!).map((f) => DropdownMenuItem(value: f, child: Text(f))).toList()
                : const [],
            _filialId != null ? _onFacultad : null),
        const SizedBox(height: 12),
        _dropdown('Carrera', _carrera,
            (_filialId != null && _facultad != null)
                ? _carreras(_filialId!, _facultad!)
                    .map((c) => DropdownMenuItem(value: c['nombre'] as String, child: Text(c['nombre'] as String)))
                    .toList()
                : const [],
            _facultad != null ? _onCarrera : null),
      ]),
    );
  }

 Widget _dropdown(String label, String? value, List<DropdownMenuItem<String>> items,
    ValueChanged<String?>? onChanged) {
  // Deduplica por value: si hay 2+ items con el mismo texto (p. ej.
  // carreras repetidas en la estructura de Firestore), solo se queda con
  // el primero. Evita el crash "exactly one item with value X".
  final vistos = <String>{};
  final itemsUnicos = items.where((it) => vistos.add(it.value!)).toList();

  // Si el value seleccionado ya no existe entre los items (p. ej. cambiaste
  // de facultad y el nombre no aplica aquí), lo tratamos como null en vez
  // de dejar que el DropdownButtonFormField lance la excepción.
  final valueValido = value != null && itemsUnicos.any((it) => it.value == value)
      ? value
      : null;

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kJurado)),
    const SizedBox(height: 6),
    DropdownButtonFormField<String>(
      initialValue: valueValido,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true, fillColor: onChanged != null ? _kCampoFondo : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      items: itemsUnicos,
      onChanged: onChanged,
    ),
  ]);
}

  Widget _buildEventoCard() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Evento', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kJurado)),
        const SizedBox(height: 10),
        if (_cargandoEventos)
          const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: _kJurado)))
        else if (_eventos.isEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
            child: const Text('No hay eventos para esta carrera', style: TextStyle(fontSize: 12, color: Color(0xFF78350F))),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _evento?['id'] as String?,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true, fillColor: _kCampoFondo,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            items: _eventos
                .map((e) => DropdownMenuItem(
                    value: e['id'] as String,
                    child: Text(e['name'] as String, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (id) => setState(() => _evento = _eventos.firstWhere((e) => e['id'] == id)),
          ),
      ]),
    );
  }

  Widget _buildJuradosCard() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: Text('Jurados de esta carrera',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kJurado)),
          ),
          Text('$_seleccionados / ${_jurados.length}',
              style: const TextStyle(fontSize: 12, color: _kTextoGris, fontWeight: FontWeight.w600)),
        ]),
        if (_jurados.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                final marcarTodos = _seleccionados != _jurados.length;
                for (final j in _jurados) j.seleccionado = marcarTodos;
              }),
              child: Text(_seleccionados == _jurados.length ? 'Ninguno' : 'Todos',
                  style: const TextStyle(fontSize: 12, color: _kJurado)),
            ),
          ),
        if (_cargandoJurados)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _kJurado)))
        else if (_jurados.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('No hay jurados registrados en esta carrera',
                style: TextStyle(fontSize: 12, color: _kTextoGrisClaro, fontStyle: FontStyle.italic))),
          )
        else
          ..._jurados.map((j) => CheckboxListTile(
                value: j.seleccionado,
                onChanged: (v) => setState(() => j.seleccionado = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: _kJurado,
                contentPadding: EdgeInsets.zero,
                title: Text(j.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Usuario: ${j.usuario.isNotEmpty ? j.usuario : '—'}'
                  '${j.dni.isNotEmpty ? '   ·   DNI: ${j.dni}' : ''}',
                  style: const TextStyle(fontSize: 11, color: _kTextoGrisClaro),
                ),
              )),
      ]),
    );
  }
}

class _JuradoOpcion {
  final String id, nombre, dni, usuario;
  bool seleccionado = false;
  _JuradoOpcion({
    required this.id,
    required this.nombre,
    this.dni = '',
    this.usuario = '',
  });
}