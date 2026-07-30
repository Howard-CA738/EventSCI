import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import '/resolver_nombres_service.dart';
import 'nota_docente_service.dart';

class _C {
  static const primary = Color(0xFF1E3A5F);
  static const primaryLight = Color(0xFF2D5590);
  static const gold = Color(0xFFFFD700);
  static const silver = Color(0xFFB0BEC5);
  static const bronze = Color(0xFFCD7F32);
  static const textSecondary = Color(0xFF64748B);

  static const Color cuarto = Color(0xFF78909C);
  static const podioColors = [gold, silver, bronze, cuarto];
  static const podioFondos = [
    Color(0xFFFFFDE7),
    Color(0xFFF5F5F5),
    Color(0xFFFBE9E7),
    Color(0xFFECEFF1),
  ];
  static const podioIconos = ['🥇', '🥈', '🥉', '🏅'];
  static const podioEtiquetas = ['1er lugar', '2do lugar', '3er lugar', '4to lugar'];
}

enum _ModoVista { lista, tabla, grafico }

String _s(dynamic v, [String fb = '—']) {
  if (v == null) return fb;
  final s = v.toString().trim();
  return s.isEmpty ? fb : s;
}

String _sf(dynamic v, [int dec = 2]) {
  final d = v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  return d.toStringAsFixed(dec);
}

class VerGanadoresScreen extends StatefulWidget {
  const VerGanadoresScreen({super.key});

  @override
  State<VerGanadoresScreen> createState() => _VerGanadoresScreenState();
}

class _VerGanadoresScreenState extends State<VerGanadoresScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _notaDocenteService = NotaDocenteService();

  String? _filialId;
  String? _filialNombre;
  String? _facultad;
  String? _carrera;
  String? _carreraId;

  bool _isLoadingInit = true;
  bool _isLoadingEventos = false;
  bool _isLoadingGanadores = false;
  bool _isImportandoNotas = false;

  List<Map<String, dynamic>> _eventos = [];
  Map<String, dynamic>? _eventoSeleccionado;
  Map<String, List<Map<String, dynamic>>> _ganadoresPorCategoria = {};



  Map<String, double> _notasDocente = {};


  _ModoVista _modoVista = _ModoVista.lista;
  final _resolverNombres = ResolverNombresService();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _init();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
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
          .where('filialId', isEqualTo: _filialId)
          .where('facultad', isEqualTo: _facultad)
          .where('carreraId', isEqualTo: _carreraId)
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _eventos = snap.docs.map((doc) => {
                'id': doc.id,
                'name': _s(doc.data()['name'], 'Sin nombre'),
              }).toList();
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
    setState(() {
      _eventoSeleccionado = evento;
      _ganadoresPorCategoria = {};
      _notasDocente = {};
      _isLoadingGanadores = true;
      _modoVista = _ModoVista.lista;
    });
    _animCtrl.reset();

    try {

      final results = await Future.wait([
        _notaDocenteService.obtenerNotasDocente(evento['id'] as String),
        _calcularGanadores(evento['id'] as String, {}),
      ]);

      final notasDoc = results[0] as Map<String, double>;

      final ganadores = notasDoc.isNotEmpty
          ? await _calcularGanadores(evento['id'] as String, notasDoc)
          : results[1] as Map<String, List<Map<String, dynamic>>>;

      if (mounted) {
        setState(() {
          _notasDocente = notasDoc;
          _ganadoresPorCategoria = ganadores;
          _isLoadingGanadores = false;
        });
        _animCtrl.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingGanadores = false);
        _snack('Error al calcular ganadores: $e', isError: true);
      }
    }
  }


  Future<void> _importarNotasDocente() async {
    if (_eventoSeleccionado == null) return;
    final eventId = _eventoSeleccionado!['id'] as String;

    setState(() => _isImportandoNotas = true);
    try {
      final result =
          await _notaDocenteService.importarDesdeExcel(eventId);

      if (result == null) {

        setState(() => _isImportandoNotas = false);
        return;
      }

      if (result.errores.isNotEmpty) {
        _snack(
          'Importado con advertencias: ${result.errores.first}',
          isError: true,
        );
      }


      final notasDoc =
          await _notaDocenteService.obtenerNotasDocente(eventId);
      final ganadores = await _calcularGanadores(eventId, notasDoc);

      if (mounted) {
        setState(() {
          _notasDocente = notasDoc;
          _ganadoresPorCategoria = ganadores;
          _isImportandoNotas = false;
        });
        _animCtrl
          ..reset()
          ..forward();
        _snack(
          '✅ ${result.codigosTotales} códigos importados '
          '(${result.gruposImportados} grupos)',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImportandoNotas = false);
        _snack('Error al importar: $e', isError: true);
      }
    }
  }


  Future<void> _eliminarNotasDocente() async {
    if (_eventoSeleccionado == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar notas docente'),
        content: const Text(
            '¿Quitar las notas docente de este evento? '
            'Los ganadores se calcularán solo con notas de jurado.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _isImportandoNotas = true);
    try {
      final eventId = _eventoSeleccionado!['id'] as String;
      await _notaDocenteService.eliminarNotasDocente(eventId);
      final ganadores = await _calcularGanadores(eventId, {});
      if (mounted) {
        setState(() {
          _notasDocente = {};
          _ganadoresPorCategoria = ganadores;
          _isImportandoNotas = false;
        });
        _animCtrl
          ..reset()
          ..forward();
        _snack('Notas docente eliminadas', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImportandoNotas = false);
        _snack('Error al eliminar: $e', isError: true);
      }
    }
  }






  Future<Map<String, List<Map<String, dynamic>>>> _calcularGanadores(
    String eventoId,
    Map<String, double> notasDocente,
  ) async {
    const double escalaBase = 20.0;

    final proyectosSnap = await _firestore
        .collection('events')
        .doc(eventoId)
        .collection('proyectos')
        .get();

    if (proyectosSnap.docs.isEmpty) return {};

    final results = await Future.wait(
      proyectosSnap.docs.map((doc) async {
        try {
          final evalSnap = await _firestore
              .collection('events')
              .doc(eventoId)
              .collection('proyectos')
              .doc(doc.id)
              .collection('evaluaciones')
              .where('evaluada', isEqualTo: true)
              .get();

          if (evalSnap.docs.isEmpty) return null;

          final d = doc.data();


          final notasNormalizadas = <double>[];
          for (final e in evalSnap.docs) {
            final data = e.data();
            final notaTotal =
                ((data['notaTotal'] ?? 0.0) as num).toDouble();

            if (!data.containsKey('puntajeMaximo')) continue;

            final puntajeMax =
                (data['puntajeMaximo'] as num).toDouble();
            final maxSeguro = puntajeMax > 0 ? puntajeMax : escalaBase;
            final normalizada =
                ((notaTotal / maxSeguro) * escalaBase)
                    .clamp(0.0, escalaBase);

            notasNormalizadas
                .add(double.parse(normalizada.toStringAsFixed(2)));
          }

          if (notasNormalizadas.isEmpty) return null;

          final promedioJurados =
              notasNormalizadas.reduce((a, b) => a + b) /
                  notasNormalizadas.length;


          double? notaDoc;
          if (notasDocente.isNotEmpty) {
            final integrantesRaw =
                d['Integrantes'] ?? d['integrantes'];
            final codigos = _extraerCodigos(integrantesRaw);
            for (final cod in codigos) {
              if (notasDocente.containsKey(cod)) {
                notaDoc = notasDocente[cod];
                break;
              }
            }
          }




          final notaFinal = notaDoc != null
              ? (promedioJurados + notaDoc) / 2.0
              : promedioJurados;

          final notaMax =
              notasNormalizadas.reduce((a, b) => a > b ? a : b);
          final notaMin =
              notasNormalizadas.reduce((a, b) => a < b ? a : b);

          return {
            'proyectoId': doc.id,
            'codigo':      _s(d['Código'],       'Sin código'),
            'titulo':      _s(d['Título'],        'Sin título'),
            'integrantes': _resolverNombres.resolver(d['Integrantes']),
            'sala':        _s(d['Sala'],           ''),
            'clasificacion': _s(d['Clasificación'], 'Sin categoría'),
            'asesor':      _s(d['Asesor'],         ''),
            'descripcion': _s(d['Descripción'],   ''),
            'promedio':    double.parse(notaFinal.toStringAsFixed(2)),
            'promedioJurados': double.parse(promedioJurados.toStringAsFixed(2)),
            'notaDocente': notaDoc,
            'notaMax':     notaMax,
            'notaMin':     notaMin,
            'cantidadJurados': notasNormalizadas.length,
            'notas':       notasNormalizadas,
            'escalaBase':  escalaBase,
            'tieneNotaDocente': notaDoc != null,
          };
        } catch (e) {
          debugPrint('❌ [Ganadores] Error en proyecto ${doc.id}: $e');
          return null;
        }
      }),
    );

    final validos = results.whereType<Map<String, dynamic>>().toList();
    if (validos.isEmpty) return {};

    final Map<String, List<Map<String, dynamic>>> porCategoria = {};
    for (final p in validos) {
      final cat = p['clasificacion'] as String;
      porCategoria.putIfAbsent(cat, () => []).add(p);
    }

    return {
      for (final entry in porCategoria.entries)
        entry.key: (entry.value
              ..sort((a, b) => (b['promedio'] as double)
                  .compareTo(a['promedio'] as double)))
            .take(4)
            .toList(),
    };
  }



  List<String> _extraerCodigos(dynamic integrantes) {
    if (integrantes == null) return [];
    if (integrantes is List) {
      return integrantes.map((e) => e.toString().trim()).toList();
    }
    if (integrantes is String) {
      return integrantes
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
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
                ? Colors.red[700]
                : _C.primary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ));
  }

  void _mostrarDetalle(
      BuildContext context, Map<String, dynamic> proyecto, int posicion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleProyectoSheet(
        proyecto: proyecto,
        posicion: posicion,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3),
      ),
      child: Scaffold(
        backgroundColor: _C.primary,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEF2F7),
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
                Text('Ganadores',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        overflow: TextOverflow.ellipsis),
                    maxLines: 1),
                Text('TOP 3 por categoría',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (_eventoSeleccionado != null) ...[

            if (_isImportandoNotas)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            else
              _NotaDocenteButton(
                tieneNotas: _notasDocente.isNotEmpty,
                onImportar: _importarNotasDocente,
                onEliminar: _eliminarNotasDocente,
              ),
            const SizedBox(width: 4),
            if (!_isLoadingGanadores && _ganadoresPorCategoria.isNotEmpty)
              _VistaToggle(
                modoActual: _modoVista,
                onChange: (modo) => setState(() => _modoVista = modo),
              ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 22),
              onPressed: _isLoadingGanadores
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
          _InfoCarreraCard(
            carrera: _carrera,
            facultad: _facultad,
            filialNombre: _filialNombre,
          ),
          const SizedBox(height: 24),
          _SectionTitle(
            icon: Icons.event_outlined,
            titulo: 'Selecciona un evento',
            subtitulo: 'Elige el evento para ver su podio por categoría',
          ),
          const SizedBox(height: 16),
          if (_isLoadingEventos)
            const _CenteredLoader(mensaje: 'Cargando eventos...')
          else if (_eventos.isEmpty)
            const _EmptyEventos()
          else
            ..._eventos.map((e) => _EventoCard(
                  evento: e,
                  onTap: () => _seleccionarEvento(e),
                )),
        ],
      ),
    );
  }

  Widget _buildResultados() {
    return Column(
      children: [
        _EventoBanner(
          nombre: _s(_eventoSeleccionado!['name']),
          totalCategorias: _ganadoresPorCategoria.length,
          tieneNotaDocente: _notasDocente.isNotEmpty,
          cantidadCodigos: _notasDocente.length,
          onTap: () => setState(() {
            _eventoSeleccionado = null;
            _ganadoresPorCategoria = {};
            _notasDocente = {};
          }),
        ),
        Expanded(
          child: _isLoadingGanadores
              ? const _CenteredLoader(mensaje: 'Calculando ganadores...')
              : _ganadoresPorCategoria.isEmpty
                  ? const _SinEvaluaciones()
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: _buildContenidoSegunModo(),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildContenidoSegunModo() {
    switch (_modoVista) {
      case _ModoVista.lista:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: _ganadoresPorCategoria.entries
              .map((entry) => _CategoriaSection(
                    categoria: entry.key,
                    ganadores: entry.value,
                    onTapGanador: (proyecto, posicion) =>
                        _mostrarDetalle(context, proyecto, posicion),
                  ))
              .toList(),
        );
      case _ModoVista.tabla:
        return _VistaTabla(
          ganadoresPorCategoria: _ganadoresPorCategoria,
          onTapFila: (proyecto, posicion) =>
              _mostrarDetalle(context, proyecto, posicion),
        );
      case _ModoVista.grafico:
        return _VistaGrafico(
            ganadoresPorCategoria: _ganadoresPorCategoria);
    }
  }
}


class _NotaDocenteButton extends StatelessWidget {
  final bool tieneNotas;
  final VoidCallback onImportar;
  final VoidCallback onEliminar;

  const _NotaDocenteButton({
    required this.tieneNotas,
    required this.onImportar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tieneNotas ? 'Notas docente cargadas' : 'Importar notas docente',
      child: GestureDetector(
        onTap: tieneNotas ? null : onImportar,
        onLongPress: tieneNotas ? onEliminar : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: tieneNotas
                ? Colors.green.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: tieneNotas
                  ? Colors.greenAccent.withValues(alpha: 0.6)
                  : Colors.white30,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                tieneNotas ? Icons.how_to_reg : Icons.upload_file,
                color: tieneNotas ? Colors.greenAccent : Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 5),
              Text(
                tieneNotas ? 'Docente ✓' : 'Docente',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tieneNotas ? Colors.greenAccent : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
            icon: Icons.view_list_rounded,
            activo: modoActual == _ModoVista.lista,
            onTap: () => onChange(_ModoVista.lista),
            tooltip: 'Lista',
          ),
          _ToggleBtn(
            icon: Icons.table_chart_rounded,
            activo: modoActual == _ModoVista.tabla,
            onTap: () => onChange(_ModoVista.tabla),
            tooltip: 'Tabla',
          ),
          _ToggleBtn(
            icon: Icons.bar_chart_rounded,
            activo: modoActual == _ModoVista.grafico,
            onTap: () => onChange(_ModoVista.grafico),
            tooltip: 'Gráfico',
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
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: activo ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon,
              size: 18,
              color: activo ? _C.primary : Colors.white70),
        ),
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
    final promedio = (proyecto['promedio'] as num?)?.toDouble() ?? 0.0;
    final promedioJurados =
        (proyecto['promedioJurados'] as num?)?.toDouble() ?? promedio;
    final notaDocente = proyecto['notaDocente'] as double?;
    final notaMax = (proyecto['notaMax'] as num?)?.toDouble() ?? 0.0;
    final notaMin = (proyecto['notaMin'] as num?)?.toDouble() ?? 0.0;
    final jurados = (proyecto['cantidadJurados'] as int?) ?? 0;
    final notas = (proyecto['notas'] as List?)?.cast<double>() ?? [];
    final tieneNotaDocente = proyecto['tieneNotaDocente'] as bool? ?? false;

    final color = posicion < 4
        ? _C.podioColors[posicion]
        : const Color(0xFF90A4AE);
    final icono = posicion < 4 ? _C.podioIconos[posicion] : '🏅';
    final etiqueta = posicion < 4
        ? _C.podioEtiquetas[posicion]
        : '${posicion + 1}° lugar';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: color.withValues(alpha: 0.5), width: 2),
                    ),
                    child: Center(
                      child:
                          Text(icono, style: const TextStyle(fontSize: 24)),
                    ),
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: color)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _s(proyecto['titulo'], 'Sin título'),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _C.primary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
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
            Divider(height: 1, color: Colors.grey[200]),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_C.primary, _C.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatItem(
                            label: 'Final',
                            value: _sf(promedio),
                            icon: Icons.star_rounded,
                            color: _C.gold,
                            grande: true,
                          ),
                        ),
                        Container(
                            width: 1, height: 40, color: Colors.white24),
                        Expanded(
                          child: _StatItem(
                            label: 'Jurados',
                            value: _sf(promedioJurados),
                            icon: Icons.gavel_rounded,
                            color: Colors.lightBlueAccent,
                          ),
                        ),
                        if (tieneNotaDocente) ...[
                          Container(
                              width: 1, height: 40, color: Colors.white24),
                          Expanded(
                            child: _StatItem(
                              label: 'Docente',
                              value: _sf(notaDocente ?? 0),
                              icon: Icons.school_rounded,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                        Container(
                            width: 1, height: 40, color: Colors.white24),
                        Expanded(
                          child: _StatItem(
                            label: 'J. cant.',
                            value: '$jurados',
                            icon: Icons.how_to_vote_outlined,
                            color: Colors.orangeAccent,
                          ),
                        ),
                      ],
                    ),
                  ),


                  if (tieneNotaDocente) ...[
                    const SizedBox(height: 14),
                    _FormulaDesglose(
                      promedioJurados: promedioJurados,
                      notaDocente: notaDocente!,
                      notaFinal: promedio,
                    ),
                  ],

                  const SizedBox(height: 20),


                  if (notas.isNotEmpty) ...[
                    _SheetSection(
                      titulo: 'Notas por jurado',
                      icon: Icons.how_to_vote_rounded,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: notas.asMap().entries.map((e) {
                        final isMax = e.value == notaMax;
                        final isMin =
                            e.value == notaMin && jurados > 1;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isMax
                                ? Colors.green[50]
                                : isMin
                                    ? Colors.red[50]
                                    : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isMax
                                  ? Colors.green[300]!
                                  : isMin
                                      ? Colors.red[300]!
                                      : Colors.grey[300]!,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('J${e.key + 1}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600])),
                              Text(_sf(e.value),
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isMax
                                          ? Colors.green[700]
                                          : isMin
                                              ? Colors.red[700]
                                              : _C.primary)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],


                  _SheetSection(
                    titulo: 'Información del proyecto',
                    icon: Icons.info_outline_rounded,
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                      icon: Icons.qr_code_rounded,
                      label: 'Código',
                      value: _s(proyecto['codigo'])),
                  _InfoRow(
                      icon: Icons.category_outlined,
                      label: 'Categoría',
                      value: _s(proyecto['clasificacion'])),
                  if (_s(proyecto['sala'], '').isNotEmpty)
                    _InfoRow(
                        icon: Icons.room_outlined,
                        label: 'Sala',
                        value: 'Sala ${_s(proyecto['sala'])}'),
                  if (_s(proyecto['integrantes'], '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SheetSection(
                      titulo: 'Integrantes',
                      icon: Icons.people_outline_rounded,
                    ),
                    const SizedBox(height: 8),
                    _IntegrantesCard(texto: _s(proyecto['integrantes'])),
                  ],
                  if (_s(proyecto['asesor'], '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                        icon: Icons.school_outlined,
                        label: 'Asesor',
                        value: _s(proyecto['asesor'])),
                  ],
                  if (_s(proyecto['descripcion'], '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SheetSection(
                      titulo: 'Descripción',
                      icon: Icons.description_outlined,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Text(
                        _s(proyecto['descripcion']),
                        style: const TextStyle(
                            fontSize: 13,
                            color: _C.textSecondary,
                            height: 1.6),
                      ),
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


class _FormulaDesglose extends StatelessWidget {
  final double promedioJurados;
  final double notaDocente;
  final double notaFinal;

  const _FormulaDesglose({
    required this.promedioJurados,
    required this.notaDocente,
    required this.notaFinal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FFF4),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined,
                  size: 15, color: Colors.green),
              const SizedBox(width: 6),
              const Text('Cálculo nota final',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green)),
            ],
          ),
          const SizedBox(height: 10),
          _FormulaRow(
            label: 'Prom. jurados',
            valor: _sf(promedioJurados),
            color: Colors.blue,
            peso: '50%',
          ),
          const SizedBox(height: 4),
          _FormulaRow(
            label: 'Nota docente',
            valor: _sf(notaDocente),
            color: Colors.green,
            peso: '50%',
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('= Nota final',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _C.primary)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _C.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_sf(notaFinal),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormulaRow extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;
  final String peso;

  const _FormulaRow({
    required this.label,
    required this.valor,
    required this.color,
    required this.peso,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: _C.textSecondary)),
        ),
        Text(peso,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color)),
        const SizedBox(width: 10),
        Text(valor,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _C.primary)),
      ],
    );
  }
}


class _VistaTabla extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> ganadoresPorCategoria;
  final void Function(Map<String, dynamic> proyecto, int posicion) onTapFila;

  const _VistaTabla({
    required this.ganadoresPorCategoria,
    required this.onTapFila,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: ganadoresPorCategoria.entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                color: _C.primary,
                child: Row(
                  children: [
                    const Icon(Icons.category_outlined,
                        color: _C.gold, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(entry.key,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              overflow: TextOverflow.ellipsis),
                          maxLines: 1),
                    ),
                  ],
                ),
              ),
              Container(
                color: _C.primary.withValues(alpha: 0.06),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                child: const Row(
                  children: [
                    SizedBox(
                        width: 32,
                        child: Text('#',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _C.textSecondary))),
                    Expanded(
                        flex: 3,
                        child: Text('Proyecto',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _C.textSecondary))),
                    SizedBox(
                        width: 52,
                        child: Text('Final',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _C.textSecondary),
                            textAlign: TextAlign.center)),
                    SizedBox(
                        width: 36,
                        child: Text('J.',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _C.textSecondary),
                            textAlign: TextAlign.center)),
                  ],
                ),
              ),
              ...entry.value.asMap().entries.map((e) {
                final i = e.key;
                final p = e.value;
                final color = i < 4
                    ? _C.podioColors[i]
                    : const Color(0xFF90A4AE);
                final icono = i < 4 ? _C.podioIconos[i] : '🏅';
                final promedio =
                    (p['promedio'] as num?)?.toDouble() ?? 0.0;
                final jurados =
                    (p['cantidadJurados'] as int?) ?? 0;
                final tieneDoc =
                    p['tieneNotaDocente'] as bool? ?? false;

                return InkWell(
                  onTap: () => onTapFila(p, i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom:
                            BorderSide(color: Colors.grey[100]!),
                      ),
                      color: i == 0
                          ? _C.gold.withValues(alpha: 0.04)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text(icono,
                              style: const TextStyle(fontSize: 18)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_s(p['titulo'], 'Sin título'),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _C.primary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              Row(children: [
                                Text(_s(p['codigo'], '—'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: _C.textSecondary)),
                                if (tieneDoc) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.school,
                                      size: 10,
                                      color: Colors.green),
                                ],
                              ]),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 52,
                          child: Center(
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(_sf(promedio),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                    textAlign: TextAlign.center),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text('$jurados',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: _C.textSecondary),
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
                        size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                          'Toca una fila para ver detalle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[400])),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}


class _VistaGrafico extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> ganadoresPorCategoria;

  const _VistaGrafico({required this.ganadoresPorCategoria});

  double get _maxNota {
    double max = 0;
    for (final lista in ganadoresPorCategoria.values) {
      for (final p in lista) {
        final v = (p['promedio'] as num?)?.toDouble() ?? 0.0;
        if (v > max) max = v;
      }
    }
    return max == 0 ? 100 : max;
  }

  @override
  Widget build(BuildContext context) {
    final maxNota = _maxNota;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: ganadoresPorCategoria.entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                color: _C.primary,
                child: Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded,
                        color: _C.gold, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(entry.key,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              overflow: TextOverflow.ellipsis),
                          maxLines: 1),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: entry.value.asMap().entries.map((e) {
                    final i = e.key;
                    final p = e.value;
                    final promedio =
                        (p['promedio'] as num?)?.toDouble() ?? 0.0;
                    final porcentaje =
                        maxNota > 0 ? promedio / maxNota : 0.0;
                    final color = i < 4
                        ? _C.podioColors[i]
                        : const Color(0xFF90A4AE);
                    final icono =
                        i < 4 ? _C.podioIconos[i] : '🏅';
                    final tieneDoc =
                        p['tieneNotaDocente'] as bool? ?? false;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(icono,
                                  style:
                                      const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _s(p['titulo'], 'Sin título'),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _C.primary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (tieneDoc)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(right: 4),
                                  child: const Icon(Icons.school,
                                      size: 12, color: Colors.green),
                                ),
                              const SizedBox(width: 6),
                              Text(_sf(promedio),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: color)),
                              const Text(' pts',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _C.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LayoutBuilder(
                            builder: (_, constraints) {
                              return Stack(
                                children: [
                                  Container(
                                    height: 14,
                                    width: constraints.maxWidth,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius:
                                          BorderRadius.circular(7),
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(
                                        milliseconds: 700),
                                    curve: Curves.easeOutCubic,
                                    height: 14,
                                    width: constraints.maxWidth *
                                        porcentaje.clamp(0.0, 1.0),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius:
                                          BorderRadius.circular(7),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 3),
                          Row(children: [
                            Flexible(
                              child: Text(_s(p['codigo'], '—'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: _C.textSecondary)),
                            ),
                            if (_s(p['sala'], '').isNotEmpty) ...[
                              Flexible(
                                child: Text(
                                    ' · Sala ${_s(p['sala'])}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: _C.textSecondary)),
                              ),
                            ],
                          ]),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}



class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool grande;

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
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: grande ? 22 : 15)),
        ),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String titulo;
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
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _C.primary)),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _C.primary)),
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _C.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                      nombre.isNotEmpty
                          ? nombre[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _C.primary)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(nombre,
                    style: const TextStyle(
                        fontSize: 12, color: _C.textSecondary)),
              ),
            ],
          ),
        );
      }).toList(),
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
          mainAxisSize: MainAxisSize.min,
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

class _InfoCarreraCard extends StatelessWidget {
  final String? carrera;
  final String? facultad;
  final String? filialNombre;

  const _InfoCarreraCard(
      {this.carrera, this.facultad, this.filialNombre});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _C.primary.withValues(alpha: 0.3),
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
            child: const Icon(Icons.emoji_events,
                color: _C.gold, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_s(carrera),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        overflow: TextOverflow.ellipsis),
                    maxLines: 2),
                const SizedBox(height: 3),
                Text(_s(facultad),
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
                    child: Text(_s(filialNombre),
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

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String? subtitulo;

  const _SectionTitle(
      {required this.icon, required this.titulo, this.subtitulo});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _C.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _C.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _C.primary,
                      overflow: TextOverflow.ellipsis),
                  maxLines: 1),
              if (subtitulo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitulo!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: _C.textSecondary,
                          overflow: TextOverflow.ellipsis),
                      maxLines: 1),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventoCard extends StatelessWidget {
  final Map<String, dynamic> evento;
  final VoidCallback onTap;

  const _EventoCard({required this.evento, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nombre = _s(evento['name'], 'Sin nombre');
    final inicial =
        nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
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
                      colors: [
                        Color(0xFFFFD700),
                        Color(0xFFFFA000)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(inicial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20)),
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
                              fontSize: 14,
                              color: _C.primary,
                              overflow: TextOverflow.ellipsis),
                          maxLines: 2),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.emoji_events,
                            size: 12, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text('Ver ganadores',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber[700])),
                        ),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _C.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chevron_right_rounded,
                      color: _C.gold, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyEventos extends StatelessWidget {
  const _EmptyEventos();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: Color(0xFFFFF8E1), shape: BoxShape.circle),
            child: const Icon(Icons.event_busy_rounded,
                size: 48, color: Colors.amber),
          ),
          const SizedBox(height: 16),
          const Text('No hay eventos disponibles',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _C.primary)),
          const SizedBox(height: 8),
          const Text('No se encontraron eventos para tu carrera.',
              style: TextStyle(
                  fontSize: 13,
                  color: _C.textSecondary,
                  height: 1.5),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _EventoBanner extends StatelessWidget {
  final String nombre;
  final int totalCategorias;
  final bool tieneNotaDocente;
  final int cantidadCodigos;
  final VoidCallback onTap;

  const _EventoBanner({
    required this.nombre,
    required this.totalCategorias,
    required this.tieneNotaDocente,
    required this.cantidadCodigos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _C.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: _C.gold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(nombre,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          overflow: TextOverflow.ellipsis),
                      maxLines: 1),
                  Row(children: [
                    const Text('Toca para cambiar · ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white54, fontSize: 11)),
                    if (tieneNotaDocente)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.school,
                            size: 11, color: Colors.greenAccent),
                        const SizedBox(width: 3),
                        Text('$cantidadCodigos doc.',
                            maxLines: 1,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.greenAccent)),
                      ])
                    else
                      const Text('solo jurados',
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: 11, color: Colors.white38)),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$totalCategorias categ.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SinEvaluaciones extends StatelessWidget {
  const _SinEvaluaciones();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                  color: Color(0xFFFFF8E1), shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_empty_rounded,
                  size: 56, color: Colors.amber),
            ),
            const SizedBox(height: 20),
            const Text('Sin evaluaciones completadas',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _C.primary),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Ningún proyecto tiene evaluaciones finalizadas en este evento todavía.',
              style: TextStyle(
                  fontSize: 13,
                  color: _C.textSecondary,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriaSection extends StatelessWidget {
  final String categoria;
  final List<Map<String, dynamic>> ganadores;
  final void Function(Map<String, dynamic> proyecto, int posicion)
      onTapGanador;

  const _CategoriaSection({
    required this.categoria,
    required this.ganadores,
    required this.onTapGanador,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: _C.primary,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.category_outlined,
                      color: _C.gold, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(categoria,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          overflow: TextOverflow.ellipsis),
                      maxLines: 1),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${ganadores.length} proy.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              children: List.generate(
                ganadores.length,
                (i) => _GanadorCard(
                  proyecto: ganadores[i],
                  posicion: i,
                  onTap: () => onTapGanador(ganadores[i], i),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_outlined,
                    size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                      'Toca una tarjeta para ver detalle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey[400])),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GanadorCard extends StatelessWidget {
  final Map<String, dynamic> proyecto;
  final int posicion;
  final VoidCallback onTap;

  const _GanadorCard({
    required this.proyecto,
    required this.posicion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final promedio = (proyecto['promedio'] as num?)?.toDouble() ?? 0.0;
    final jurados = (proyecto['cantidadJurados'] as int?) ?? 0;
    final titulo = _s(proyecto['titulo'], 'Sin título');
    final codigo = _s(proyecto['codigo'], '—');
    final integrantes = _s(proyecto['integrantes'], '');
    final sala = _s(proyecto['sala'], '');
    final tieneNotaDocente =
        proyecto['tieneNotaDocente'] as bool? ?? false;

    final color = posicion < 4
        ? _C.podioColors[posicion]
        : const Color(0xFF90A4AE);
    final fondo = posicion < 4
        ? _C.podioFondos[posicion]
        : const Color(0xFFF5F5F5);
    final icono = posicion < 4 ? _C.podioIconos[posicion] : '🏅';
    final etiqueta = posicion < 4
        ? _C.podioEtiquetas[posicion]
        : '${posicion + 1}° lugar';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                color.withValues(alpha: posicion == 0 ? 0.5 : 0.25),
            width: posicion == 0 ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: color.withValues(alpha: 0.4), width: 2),
              ),
              child: Center(
                child: Text(icono,
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      _MiniChip(
                          label: codigo,
                          bg: _C.primary,
                          fg: Colors.white),
                      _MiniChip(
                          label: etiqueta,
                          bg: color.withValues(alpha: 0.18),
                          fg: color),
                      if (tieneNotaDocente)
                        _MiniChip(
                          label: '+ Docente',
                          bg: Colors.green.withValues(alpha: 0.12),
                          fg: Colors.green[700]!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(titulo,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _C.primary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (integrantes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.people_outline,
                          size: 12, color: _C.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(integrantes,
                            style: const TextStyle(
                                fontSize: 11,
                                color: _C.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                  if (sala.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.room_outlined,
                          size: 12, color: _C.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text('Sala $sala',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11,
                                color: _C.textSecondary)),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.info_outline,
                        size: 11,
                        color: color.withValues(alpha: 0.7)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text('Ver detalle completo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              color:
                                  color.withValues(alpha: 0.8))),
                    ),
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
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_sf(promedio),
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                const SizedBox(height: 4),
                const Text('pts',
                    style: TextStyle(
                        fontSize: 10, color: _C.textSecondary)),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _MiniChip(
      {required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: fg,
              overflow: TextOverflow.ellipsis),
          maxLines: 1),
    );
  }
}