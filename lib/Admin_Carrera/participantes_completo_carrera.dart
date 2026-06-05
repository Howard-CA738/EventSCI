import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '/prefs_helper.dart';
import 'participantes_carrera_excel.dart';
import '/resolver_nombres_service.dart';

class _C {
  static const primary       = Color(0xFF1E3A5F);
  static const primaryLight  = Color(0xFF2D5590);
  static const gold          = Color(0xFFFFD700);
  static const silver        = Color(0xFFB0BEC5);
  static const bronze        = Color(0xFFCD7F32);
  static const textSecondary = Color(0xFF64748B);
  static const bg            = Color(0xFFEEF2F7);

  static const double escalaBase = 20.0;
}

enum _ModoVista { lista, tabla }

String _s(dynamic v, [String fb = '—']) {
  if (v == null) return fb;
  final s = v.toString().trim();
  return s.isEmpty ? fb : s;
}

String _sf(dynamic v, [int dec = 2]) {
  final d = v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  return d.toStringAsFixed(dec);
}

Color _posColor(int pos, bool tieneEval) {
  if (!tieneEval) return Colors.grey.shade400;
  if (pos == 0) return _C.gold;
  if (pos == 1) return _C.silver;
  if (pos == 2) return _C.bronze;
  return _C.primaryLight;
}

String _posIcono(int pos, bool tieneEval) {
  if (!tieneEval) return '—';
  if (pos == 0) return '🥇';
  if (pos == 1) return '🥈';
  if (pos == 2) return '🥉';
  return '${pos + 1}°';
}

class ParticipantesCompletoCarreraScreen extends StatefulWidget {
  const ParticipantesCompletoCarreraScreen({super.key});

  @override
  State<ParticipantesCompletoCarreraScreen> createState() =>
      _ParticipantesCompletoCarreraScreenState();
}

class _ParticipantesCompletoCarreraScreenState
    extends State<ParticipantesCompletoCarreraScreen>
    with SingleTickerProviderStateMixin {
  final _firestore    = FirebaseFirestore.instance;
  final _excelService = ParticipantesCarreraExcelService();

  String? _filialId;
  String? _filialNombre;
  String? _facultad;
  String? _carrera;
  String? _carreraId;

  bool _isLoadingInit          = true;
  bool _isLoadingEventos       = false;
  bool _isLoadingParticipantes = false;
  bool _isGeneratingExcel      = false;

  List<Map<String, dynamic>> _eventos = [];
  Map<String, dynamic>? _eventoSeleccionado;

  List<_CategoriaData> _categoriasData = [];

  List<_CategoriaData>? _filtradosCache;
  String _busquedaCache = '';

  final _searchCtrl = TextEditingController();
  String _busqueda  = '';
  _ModoVista _modoVista = _ModoVista.lista;
  final _resolverNombres = ResolverNombresService();

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  int _totalProyectos = 0;
  int _totalConEval   = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _init();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _isLoadingInit = true);
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData == null) {
        _snack('No se encontró información de sesión', isError: true);
        if (mounted) setState(() => _isLoadingInit = false);
        return;
      }
      _filialId     = adminData['filial']       as String?;
      _filialNombre = adminData['filialNombre'] as String?;
      _facultad     = adminData['facultad']     as String?;
      _carrera      = adminData['carrera']      as String?;
      _carreraId    = adminData['carreraId'] ?? adminData['carrera'];

      debugPrint('🔑 filialNombre: $_filialNombre');
      debugPrint('🔑 carrera: $_carrera');
      debugPrint('🔑 docKey que se usará: ${_filialNombre}_$_carrera');

      await _resolverNombres.cargarEstudiantes(
        filialNombre: _filialNombre ?? '',
        carrera: _carrera ?? '',
      );

      await _cargarEventos();
    } catch (e) {
      _snack('Error al iniciar: $e', isError: true);
    }
    if (mounted) setState(() => _isLoadingInit = false);
  }

  Future<void> _cargarEventos() async {
    if (mounted) setState(() => _isLoadingEventos = true);
    try {
      final snap = await _firestore
          .collection('events')
          .where('filialId',  isEqualTo: _filialId)
          .where('facultad',  isEqualTo: _facultad)
          .where('carreraId', isEqualTo: _carreraId)
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _eventos = snap.docs
              .map((doc) => {
                    'id':   doc.id,
                    'name': _s(doc.data()['name'], 'Sin nombre'),
                  })
              .toList();
          _isLoadingEventos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEventos = false);
        _snack('Error al cargar eventos: $e', isError: true);
      }
    }
  }

  Future<void> _seleccionarEvento(Map<String, dynamic> evento) async {
    _categoriasData  = [];
    _filtradosCache  = null;
    _busquedaCache   = '';
    _totalProyectos  = 0;
    _totalConEval    = 0;
    _busqueda        = '';
    _searchCtrl.clear();
    _animCtrl.reset();

    setState(() {
      _eventoSeleccionado      = evento;
      _isLoadingParticipantes  = true;
      _modoVista               = _ModoVista.lista;
    });

    try {
      final categorias = await _cargarParticipantes(evento['id'] as String);
      if (!mounted) return;

      int proj = 0, eval = 0;
      for (final c in categorias) {
        proj += c.proyectos.length;
        for (final p in c.proyectos) {
          if (p['tieneEvaluaciones'] == true) eval++;
        }
      }

      setState(() {
        _categoriasData         = categorias;
        _totalProyectos         = proj;
        _totalConEval           = eval;
        _isLoadingParticipantes = false;
      });
      _animCtrl.forward();
    } catch (e, stack) {
      if (mounted) {
        setState(() => _isLoadingParticipantes = false);
        debugPrint('❌ Error seleccionar evento: $e');
        debugPrint('$stack');
        _snack('Error al cargar participantes: $e', isError: true);
      }
    }
  }

  Future<List<_CategoriaData>> _cargarParticipantes(String eventoId) async {
    try {
      final proyectosSnap = await _firestore
          .collection('events')
          .doc(eventoId)
          .collection('proyectos')
          .get();

      debugPrint('📦 Proyectos encontrados: ${proyectosSnap.docs.length}');

      if (proyectosSnap.docs.isEmpty) return [];

      const batchSize = 10;
      final docs    = proyectosSnap.docs;
      final results = <Map<String, dynamic>>[];

      for (int i = 0; i < docs.length; i += batchSize) {
        final batch = docs.sublist(i, (i + batchSize).clamp(0, docs.length));
        final batchResults = await Future.wait(
          batch.map((doc) => _procesarProyecto(eventoId, doc)),
        );
        results.addAll(batchResults);
        debugPrint('✅ Lote procesado: ${i ~/ batchSize + 1} — total acumulado: ${results.length}');
      }

      final Map<String, List<Map<String, dynamic>>> porCategoria = {};
      for (final p in results) {
        final cat = p['clasificacion'] as String;
        porCategoria.putIfAbsent(cat, () => []).add(p);
      }

      for (final lista in porCategoria.values) {
        lista.sort((a, b) =>
            (b['promedio'] as double).compareTo(a['promedio'] as double));
      }

      debugPrint('📊 Categorías generadas: ${porCategoria.length}');

      return porCategoria.entries
          .map((e) => _CategoriaData(nombre: e.key, proyectos: e.value))
          .toList();
    } catch (e, stack) {
      debugPrint('❌ Error en _cargarParticipantes: $e');
      debugPrint('$stack');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _procesarProyecto(
      String eventoId, QueryDocumentSnapshot doc) async {
    try {
      final d = doc.data() as Map<String, dynamic>;
      debugPrint('🔍 Integrantes raw: ${d['Integrantes']}');
      debugPrint('🔍 Tipo: ${d['Integrantes'].runtimeType}');
      debugPrint('🔍 Resuelto: ${_resolverNombres.resolver(d['Integrantes'])}');
      final evalSnap = await _firestore
          .collection('events')
          .doc(eventoId)
          .collection('proyectos')
          .doc(doc.id)
          .collection('evaluaciones')
          .where('evaluada', isEqualTo: true)
          .get();

      if (evalSnap.docs.isEmpty) {
        return {
          'proyectoId':        doc.id,
          'codigo':            _s(d['Código'],       'Sin código'),
          'titulo':            _s(d['Título'],        'Sin título'),
          'integrantes': _resolverNombres.resolver(d['Integrantes']),
          'sala':              _s(d['Sala'],           ''),
          'clasificacion':     _s(d['Clasificación'], 'Sin categoría'),
          'asesor':            _s(d['Asesor'],         ''),
          'descripcion':       _s(d['Descripción'],   ''),
          'promedio':          0.0,
          'promedioRaw':       0.0,
          'notaMax':           0.0,
          'notaMin':           0.0,
          'cantidadJurados':   0,
          'notas':             <double>[],
          'notasRaw':          <double>[],
          'escalaBase':        _C.escalaBase,
          'tieneEvaluaciones': false,
        };
      }

      final notasNormalizadas = <double>[];
      final notasRaw          = <double>[];

      for (final e in evalSnap.docs) {
        final data      = e.data() as Map<String, dynamic>;
        final notaTotal = (data['notaTotal'] ?? 0.0 as num).toDouble();

        if (!data.containsKey('puntajeMaximo')) {
          debugPrint('⚠️ Evaluación ${e.id} sin puntajeMaximo — omitida del ranking');
          continue;
        }

        final puntajeMax = (data['puntajeMaximo'] as num).toDouble();
        final maxSeguro  = puntajeMax > 0 ? puntajeMax : _C.escalaBase;
        final normalizada =
            ((notaTotal / maxSeguro) * _C.escalaBase).clamp(0.0, _C.escalaBase);

        notasNormalizadas.add(double.parse(normalizada.toStringAsFixed(2)));
        notasRaw.add(notaTotal);
      }

      if (notasNormalizadas.isEmpty) {
        return {
          'proyectoId':        doc.id,
          'codigo':            _s(d['Código'],       'Sin código'),
          'titulo':            _s(d['Título'],        'Sin título'),
          'integrantes':       _resolverNombres.resolver(d['Integrantes']),
          'sala':              _s(d['Sala'],           ''),
          'clasificacion':     _s(d['Clasificación'], 'Sin categoría'),
          'asesor':            _s(d['Asesor'],         ''),
          'descripcion':       _s(d['Descripción'],   ''),
          'promedio':          0.0,
          'promedioRaw':       0.0,
          'notaMax':           0.0,
          'notaMin':           0.0,
          'cantidadJurados':   0,
          'notas':             <double>[],
          'notasRaw':          <double>[],
          'escalaBase':        _C.escalaBase,
          'tieneEvaluaciones': false,
        };
      }

      final promedio    = notasNormalizadas.reduce((a, b) => a + b) / notasNormalizadas.length;
      final promedioRaw = notasRaw.reduce((a, b) => a + b) / notasRaw.length;
      final notaMax     = notasNormalizadas.reduce((a, b) => a > b ? a : b);
      final notaMin     = notasNormalizadas.reduce((a, b) => a < b ? a : b);

      return {
        'proyectoId':        doc.id,
        'codigo':            _s(d['Código'],       'Sin código'),
        'titulo':            _s(d['Título'],        'Sin título'),
        'integrantes': _resolverNombres.resolver(d['Integrantes']),
        'sala':              _s(d['Sala'],           ''),
        'clasificacion':     _s(d['Clasificación'], 'Sin categoría'),
        'asesor':            _s(d['Asesor'],         ''),
        'descripcion':       _s(d['Descripción'],   ''),
        'promedio':          double.parse(promedio.toStringAsFixed(2)),
        'promedioRaw':       double.parse(promedioRaw.toStringAsFixed(2)),
        'notaMax':           notaMax,
        'notaMin':           notaMin,
        'cantidadJurados':   notasNormalizadas.length,
        'notas':             notasNormalizadas,
        'notasRaw':          notasRaw,
        'escalaBase':        _C.escalaBase,
        'tieneEvaluaciones': true,
      };
    } catch (e, stack) {
      debugPrint('❌ Error en proyecto ${doc.id}: $e');
      debugPrint('$stack');
      return {
        'proyectoId':        doc.id,
        'codigo':            'Error',
        'titulo':            'Error al procesar',
        'integrantes':       '',
        'sala':              '',
        'clasificacion':     'Sin categoría',
        'asesor':            '',
        'descripcion':       '',
        'promedio':          0.0,
        'promedioRaw':       0.0,
        'notaMax':           0.0,
        'notaMin':           0.0,
        'cantidadJurados':   0,
        'notas':             <double>[],
        'notasRaw':          <double>[],
        'escalaBase':        _C.escalaBase,
        'tieneEvaluaciones': false,
      };
    }
  }

  List<_CategoriaData> get _datosFiltrados {
    if (_busqueda == _busquedaCache && _filtradosCache != null) {
      return _filtradosCache!;
    }
    if (_busqueda.isEmpty) {
      _filtradosCache = _categoriasData;
      _busquedaCache  = '';
      return _filtradosCache!;
    }

    final q = _busqueda.toLowerCase();
    final resultado = <_CategoriaData>[];

    for (final cat in _categoriasData) {
      final filtrados = cat.proyectos.where((p) {
        return _s(p['titulo']).toLowerCase().contains(q)      ||
               _s(p['codigo']).toLowerCase().contains(q)      ||
               _s(p['integrantes']).toLowerCase().contains(q) ||
               _s(p['asesor']).toLowerCase().contains(q);
      }).toList();
      if (filtrados.isNotEmpty) {
        resultado.add(_CategoriaData(nombre: cat.nombre, proyectos: filtrados));
      }
    }

    _filtradosCache = resultado;
    _busquedaCache  = _busqueda;
    return resultado;
  }

  void _onBusquedaChanged(String v) {
    final trimmed = v.trim();
    if (trimmed == _busqueda) return;
    setState(() {
      _busqueda       = trimmed;
      _filtradosCache = null;
    });
  }

  Future<void> _exportarExcel() async {
    if (_eventoSeleccionado == null || _categoriasData.isEmpty) {
      _snack('No hay proyectos para exportar', isError: true);
      return;
    }
    setState(() => _isGeneratingExcel = true);

    final Map<String, List<Map<String, dynamic>>> mapa = {
      for (final c in _categoriasData) c.nombre: c.proyectos,
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _C.primary),
            const SizedBox(height: 20),
            const Text('Generando reporte Excel...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              '$_totalProyectos proyectos · ${_s(_eventoSeleccionado!['name'])}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    try {
      final rutaArchivo = await _excelService.generarReporteParticipantes(
        participantesPorCategoria: mapa,
        eventoNombre: _s(_eventoSeleccionado!['name']),
        filialNombre: _s(_filialNombre),
        facultad:     _s(_facultad),
        carrera:      _carrera,
        escalaBase:   _C.escalaBase,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isGeneratingExcel = false);

      if (rutaArchivo == null) {
        _snack('Error al generar el reporte Excel', isError: true);
        return;
      }
      _mostrarOpcionesArchivo(rutaArchivo);
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isGeneratingExcel = false);
        _snack('Error: $e', isError: true);
      }
    }
  }

  void _mostrarOpcionesArchivo(String rutaArchivo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle,
                  color: Color(0xFF27AE60), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Reporte generado',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const Text('¿Qué deseas hacer con el archivo Excel?',
            style: TextStyle(fontSize: 14, color: Colors.black54)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final result = await OpenFilex.open(rutaArchivo);
                if (result.type != ResultType.done && mounted) {
                  _snack(
                      'No se encontró una app para abrir Excel. Prueba compartirlo.',
                      isError: true);
                }
              },
              icon:  const Icon(Icons.open_in_new, size: 20),
              label: const Text('Abrir archivo',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await Share.shareXFiles(
                  [XFile(rutaArchivo)],
                  subject:
                      'Reporte de Participantes – ${_s(_eventoSeleccionado!['name'])}',
                );
              },
              icon:  const Icon(Icons.share, size: 20),
              label: const Text('Compartir',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: _C.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
            isSuccess
                ? Icons.check_circle_outline
                : isError
                    ? Icons.error_outline
                    : Icons.info_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: const TextStyle(fontSize: 13)),
          ),
        ]),
        backgroundColor: isSuccess
            ? const Color(0xFF27AE60)
            : isError
                ? Colors.red.shade700
                : _C.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ));
  }

  void _mostrarDetalle(Map<String, dynamic> proyecto, int pos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => _DetalleProyectoSheet(proyecto: proyecto, posicion: pos),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.primary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: _C.bg,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: _isLoadingInit
                    ? const _CenteredLoader(mensaje: 'Cargando datos...')
                    : _eventoSeleccionado == null
                        ? _buildSeleccionEvento()
                        : _buildResultados(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Participantes',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        overflow: TextOverflow.ellipsis),
                    maxLines: 1),
                Text('Ranking normalizado a /${_C.escalaBase} pts',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (_eventoSeleccionado != null) ...[
            if (!_isLoadingParticipantes && _categoriasData.isNotEmpty)
              _VistaToggle(
                modoActual: _modoVista,
                onChange: (modo) => setState(() => _modoVista = modo),
              ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 22),
              onPressed: _isLoadingParticipantes
                  ? null
                  : () => _seleccionarEvento(_eventoSeleccionado!),
              tooltip: 'Actualizar',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeleccionEvento() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContextCard(
            carrera:      _s(_carrera),
            facultad:     _s(_facultad),
            filialNombre: _s(_filialNombre),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _C.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_outlined,
                    color: _C.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Selecciona un evento',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _C.primary)),
                    SizedBox(height: 2),
                    Text('Elige el evento para ver todos sus participantes',
                        style: TextStyle(
                            fontSize: 12, color: _C.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingEventos)
            const _CenteredLoader(mensaje: 'Cargando eventos...')
          else if (_eventos.isEmpty)
            const _EmptyState(
              icon:      Icons.event_busy_rounded,
              iconColor: Colors.amber,
              titulo:    'No hay eventos disponibles',
              subtitulo: 'No se encontraron eventos para tu carrera.',
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _eventos.length,
              itemBuilder: (_, i) => _EventoCard(
                evento: _eventos[i],
                onTap:  () => _seleccionarEvento(_eventos[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultados() {
    return Column(
      children: [
        _EventoBanner(
          nombre:          _s(_eventoSeleccionado!['name']),
          totalProyectos:  _totalProyectos,
          totalCategorias: _categoriasData.length,
          totalConEval:    _totalConEval,
          onTap: () {
            _filtradosCache = null;
            setState(() {
              _eventoSeleccionado = null;
              _categoriasData     = [];
              _totalProyectos     = 0;
              _totalConEval       = 0;
            });
          },
        ),
        if (!_isLoadingParticipantes && _categoriasData.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: _SearchBar(
              controller: _searchCtrl,
              busqueda:   _busqueda,
              onChanged:  _onBusquedaChanged,
              onClear: () {
                _filtradosCache = null;
                setState(() {
                  _busqueda = '';
                  _searchCtrl.clear();
                });
              },
            ),
          ),
        const SizedBox(height: 6),
        Expanded(
          child: _isLoadingParticipantes
              ? const _CenteredLoader(mensaje: 'Cargando participantes...')
              : _categoriasData.isEmpty
                  ? const _EmptyState(
                      icon:      Icons.groups_outlined,
                      iconColor: _C.primary,
                      titulo:    'Sin proyectos registrados',
                      subtitulo: 'Este evento aún no tiene proyectos cargados.',
                    )
                  : _datosFiltrados.isEmpty
                      ? _buildSinResultados()
                      : FadeTransition(
                          opacity: _fadeAnim,
                          child: _modoVista == _ModoVista.lista
                              ? _buildLista(_datosFiltrados)
                              : _buildTabla(_datosFiltrados),
                        ),
        ),
      ],
    );
  }

  Widget _buildLista(List<_CategoriaData> datos) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _CategoriaAcordeon(
                key:           ValueKey(datos[i].nombre),
                data:          datos[i],
                onTapProyecto: _mostrarDetalle,
              ),
              childCount: datos.length,
              addAutomaticKeepAlives: false,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverToBoxAdapter(
            child: _BotonExportarExcel(
              cargando:  _isGeneratingExcel || _isLoadingParticipantes,
              generando: _isGeneratingExcel,
              onPressed: _exportarExcel,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabla(List<_CategoriaData> datos) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _TablaCategoria(
                key:       ValueKey(datos[i].nombre),
                data:      datos[i],
                onTapFila: _mostrarDetalle,
              ),
              childCount: datos.length,
              addAutomaticKeepAlives: false,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverToBoxAdapter(
            child: _BotonExportarExcel(
              cargando:  _isGeneratingExcel || _isLoadingParticipantes,
              generando: _isGeneratingExcel,
              onPressed: _exportarExcel,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSinResultados() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 56, color: _C.textSecondary),
            const SizedBox(height: 16),
            const Text('Sin resultados',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _C.primary)),
            const SizedBox(height: 8),
            Text('No se encontraron proyectos para "$_busqueda".',
                style: const TextStyle(
                    fontSize: 13, color: _C.textSecondary, height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _CategoriaData {
  final String nombre;
  final List<Map<String, dynamic>> proyectos;
  final int conEval;

  _CategoriaData({required this.nombre, required this.proyectos})
      : conEval =
            proyectos.where((p) => p['tieneEvaluaciones'] == true).length;
}

class _VistaToggle extends StatelessWidget {
  final _ModoVista modoActual;
  final ValueChanged<_ModoVista> onChange;

  const _VistaToggle({required this.modoActual, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(
            icon:    Icons.view_list_rounded,
            activo:  modoActual == _ModoVista.lista,
            onTap:   () => onChange(_ModoVista.lista),
            tooltip: 'Lista',
          ),
          _ToggleBtn(
            icon:    Icons.table_chart_rounded,
            activo:  modoActual == _ModoVista.tabla,
            onTap:   () => onChange(_ModoVista.tabla),
            tooltip: 'Tabla',
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool activo;
  final VoidCallback onTap;
  final String tooltip;

  const _ToggleBtn({
    required this.icon,
    required this.activo,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: activo ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon,
              size: 18, color: activo ? _C.primary : Colors.white70),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String busqueda;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.busqueda,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged:  onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14, color: _C.primary),
      decoration: InputDecoration(
        hintText: 'Buscar por título, código, integrante o asesor...',
        hintStyle: const TextStyle(fontSize: 13, color: _C.textSecondary),
        prefixIcon: const Icon(Icons.search, color: _C.textSecondary),
        suffixIcon: busqueda.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear,
                    color: _C.textSecondary, size: 18),
                onPressed: onClear,
              )
            : null,
        filled:      true,
        fillColor:   Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _BotonExportarExcel extends StatelessWidget {
  final bool cargando;
  final bool generando;
  final VoidCallback onPressed;

  const _BotonExportarExcel({
    required this.cargando,
    required this.generando,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: cargando
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF27AE60).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: ElevatedButton.icon(
        onPressed: cargando ? null : onPressed,
        icon: cargando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white54),
              )
            : const Icon(Icons.file_download_rounded, size: 22),
        label: Text(
          generando ? 'Generando Excel...' : 'Exportar Reporte Excel',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:        const Color(0xFF27AE60),
          foregroundColor:        Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  final String carrera;
  final String facultad;
  final String filialNombre;

  const _ContextCard({
    required this.carrera,
    required this.facultad,
    required this.filialNombre,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color:  _C.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.groups_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(carrera,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        overflow: TextOverflow.ellipsis),
                    maxLines: 2),
                const SizedBox(height: 3),
                Text(facultad,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        overflow: TextOverflow.ellipsis),
                    maxLines: 1),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      color: Colors.white54, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(filialNombre,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            overflow: TextOverflow.ellipsis),
                        maxLines: 1),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventoBanner extends StatelessWidget {
  final String nombre;
  final int totalProyectos;
  final int totalCategorias;
  final int totalConEval;
  final VoidCallback onTap;

  const _EventoBanner({
    required this.nombre,
    required this.totalProyectos,
    required this.totalCategorias,
    required this.totalConEval,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:  const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_rounded,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(nombre,
                      style: const TextStyle(
                          color:         Colors.white,
                          fontWeight:    FontWeight.bold,
                          fontSize:      13,
                          overflow:      TextOverflow.ellipsis),
                      maxLines: 1),
                ),
                const Text('Cambiar',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(width: 4),
                const Icon(Icons.swap_horiz_rounded,
                    color: Colors.white54, size: 16),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _BannerStat(
                    valor: '$totalProyectos',
                    label: 'proyectos',
                    icon:  Icons.science_outlined),
                const _BannerDivider(),
                _BannerStat(
                    valor: '$totalCategorias',
                    label: 'categorías',
                    icon:  Icons.category_outlined),
                const _BannerDivider(),
                _BannerStat(
                    valor: '$totalConEval',
                    label: 'evaluados',
                    icon:  Icons.check_circle_outline),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final String valor;
  final String label;
  final IconData icon;

  const _BannerStat(
      {required this.valor, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: Colors.white54),
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(valor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color:      Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize:   14)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerDivider extends StatelessWidget {
  const _BannerDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.2));
}

class _EventoCard extends StatelessWidget {
  final Map<String, dynamic> evento;
  final VoidCallback onTap;

  const _EventoCard({required this.evento, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nombre  = _s(evento['name'], 'Sin nombre');
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:  Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color:     Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset:    const Offset(0, 2))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_C.primary, _C.primaryLight],
                      begin:  Alignment.topLeft,
                      end:    Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(inicial,
                        style: const TextStyle(
                            color:      Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize:   20)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize:   14,
                              color:      _C.primary,
                              overflow:   TextOverflow.ellipsis),
                          maxLines: 2),
                      const SizedBox(height: 4),
                      const Row(children: [
                        Icon(Icons.groups_outlined,
                            size: 12, color: _C.textSecondary),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text('Ver todos los participantes',
                              style: TextStyle(
                                  fontSize: 11, color: _C.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _C.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chevron_right_rounded,
                      color: _C.primary, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoriaAcordeon extends StatefulWidget {
  final _CategoriaData data;
  final void Function(Map<String, dynamic> p, int i) onTapProyecto;

  const _CategoriaAcordeon({
    super.key,
    required this.data,
    required this.onTapProyecto,
  });

  @override
  State<_CategoriaAcordeon> createState() => _CategoriaAcordeonState();
}

class _CategoriaAcordeonState extends State<_CategoriaAcordeon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _expandAnim;
  late Animation<double>   _rotateAnim;

  bool _expandida    = false;
  bool _fueExpandido = false;
  late final List<Widget> _hijosPrebuilts;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _rotateAnim = Tween<double>(begin: 0.0, end: 0.5).animate(_expandAnim);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<Widget> _buildHijos() {
    _fueExpandido = true;
    final cat = widget.data;
    _hijosPrebuilts = List.generate(cat.proyectos.length, (i) {
      return RepaintBoundary(
        key: ValueKey(cat.proyectos[i]['proyectoId']),
        child: _ProyectoCard(
          proyecto: cat.proyectos[i],
          posicion: i,
          onTap: () => widget.onTapProyecto(cat.proyectos[i], i),
        ),
      );
    });
    return _hijosPrebuilts;
  }

  void _toggle() {
    if (!_fueExpandido) _buildHijos();
    setState(() => _expandida = !_expandida);
    _expandida ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final cat     = widget.data;
    final conEval = cat.conEval;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color:      Color(0x0F000000),
              blurRadius: 12,
              offset:     Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: _C.primary,
            child: InkWell(
              onTap:          _toggle,
              splashColor:    Colors.white12,
              highlightColor: Colors.white10,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.category_outlined,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.nombre,
                            style: const TextStyle(
                                fontSize:   14,
                                fontWeight: FontWeight.bold,
                                color:      Colors.white,
                                overflow:   TextOverflow.ellipsis),
                            maxLines: 1,
                          ),
                          Text(
                            '${cat.proyectos.length} proyectos · $conEval evaluados',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    RotationTransition(
                      turns: _rotateAnim,
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white70, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizeTransition(
            sizeFactor:    _expandAnim,
            axisAlignment: -1.0,
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _fueExpandido ? _hijosPrebuilts : const [],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProyectoCard extends StatelessWidget {
  final Map<String, dynamic> proyecto;
  final int posicion;
  final VoidCallback onTap;

  const _ProyectoCard({
    super.key,
    required this.proyecto,
    required this.posicion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final promedio  = (proyecto['promedio'] as num?)?.toDouble() ?? 0.0;
    final jurados   = (proyecto['cantidadJurados'] as int?) ?? 0;
    final tieneEval = proyecto['tieneEvaluaciones'] == true;
    final escala    = (proyecto['escalaBase'] as num?)?.toDouble() ?? _C.escalaBase;

    final color = _posColor(posicion, tieneEval);
    final icono = _posIcono(posicion, tieneEval);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tieneEval
              ? (posicion == 0
                  ? _C.gold.withValues(alpha: 0.06)
                  : const Color(0xFFF8FAFC))
              : const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: posicion < 3 && tieneEval
                ? color.withValues(alpha: 0.3)
                : const Color(0xFFE5E7EB),
            width: posicion == 0 && tieneEval ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Center(
                child: posicion < 3 && tieneEval
                    ? Text(icono, style: const TextStyle(fontSize: 20))
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: tieneEval
                              ? _C.primary.withValues(alpha: 0.1)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tieneEval ? '${posicion + 1}°' : 'S/E',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: tieneEval ? _C.primary : Colors.grey),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 5, runSpacing: 4, children: [
                    _MiniChip(
                        label: _s(proyecto['codigo'], '—'),
                        bg:    _C.primary,
                        fg:    Colors.white),
                    if (_s(proyecto['sala'], '').isNotEmpty)
                      _MiniChip(
                          label: 'Sala ${_s(proyecto['sala'])}',
                          bg:    const Color(0xFFE5E7EB),
                          fg:    _C.textSecondary),
                  ]),
                  const SizedBox(height: 5),
                  Text(_s(proyecto['titulo'], 'Sin título'),
                      style: const TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.bold,
                          color:      _C.primary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (_s(proyecto['integrantes'], '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.people_outline,
                          size: 11, color: _C.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(_s(proyecto['integrantes']),
                            style: const TextStyle(
                                fontSize: 11, color: _C.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.touch_app_outlined,
                        size:  11,
                        color: _C.textSecondary.withValues(alpha: 0.6)),
                    const SizedBox(width: 3),
                    Text('Ver detalle',
                        style: TextStyle(
                            fontSize: 10,
                            color: _C.textSecondary.withValues(alpha: 0.7))),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: tieneEval ? color : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tieneEval ? _sf(promedio) : 'S/E',
                    style: TextStyle(
                        fontSize:   tieneEval ? 16 : 12,
                        fontWeight: FontWeight.bold,
                        color:      Colors.white),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tieneEval ? '/${escala.toStringAsFixed(0)}' : 'Sin eval.',
                  style: const TextStyle(
                      fontSize: 10, color: _C.textSecondary),
                ),
                if (tieneEval) ...[
                  const SizedBox(height: 2),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.how_to_vote_outlined,
                        size: 10, color: _C.textSecondary),
                    const SizedBox(width: 3),
                    Text('$jurados j.',
                        style: const TextStyle(
                            fontSize: 10, color: _C.textSecondary)),
                  ]),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TablaCategoria extends StatelessWidget {
  final _CategoriaData data;
  final void Function(Map<String, dynamic> p, int i) onTapFila;

  const _TablaCategoria({
    super.key,
    required this.data,
    required this.onTapFila,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color:     Color(0x0F000000),
              blurRadius: 12,
              offset:    Offset(0, 4))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            color: _C.primary,
            child: Row(
              children: [
                const Icon(Icons.category_outlined,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(data.nombre,
                      style: const TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.bold,
                          color:      Colors.white,
                          overflow:   TextOverflow.ellipsis),
                      maxLines: 1),
                ),
                Text('${data.proyectos.length} proyectos',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          ColoredBox(
            color: const Color(0x101E3A5F),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                      width: 32,
                      child: Text('#',
                          style: TextStyle(
                              fontSize:   11,
                              fontWeight: FontWeight.bold,
                              color:      _C.textSecondary))),
                  const Expanded(
                      flex: 3,
                      child: Text('Proyecto',
                          style: TextStyle(
                              fontSize:   11,
                              fontWeight: FontWeight.bold,
                              color:      _C.textSecondary))),
                  SizedBox(
                      width: 60,
                      child: Text('Prom./${_C.escalaBase.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize:   10,
                              fontWeight: FontWeight.bold,
                              color:      _C.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center)),
                  const SizedBox(
                      width: 36,
                      child: Text('J.',
                          style: TextStyle(
                              fontSize:   11,
                              fontWeight: FontWeight.bold,
                              color:      _C.textSecondary),
                          textAlign: TextAlign.center)),
                ],
              ),
            ),
          ),
          ...List.generate(data.proyectos.length, (i) {
            final p         = data.proyectos[i];
            final tieneEval = p['tieneEvaluaciones'] == true;
            final promedio  = (p['promedio'] as num?)?.toDouble() ?? 0.0;
            final jurados   = (p['cantidadJurados'] as int?) ?? 0;
            final color     = _posColor(i, tieneEval);
            final icono     = _posIcono(i, tieneEval);

            return InkWell(
              onTap: () => onTapFila(p, i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Colors.grey.shade100)),
                  color: i == 0 && tieneEval
                      ? _C.gold.withValues(alpha: 0.04)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: i < 3 && tieneEval
                          ? Text(icono,
                              style: const TextStyle(fontSize: 16))
                          : Text(tieneEval ? '${i + 1}°' : 'S/E',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize:   11,
                                  fontWeight: FontWeight.bold,
                                  color: tieneEval
                                      ? _C.textSecondary
                                      : Colors.grey)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_s(p['titulo'], 'Sin título'),
                              style: const TextStyle(
                                  fontSize:   12,
                                  fontWeight: FontWeight.w600,
                                  color:      _C.primary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          Text(_s(p['codigo'], '—'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10, color: _C.textSecondary)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tieneEval ? _sf(promedio) : 'S/E',
                            style: const TextStyle(
                                fontSize:   11,
                                fontWeight: FontWeight.bold,
                                color:      Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(tieneEval ? '$jurados' : '—',
                          style: const TextStyle(
                              fontSize: 12, color: _C.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_outlined,
                    size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Flexible(
                  child: Text('Toca una fila para ver detalle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade400)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetalleProyectoSheet extends StatelessWidget {
  final Map<String, dynamic> proyecto;
  final int posicion;

  const _DetalleProyectoSheet({
    required this.proyecto,
    required this.posicion,
  });

  @override
  Widget build(BuildContext context) {
    final promedio    = (proyecto['promedio']    as num?)?.toDouble() ?? 0.0;
    final promedioRaw = (proyecto['promedioRaw'] as num?)?.toDouble() ?? 0.0;
    final notaMax     = (proyecto['notaMax']     as num?)?.toDouble() ?? 0.0;
    final notaMin     = (proyecto['notaMin']     as num?)?.toDouble() ?? 0.0;
    final jurados     = (proyecto['cantidadJurados'] as int?) ?? 0;
    final notas       = (proyecto['notas']    as List?)?.cast<double>() ?? [];
    final notasRaw    = (proyecto['notasRaw'] as List?)?.cast<double>() ?? [];
    final tieneEval   = proyecto['tieneEvaluaciones'] == true;
    final escala      = (proyecto['escalaBase'] as num?)?.toDouble() ?? _C.escalaBase;

    final color    = _posColor(posicion, tieneEval);
    final icono    = _posIcono(posicion, tieneEval);
    final etiqueta = !tieneEval
        ? 'Sin evaluación'
        : posicion == 0
            ? '1er lugar'
            : posicion == 1
                ? '2do lugar'
                : posicion == 2
                    ? '3er lugar'
                    : '${posicion + 1}° lugar';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width:  40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Container(
                    width:  52,
                    height: 52,
                    decoration: BoxDecoration(
                      color:  color.withValues(alpha: 0.15),
                      shape:  BoxShape.circle,
                      border: Border.all(
                          color: color.withValues(alpha: 0.5), width: 2),
                    ),
                    child: Center(
                        child: Text(icono,
                            style: const TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(etiqueta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize:   11,
                                  fontWeight: FontWeight.bold,
                                  color:      color)),
                        ),
                        const SizedBox(height: 4),
                        Text(_s(proyecto['titulo'], 'Sin título'),
                            style: const TextStyle(
                                fontSize:   15,
                                fontWeight: FontWeight.bold,
                                color:      _C.primary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: _C.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  if (tieneEval)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_C.primary, _C.primaryLight],
                          begin:  Alignment.topLeft,
                          end:    Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _StatItem(
                                    label:  'Prom./${escala.toStringAsFixed(0)}',
                                    value:  _sf(promedio),
                                    icon:   Icons.star_rounded,
                                    color:  _C.gold,
                                    grande: true),
                              ),
                              Container(
                                  width: 1, height: 40, color: Colors.white24),
                              Expanded(
                                child: _StatItem(
                                    label: 'Nota máx.',
                                    value: _sf(notaMax),
                                    icon:  Icons.arrow_upward_rounded,
                                    color: Colors.greenAccent),
                              ),
                              Container(
                                  width: 1, height: 40, color: Colors.white24),
                              Expanded(
                                child: _StatItem(
                                    label: 'Nota mín.',
                                    value: _sf(notaMin),
                                    icon:  Icons.arrow_downward_rounded,
                                    color: Colors.redAccent.shade100),
                              ),
                              Container(
                                  width: 1, height: 40, color: Colors.white24),
                              Expanded(
                                child: _StatItem(
                                    label: 'Jurados',
                                    value: '$jurados',
                                    icon:  Icons.how_to_vote_outlined,
                                    color: Colors.lightBlueAccent),
                              ),
                            ],
                          ),
                          if (promedioRaw > 0) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Nota original promedio: ${_sf(promedioRaw)} pts (sin normalizar)',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white60),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:  Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hourglass_empty_rounded,
                              color: _C.textSecondary, size: 20),
                          SizedBox(width: 10),
                          Flexible(
                            child: Text(
                                'Este proyecto aún no tiene evaluaciones',
                                style: TextStyle(
                                    fontSize: 13, color: _C.textSecondary)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (notas.isNotEmpty) ...[
                    _SheetSection(
                        titulo: 'Notas por jurado (normalizadas a /${escala.toStringAsFixed(0)})',
                        icon:   Icons.how_to_vote_rounded),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing:    8,
                      runSpacing: 8,
                      children: notas.asMap().entries.map((e) {
                        final isMax = e.value == notaMax;
                        final isMin = e.value == notaMin && jurados > 1;
                        final rawVal = e.key < notasRaw.length
                            ? notasRaw[e.key]
                            : null;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isMax
                                ? Colors.green.shade50
                                : isMin
                                    ? Colors.red.shade50
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isMax
                                  ? Colors.green.shade300
                                  : isMin
                                      ? Colors.red.shade300
                                      : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('J${e.key + 1}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600)),
                              Text(_sf(e.value),
                                  style: TextStyle(
                                      fontSize:   14,
                                      fontWeight: FontWeight.bold,
                                      color: isMax
                                          ? Colors.green.shade700
                                          : isMin
                                              ? Colors.red.shade700
                                              : _C.primary)),
                              if (rawVal != null)
                                Text('(${_sf(rawVal)} orig.)',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey.shade500)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const _SheetSection(
                      titulo: 'Información del proyecto',
                      icon:   Icons.info_outline_rounded),
                  const SizedBox(height: 10),
                  _InfoRow(
                      icon:  Icons.qr_code_rounded,
                      label: 'Código',
                      value: _s(proyecto['codigo'])),
                  _InfoRow(
                      icon:  Icons.category_outlined,
                      label: 'Categoría',
                      value: _s(proyecto['clasificacion'])),
                  if (_s(proyecto['sala'], '').isNotEmpty)
                    _InfoRow(
                        icon:  Icons.room_outlined,
                        label: 'Sala',
                        value: 'Sala ${_s(proyecto['sala'])}'),
                  if (_s(proyecto['integrantes'], '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const _SheetSection(
                        titulo: 'Integrantes',
                        icon:   Icons.people_outline_rounded),
                    const SizedBox(height: 8),
                    _IntegrantesCard(texto: _s(proyecto['integrantes'])),
                  ],
                  if (_s(proyecto['asesor'], '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _InfoRow(
                        icon:  Icons.school_outlined,
                        label: 'Asesor',
                        value: _s(proyecto['asesor'])),
                  ],
                  if (_s(proyecto['descripcion'], '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const _SheetSection(
                        titulo: 'Descripción',
                        icon:   Icons.description_outlined),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(_s(proyecto['descripcion']),
                          style: const TextStyle(
                              fontSize: 13,
                              color:    _C.textSecondary,
                              height:   1.6)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredLoader extends StatelessWidget {
  final String mensaje;
  const _CenteredLoader({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize:      MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _C.primary),
            const SizedBox(height: 16),
            Text(mensaje,
                style: const TextStyle(
                    color: _C.textSecondary, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   titulo;
  final String   subtitulo;

  const _EmptyState({
    required this.icon,
    required this.iconColor,
    required this.titulo,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize:      MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration:
                  const BoxDecoration(color: _C.bg, shape: BoxShape.circle),
              child: Icon(icon, size: 56, color: iconColor),
            ),
            const SizedBox(height: 20),
            Text(titulo,
                style: const TextStyle(
                    fontSize:   17,
                    fontWeight: FontWeight.bold,
                    color:      _C.primary),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitulo,
                style: const TextStyle(
                    fontSize: 13, color: _C.textSecondary, height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  final bool     grande;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.grande = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: grande ? 18 : 14),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              maxLines: 1,
              style: TextStyle(
                  color:      Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize:   grande ? 22 : 15)),
        ),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String   titulo;
  final IconData icon;

  const _SheetSection({required this.titulo, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _C.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(titulo,
              style: const TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.bold,
                  color:      _C.primary)),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: _C.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: _C.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                    color:      _C.primary)),
          ),
        ],
      ),
    );
  }
}

class _IntegrantesCard extends StatelessWidget {
  final String texto;
  const _IntegrantesCard({required this.texto});

  @override
  Widget build(BuildContext context) {
    final items = texto
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (items.length <= 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(texto,
            style: const TextStyle(
                fontSize: 13, color: _C.textSecondary)),
      );
    }

    return Column(
      children: items.map((nombre) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                width:  28,
                height: 28,
                decoration: BoxDecoration(
                  color: _C.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontSize:   11,
                          fontWeight: FontWeight.bold,
                          color:      _C.primary)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(nombre,
                    style: const TextStyle(
                        fontSize: 13, color: _C.textSecondary)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color  bg;
  final Color  fg;

  const _MiniChip(
      {required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize:   10,
              fontWeight: FontWeight.bold,
              color:      fg,
              overflow:   TextOverflow.ellipsis),
          maxLines: 1),
    );
  }
}