import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '/roles/admin/logica/reporte_certificados_service.dart';
import '/roles/admin/logica/reporte_certificados_excel_service.dart';

enum _ModoRep { matriculados, inscritos, porSellos }

class CertificadosSheet extends StatefulWidget {
  final List<EscuelaItem> estructura;
  final ReporteCertificadosService service;
  final ReporteCertificadosExcelService excel;

  const CertificadosSheet({
    super.key,
    required this.estructura,
    required this.service,
    required this.excel,
  });

  @override
  State<CertificadosSheet> createState() => _CertificadosSheetState();
}

class _CertificadosSheetState extends State<CertificadosSheet> {
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
