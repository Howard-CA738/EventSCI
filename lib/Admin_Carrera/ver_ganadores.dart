import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import '/resolver_nombres_service.dart';

class _C {
  static const primary = Color(0xFF1E3A5F);
  static const primaryLight = Color(0xFF2D5590);
  static const gold = Color(0xFFFFD700);
  static const silver = Color(0xFFB0BEC5);
  static const bronze = Color(0xFFCD7F32);
  static const textSecondary = Color(0xFF64748B);

  static const podioColors = [gold, silver, bronze];
  static const podioFondos = [
    Color(0xFFFFFDE7),
    Color(0xFFF5F5F5),
    Color(0xFFFBE9E7),
  ];
  static const podioIconos = ['🥇', '🥈', '🥉'];
  static const podioEtiquetas = ['1er lugar', '2do lugar', '3er lugar'];
}

// ============================================================================
// ENUM MODO DE VISTA
// ============================================================================
enum _ModoVista { lista, tabla, grafico }

// ============================================================================
// HELPERS SEGUROS
// ============================================================================
String _s(dynamic v, [String fb = '—']) {
  if (v == null) return fb;
  final s = v.toString().trim();
  return s.isEmpty ? fb : s;
}

String _sf(dynamic v, [int dec = 2]) {
  final d = v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  return d.toStringAsFixed(dec);
}

// ============================================================================
// SCREEN PRINCIPAL
// ============================================================================
class VerGanadoresScreen extends StatefulWidget {
  const VerGanadoresScreen({super.key});

  @override
  State<VerGanadoresScreen> createState() => _VerGanadoresScreenState();
}

class _VerGanadoresScreenState extends State<VerGanadoresScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _filialId;
  String? _filialNombre;
  String? _facultad;
  String? _carrera;
  String? _carreraId;

  bool _isLoadingInit = true;
  bool _isLoadingEventos = false;
  bool _isLoadingGanadores = false;

  List<Map<String, dynamic>> _eventos = [];
  Map<String, dynamic>? _eventoSeleccionado;
  Map<String, List<Map<String, dynamic>>> _ganadoresPorCategoria = {};

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
      setState(() => _isLoadingInit = false);
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
    // ← AQUÍ
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
      _isLoadingGanadores = true;
      _modoVista = _ModoVista.lista;
    });
    _animCtrl.reset();

    try {
      final ganadores = await _calcularGanadores(evento['id'] as String);
      if (mounted) {
        setState(() {
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

  Future<Map<String, List<Map<String, dynamic>>>> _calcularGanadores(
    String eventoId) async {
  // Escala base igual que en participantes
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

        // FIX: normalizar igual que en participantes_completo_carrera
        final notasNormalizadas = <double>[];

        for (final e in evalSnap.docs) {
          final data = e.data();
          final notaTotal =
              ((data['notaTotal'] ?? 0.0) as num).toDouble();

          if (!data.containsKey('puntajeMaximo')) {
            debugPrint(
                '⚠️ [Ganadores] Evaluación ${e.id} sin puntajeMaximo — omitida');
            continue;
          }

          final puntajeMax =
              (data['puntajeMaximo'] as num).toDouble();
          final maxSeguro = puntajeMax > 0 ? puntajeMax : escalaBase;
          final normalizada =
              ((notaTotal / maxSeguro) * escalaBase)
                  .clamp(0.0, escalaBase);

          notasNormalizadas
              .add(double.parse(normalizada.toStringAsFixed(2)));
        }

        // Si todas las evaluaciones fueron omitidas, tratar como sin eval
        if (notasNormalizadas.isEmpty) return null;

        final promedio = notasNormalizadas.reduce((a, b) => a + b) /
            notasNormalizadas.length;
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
          'promedio':    double.parse(promedio.toStringAsFixed(2)),
          'notaMax':     notaMax,
          'notaMin':     notaMin,
          'cantidadJurados': notasNormalizadas.length,
          'notas':       notasNormalizadas,
          'escalaBase':  escalaBase,
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
          .take(3)
          .toList(),
  };
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

  // ============================================================================
  // Mostrar detalle de un proyecto
  // ============================================================================
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

  // ============================================================================
  // BUILD
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.primary,
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
              children: [
                Text('Ganadores',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        overflow: TextOverflow.ellipsis),
                    maxLines: 1),
                Text('TOP 3 por categoría',
                    style: TextStyle(fontSize: 12, color: Colors.white60)),
              ],
            ),
          ),
          if (_eventoSeleccionado != null) ...[
            // Botones de modo de vista
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

  // ============================================================================
  // PASO 1 — Seleccionar evento
  // ============================================================================
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

  // ============================================================================
  // PASO 2 — Resultados
  // ============================================================================
  Widget _buildResultados() {
    return Column(
      children: [
        _EventoBanner(
          nombre: _s(_eventoSeleccionado!['name']),
          totalCategorias: _ganadoresPorCategoria.length,
          onTap: () => setState(() {
            _eventoSeleccionado = null;
            _ganadoresPorCategoria = {};
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
        return _VistaGrafico(ganadoresPorCategoria: _ganadoresPorCategoria);
    }
  }
}

// ============================================================================
// TOGGLE DE VISTA
// ============================================================================
class _VistaToggle extends StatelessWidget {
  final _ModoVista modoActual;
  final ValueChanged<_ModoVista> onChange;

  const _VistaToggle({required this.modoActual, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.15),
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

// ============================================================================
// DETALLE DE PROYECTO — BOTTOM SHEET
// ============================================================================
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
    final notaMax = (proyecto['notaMax'] as num?)?.toDouble() ?? 0.0;
    final notaMin = (proyecto['notaMin'] as num?)?.toDouble() ?? 0.0;
    final jurados = (proyecto['cantidadJurados'] as int?) ?? 0;
    final notas = (proyecto['notas'] as List?)?.cast<double>() ?? [];

    final color =
        posicion < 3 ? _C.podioColors[posicion] : const Color(0xFF90A4AE);
    final icono = posicion < 3 ? _C.podioIconos[posicion] : '🏅';
    final etiqueta = posicion < 3
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
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header del sheet
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha:0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha:0.5), width: 2),
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
                            color: color.withValues(alpha:0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(etiqueta,
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
                    icon: const Icon(Icons.close_rounded, color: _C.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: Colors.grey[200]),

            // Contenido scrollable
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  // Nota promedio destacada
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
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          label: 'Promedio',
                          value: _sf(promedio),
                          icon: Icons.star_rounded,
                          color: _C.gold,
                          grande: true,
                        ),
                        Container(
                            width: 1, height: 40, color: Colors.white24),
                        _StatItem(
                          label: 'Nota máx.',
                          value: _sf(notaMax),
                          icon: Icons.arrow_upward_rounded,
                          color: Colors.greenAccent,
                        ),
                        Container(
                            width: 1, height: 40, color: Colors.white24),
                        _StatItem(
                          label: 'Nota mín.',
                          value: _sf(notaMin),
                          icon: Icons.arrow_downward_rounded,
                          color: Colors.redAccent[100]!,
                        ),
                        Container(
                            width: 1, height: 40, color: Colors.white24),
                        _StatItem(
                          label: 'Jurados',
                          value: '$jurados',
                          icon: Icons.how_to_vote_outlined,
                          color: Colors.lightBlueAccent,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Notas individuales de jurados
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

                  // Información del proyecto
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

// ============================================================================
// VISTA TABLA
// ============================================================================
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
                  color: Colors.black.withValues(alpha:0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header categoría
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
              // Cabecera tabla
              Container(
                color: _C.primary.withValues(alpha:0.06),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: const Row(
                  children: [
                    SizedBox(width: 32, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _C.textSecondary))),
                    Expanded(flex: 3, child: Text('Proyecto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _C.textSecondary))),
                    SizedBox(width: 52, child: Text('Prom.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _C.textSecondary), textAlign: TextAlign.center)),
                    SizedBox(width: 36, child: Text('J.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _C.textSecondary), textAlign: TextAlign.center)),
                  ],
                ),
              ),
              // Filas
              ...entry.value.asMap().entries.map((e) {
                final i = e.key;
                final p = e.value;
                final color = i < 3
                    ? _C.podioColors[i]
                    : const Color(0xFF90A4AE);
                final icono = i < 3 ? _C.podioIconos[i] : '🏅';
                final promedio =
                    (p['promedio'] as num?)?.toDouble() ?? 0.0;
                final jurados = (p['cantidadJurados'] as int?) ?? 0;

                return InkWell(
                  onTap: () => onTapFila(p, i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[100]!),
                      ),
                      color: i == 0
                          ? _C.gold.withValues(alpha:0.04)
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
                              Text(_s(p['codigo'], '—'),
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: _C.textSecondary)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 52,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_sf(promedio),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                  textAlign: TextAlign.center),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text('$jurados',
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
              // Hint
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_outlined,
                        size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text('Toca una fila para ver detalle',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey[400])),
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

// ============================================================================
// VISTA GRÁFICO (barras horizontales)
// ============================================================================
class _VistaGrafico extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> ganadoresPorCategoria;

  const _VistaGrafico({required this.ganadoresPorCategoria});

  // Nota máxima global para escalar las barras
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
                  color: Colors.black.withValues(alpha:0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                    final color = i < 3
                        ? _C.podioColors[i]
                        : const Color(0xFF90A4AE);
                    final icono = i < 3 ? _C.podioIconos[i] : '🏅';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Título y medalla
                          Row(
                            children: [
                              Text(icono,
                                  style: const TextStyle(fontSize: 16)),
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
                              Text(_sf(promedio),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: color)),
                              Text(' pts',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: _C.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Barra
                          LayoutBuilder(
                            builder: (_, constraints) {
                              return Stack(
                                children: [
                                  // Fondo
                                  Container(
                                    height: 14,
                                    width: constraints.maxWidth,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius:
                                          BorderRadius.circular(7),
                                    ),
                                  ),
                                  // Relleno
                                  AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 700),
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
                          // Código y sala
                          Row(children: [
                            Text(_s(p['codigo'], '—'),
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: _C.textSecondary)),
                            if (_s(p['sala'], '').isNotEmpty) ...[
                              Text(' · Sala ${_s(p['sala'])}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: _C.textSecondary)),
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

// ============================================================================
// WIDGETS DE DETALLE
// ============================================================================
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
        Text(value,
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: grande ? 22 : 15)),
        Text(label,
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
        Text(titulo,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _C.primary)),
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
    // Separar por comas o saltos de línea
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
                  color: _C.primary.withValues(alpha:0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
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

// ============================================================================
// WIDGETS AUXILIARES EXISTENTES (sin cambios)
// ============================================================================
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

class _InfoCarreraCard extends StatelessWidget {
  final String? carrera;
  final String? facultad;
  final String? filialNombre;

  const _InfoCarreraCard({this.carrera, this.facultad, this.filialNombre});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _C.primary.withValues(alpha:0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.emoji_events, color: _C.gold, size: 28),
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
            color: _C.primary.withValues(alpha:0.1),
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
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha:0.04),
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
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.emoji_events,
                            size: 12, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Text('Ver ganadores',
                            style: TextStyle(
                                fontSize: 11, color: Colors.amber[700])),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _C.gold.withValues(alpha:0.12),
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
                  fontSize: 13, color: _C.textSecondary, height: 1.5),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _EventoBanner extends StatelessWidget {
  final String nombre;
  final int totalCategorias;
  final VoidCallback onTap;

  const _EventoBanner({
    required this.nombre,
    required this.totalCategorias,
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
                children: [
                  Text(nombre,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          overflow: TextOverflow.ellipsis),
                      maxLines: 1),
                  const Text('Toca para cambiar de evento',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$totalCategorias categ.',
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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

// ---------------------------------------------------------------------------
// Sección por categoría (modo lista) — ahora con onTapGanador
// ---------------------------------------------------------------------------
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
              color: Colors.black.withValues(alpha:0.06),
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
                    color: Colors.amber.withValues(alpha:0.2),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${ganadores.length} proy.',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11),
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
          // Hint de toque
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_outlined,
                    size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text('Toca una tarjeta para ver detalle',
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey[400])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card de ganador — con onTap
// ---------------------------------------------------------------------------
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

    final color =
        posicion < 3 ? _C.podioColors[posicion] : const Color(0xFF90A4AE);
    final fondo =
        posicion < 3 ? _C.podioFondos[posicion] : const Color(0xFFF5F5F5);
    final icono = posicion < 3 ? _C.podioIconos[posicion] : '🏅';
    final etiqueta = posicion < 3
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
            color: color.withValues(alpha:posicion == 0 ? 0.5 : 0.25),
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
                color: color.withValues(alpha:0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha:0.4), width: 2),
              ),
              child: Center(
                child: Text(icono, style: const TextStyle(fontSize: 20)),
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
                          bg: color.withValues(alpha:0.18),
                          fg: color),
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
                  if (sala.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.room_outlined,
                          size: 12, color: _C.textSecondary),
                      const SizedBox(width: 4),
                      Text('Sala $sala',
                          style: const TextStyle(
                              fontSize: 11,
                              color: _C.textSecondary,
                              overflow: TextOverflow.ellipsis)),
                    ]),
                  ],
                  // Indicador de "ver más"
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.info_outline,
                        size: 11, color: color.withValues(alpha:0.7)),
                    const SizedBox(width: 3),
                    Text('Ver detalle completo',
                        style: TextStyle(
                            fontSize: 10, color: color.withValues(alpha:0.8))),
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
                    style:
                        TextStyle(fontSize: 10, color: _C.textSecondary)),
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