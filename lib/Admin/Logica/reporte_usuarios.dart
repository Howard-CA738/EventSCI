import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'reporte_usuarios_service.dart';
import 'usuarios_excel_service.dart';
import 'reporte_final_service.dart';
import 'reporte_final_excel_service.dart';
import 'reporte_certificados_service.dart';
import 'reporte_certificados_excel_service.dart';

class ReporteUsuariosScreen extends StatefulWidget {
  const ReporteUsuariosScreen({super.key});

  @override
  State<ReporteUsuariosScreen> createState() => _ReporteUsuariosScreenState();
}

class _ReporteUsuariosScreenState extends State<ReporteUsuariosScreen> {
  final ReporteUsuariosService _service = ReporteUsuariosService();
  final UsuariosExcelService _excel = UsuariosExcelService();
  final ReporteFinalService _finalService = ReporteFinalService();
  final ReporteFinalExcelService _finalExcel = ReporteFinalExcelService();
  final ReporteCertificadosService _certService = ReporteCertificadosService();
  final ReporteCertificadosExcelService _certExcel =
      ReporteCertificadosExcelService();

  late Future<List<FilialResumen>> _futureResumen;

  bool _isExporting = false;
  String _exportMsg = '';

  static const _navy = Color(0xFF1E3A5F);
  static const _bg = Color(0xFFE8EDF2);

  @override
  void initState() {
    super.initState();
    _futureResumen = _service.getResumen();
  }

  Future<void> _refrescar() async {
    _service.invalidarCache();
    setState(() => _futureResumen = _service.getResumen(forceRefresh: true));
  }

  void _msg(String texto, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: err ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  Future<void> _exportarTodo() async {
    setState(() {
      _isExporting = true;
      _exportMsg = 'Generando Excel...';
    });
    try {
      final resumen = await _service.getResumen();
      final path = await _excel.generarReporte(resumen: resumen);

      if (!mounted) return;
      setState(() => _isExporting = false);

      if (path == null) {
        _msg('No se pudo generar el archivo', err: true);
        return;
      }
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Reporte de eventos por carrera',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        _msg('Error al exportar: $e', err: true);
      }
    }
  }


  Future<void> _exportarReporteFinal() async {
    setState(() {
      _isExporting = true;
      _exportMsg = 'Generando Reporte Final...';
    });
    try {
      final resumen = await _service.getResumen();
      final filas = await _finalService.getReporteFinal(resumen: resumen);
      final path = await _finalExcel.generarReporte(filas: filas);

      if (!mounted) return;
      setState(() => _isExporting = false);

      if (path == null) {
        _msg('No se pudo generar el archivo', err: true);
        return;
      }
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Reporte Final de eventos científicos',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        _msg('Error al exportar: $e', err: true);
      }
    }
  }


  Future<void> _abrirReporteCertificados() async {
    setState(() {
      _isExporting = true;
      _exportMsg = 'Cargando estructura...';
    });
    List<EscuelaItem> estructura;
    try {
      estructura = await _certService.getEstructura();
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        _msg('Error al cargar estructura: $e', err: true);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _isExporting = false);

    if (estructura.isEmpty) {
      _msg('No hay escuelas con eventos', err: true);
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CertificadosSheet(
        estructura: estructura,
        service: _certService,
        excel: _certExcel,
      ),
    );
  }


  Future<void> _exportarCarrera(
    CarreraResumen c,
    String filialNombre,
  ) async {
    setState(() {
      _isExporting = true;
      _exportMsg = 'Generando ${c.carrera}...';
    });
    try {
      final resumen = [
        FilialResumen(c.filialId, filialNombre, [
          FacultadResumen(c.facultad, [c]),
        ]),
      ];
      final path = await _excel.generarReporte(resumen: resumen);

      if (!mounted) return;
      setState(() => _isExporting = false);

      if (path == null) {
        _msg('No se pudo generar el archivo', err: true);
        return;
      }
      await Share.shareXFiles([XFile(path)], text: 'Eventos — ${c.carrera}');
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        _msg('Error al exportar: $e', err: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fab_certificados',
            onPressed: _isExporting ? null : _abrirReporteCertificados,
            backgroundColor: const Color(0xFF0F6E56),
            icon: const Icon(Icons.workspace_premium),
            label: const Text('Certificados'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'fab_reporte_final',
            onPressed: _isExporting ? null : _exportarReporteFinal,
            backgroundColor: const Color(0xFF7C3AED),
            icon: const Icon(Icons.assignment_turned_in),
            label: const Text('Reporte Final'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'fab_exportar_todo',
            onPressed: _isExporting ? null : _exportarTodo,
            backgroundColor: _navy,
            icon: const Icon(Icons.download),
            label: const Text('Exportar Excel'),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      child: FutureBuilder<List<FilialResumen>>(
                        future: _futureResumen,
                        builder: (context, snap) {
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snap.hasError) {
                            return _buildError('${snap.error}');
                          }
                          final data = snap.data ?? [];
                          if (data.isEmpty) return _buildVacio();
                          return _buildContenido(data);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isExporting) _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Volver',
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.insights, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Reporte de Eventos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isExporting ? null : _refrescar,
            tooltip: 'Actualizar',
          ),
        ],
      ),
    );
  }

  Widget _buildContenido(List<FilialResumen> data) {
    int totalEventos = 0;
    int totalPagaron = 0;
    int totalAsistieron = 0;
    for (final f in data) {
      totalEventos += f.totalEventos;
      for (final fa in f.facultades) {
        for (final c in fa.carreras) {
          totalPagaron += c.totalPagaron;
          totalAsistieron += c.totalAsistieron;
        }
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Row(
            children: [
              Expanded(
                  child: _buildStat(
                      'Eventos', '$totalEventos', Icons.event, _navy)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStat('Inscritos', '$totalPagaron',
                      Icons.payments, Colors.indigo)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStat('Asistieron', '$totalAsistieron',
                      Icons.how_to_reg, Colors.green)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 230),
            itemCount: data.length,
            itemBuilder: (context, i) => _buildFilial(data[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildFilial(FilialResumen filial) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('filial_${filial.filialId}'),
          initiallyExpanded: true,
          leading: const Icon(Icons.location_city, color: _navy),
          title: Text(
            filial.filialNombre,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _navy,
              fontSize: 15,
            ),
          ),
          trailing: _badge('${filial.totalEventos} ev.'),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children:
              filial.facultades.map((f) => _buildFacultad(filial, f)).toList(),
        ),
      ),
    );
  }

  Widget _buildFacultad(FilialResumen filial, FacultadResumen facultad) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('fac_${filial.filialId}_${facultad.nombre}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Icon(Icons.business, color: Colors.grey[700], size: 20),
          title: Text(
            facultad.nombre,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
              fontSize: 13,
            ),
          ),
          trailing: _badge('${facultad.totalEventos} ev.', soft: true),
          children: facultad.carreras
              .map((c) => _buildCarrera(filial, c))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCarrera(FilialResumen filial, CarreraResumen carrera) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('car_${carrera.carreraPath}'),
        tilePadding: const EdgeInsets.only(left: 28, right: 8),
        leading: Icon(Icons.school_outlined,
            color: Colors.grey[600], size: 18),
        title: Text(
          carrera.carrera,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
        subtitle: Text(
          '${carrera.matriculados} matriculados',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _badge('${carrera.eventos.length}', soft: true),
            IconButton(
              icon: const Icon(Icons.download, size: 20, color: _navy),
              tooltip: 'Exportar esta carrera',
              onPressed: () =>
                  _exportarCarrera(carrera, filial.filialNombre),
            ),
          ],
        ),
        children: carrera.eventos
            .map((e) => _buildEventoCard(e, carrera.matriculados))
            .toList(),
      ),
    );
  }

  Widget _buildEventoCard(EventoResumen ev, int matriculados) {
    final pct = ev.pctAsistioVsPago.clamp(0, 100).toDouble();
    return Container(
      margin: const EdgeInsets.fromLTRB(40, 4, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note, size: 16, color: _navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ev.eventName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: _navy,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (ev.periodoNombre.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                ev.periodoNombre,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _miniStat('Matriculados', '$matriculados', Colors.blueGrey),
              _divider(),
              _miniStat('Inscritos', '${ev.pagaron}', Colors.indigo),
              _divider(),
              _miniStat('Asistieron', '${ev.asistieron}', Colors.green),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.green),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${pct.toStringAsFixed(0)}% asistió',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 30, color: Colors.grey.shade200);

  Widget _badge(String text, {bool soft = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: soft ? _navy.withValues(alpha: 0.08) : _navy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: soft ? _navy : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text('Error al cargar: $error',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refrescar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Aún no hay eventos creados',
              style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(28),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 18),
                Text(
                  _exportMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}




enum _ModoRep { matriculados, inscritos, porSellos }




class _CertificadosSheet extends StatefulWidget {
  final List<EscuelaItem> estructura;
  final ReporteCertificadosService service;
  final ReporteCertificadosExcelService excel;

  const _CertificadosSheet({
    required this.estructura,
    required this.service,
    required this.excel,
  });

  @override
  State<_CertificadosSheet> createState() => _CertificadosSheetState();
}

class _CertificadosSheetState extends State<_CertificadosSheet> {
  static const _navy = Color(0xFF1E3A5F);

  String? _filial;
  String? _facultad;
  EscuelaItem? _escuela;
  EventoItem? _evento;

  List<EventoItem> _eventos = [];
  bool _cargandoEventos = false;

  int _meta = 0;
  int _minimo = 1;
  bool _cargandoConfig = false;

  List<CertificadoRow> _filas = [];
  bool _generando = false;

  _ModoRep _modo = _ModoRep.porSellos;


  List<String> get _filiales =>
      widget.estructura.map((e) => e.filialNombre).toSet().toList()..sort();

  List<String> get _facultades => widget.estructura
      .where((e) => e.filialNombre == _filial)
      .map((e) => e.facultad)
      .toSet()
      .toList()
    ..sort();

  List<EscuelaItem> get _escuelas => widget.estructura
      .where((e) => e.filialNombre == _filial && e.facultad == _facultad)
      .toList()
    ..sort((a, b) => a.carreraNombre.compareTo(b.carreraNombre));

  int get _conMinimo => _modo == _ModoRep.porSellos
      ? _filas.where((f) => f.sellos >= _minimo).length
      : _filas.length;

  void _msg(String t, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t),
      backgroundColor: err ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _onEscuela(EscuelaItem esc) async {
    setState(() {
      _escuela = esc;
      _evento = null;
      _eventos = [];
      _filas = [];
      _meta = 0;
      _minimo = 1;
      _cargandoEventos = true;
    });
    try {
      final ev = await widget.service.getEventos(esc);
      if (mounted) setState(() => _eventos = ev);
    } catch (e) {
      if (mounted) _msg('Error cargando eventos: $e', err: true);
    } finally {
      if (mounted) setState(() => _cargandoEventos = false);
    }
  }

  Future<void> _onEvento(EventoItem ev) async {
    setState(() {
      _evento = ev;
      _filas = [];
      _cargandoConfig = true;
    });
    try {
      final meta = await widget.service.getMetaSellos(_escuela!, ev.id);
      final filas = await _cargarFilas(ev.id);
      if (!mounted) return;
      setState(() {
        _meta = meta;
        _minimo = meta > 0 ? meta : 1;
        _filas = filas;
      });
    } catch (e) {
      if (mounted) _msg('Error cargando datos: $e', err: true);
    } finally {
      if (mounted) setState(() => _cargandoConfig = false);
    }
  }


  Future<List<CertificadoRow>> _cargarFilas(String eventoId) async {
    if (_modo == _ModoRep.matriculados) {
      return widget.service.getMatriculadosConSellos(
        escuela: _escuela!,
        eventoId: eventoId,
      );
    }

    return widget.service.getInscritosConSellos(
      escuela: _escuela!,
      eventoId: eventoId,
    );
  }


  Future<void> _cambiarModo(_ModoRep modo) async {
    if (_modo == modo) return;
    setState(() => _modo = modo);
    if (_evento == null) return;
    setState(() => _cargandoConfig = true);
    try {
      final filas = await _cargarFilas(_evento!.id);
      if (!mounted) return;
      setState(() => _filas = filas);
    } catch (e) {
      if (mounted) _msg('Error: $e', err: true);
    } finally {
      if (mounted) setState(() => _cargandoConfig = false);
    }
  }

  Future<void> _generar() async {
    setState(() => _generando = true);
    try {

      final roles = await widget.service.getReporteRoles(
        escuela: _escuela!,
        eventoId: _evento!.id,
        asistentes: _filas,
      );


      final minEfectivo = _modo == _ModoRep.porSellos ? _minimo : 0;

      final path = await widget.excel.generarReporte(
        escuela: _escuela!,
        eventoNombre: _evento!.name,
        minimoSellos: minEfectivo,
        metaSellos: _meta,
        roles: roles,
      );
      if (!mounted) return;
      setState(() => _generando = false);
      if (path == null) {
        _msg('No se pudo generar el archivo', err: true);
        return;
      }
      await Share.shareXFiles([XFile(path)],
          text: 'Reporte por roles — ${_escuela!.carreraNombre}');
    } catch (e) {
      if (mounted) {
        setState(() => _generando = false);
        _msg('Error: $e', err: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium, color: _navy),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Reporte de Certificados',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _navy)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [

                  _dropdown<String>(
                    label: 'Filial',
                    icon: Icons.location_city,
                    value: _filial,
                    items: _filiales,
                    itemLabel: (s) => s,
                    onChanged: (v) => setState(() {
                      _filial = v;
                      _facultad = null;
                      _escuela = null;
                      _evento = null;
                      _eventos = [];
                      _filas = [];
                    }),
                  ),
                  const SizedBox(height: 10),

                  _dropdown<String>(
                    label: 'Facultad',
                    icon: Icons.business,
                    value: _facultad,
                    items: _filial == null ? [] : _facultades,
                    itemLabel: (s) => s,
                    onChanged: (v) => setState(() {
                      _facultad = v;
                      _escuela = null;
                      _evento = null;
                      _eventos = [];
                      _filas = [];
                    }),
                  ),
                  const SizedBox(height: 10),

                  _dropdown<EscuelaItem>(
                    label: 'Escuela profesional',
                    icon: Icons.school,
                    value: _escuela,
                    items: _facultad == null ? [] : _escuelas,
                    itemLabel: (e) => e.carreraNombre,
                    onChanged: (v) {
                      if (v != null) _onEscuela(v);
                    },
                  ),
                  const SizedBox(height: 10),

                  if (_cargandoEventos)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                          child: CircularProgressIndicator(color: _navy)),
                    )
                  else if (_escuela != null)
                    _dropdown<EventoItem>(
                      label: 'Evento',
                      icon: Icons.event,
                      value: _evento,
                      items: _eventos,
                      itemLabel: (e) => e.name,
                      onChanged: (v) {
                        if (v != null) _onEvento(v);
                      },
                    ),
                  const SizedBox(height: 16),


                  if (_cargandoConfig)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                          child: CircularProgressIndicator(color: _navy)),
                    )
                  else if (_evento != null) ...[
                    _buildPanelSellos(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _generando ? null : _generar,
                        icon: _generando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.download),
                        label: Text(_generando
                            ? 'Generando...'
                            : 'Descargar Excel ($_conMinimo)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
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

  Widget _buildPanelSellos() {
    if (_filas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Text(
          _modo == _ModoRep.matriculados
              ? 'No hay estudiantes matriculados en esta carrera.'
              : 'No hay estudiantes inscritos (con pago) en este evento.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF78350F)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              _chipModo('Matriculados', _ModoRep.matriculados),
              const SizedBox(width: 6),
              _chipModo('Inscritos', _ModoRep.inscritos),
              const SizedBox(width: 6),
              _chipModo('Por sellos', _ModoRep.porSellos),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _stat(
                    _modo == _ModoRep.porSellos
                        ? 'Con $_minimo+ sellos'
                        : 'Total',
                    '$_conMinimo',
                    Colors.green.shade700),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _stat(
                    _modo == _ModoRep.matriculados
                        ? 'Matriculados'
                        : 'Inscritos',
                    '${_filas.length}',
                    _navy),
              ),
            ],
          ),

          if (_modo == _ModoRep.porSellos) ...[
            const SizedBox(height: 14),
            if (_meta <= 0)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text(
                  'Este evento no tiene meta de sellos configurada. '
                  'Puedes filtrar igual con el control de abajo.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mínimo de sellos',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$_minimo sellos',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Slider(
              value: _minimo.toDouble().clamp(
                  1, (_meta > 0 ? _meta : _maxSellos()).toDouble()),
              min: 1,
              max: (_meta > 0 ? _meta : _maxSellos()).toDouble().clamp(1, 999),
              divisions:
                  ((_meta > 0 ? _meta : _maxSellos()) - 1).clamp(1, 998),
              label: '$_minimo',
              activeColor: _navy,
              onChanged: (v) => setState(() => _minimo = v.round()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chipModo(String label, _ModoRep modo) {
    final activo = _modo == modo;
    return Expanded(
      child: GestureDetector(
        onTap: () => _cambiarModo(modo),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: activo ? _navy : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: activo ? _navy : Colors.grey.shade300),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: activo ? Colors.white : Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  int _maxSellos() {
    var m = 1;
    for (final f in _filas) {
      if (f.sellos > m) m = f.sellos;
    }
    return m;
  }

  Widget _stat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value != null ? _navy : Colors.grey.shade300,
          width: value != null ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Text(label,
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ],
          ),
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Row(
                      children: [
                        Icon(icon, size: 18, color: _navy),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(itemLabel(e),
                              style: const TextStyle(
                                  fontSize: 13, color: _navy),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}