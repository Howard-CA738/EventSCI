import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/resolver_nombres_service.dart';
import '/admin/logica/filiales_service.dart';

class _C {
  static const primary = Color(0xFF1E3A5F);
  static const primaryLight = Color(0xFF2D5590);
  static const gold = Color(0xFFFFD700);
  static const textSecondary = Color(0xFF64748B);
}

String _s(dynamic v, [String fb = '—']) {
  if (v == null) return fb;
  final s = v.toString().trim();
  return s.isEmpty ? fb : s;
}

String _sf(dynamic v, [int dec = 2]) {
  final d = v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  return d.toStringAsFixed(dec);
}

class VerGanadoresPorSalaScreen extends StatefulWidget {
  const VerGanadoresPorSalaScreen({super.key});

  @override
  State<VerGanadoresPorSalaScreen> createState() =>
      _VerGanadoresPorSalaScreenState();
}

class _VerGanadoresPorSalaScreenState extends State<VerGanadoresPorSalaScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FilialesService _filialesService = FilialesService();
  final _resolverNombres = ResolverNombresService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoadingInit = true;
  bool _isLoadingGanadores = false;

  // Todos los eventos (super admin ve de todas las filiales/facultades/carreras)
  List<Map<String, dynamic>> _eventos = [];
  Map<String, dynamic>? _eventoSeleccionado;

  // _ganadoresPorSala['Sala 1'] = { 'ganador': {...}, 'resto': [ {...}, ... ] }
  Map<String, Map<String, dynamic>> _ganadoresPorSala = {};

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
    _searchController.addListener(() => setState(() {}));
    _init();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _isLoadingInit = true);
    try {
      await _cargarTodosLosEventos();
    } catch (e) {
      _snack('Error al iniciar: $e', isError: true);
    }
    if (mounted) setState(() => _isLoadingInit = false);
  }

  /// Carga TODOS los eventos del sistema (sin filtrar por carrera).
  Future<void> _cargarTodosLosEventos() async {
    final snap = await _firestore.collection('events').get();

    final lista = snap.docs.map((doc) {
      final d = doc.data();
      final filialNombre = _s(d['filialNombre'], '').isNotEmpty
          ? d['filialNombre'] as String
          : _filialesService.getNombreFilial(_s(d['filialId'], ''));
      return {
        'id': doc.id,
        'name': _s(d['name'], 'Sin nombre'),
        'filialId': _s(d['filialId'], ''),
        'filialNombre': filialNombre,
        'facultad': _s(d['facultad'], ''),
        'carreraId': _s(d['carreraId'], ''),
        'carreraNombre': _s(d['carreraNombre'] ?? d['carrera'], ''),
        'periodoNombre': _s(d['periodoNombre'], ''),
        'createdAt': d['createdAt'],
      };
    }).toList();

    lista.sort((a, b) {
      final ta = a['createdAt'];
      final tb = b['createdAt'];
      if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
      if (ta is Timestamp) return -1;
      if (tb is Timestamp) return 1;
      return 0;
    });

    if (mounted) setState(() => _eventos = lista);
  }

  List<Map<String, dynamic>> get _eventosFiltrados {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _eventos;
    return _eventos.where((e) {
      final nombre = (e['name'] as String).toLowerCase();
      final carrera = (e['carreraNombre'] as String).toLowerCase();
      final filial = (e['filialNombre'] as String).toLowerCase();
      final facultad = (e['facultad'] as String).toLowerCase();
      return nombre.contains(q) ||
          carrera.contains(q) ||
          filial.contains(q) ||
          facultad.contains(q);
    }).toList();
  }

  Future<void> _seleccionarEvento(Map<String, dynamic> evento) async {
    setState(() {
      _eventoSeleccionado = evento;
      _ganadoresPorSala = {};
      _isLoadingGanadores = true;
    });
    _animCtrl.reset();

    try {
      await _resolverNombres.cargarEstudiantes(
        filialNombre: _s(evento['filialNombre'], ''),
        carrera: _s(evento['carreraNombre'], ''),
      );

      final ganadores = await _calcularGanadoresPorSala(evento['id'] as String);
      if (mounted) {
        setState(() {
          _ganadoresPorSala = ganadores;
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

  Future<Map<String, Map<String, dynamic>>> _calcularGanadoresPorSala(
      String eventoId) async {
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
            final notaTotal = ((data['notaTotal'] ?? 0.0) as num).toDouble();

            if (!data.containsKey('puntajeMaximo')) {
              continue;
            }

            final puntajeMax = (data['puntajeMaximo'] as num).toDouble();
            final maxSeguro = puntajeMax > 0 ? puntajeMax : escalaBase;
            final normalizada =
                ((notaTotal / maxSeguro) * escalaBase).clamp(0.0, escalaBase);

            notasNormalizadas.add(double.parse(normalizada.toStringAsFixed(2)));
          }

          if (notasNormalizadas.isEmpty) return null;

          final promedio = notasNormalizadas.reduce((a, b) => a + b) /
              notasNormalizadas.length;
          final notaMax = notasNormalizadas.reduce((a, b) => a > b ? a : b);
          final notaMin = notasNormalizadas.reduce((a, b) => a < b ? a : b);

          return {
            'proyectoId': doc.id,
            'codigo': _s(d['Código'], 'Sin código'),
            'titulo': _s(d['Título'], 'Sin título'),
            'integrantes': _resolverNombres.resolver(d['Integrantes']),
            'sala': _s(d['Sala'], 'Sin sala'),
            'clasificacion': _s(d['Clasificación'], 'Sin categoría'),
            'asesor': _s(d['Asesor'], ''),
            'descripcion': _s(d['Descripción'], ''),
            'promedio': double.parse(promedio.toStringAsFixed(2)),
            'notaMax': notaMax,
            'notaMin': notaMin,
            'cantidadJurados': notasNormalizadas.length,
            'notas': notasNormalizadas,
            'escalaBase': escalaBase,
          };
        } catch (_) {
          return null;
        }
      }),
    );

    final validos = results.whereType<Map<String, dynamic>>().toList();
    if (validos.isEmpty) return {};

    final Map<String, List<Map<String, dynamic>>> porSala = {};
    for (final p in validos) {
      final sala = p['sala'] as String;
      porSala.putIfAbsent(sala, () => []).add(p);
    }

    final Map<String, Map<String, dynamic>> resultado = {};
    for (final entry in porSala.entries) {
      final lista = entry.value
        ..sort((a, b) =>
            (b['promedio'] as double).compareTo(a['promedio'] as double));
      resultado[entry.key] = {
        'ganador': lista.first,
        'resto': lista.length > 1 ? lista.sublist(1) : <Map<String, dynamic>>[],
      };
    }
    return resultado;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ));
  }

  void _mostrarDetalle(Map<String, dynamic> proyecto, int posicion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _DetalleProyectoSheet(proyecto: proyecto, posicion: posicion),
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
                      ? const _CenteredLoader(mensaje: 'Cargando eventos...')
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
                Text('Ganadores por Sala',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        overflow: TextOverflow.ellipsis),
                    maxLines: 1),
                Text('1 ganador por cada sala',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (_eventoSeleccionado != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 22),
              onPressed: _isLoadingGanadores
                  ? null
                  : () => _seleccionarEvento(_eventoSeleccionado!),
              tooltip: 'Actualizar',
            ),
        ],
      ),
    );
  }

  Widget _buildSeleccionEvento() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: const _InfoSuperAdminCard(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por evento, carrera o filial...',
              hintStyle:
                  const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: _C.primary, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFF94A3B8), size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: _C.primary, width: 1.5)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _eventosFiltrados.isEmpty
              ? const _EmptyEventos()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    _SectionTitle(
                      icon: Icons.event_outlined,
                      titulo: 'Eventos (${_eventosFiltrados.length})',
                      subtitulo:
                          'Elige el evento para ver el ganador de cada sala',
                    ),
                    const SizedBox(height: 12),
                    ..._eventosFiltrados.map((e) => _EventoCard(
                          evento: e,
                          onTap: () => _seleccionarEvento(e),
                        )),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildResultados() {
    return Column(
      children: [
        _EventoBanner(
          nombre: _s(_eventoSeleccionado!['name']),
          subtitulo:
              '${_s(_eventoSeleccionado!['carreraNombre'])} · ${_s(_eventoSeleccionado!['filialNombre'])}',
          totalSalas: _ganadoresPorSala.length,
          onTap: () => setState(() {
            _eventoSeleccionado = null;
            _ganadoresPorSala = {};
          }),
        ),
        Expanded(
          child: _isLoadingGanadores
              ? const _CenteredLoader(mensaje: 'Calculando ganadores...')
              : _ganadoresPorSala.isEmpty
                  ? const _SinEvaluaciones()
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: _buildLista(),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildLista() {
    final salas = _ganadoresPorSala.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: salas.map((sala) {
        final data = _ganadoresPorSala[sala]!;
        return _SalaSection(
          sala: sala,
          ganador: data['ganador'] as Map<String, dynamic>,
          resto: (data['resto'] as List).cast<Map<String, dynamic>>(),
          onTapProyecto: (proyecto, posicion) =>
              _mostrarDetalle(proyecto, posicion),
        );
      }).toList(),
    );
  }
}

class _SalaSection extends StatelessWidget {
  final String sala;
  final Map<String, dynamic> ganador;
  final List<Map<String, dynamic>> resto;
  final void Function(Map<String, dynamic> proyecto, int posicion)
      onTapProyecto;

  const _SalaSection({
    required this.sala,
    required this.ganador,
    required this.resto,
    required this.onTapProyecto,
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
                  child: const Icon(Icons.meeting_room_outlined,
                      color: _C.gold, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(sala,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          overflow: TextOverflow.ellipsis),
                      maxLines: 1),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${resto.length + 1} proy.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: _GanadorCard(
              proyecto: ganador,
              onTap: () => onTapProyecto(ganador, 0),
            ),
          ),
          if (resto.isNotEmpty)
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                title: Text(
                  'Ver demás proyectos de la sala (${resto.length})',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _C.textSecondary),
                ),
                iconColor: _C.primary,
                collapsedIconColor: _C.textSecondary,
                children: List.generate(
                  resto.length,
                  (i) => _OtroProyectoRow(
                    proyecto: resto[i],
                    posicion: i + 2,
                    onTap: () => onTapProyecto(resto[i], i + 1),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _GanadorCard extends StatelessWidget {
  final Map<String, dynamic> proyecto;
  final VoidCallback onTap;

  const _GanadorCard({required this.proyecto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final promedio = (proyecto['promedio'] as num?)?.toDouble() ?? 0.0;
    final jurados = (proyecto['cantidadJurados'] as int?) ?? 0;
    final titulo = _s(proyecto['titulo'], 'Sin título');
    final codigo = _s(proyecto['codigo'], '—');
    final integrantes = _s(proyecto['integrantes'], '');
    final categoria = _s(proyecto['clasificacion'], '');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDE7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.gold.withValues(alpha: 0.6), width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _C.gold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border:
                    Border.all(color: _C.gold.withValues(alpha: 0.5), width: 2),
              ),
              child: const Center(
                child: Text('🥇', style: TextStyle(fontSize: 20)),
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
                      _MiniChip(label: codigo, bg: _C.primary, fg: Colors.white),
                      _MiniChip(
                          label: 'Ganador',
                          bg: _C.gold.withValues(alpha: 0.2),
                          fg: const Color(0xFF8A6D00)),
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
                                fontSize: 11, color: _C.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                  if (categoria.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.category_outlined,
                          size: 12, color: _C.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(categoria,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: _C.textSecondary)),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.info_outline,
                        size: 11, color: _C.gold.withValues(alpha: 0.9)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text('Ver detalle completo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              color: const Color(0xFF8A6D00)
                                  .withValues(alpha: 0.9))),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: _C.gold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_sf(promedio),
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5A4700))),
                ),
                const SizedBox(height: 4),
                const Text('pts',
                    style: TextStyle(fontSize: 10, color: _C.textSecondary)),
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

class _OtroProyectoRow extends StatelessWidget {
  final Map<String, dynamic> proyecto;
  final int posicion;
  final VoidCallback onTap;

  const _OtroProyectoRow({
    required this.proyecto,
    required this.posicion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final promedio = (proyecto['promedio'] as num?)?.toDouble() ?? 0.0;
    final titulo = _s(proyecto['titulo'], 'Sin título');
    final codigo = _s(proyecto['codigo'], '—');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text('$posicion°',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _C.textSecondary)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _C.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(codigo,
                      style: const TextStyle(
                          fontSize: 10, color: _C.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF90A4AE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_sf(promedio),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetalleProyectoSheet extends StatelessWidget {
  final Map<String, dynamic> proyecto;
  final int posicion;

  const _DetalleProyectoSheet({required this.proyecto, required this.posicion});

  @override
  Widget build(BuildContext context) {
    final promedio = (proyecto['promedio'] as num?)?.toDouble() ?? 0.0;
    final notaMax = (proyecto['notaMax'] as num?)?.toDouble() ?? 0.0;
    final notaMin = (proyecto['notaMin'] as num?)?.toDouble() ?? 0.0;
    final jurados = (proyecto['cantidadJurados'] as int?) ?? 0;
    final notas = (proyecto['notas'] as List?)?.cast<double>() ?? [];

    final esGanador = posicion == 0;
    final color = esGanador ? _C.gold : const Color(0xFF90A4AE);
    final icono = esGanador ? '🥇' : '🏅';
    final etiqueta = esGanador ? 'Ganador de sala' : '${posicion + 1}° lugar';

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
                      child: Text(icono, style: const TextStyle(fontSize: 24)),
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
                                  color: esGanador
                                      ? const Color(0xFF8A6D00)
                                      : color)),
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
                      gradient: const LinearGradient(
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
                            label: 'Promedio',
                            value: _sf(promedio),
                            icon: Icons.star_rounded,
                            color: _C.gold,
                            grande: true,
                          ),
                        ),
                        Container(width: 1, height: 40, color: Colors.white24),
                        Expanded(
                          child: _StatItem(
                            label: 'Nota máx.',
                            value: _sf(notaMax),
                            icon: Icons.arrow_upward_rounded,
                            color: Colors.greenAccent,
                          ),
                        ),
                        Container(width: 1, height: 40, color: Colors.white24),
                        Expanded(
                          child: _StatItem(
                            label: 'Nota mín.',
                            value: _sf(notaMin),
                            icon: Icons.arrow_downward_rounded,
                            color: Colors.redAccent[100]!,
                          ),
                        ),
                        Container(width: 1, height: 40, color: Colors.white24),
                        Expanded(
                          child: _StatItem(
                            label: 'Jurados',
                            value: '$jurados',
                            icon: Icons.how_to_vote_outlined,
                            color: Colors.lightBlueAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                        final isMin = e.value == notaMin && jurados > 1;
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
                                      fontSize: 10, color: Colors.grey[600])),
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
                      icon: Icons.room_outlined,
                      label: 'Sala',
                      value: _s(proyecto['sala'])),
                  _InfoRow(
                      icon: Icons.category_outlined,
                      label: 'Categoría',
                      value: _s(proyecto['clasificacion'])),
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
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
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
            style: const TextStyle(fontSize: 13, color: _C.textSecondary)),
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
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
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
                style:
                    const TextStyle(color: _C.textSecondary, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _InfoSuperAdminCard extends StatelessWidget {
  const _InfoSuperAdminCard();

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
            child: const Icon(Icons.admin_panel_settings,
                color: _C.gold, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Super Administrador',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                SizedBox(height: 3),
                Text('Eventos de todas las filiales, facultades y carreras',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                      maxLines: 2),
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
    final carrera = _s(evento['carreraNombre'], '');
    final filial = _s(evento['filialNombre'], '');
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

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
                      colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
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
                      if (carrera.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.school_outlined,
                              size: 12, color: _C.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(carrera,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: _C.textSecondary)),
                          ),
                        ]),
                      ],
                      if (filial.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: _C.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(filial,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: _C.textSecondary)),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Text('No se encontraron eventos en el sistema.',
                style: TextStyle(
                    fontSize: 13, color: _C.textSecondary, height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _EventoBanner extends StatelessWidget {
  final String nombre;
  final String subtitulo;
  final int totalSalas;
  final VoidCallback onTap;

  const _EventoBanner({
    required this.nombre,
    required this.subtitulo,
    required this.totalSalas,
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
                  Text(subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$totalSalas sala${totalSalas == 1 ? '' : 's'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
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
                  fontSize: 13, color: _C.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
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

  const _MiniChip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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