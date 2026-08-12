import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import '/resolver_nombres_service.dart';
import '../logica/nota_docente_service.dart';
import '../logica/participantes_ranking_calculator.dart';
import '../logica/ver_ganadores_service.dart';
import 'widgets/ver_ganadores_detalle_widgets.dart';
import 'widgets/ver_ganadores_layout_widgets.dart';
import 'widgets/ver_ganadores_podio_widgets.dart';
import 'widgets/ver_ganadores_shared.dart';

class VerGanadoresScreen extends StatefulWidget {
  const VerGanadoresScreen({super.key});

  @override
  State<VerGanadoresScreen> createState() => _VerGanadoresScreenState();
}

class _VerGanadoresScreenState extends State<VerGanadoresScreen>
    with SingleTickerProviderStateMixin {
  final _service = VerGanadoresService();
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

  ModoVistaGanadores _modoVista = ModoVistaGanadores.lista;
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
      _filialId = adminData['filial'] as String?;
      _filialNombre = adminData['filialNombre'] as String?;
      _facultad = adminData['facultad'] as String?;
      _carrera = adminData['carrera'] as String?;
      _carreraId = adminData['carreraId'] ?? adminData['carrera'];

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
      final eventos = await _service.cargarEventos(
        filialId: _filialId,
        facultad: _facultad,
        carreraId: _carreraId,
      );

      if (mounted) {
        setState(() {
          _eventos = eventos;
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
      _modoVista = ModoVistaGanadores.lista;
    });
    _animCtrl.reset();

    try {
      final results = await Future.wait([
        _notaDocenteService.obtenerNotasDocente(evento['id'] as String),
        _service.calcularGanadores(evento['id'] as String, {},
            resolverNombres: _resolverNombres),
      ]);

      final notasDoc = results[0] as Map<String, double>;

      final ganadores = notasDoc.isNotEmpty
          ? await _service.calcularGanadores(
              evento['id'] as String, notasDoc,
              resolverNombres: _resolverNombres)
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
      final result = await _notaDocenteService.importarDesdeExcel(
        eventId,
        filialNombre: _filialNombre,
        filialId: _filialId,
        carreraNombre: _carrera,
        carreraId: _carreraId,
      );

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

      final notasDoc = await _notaDocenteService.obtenerNotasDocente(eventId);
      final ganadores = await _service.calcularGanadores(eventId, notasDoc,
          resolverNombres: _resolverNombres);

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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _isImportandoNotas = true);
    try {
      final eventId = _eventoSeleccionado!['id'] as String;
      await _notaDocenteService.eliminarNotasDocente(eventId);
      final ganadores = await _service.calcularGanadores(eventId, {},
          resolverNombres: _resolverNombres);
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
                : GColores.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      builder: (_) => DetalleProyectoSheet(
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
        backgroundColor: GColores.primary,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEF2F7),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: _isLoadingInit
                      ? const CenteredLoader(mensaje: 'Cargando datos...')
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
              NotaDocenteButton(
                tieneNotas: _notasDocente.isNotEmpty,
                onImportar: _importarNotasDocente,
                onEliminar: _eliminarNotasDocente,
              ),
            const SizedBox(width: 4),
            if (!_isLoadingGanadores && _ganadoresPorCategoria.isNotEmpty)
              VistaToggle(
                modoActual: _modoVista,
                onChange: (modo) => setState(() => _modoVista = modo),
              ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
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
          InfoCarreraCard(
            carrera: _carrera,
            facultad: _facultad,
            filialNombre: _filialNombre,
          ),
          const SizedBox(height: 24),
          const SectionTitle(
            icon: Icons.event_outlined,
            titulo: 'Selecciona un evento',
            subtitulo: 'Elige el evento para ver su podio por categoría',
          ),
          const SizedBox(height: 16),
          if (_isLoadingEventos)
            const CenteredLoader(mensaje: 'Cargando eventos...')
          else if (_eventos.isEmpty)
            const EmptyEventos()
          else
            ..._eventos.map((e) => EventoCard(
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
        EventoBanner(
          nombre: formatearTexto(_eventoSeleccionado!['name']),
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
              ? const CenteredLoader(mensaje: 'Calculando ganadores...')
              : _ganadoresPorCategoria.isEmpty
                  ? const SinEvaluaciones()
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
      case ModoVistaGanadores.lista:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: _ganadoresPorCategoria.entries
              .map((entry) => CategoriaSection(
                    categoria: entry.key,
                    ganadores: entry.value,
                    onTapGanador: (proyecto, posicion) =>
                        _mostrarDetalle(context, proyecto, posicion),
                  ))
              .toList(),
        );
      case ModoVistaGanadores.tabla:
        return VistaTabla(
          ganadoresPorCategoria: _ganadoresPorCategoria,
          onTapFila: (proyecto, posicion) =>
              _mostrarDetalle(context, proyecto, posicion),
        );
      case ModoVistaGanadores.grafico:
        return VistaGrafico(ganadoresPorCategoria: _ganadoresPorCategoria);
    }
  }
}
