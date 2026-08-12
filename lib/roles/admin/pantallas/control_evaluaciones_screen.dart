import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ControlEvaluacionesScreen extends StatefulWidget {
  const ControlEvaluacionesScreen({super.key});

  @override
  State<ControlEvaluacionesScreen> createState() =>
      _ControlEvaluacionesScreenState();
}

class _ControlEvaluacionesScreenState
    extends State<ControlEvaluacionesScreen> {

  static const Color _primary = Color(0xFF1E3A5F);
  static const Color _primaryLight = Color(0xFF2D5F8D);
  static const Color _bg = Color(0xFFE8EDF2);
  static const Color _danger = Color(0xFFE53935);
  static const Color _success = Color(0xFF43A047);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _surface = Colors.white;
  static const Color _muted = Color(0xFF64748B);

  static final List<BoxShadow> _cardShadow = [
    BoxShadow(
      color: _primary.withValues(alpha: 0.07),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  List<Map<String, dynamic>> _eventos = [];
  bool _cargandoEventos = true;
  Map<String, dynamic>? _eventoSeleccionado;






  List<Map<String, dynamic>> _proyectos = [];
  bool _cargandoEvaluaciones = false;


  final TextEditingController _buscarEventoCtrl = TextEditingController();
  String _queryEvento = '';
  final TextEditingController _buscarProyectoCtrl = TextEditingController();
  String _queryProyecto = '';


  String _filtroEstado = 'todos';

  @override
  void initState() {
    super.initState();
    _cargarEventos();
  }

  @override
  void dispose() {
    _buscarEventoCtrl.dispose();
    _buscarProyectoCtrl.dispose();
    super.dispose();
  }


  void _snack(String msg, {bool error = false, bool warn = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            error
                ? Icons.error_outline
                : warn
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
        ]),
        backgroundColor: error ? _danger : warn ? _warning : _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatTs(dynamic ts) {
    if (ts == null) return '—';
    try {
      DateTime dt;
      if (ts is Timestamp) {
        dt = ts.toDate();
      } else if (ts is DateTime) {
        dt = ts;
      } else {
        return ts.toString();
      }
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return '—';
    }
  }


  Future<void> _cargarEventos() async {
    setState(() => _cargandoEventos = true);
    try {
      final snap = await _firestore
          .collection('events')
          .orderBy('createdAt', descending: true)
          .get();

      final lista = snap.docs.map((doc) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        return d;
      }).toList();

      if (mounted) setState(() => _eventos = lista);
    } catch (e) {
      _snack('Error cargando eventos: $e', error: true);
    } finally {
      if (mounted) setState(() => _cargandoEventos = false);
    }
  }

  List<Map<String, dynamic>> get _eventosFiltrados {
    if (_queryEvento.trim().isEmpty) return _eventos;
    final q = _queryEvento.toLowerCase();
    return _eventos.where((e) {
      final nombre = (e['name'] ?? e['nombre'] ?? '').toString().toLowerCase();
      final filial = (e['filialNombre'] ?? '').toString().toLowerCase();
      final facultad = (e['facultad'] ?? '').toString().toLowerCase();
      final carrera = (e['carreraNombre'] ?? '').toString().toLowerCase();
      return nombre.contains(q) ||
          filial.contains(q) ||
          facultad.contains(q) ||
          carrera.contains(q);
    }).toList();
  }


  Future<void> _cargarEvaluaciones(String eventId) async {
    setState(() {
      _cargandoEvaluaciones = true;
      _proyectos = [];
    });
    try {
      final proyectosSnap = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .get();

      if (proyectosSnap.docs.isEmpty) {
        if (mounted) setState(() => _cargandoEvaluaciones = false);
        return;
      }

      final futures = proyectosSnap.docs.map((pDoc) async {
        final pData = Map<String, dynamic>.from(pDoc.data());

        final evalSnap = await _firestore
            .collection('events')
            .doc(eventId)
            .collection('proyectos')
            .doc(pDoc.id)
            .collection('evaluaciones')
            .get();

        final evaluaciones = evalSnap.docs.map((eDoc) {
          final eData = Map<String, dynamic>.from(eDoc.data());
          return {
            'juradoId': eDoc.id,
            'juradoNombre': eData['juradoNombre'] ?? 'Jurado',
            'evaluada': eData['evaluada'] ?? false,
            'bloqueada': eData['bloqueada'] ?? false,
            'notaTotal': (eData['notaTotal'] ?? 0.0).toDouble(),
            'puntajeMaximo': (eData['puntajeMaximo'] ?? 20.0).toDouble(),
            'rubricaId': eData['rubricaId'] ?? '',
            'rubricaNombre': eData['rubricaNombre'] ?? '',
            'fechaEvaluacion': eData['fechaEvaluacion'],
            'notas': eData['notas'] ?? {},
          };
        }).toList();


        if (evaluaciones.isEmpty) return null;

        return {
          'proyectoId': pDoc.id,
          'proyectoCodigo': (pData['Código'] ?? pData['codigo'] ?? 'Sin código').toString(),
          'proyectoTitulo': (pData['Título'] ?? pData['titulo'] ?? 'Sin título').toString(),
          'integrantes': (pData['Integrantes'] ?? pData['integrantes'] ?? '').toString(),
          'sala': (pData['Sala'] ?? pData['sala'] ?? '').toString(),
          'categoria': (pData['Clasificación'] ?? pData['clasificacion'] ?? '').toString(),
          'evaluaciones': evaluaciones,
        };
      }).toList();

      final resultados = await Future.wait(futures);
      final lista = resultados
          .whereType<Map<String, dynamic>>()
          .toList();

      lista.sort((a, b) =>
          (a['proyectoCodigo'] as String).compareTo(b['proyectoCodigo'] as String));

      if (mounted) setState(() => _proyectos = lista);
    } catch (e) {
      _snack('Error cargando evaluaciones: $e', error: true);
    } finally {
      if (mounted) setState(() => _cargandoEvaluaciones = false);
    }
  }

  List<Map<String, dynamic>> get _proyectosFiltrados {
    var lista = _proyectos;


    if (_queryProyecto.trim().isNotEmpty) {
      final q = _queryProyecto.toLowerCase();
      lista = lista.where((p) {
        final codigo = (p['proyectoCodigo'] ?? '').toString().toLowerCase();
        final titulo = (p['proyectoTitulo'] ?? '').toString().toLowerCase();
        final integrantes = (p['integrantes'] ?? '').toString().toLowerCase();
        return codigo.contains(q) || titulo.contains(q) || integrantes.contains(q);
      }).toList();
    }


    if (_filtroEstado != 'todos') {
      lista = lista.where((p) {
        final evals = List<Map<String, dynamic>>.from(p['evaluaciones'] ?? []);
        if (_filtroEstado == 'evaluadas') {
          return evals.any((e) => e['evaluada'] == true);
        } else {
          return evals.any((e) => e['evaluada'] != true);
        }
      }).toList();
    }

    return lista;
  }


  Map<String, int> get _stats {
    int totalEvals = 0;
    int evaluadas = 0;
    int pendientes = 0;
    int bloqueadas = 0;

    for (final p in _proyectos) {
      final evals = List<Map<String, dynamic>>.from(p['evaluaciones'] ?? []);
      for (final e in evals) {
        totalEvals++;
        if (e['evaluada'] == true) evaluadas++;
        if (e['bloqueada'] == true && e['evaluada'] != true) bloqueadas++;
        if (e['evaluada'] != true && e['bloqueada'] != true) pendientes++;
      }
    }

    return {
      'total': totalEvals,
      'evaluadas': evaluadas,
      'pendientes': pendientes,
      'bloqueadas': bloqueadas,
    };
  }


  Future<void> _resetearEvaluacion({
    required String eventId,
    required String proyectoId,
    required String proyectoCodigo,
    required Map<String, dynamic> evaluacion,
  }) async {
    final juradoNombre = evaluacion['juradoNombre'] as String? ?? 'este jurado';
    final juradoId = evaluacion['juradoId'] as String;

    final confirm = await _dialogConfirmar(
      titulo: 'Resetear evaluación',
      mensaje:
          '¿Resetear la evaluación de "$juradoNombre" para el proyecto $proyectoCodigo?\n\n'
          'Esto eliminará la nota, las calificaciones por criterio y la fecha de evaluación. '
          'El jurado podrá volver a evaluar desde cero.',
      labelConfirmar: 'Resetear',
      colorConfirmar: _warning,
      icono: Icons.restart_alt_rounded,
    );
    if (confirm != true) return;

    try {
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .doc(proyectoId)
          .collection('evaluaciones')
          .doc(juradoId)
          .update({
        'evaluada': false,
        'bloqueada': false,
        'notas': {},
        'notaTotal': 0.0,
        'fechaEvaluacion': null,
      });

      _snack('Evaluación de "$juradoNombre" reseteada');
      await _cargarEvaluaciones(eventId);
    } catch (e) {
      _snack('Error reseteando evaluación: $e', error: true);
    }
  }


  Future<void> _resetearTodasEvaluacionesProyecto({
    required String eventId,
    required Map<String, dynamic> proyecto,
  }) async {
    final codigo = proyecto['proyectoCodigo'] as String? ?? 'este proyecto';
    final evals = List<Map<String, dynamic>>.from(proyecto['evaluaciones'] ?? []);
    final evalCount = evals.length;

    final confirm = await _dialogConfirmar(
      titulo: 'Resetear todas las evaluaciones',
      mensaje:
          '¿Resetear las $evalCount evaluaciones del proyecto "$codigo"?\n\n'
          'Todos los jurados asignados podrán volver a evaluar desde cero. '
          'Las notas y calificaciones se borrarán de Firestore.',
      labelConfirmar: 'Resetear todo',
      colorConfirmar: _danger,
      icono: Icons.restart_alt_rounded,
    );
    if (confirm != true) return;

    try {
      final batch = _firestore.batch();
      for (final eval in evals) {
        final juradoId = eval['juradoId'] as String;
        final ref = _firestore
            .collection('events')
            .doc(eventId)
            .collection('proyectos')
            .doc(proyecto['proyectoId'] as String)
            .collection('evaluaciones')
            .doc(juradoId);
        batch.update(ref, {
          'evaluada': false,
          'bloqueada': false,
          'notas': {},
          'notaTotal': 0.0,
          'fechaEvaluacion': null,
        });
      }
      await batch.commit();

      _snack('Evaluaciones de "$codigo" reseteadas');
      await _cargarEvaluaciones(eventId);
    } catch (e) {
      _snack('Error reseteando evaluaciones: $e', error: true);
    }
  }


  Future<void> _resetearTodasEvaluacionesEvento() async {
    final eventoNombre = _eventoSeleccionado?['name'] ??
        _eventoSeleccionado?['nombre'] ??
        'este evento';
    final eventId = _eventoSeleccionado?['id'] as String?;
    if (eventId == null) return;

    int totalEvals = 0;
    for (final p in _proyectos) {
      totalEvals +=
          (List<Map<String, dynamic>>.from(p['evaluaciones'] ?? [])).length;
    }

    final confirm = await _dialogConfirmar(
      titulo: 'Resetear TODAS las evaluaciones',
      mensaje:
          '¿Resetear las $totalEvals evaluaciones de todos los proyectos del evento "$eventoNombre"?\n\n'
          '⚠ Esta acción afecta a TODOS los jurados de TODOS los proyectos del evento. '
          'Los datos borrados no se podrán recuperar.',
      labelConfirmar: 'Resetear evento completo',
      colorConfirmar: _danger,
      icono: Icons.warning_amber_rounded,
    );
    if (confirm != true) return;

    try {
      const int batchLimit = 490;
      int ops = 0;
      WriteBatch batch = _firestore.batch();

      for (final proyecto in _proyectos) {
        final proyectoId = proyecto['proyectoId'] as String;
        final evals = List<Map<String, dynamic>>.from(proyecto['evaluaciones'] ?? []);
        for (final eval in evals) {
          final juradoId = eval['juradoId'] as String;
          final ref = _firestore
              .collection('events')
              .doc(eventId)
              .collection('proyectos')
              .doc(proyectoId)
              .collection('evaluaciones')
              .doc(juradoId);
          batch.update(ref, {
            'evaluada': false,
            'bloqueada': false,
            'notas': {},
            'notaTotal': 0.0,
            'fechaEvaluacion': null,
          });
          ops++;
          if (ops >= batchLimit) {
            await batch.commit();
            batch = _firestore.batch();
            ops = 0;
          }
        }
      }
      if (ops > 0) await batch.commit();

      _snack('Todas las evaluaciones del evento reseteadas');
      await _cargarEvaluaciones(eventId);
    } catch (e) {
      _snack('Error reseteando evaluaciones: $e', error: true);
    }
  }


  Future<bool?> _dialogConfirmar({
    required String titulo,
    required String mensaje,
    required String labelConfirmar,
    Color colorConfirmar = _danger,
    IconData icono = Icons.warning_amber_rounded,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final maxH = (mq.size.height
                - mq.viewInsets.bottom
                - mq.padding.top
                - mq.padding.bottom
                - 48)
            .clamp(260.0, 480.0);

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorConfirmar.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          Icon(icono, color: colorConfirmar, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        titulo,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _primary),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Text(
                    mensaje,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Flexible(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancelar',
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: Colors.grey.shade600)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorConfirmar,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Text(labelConfirmar,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }




  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isSmall = sw < 360;
    final hPad = isSmall ? 14.0 : 20.0;

    return Scaffold(
      backgroundColor: _primary,
      body: SafeArea(
        child: Column(children: [

          Padding(
            padding: EdgeInsets.fromLTRB(8, 14, hPad, 14),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  if (_eventoSeleccionado != null) {
                    setState(() {
                      _eventoSeleccionado = null;
                      _proyectos = [];
                      _buscarProyectoCtrl.clear();
                      _queryProyecto = '';
                      _filtroEstado = 'todos';
                    });
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                tooltip:
                    _eventoSeleccionado != null ? 'Volver' : 'Salir',
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.gavel,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Control de Evaluaciones',
                      style: TextStyle(
                        fontSize: isSmall ? 15 : 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (_eventoSeleccionado != null)
                      Text(
                        _eventoSeleccionado!['name'] ??
                            _eventoSeleccionado!['nombre'] ??
                            '',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              if (_eventoSeleccionado != null)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () => _cargarEvaluaciones(
                      _eventoSeleccionado!['id'] as String),
                  tooltip: 'Actualizar',
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _cargarEventos,
                  tooltip: 'Actualizar',
                ),
            ]),
          ),


          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: _eventoSeleccionado == null
                  ? _buildListaEventos(hPad)
                  : _buildPantallaEvaluaciones(hPad),
            ),
          ),
        ]),
      ),
    );
  }




  Widget _buildListaEventos(double hPad) {
    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 12),
        child: TextField(
          controller: _buscarEventoCtrl,
          onChanged: (v) => setState(() => _queryEvento = v),
          decoration: InputDecoration(
            hintText: 'Buscar evento por nombre, filial...',
            hintStyle:
                TextStyle(fontSize: 13, color: Colors.grey.shade400),
            prefixIcon:
                const Icon(Icons.search, color: _primary, size: 20),
            suffixIcon: _queryEvento.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _buscarEventoCtrl.clear();
                      setState(() => _queryEvento = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: _surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
      ),
      Expanded(
        child: _cargandoEventos
            ? const Center(
                child: CircularProgressIndicator(color: _primary))
            : _eventosFiltrados.isEmpty
                ? _buildEstadoVacio(
                    icon: Icons.event_busy,
                    titulo: 'No hay eventos',
                    subtitulo: _queryEvento.isNotEmpty
                        ? 'Sin resultados para "$_queryEvento"'
                        : 'No se encontraron eventos',
                  )
                : RefreshIndicator(
                    onRefresh: _cargarEventos,
                    color: _primary,
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 40),
                      itemCount: _eventosFiltrados.length,
                      itemBuilder: (ctx, i) =>
                          _buildEventoCard(_eventosFiltrados[i]),
                    ),
                  ),
      ),
    ]);
  }

  Widget _buildEventoCard(Map<String, dynamic> evento) {
    final nombre =
        (evento['name'] ?? evento['nombre'] ?? 'Sin nombre').toString();
    final filial = (evento['filialNombre'] ?? '').toString();
    final facultad = (evento['facultad'] ?? '').toString();
    final carrera = (evento['carreraNombre'] ?? '').toString();
    final inicial =
        nombre.isNotEmpty ? nombre[0].toUpperCase() : 'E';

    return GestureDetector(
      onTap: () {
        setState(() => _eventoSeleccionado = evento);
        _cargarEvaluaciones(evento['id'] as String);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_primary, _primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                inicial,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _primary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                if (filial.isNotEmpty)
                  _metaRow(Icons.location_city, filial),
                if (facultad.isNotEmpty)
                  _metaRow(Icons.account_balance, facultad),
                if (carrera.isNotEmpty)
                  _metaRow(Icons.menu_book, carrera),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: _primary),
        ]),
      ),
    );
  }

  Widget _metaRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(children: [
        Icon(icon, size: 11, color: _muted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: _muted),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }




  Widget _buildPantallaEvaluaciones(double hPad) {
    final stats = _stats;
    final eventId = _eventoSeleccionado!['id'] as String;

    return Column(children: [

      Padding(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_primary, _primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.event,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _eventoSeleccionado!['name'] ??
                            _eventoSeleccionado!['nombre'] ??
                            '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      Text(
                        '${_eventoSeleccionado!['filialNombre'] ?? ''} · ${_eventoSeleccionado!['facultad'] ?? ''}',
                        style: TextStyle(
                            color: Colors.white
                                .withValues(alpha: 0.75),
                            fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                if (!_cargandoEvaluaciones && _proyectos.isNotEmpty)
                  Tooltip(
                    message: 'Resetear todo el evento',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _resetearTodasEvaluacionesEvento,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: _danger.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.restart_alt_rounded,
                                  color: Colors.white, size: 15),
                              SizedBox(width: 4),
                              Text('Reset total',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),


              if (!_cargandoEvaluaciones && _proyectos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(children: [
                  _statChip(
                      '${stats['evaluadas']}',
                      'Evaluadas',
                      _success),
                  const SizedBox(width: 8),
                  _statChip(
                      '${stats['pendientes']}',
                      'Pendientes',
                      _warning),
                  const SizedBox(width: 8),
                  _statChip(
                      '${stats['total']}',
                      'Total',
                      Colors.white54),
                ]),
              ],
            ],
          ),
        ),
      ),


      Padding(
        padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
        child: Column(children: [
          TextField(
            controller: _buscarProyectoCtrl,
            onChanged: (v) => setState(() => _queryProyecto = v),
            decoration: InputDecoration(
              hintText: 'Buscar proyecto, código, integrante...',
              hintStyle: TextStyle(
                  fontSize: 13, color: Colors.grey.shade400),
              prefixIcon:
                  const Icon(Icons.search, color: _primary, size: 20),
              suffixIcon: _queryProyecto.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _buscarProyectoCtrl.clear();
                        setState(() => _queryProyecto = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: _surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),

          Row(children: [
            _filtroChip('todos', 'Todos'),
            const SizedBox(width: 8),
            _filtroChip('evaluadas', 'Con evaluadas'),
            const SizedBox(width: 8),
            _filtroChip('pendientes', 'Con pendientes'),
          ]),
        ]),
      ),


      Expanded(
        child: _cargandoEvaluaciones
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: _primary),
                    SizedBox(height: 12),
                    Text('Cargando evaluaciones...',
                        style:
                            TextStyle(color: _muted, fontSize: 13)),
                  ],
                ),
              )
            : _proyectosFiltrados.isEmpty
                ? _buildEstadoVacio(
                    icon: Icons.assignment_outlined,
                    titulo: 'Sin proyectos',
                    subtitulo: _queryProyecto.isNotEmpty ||
                            _filtroEstado != 'todos'
                        ? 'No hay resultados con los filtros actuales'
                        : 'Este evento no tiene proyectos con evaluaciones asignadas',
                  )
                : RefreshIndicator(
                    onRefresh: () => _cargarEvaluaciones(eventId),
                    color: _primary,
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 60),
                      itemCount: _proyectosFiltrados.length,
                      itemBuilder: (ctx, i) => _buildProyectoCard(
                        _proyectosFiltrados[i],
                        eventId,
                      ),
                    ),
                  ),
      ),
    ]);
  }

  Widget _statChip(String valor, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          valor,
          style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75), fontSize: 10),
        ),
      ]),
    );
  }

  Widget _filtroChip(String value, String label) {
    final selected = _filtroEstado == value;
    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _primary : _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? _primary : Colors.grey.shade300),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _primary,
          ),
        ),
      ),
    );
  }




  Widget _buildProyectoCard(
      Map<String, dynamic> proyecto, String eventId) {
    final codigo = (proyecto['proyectoCodigo'] ?? '').toString();
    final titulo = (proyecto['proyectoTitulo'] ?? '').toString();
    final integrantes = (proyecto['integrantes'] ?? '').toString();
    final sala = (proyecto['sala'] ?? '').toString();
    final categoria = (proyecto['categoria'] ?? '').toString();
    final evals = List<Map<String, dynamic>>.from(
        proyecto['evaluaciones'] ?? []);

    final totalEvals = evals.length;
    final totalEvaluadas = evals.where((e) => e['evaluada'] == true).length;
    final todasEvaluadas = totalEvaluadas == totalEvals && totalEvals > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _cardShadow,
        border: Border.all(
          color: todasEvaluadas
              ? _success.withValues(alpha: 0.3)
              : Colors.transparent,
          width: todasEvaluadas ? 1.5 : 0,
        ),
      ),
      child: Theme(
        data:
            Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding:
              const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: todasEvaluadas
                    ? [_success, const Color(0xFF2E7D32)]
                    : [_primary, _primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                codigo.isNotEmpty && codigo.length <= 6
                    ? codigo
                    : codigo.substring(0, codigo.length.clamp(0, 6)),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          title: Text(
            titulo,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: _primary),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (integrantes.isNotEmpty)
                  Text(integrantes,
                      style: const TextStyle(
                          fontSize: 11, color: _muted),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (sala.isNotEmpty)
                    _chip('Sala: $sala', Colors.blue),
                  if (categoria.isNotEmpty)
                    _chip(categoria, Colors.purple),
                  _chip(
                      '$totalEvaluadas/$totalEvals evaluadas',
                      todasEvaluadas ? _success : _warning),
                ]),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [

              Tooltip(
                message: 'Resetear todas las evaluaciones del proyecto',
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 36, minHeight: 36),
                  icon: Icon(Icons.restart_alt_rounded,
                      color: _danger.withValues(alpha: 0.7), size: 20),
                  onPressed: () => _resetearTodasEvaluacionesProyecto(
                      eventId: eventId, proyecto: proyecto),
                ),
              ),
            ],
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 10),
            if (evals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Sin evaluaciones asignadas',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade400)),
              )
            else
              ...evals.map((eval) =>
                  _buildEvaluacionRow(eval, eventId, proyecto)),
          ],
        ),
      ),
    );
  }




  Widget _buildEvaluacionRow(
    Map<String, dynamic> eval,
    String eventId,
    Map<String, dynamic> proyecto,
  ) {
    final juradoNombre =
        (eval['juradoNombre'] ?? 'Jurado').toString();
    final evaluada = eval['evaluada'] == true;
    final bloqueada = eval['bloqueada'] == true;
    final notaTotal = (eval['notaTotal'] as double? ?? 0.0);
    final puntajeMaximo = (eval['puntajeMaximo'] as double? ?? 20.0);
    final fechaEval = eval['fechaEvaluacion'];
    final rubricaNombre = (eval['rubricaNombre'] ?? '').toString();
    final notas = eval['notas'] as Map<dynamic, dynamic>? ?? {};

    Color estadoColor;
    IconData estadoIcon;
    String estadoLabel;

    if (bloqueada && evaluada) {
      estadoColor = _success;
      estadoIcon = Icons.lock;
      estadoLabel = 'Evaluada';
    } else if (bloqueada) {
      estadoColor = _danger;
      estadoIcon = Icons.lock_outline;
      estadoLabel = 'Bloqueada';
    } else {
      estadoColor = _warning;
      estadoIcon = Icons.pending_outlined;
      estadoLabel = 'Pendiente';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: evaluada
            ? _success.withValues(alpha: 0.04)
            : Colors.orange.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: evaluada
              ? _success.withValues(alpha: 0.2)
              : Colors.orange.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [

            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: evaluada
                    ? _success.withValues(alpha: 0.15)
                    : _warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(Icons.gavel,
                    color: evaluada ? _success : _warning, size: 18),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    juradoNombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (rubricaNombre.isNotEmpty)
                    Text(rubricaNombre,
                        style: const TextStyle(
                            fontSize: 10, color: _muted)),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: estadoColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: estadoColor.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(estadoIcon, size: 11, color: estadoColor),
                const SizedBox(width: 4),
                Text(estadoLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: estadoColor)),
              ]),
            ),
          ]),


          if (evaluada) ...[
            const SizedBox(height: 10),
            Row(children: [

              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _success.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      notaTotal.toStringAsFixed(2),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _success),
                    ),
                    Text(
                      '/ ${puntajeMaximo.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 10, color: _muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: puntajeMaximo > 0
                            ? (notaTotal / puntajeMaximo)
                                .clamp(0.0, 1.0)
                            : 0,
                        minHeight: 6,
                        backgroundColor:
                            Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          notaTotal / puntajeMaximo >= 0.8
                              ? _success
                              : notaTotal / puntajeMaximo >= 0.5
                                  ? _warning
                                  : _danger,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(notaTotal / (puntajeMaximo > 0 ? puntajeMaximo : 1) * 100).toStringAsFixed(1)}% del máximo',
                      style: const TextStyle(
                          fontSize: 10, color: _muted),
                    ),
                    if (fechaEval != null) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.access_time,
                            size: 10, color: _muted),
                        const SizedBox(width: 3),
                        Text(
                          _formatTs(fechaEval),
                          style: const TextStyle(
                              fontSize: 10, color: _muted),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ]),


            if (notas.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.checklist,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    '${notas.length} criterio${notas.length != 1 ? 's' : ''} evaluados',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                ]),
              ),
            ],
          ],


          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _resetearEvaluacion(
                eventId: eventId,
                proyectoId: proyecto['proyectoId'] as String,
                proyectoCodigo:
                    proyecto['proyectoCodigo'] as String? ?? '',
                evaluacion: eval,
              ),
              icon: const Icon(Icons.restart_alt_rounded, size: 14),
              label: const Text('Resetear evaluación',
                  style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                foregroundColor: evaluada ? _danger : _warning,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildEstadoVacio({
    required IconData icon,
    required String titulo,
    required String subtitulo,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 72, color: Colors.grey.shade300),
              const SizedBox(height: 20),
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _primary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(subtitulo,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade500),
                  textAlign: TextAlign.center),
            ]),
      ),
    );
  }
}