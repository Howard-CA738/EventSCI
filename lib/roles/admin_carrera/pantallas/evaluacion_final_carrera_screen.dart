import 'dart:async';
import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import '../datos/eval_final_config.dart';
import '../datos/nota_final_item.dart';
import '../logica/evaluacion_final_carrera_service.dart';
import 'widgets/boton_exportar_evaluacion_final.dart';
import 'widgets/config_bottom_sheet.dart';

class EvaluacionFinalCarreraScreen extends StatefulWidget {
  final String filialId;
  final String filialNombre;
  final String facultad;
  final String carrera;

  const EvaluacionFinalCarreraScreen({
    required this.filialId,
    required this.filialNombre,
    required this.facultad,
    required this.carrera,
    super.key,
  });

  @override
  State<EvaluacionFinalCarreraScreen> createState() =>
      _EvaluacionFinalCarreraScreenState();
}

class _EvaluacionFinalCarreraScreenState
    extends State<EvaluacionFinalCarreraScreen>
    with SingleTickerProviderStateMixin {
  final _service = EvaluacionFinalCarreraService();

  String? _filialId;
  String? _facultad;
  String? _carreraId;
  bool _isLoadingSession = true;

  List<Map<String, dynamic>> _eventos = [];
  String? _eventoId;
  String? _eventoNombre;
  bool _isLoadingEventos = false;

  EvalFinalConfig _config = EvalFinalConfig();
  bool _configCargada = false;

  List<NotaFinalItem> _notas = [];
  bool _isCalculando = false;
  bool _calculoDone = false;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQ = '';
  bool _ordenDesc = true;

  String _filtro = 'todos';

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  String _docIdConfig(String eventoId) => _service.docIdConfig(
        filialId: _filialId,
        facultad: _facultad,
        carreraId: _carreraId,
        eventoId: eventoId,
      );

  String _docIdSellos(String eventoId) => _service.docIdSellos(
        filialId: _filialId,
        facultad: _facultad,
        carreraId: _carreraId,
        eventoId: eventoId,
      );

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadSession();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    setState(() => _isLoadingSession = true);
    try {
      final data = await PrefsHelper.getAdminCarreraData();
      if (data != null) {
        setState(() {
          _filialId = data['filial'];
          _facultad = data['facultad'];
          _carreraId = data['carreraId'] ?? data['carrera'];
        });
        await _cargarEventos();
      }
    } catch (e) {
      _snack('Error de sesión: $e', isError: true);
    } finally {
      setState(() => _isLoadingSession = false);
    }
  }

  Future<void> _cargarEventos() async {
    setState(() => _isLoadingEventos = true);
    try {
      final eventos = await _service.cargarEventos(
        filialId: _filialId,
        facultad: _facultad,
        carreraId: _carreraId,
      );
      setState(() => _eventos = eventos);
    } catch (e) {
      _snack('Error al cargar eventos: $e', isError: true);
    } finally {
      setState(() => _isLoadingEventos = false);
    }
  }

  Future<void> _cargarConfig(String eventoId) async {
    final config = await _service.cargarConfig(_docIdConfig(eventoId));
    setState(() {
      _config = config;
      _configCargada = true;
    });
  }

  Future<void> _guardarConfig() async {
    if (_eventoId == null) return;

    if (_config.incluirDocenteNoSel) {
      final sum = _config.pctAsistNoSel + _config.pctDocenteNoSel;
      if ((sum - 100).abs() > 0.5) {
        _snack(
            'No seleccionados: los porcentajes deben sumar 100% (actual: ${sum.toStringAsFixed(1)}%)',
            isError: true);
        return;
      }
    }

    if (_config.modalidad == 'jurado') {
      final sum = _config.pctAsistSel + _config.pctJuradoSel;
      if ((sum - 100).abs() > 0.5) {
        _snack(
            'Seleccionados (jurado): los porcentajes deben sumar 100% (actual: ${sum.toStringAsFixed(1)}%)',
            isError: true);
        return;
      }
    } else {
      final sum = _config.pctAsistSelMixta +
          _config.pctJuradoSelMixta +
          _config.pctDocenteSelMixta;
      if ((sum - 100).abs() > 0.5) {
        _snack(
            'Seleccionados (mixta): los porcentajes deben sumar 100% (actual: ${sum.toStringAsFixed(1)}%)',
            isError: true);
        return;
      }
    }

    try {
      await _service.guardarConfig(
        docId: _docIdConfig(_eventoId!),
        config: _config,
      );
      _snack('Configuración guardada ✓');
    } catch (e) {
      _snack('Error al guardar config: $e', isError: true);
    }
  }

  Future<void> _calcularNotas() async {
    final eventoId = _eventoId;
    if (eventoId == null) return;
    setState(() {
      _isCalculando = true;
      _notas = [];
      _calculoDone = false;
    });

    try {
      final resultados = await _service.calcularNotas(
        eventoId: eventoId,
        filialNombreWidget: widget.filialNombre,
        carreraWidget: widget.carrera,
        filialId: _filialId,
        carreraId: _carreraId,
        docIdSellos: _docIdSellos(eventoId),
        config: _config,
      );

      setState(() {
        _notas = resultados;
        _calculoDone = true;
      });
      _animCtrl.reset();
      unawaited(_animCtrl.forward());
    } catch (e) {
      _snack('Error al calcular: $e', isError: true);
    } finally {
      setState(() => _isCalculando = false);
    }
  }

  List<NotaFinalItem> get _notasFiltradas {
    final lista = _notas.where((n) {
      if (_filtro == 'seleccionados') return n.seleccionado;
      if (_filtro == 'no_seleccionados') return !n.seleccionado;
      return true;
    }).where((n) {
      if (_searchQ.isEmpty) return true;
      final q = _searchQ.toLowerCase();
      return n.nombre.toLowerCase().contains(q) ||
          n.codigo.toLowerCase().contains(q) ||
          n.proyectoCodigo.toLowerCase().contains(q);
    }).toList();

    lista.sort((a, b) {
      final c = a.notaFinal.compareTo(b.notaFinal);
      return _ordenDesc ? -c : c;
    });
    return lista;
  }

  Color _colorNota(double n) {
    if (n >= 17) return EColores.green;
    if (n >= 14) return EColores.accent;
    if (n >= 11) return EColores.orange;
    if (n >= 7) return const Color(0xFFEA580C);
    return EColores.red;
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? EColores.red : EColores.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EColores.navy,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: EColores.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: (_isLoadingSession || _isLoadingEventos)
                    ? const Center(
                        child: CircularProgressIndicator(color: EColores.navy))
                    : _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Evaluación Final',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3)),
                Text(
                  widget.carrera,
                  style: TextStyle(
                      fontSize: 12, color: Colors.white.withValues(alpha: 0.65)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_eventoId != null)
            GestureDetector(
              onTap: _abrirConfig,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: EColores.purple.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: EColores.purple.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded, color: Colors.white, size: 17),
                    SizedBox(width: 5),
                    Text('Config',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: _buildSelectorEvento(),
        ),
        Expanded(
          child: _isCalculando
              ? _buildCalculando()
              : !_calculoDone
                  ? _buildEstadoInicial()
                  : _buildResultados(),
        ),
      ],
    );
  }

  Widget _buildSelectorEvento() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EColores.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: EColores.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_rounded,
                    color: EColores.teal, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Seleccionar evento',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: EColores.navy)),
            ],
          ),
          const SizedBox(height: 12),
          if (_eventos.isEmpty)
            _infoBox('No hay eventos disponibles para esta carrera.',
                EColores.orange, Icons.event_busy_rounded)
          else
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _eventoId != null ? EColores.teal : EColores.border,
                  width: 1.5,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _eventoId,
                  isExpanded: true,
                  hint: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Elige un evento...',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13)),
                  ),
                  icon: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(Icons.arrow_drop_down,
                        color: Colors.grey.shade600),
                  ),
                  items: _eventos
                      .map((e) => DropdownMenuItem<String?>(
                            value: e['id'] as String,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.event,
                                      size: 18, color: EColores.teal),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(e['name'],
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: EColores.navy,
                                            fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final nombre =
                        _eventos.firstWhere((e) => e['id'] == v)['name'] as String;
                    setState(() {
                      _eventoId = v;
                      _eventoNombre = nombre;
                      _notas = [];
                      _calculoDone = false;
                      _configCargada = false;
                    });
                    unawaited(_cargarConfig(v));
                  },
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ),
          if (_eventoId != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCalculando ? null : _calcularNotas,
                icon: const Icon(Icons.calculate_rounded, size: 20),
                label: Text(
                  _calculoDone ? 'Recalcular notas' : 'Calcular notas finales',
                  style:
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EColores.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEstadoInicial() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calculate_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              _eventoId == null
                  ? 'Selecciona un evento'
                  : 'Presiona "Calcular notas finales"',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: EColores.navy),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _eventoId == null
                  ? 'Elige un evento para comenzar el cálculo'
                  : 'Se ponderarán asistencias, jurados y docentes\nsegún la configuración activa',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade500, height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (_eventoId != null && _configCargada) ...[
              const SizedBox(height: 20),
              _buildResumenConfig(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalculando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: EColores.teal),
          SizedBox(height: 16),
          Text('Calculando notas finales...',
              style: TextStyle(color: EColores.txt2, fontSize: 14)),
          SizedBox(height: 6),
          Text('Esto puede tomar unos segundos',
              style: TextStyle(color: EColores.txt3, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildResultados() {
    final filtradas = _notasFiltradas;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                _buildStatsCard(),
                const SizedBox(height: 12),
                _buildFiltrosYBusqueda(),
                const SizedBox(height: 12),
                _buildBotonExportar(),
              ],
            ),
          ),
          Expanded(
            child: filtradas.isEmpty
                ? Center(
                    child: Text('Sin resultados',
                        style:
                            TextStyle(color: Colors.grey.shade500, fontSize: 14)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: filtradas.length,
                    itemBuilder: (ctx, i) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 200 + (i * 35)),
                        curve: Curves.easeOut,
                        builder: (c, v, _) => Transform.translate(
                          offset: Offset(0, 14 * (1 - v)),
                          child: Opacity(
                              opacity: v, child: _buildStudentCard(filtradas[i], i)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_notas.isEmpty) return const SizedBox.shrink();

    final sel = _notas.where((n) => n.seleccionado).length;
    final noSel = _notas.length - sel;
    final aprobados = _notas.where((n) => n.notaFinal >= 11).length;
    final prom =
        _notas.map((n) => n.notaFinal).reduce((a, b) => a + b) / _notas.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [EColores.navy, EColores.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: EColores.navy.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _eventoNombre ?? '',
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statItem('Total', '${_notas.length}', Colors.white),
              _vDivider(),
              _statItem('Seleccion.', '$sel', const Color(0xFF86EFAC)),
              _vDivider(),
              _statItem('Sin exp.', '$noSel', Colors.amber),
              _vDivider(),
              _statItem('Aprobados', '$aprobados', const Color(0xFF6EE7B7)),
              _vDivider(),
              _statItem(
                  'Promedio', prom.toStringAsFixed(1), const Color(0xFF93C5FD)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String val, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(val,
              style:
                  TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 32,
        color: Colors.white.withValues(alpha: 0.15),
      );

  Widget _buildFiltrosYBusqueda() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: EColores.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: EColores.border),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQ = v),
              style: const TextStyle(fontSize: 13, color: EColores.navy),
              decoration: InputDecoration(
                hintText: 'Buscar...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search, color: Colors.grey.shade400, size: 18),
                suffixIcon: _searchQ.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close,
                            color: Colors.grey.shade400, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQ = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _filtroBtn(),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() => _ordenDesc = !_ordenDesc),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: EColores.navy,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  _ordenDesc
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _ordenDesc ? 'Mayor' : 'Menor',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _filtroBtn() {
    final opciones = {
      'todos': 'Todos',
      'seleccionados': 'Exponen',
      'no_seleccionados': 'Sin exp.',
    };
    return PopupMenuButton<String>(
      initialValue: _filtro,
      onSelected: (v) => setState(() => _filtro = v),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => opciones.entries
          .map((e) => PopupMenuItem(
                value: e.key,
                child: Text(e.value, style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: EColores.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: EColores.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.filter_list_rounded, color: EColores.navy, size: 18),
            const SizedBox(width: 4),
            Text(opciones[_filtro]!,
                style: const TextStyle(
                    color: EColores.navy, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonExportar() {
    return SizedBox(
      width: double.infinity,
      child: BotonExportarEvaluacionFinal(
        notas: _notas,
        config: _config,
        eventoNombre: _eventoNombre ?? '',
        filialNombre: widget.filialNombre,
        facultad: widget.facultad,
        carrera: widget.carrera,
        onExportado: (path) async {},
      ),
    );
  }

  Widget _buildStudentCard(NotaFinalItem n, int index) {
    final color = _colorNota(n.notaFinal);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: EColores.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: n.seleccionado ? EColores.teal.withValues(alpha: 0.3) : EColores.border,
          width: n.seleccionado ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: index < 3
                        ? [
                            const Color(0xFFFFD700),
                            const Color(0xFFC0C0C0),
                            const Color(0xFFCD7F32),
                          ][index]
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${index + 1}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color:
                                index < 3 ? Colors.white : Colors.grey.shade600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.nombre,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold, color: EColores.navy),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (n.codigo.isNotEmpty)
                            Text(n.codigo,
                                style: const TextStyle(fontSize: 10, color: EColores.txt3)),
                          if (n.ciclo.isNotEmpty) _miniTag('C${n.ciclo}', EColores.accent),
                          if (n.grupo.isNotEmpty) _miniTag('G${n.grupo}', EColores.purple),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: n.seleccionado ? EColores.tealL : EColores.orangeL,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  n.seleccionado
                                      ? Icons.present_to_all_rounded
                                      : Icons.person_rounded,
                                  size: 9,
                                  color: n.seleccionado ? EColores.teal : EColores.orange,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  n.seleccionado ? 'Expone' : 'Sin exp.',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: n.seleccionado ? EColores.teal : EColores.orange),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Text(
                    n.notaFinal.toStringAsFixed(1),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _notaChip('Asist.', n.notaAsist, EColores.accent),
                const SizedBox(width: 6),
                if (n.seleccionado) _notaChip('Jurado', n.notaJurado, EColores.purple),
                if (n.seleccionado) const SizedBox(width: 6),
                _notaChip('Docente', n.notaDocente, EColores.orange,
                    isEmpty: n.notaDocente == 0),
                if (n.seleccionado && n.proyectoCodigo.isNotEmpty) ...[
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.assignment_rounded, size: 11, color: EColores.txt3),
                      const SizedBox(width: 3),
                      Text(n.proyectoCodigo,
                          style: const TextStyle(
                              fontSize: 10, color: EColores.txt3, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _notaChip(String label, double nota, Color color, {bool isEmpty = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isEmpty ? Colors.grey.shade100 : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEmpty ? EColores.border : color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            isEmpty ? '—' : nota.toStringAsFixed(1),
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: isEmpty ? EColores.txt3 : color),
          ),
          Text(label,
              style: const TextStyle(fontSize: 9, color: EColores.txt3, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _miniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _infoBox(String msg, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: TextStyle(color: color, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildResumenConfig() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EColores.purpleL,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EColores.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: EColores.purple, size: 15),
              SizedBox(width: 6),
              Text('Configuración activa',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: EColores.purple)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Sin exponer: Asist. ${_config.pctAsistNoSel.toStringAsFixed(0)}%'
            '${_config.incluirDocenteNoSel ? ' / Docente ${_config.pctDocenteNoSel.toStringAsFixed(0)}%' : ''}',
            style: const TextStyle(fontSize: 11, color: EColores.txt2),
          ),
          const SizedBox(height: 3),
          Text(
            _config.modalidad == 'jurado'
                ? '• Expone (Solo jurado): Asist. ${_config.pctAsistSel.toStringAsFixed(0)}% / Jurado ${_config.pctJuradoSel.toStringAsFixed(0)}%'
                : '• Expone (Mixta): Asist. ${_config.pctAsistSelMixta.toStringAsFixed(0)}% / Jurado ${_config.pctJuradoSelMixta.toStringAsFixed(0)}% / Docente ${_config.pctDocenteSelMixta.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 11, color: EColores.txt2),
          ),
        ],
      ),
    );
  }

  void _abrirConfig() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConfigBottomSheet(
        config: EvalFinalConfig.fromMap(_config.toMap()..remove('updatedAt')),
        onGuardar: (nuevaConfig) async {
          setState(() => _config = nuevaConfig);
          await _guardarConfig();
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }
}
