import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '/prefs_helper.dart';
import '../datos/categoria_data.dart';
import '../logica/participantes_carrera_excel.dart';
import '../logica/participantes_completo_service.dart';
import '../logica/participantes_ranking_calculator.dart';
import 'widgets/participantes_shared.dart';
import 'widgets/participantes_layout_widgets.dart';
import 'widgets/participantes_ranking_widgets.dart';
import 'widgets/participantes_detalle_widgets.dart';

class ParticipantesCompletoCarreraScreen extends StatefulWidget {
  const ParticipantesCompletoCarreraScreen({super.key});

  @override
  State<ParticipantesCompletoCarreraScreen> createState() =>
      _ParticipantesCompletoCarreraScreenState();
}

class _ParticipantesCompletoCarreraScreenState
    extends State<ParticipantesCompletoCarreraScreen>
    with SingleTickerProviderStateMixin {
  final _service      = ParticipantesCompletoService();
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
  bool _isImportandoNotas      = false;

  List<Map<String, dynamic>> _eventos = [];
  Map<String, dynamic>? _eventoSeleccionado;



  Map<String, double> _notasDocente = {};

  List<CategoriaData> _categoriasData = [];

  List<CategoriaData>? _filtradosCache;
  String _busquedaCache = '';

  final _searchCtrl = TextEditingController();
  String _busqueda  = '';
  ModoVista _modoVista = ModoVista.lista;

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

      await _service.cargarEstudiantesParaResolucion(
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
        filialId:  _filialId,
        facultad:  _facultad,
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
    _categoriasData  = [];
    _filtradosCache  = null;
    _busquedaCache   = '';
    _totalProyectos  = 0;
    _totalConEval    = 0;
    _busqueda        = '';
    _notasDocente    = {};
    _searchCtrl.clear();
    _animCtrl.reset();

    setState(() {
      _eventoSeleccionado      = evento;
      _isLoadingParticipantes  = true;
      _modoVista               = ModoVista.lista;
    });

    try {

      final notasDoc =
          await _service.obtenerNotasDocente(evento['id'] as String);

      final categorias =
          await _service.cargarParticipantes(evento['id'] as String, notasDoc);
      if (!mounted) return;

      int proj = 0, eval = 0;
      for (final c in categorias) {
        proj += c.proyectos.length;
        for (final p in c.proyectos) {
          if (p['tieneEvaluaciones'] == true) eval++;
        }
      }

      setState(() {
        _notasDocente           = notasDoc;
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

  List<CategoriaData> get _datosFiltrados {
    if (_busqueda == _busquedaCache && _filtradosCache != null) {
      return _filtradosCache!;
    }
    if (_busqueda.isEmpty) {
      _filtradosCache = _categoriasData;
      _busquedaCache  = '';
      return _filtradosCache!;
    }

    final q = _busqueda.toLowerCase();
    final resultado = <CategoriaData>[];

    for (final cat in _categoriasData) {
      final filtrados = cat.proyectos.where((p) {
        return formatearTexto(p['titulo']).toLowerCase().contains(q)      ||
               formatearTexto(p['codigo']).toLowerCase().contains(q)      ||
               formatearTexto(p['integrantes']).toLowerCase().contains(q) ||
               formatearTexto(p['asesor']).toLowerCase().contains(q);
      }).toList();
      if (filtrados.isNotEmpty) {
        resultado.add(CategoriaData(nombre: cat.nombre, proyectos: filtrados));
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


  Future<void> _importarNotasDocente() async {
    if (_eventoSeleccionado == null) return;
    final eventId = _eventoSeleccionado!['id'] as String;

    setState(() => _isImportandoNotas = true);
    try {
      final result = await _service.importarNotasDocenteDesdeExcel(
        eventId,
        filialNombre: _filialNombre,
        filialId: _filialId,
        carreraNombre: _carrera,
        carreraId: _carreraId,
      );

      if (result == null) {

        if (mounted) setState(() => _isImportandoNotas = false);
        return;
      }

      if (result.errores.isNotEmpty) {
        _snack(
          'Importado con advertencias: ${result.errores.first}',
          isError: true,
        );
      }


      final notasDoc = await _service.obtenerNotasDocente(eventId);
      final categorias = await _service.cargarParticipantes(eventId, notasDoc);

      int proj = 0, eval = 0;
      for (final c in categorias) {
        proj += c.proyectos.length;
        for (final p in c.proyectos) {
          if (p['tieneEvaluaciones'] == true) eval++;
        }
      }

      if (mounted) {
        _filtradosCache = null;
        setState(() {
          _notasDocente           = notasDoc;
          _categoriasData         = categorias;
          _totalProyectos         = proj;
          _totalConEval           = eval;
          _isImportandoNotas      = false;
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
            'El ranking se calculará solo con notas de jurado.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
      await _service.eliminarNotasDocente(eventId);
      final categorias = await _service.cargarParticipantes(eventId, {});

      int proj = 0, eval = 0;
      for (final c in categorias) {
        proj += c.proyectos.length;
        for (final p in c.proyectos) {
          if (p['tieneEvaluaciones'] == true) eval++;
        }
      }

      if (mounted) {
        _filtradosCache = null;
        setState(() {
          _notasDocente      = {};
          _categoriasData    = categorias;
          _totalProyectos    = proj;
          _totalConEval      = eval;
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
            const CircularProgressIndicator(color: PColores.primary),
            const SizedBox(height: 20),
            const Text('Generando reporte Excel...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              '$_totalProyectos proyectos · ${formatearTexto(_eventoSeleccionado!['name'])}',
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
        eventoNombre: formatearTexto(_eventoSeleccionado!['name']),
        filialNombre: formatearTexto(_filialNombre),
        facultad:     formatearTexto(_facultad),
        carrera:      _carrera,
        escalaBase:   escalaBaseParticipantes,
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
                backgroundColor: PColores.primary,
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
                      'Reporte de Participantes – ${formatearTexto(_eventoSeleccionado!['name'])}',
                );
              },
              icon:  const Icon(Icons.share, size: 20),
              label: const Text('Compartir',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: PColores.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: PColores.primary, width: 1.5),
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
                : PColores.primary,
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
      builder: (_) => DetalleProyectoSheet(proyecto: proyecto, posicion: pos),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PColores.primary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: PColores.bg,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
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
                Text('Ranking normalizado a /${escalaBaseParticipantes} pts',
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
            if (!_isLoadingParticipantes && _categoriasData.isNotEmpty)
              VistaToggle(
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
          ContextCard(
            carrera:      formatearTexto(_carrera),
            facultad:     formatearTexto(_facultad),
            filialNombre: formatearTexto(_filialNombre),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PColores.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_outlined,
                    color: PColores.primary, size: 20),
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
                            color: PColores.primary)),
                    SizedBox(height: 2),
                    Text('Elige el evento para ver todos sus participantes',
                        style: TextStyle(
                            fontSize: 12, color: PColores.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingEventos)
            const CenteredLoader(mensaje: 'Cargando eventos...')
          else if (_eventos.isEmpty)
            const EmptyState(
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
              itemBuilder: (_, i) => EventoCard(
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
        EventoBanner(
          nombre:          formatearTexto(_eventoSeleccionado!['name']),
          totalProyectos:  _totalProyectos,
          totalCategorias: _categoriasData.length,
          totalConEval:    _totalConEval,
          tieneNotaDocente: _notasDocente.isNotEmpty,
          cantidadCodigos:  _notasDocente.length,
          onTap: () {
            _filtradosCache = null;
            setState(() {
              _eventoSeleccionado = null;
              _categoriasData     = [];
              _totalProyectos     = 0;
              _totalConEval       = 0;
              _notasDocente       = {};
            });
          },
        ),
        if (!_isLoadingParticipantes && _categoriasData.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: SearchBarParticipantes(
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
              ? const CenteredLoader(mensaje: 'Cargando participantes...')
              : _categoriasData.isEmpty
                  ? const EmptyState(
                      icon:      Icons.groups_outlined,
                      iconColor: PColores.primary,
                      titulo:    'Sin proyectos registrados',
                      subtitulo: 'Este evento aún no tiene proyectos cargados.',
                    )
                  : _datosFiltrados.isEmpty
                      ? _buildSinResultados()
                      : FadeTransition(
                          opacity: _fadeAnim,
                          child: _modoVista == ModoVista.lista
                              ? _buildLista(_datosFiltrados)
                              : _buildTabla(_datosFiltrados),
                        ),
        ),
      ],
    );
  }

  Widget _buildLista(List<CategoriaData> datos) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => CategoriaAcordeon(
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
            child: BotonExportarExcelParticipantes(
              cargando:  _isGeneratingExcel || _isLoadingParticipantes,
              generando: _isGeneratingExcel,
              onPressed: _exportarExcel,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabla(List<CategoriaData> datos) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => TablaCategoria(
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
            child: BotonExportarExcelParticipantes(
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
                size: 56, color: PColores.textSecondary),
            const SizedBox(height: 16),
            const Text('Sin resultados',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: PColores.primary)),
            const SizedBox(height: 8),
            Text('No se encontraron proyectos para "$_busqueda".',
                style: const TextStyle(
                    fontSize: 13, color: PColores.textSecondary, height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
