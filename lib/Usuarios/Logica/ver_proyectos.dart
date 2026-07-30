import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import '/resolver_nombres_service.dart';






class _ProyectosCache {
  static final Map<String, List<Map<String, dynamic>>> _proyectosPorEvento = {};
  static List<Map<String, dynamic>>? _eventosCache;
  static DateTime? _eventosCacheTime;

  static const _eventosMaxAge = Duration(minutes: 10);
  static const _proyectosMaxAge = Duration(minutes: 15);
  static final Map<String, DateTime> _proyectosCacheTime = {};

  static bool get eventosVigentes {
    if (_eventosCache == null || _eventosCacheTime == null) return false;
    return DateTime.now().difference(_eventosCacheTime!) < _eventosMaxAge;
  }

  static List<Map<String, dynamic>>? get eventos => _eventosCache;

  static void setEventos(List<Map<String, dynamic>> eventos) {
    _eventosCache = eventos;
    _eventosCacheTime = DateTime.now();
  }

  static bool proyectosVigentes(String eventoId) {
    if (!_proyectosPorEvento.containsKey(eventoId)) return false;
    final t = _proyectosCacheTime[eventoId];
    if (t == null) return false;
    return DateTime.now().difference(t) < _proyectosMaxAge;
  }

  static List<Map<String, dynamic>>? proyectos(String eventoId) =>
      _proyectosPorEvento[eventoId];

  static void setProyectos(
      String eventoId, List<Map<String, dynamic>> proyectos) {
    _proyectosPorEvento[eventoId] = proyectos;
    _proyectosCacheTime[eventoId] = DateTime.now();
  }

  static void invalidateEventos() {
    _eventosCache = null;
    _eventosCacheTime = null;
  }

  static void invalidateProyectos(String eventoId) {
    _proyectosPorEvento.remove(eventoId);
    _proyectosCacheTime.remove(eventoId);
  }
}

class VerProyectosScreen extends StatefulWidget {
  const VerProyectosScreen({super.key});

  @override
  State<VerProyectosScreen> createState() => _VerProyectosScreenState();
}

class _VerProyectosScreenState extends State<VerProyectosScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ResolverNombresService _resolver = ResolverNombresService();

  bool _isLoadingSession = true;
  bool _isLoadingEvents = false;
  bool _isLoadingProjects = false;

  String? _studentFilial;
  String? _studentFacultad;
  String? _studentCarrera;

  List<Map<String, dynamic>> _eventos = [];

  String? _selectedEventoId;
  String? _selectedEventoNombre;

  List<Map<String, dynamic>> _proyectos = [];
  Map<String, List<Map<String, dynamic>>> _proyectosPorCategoria = {};

  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  static const _navy = Color(0xFF1E3A5F);
  static const _navyLight = Color(0xFF2A5298);
  static const _green = Color(0xFF00875A);
  static const _greenLight = Color(0xFFE3F9EE);
  static const _greenBorder = Color(0xFF57D9A3);
  static const _amber = Color(0xFFF59E0B);
  static const _amberLight = Color(0xFFFFF8E1);
  static const _amberBorder = Color(0xFFFFD166);
  static const _surface = Color(0xFFF4F6FA);

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    setState(() => _isLoadingSession = true);
    try {
      final userData = await PrefsHelper.getCurrentUserData();
      if (userData == null) return;
      if (!mounted) return;
      setState(() {
        _studentFilial = userData['filial']?.toString();
        _studentFacultad = userData['facultad']?.toString();
        _studentCarrera = userData['carrera']?.toString();
      });
      await _resolver.cargarEstudiantes(
        filialNombre: _studentFilial ?? '',
        carrera: _studentCarrera ?? '',
      );
      await _loadEventos();
    } catch (e) {
      debugPrint('Error cargando sesión: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSession = false);
    }
  }

  Future<void> _loadEventos({bool forceRefresh = false}) async {

    if (!forceRefresh && _ProyectosCache.eventosVigentes) {
      if (mounted) {
        setState(() => _eventos = List.from(_ProyectosCache.eventos!));
      }
      return;
    }

    setState(() => _isLoadingEvents = true);
    try {
      Query query = _firestore
          .collection('events')
          .orderBy('createdAt', descending: true);
      if (_studentFacultad != null && _studentFacultad!.isNotEmpty) {
        query = query.where('facultad', isEqualTo: _studentFacultad);
      }
      if (_studentCarrera != null && _studentCarrera!.isNotEmpty) {
        query = query.where('carreraNombre', isEqualTo: _studentCarrera);
      }
      if (_studentFilial != null && _studentFilial!.isNotEmpty) {
        query = query.where('filialNombre', isEqualTo: _studentFilial);
      }



      QuerySnapshot snap;
      try {
        snap = await query.get(const GetOptions(source: Source.cache));
        debugPrint('Eventos cargados desde caché Firestore offline');
      } catch (_) {

        snap = await query.get(const GetOptions(source: Source.server));
        debugPrint('Eventos cargados desde servidor Firestore');
      }

      if (!mounted) return;
      final eventos = snap.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        d['id'] = doc.id;
        return d;
      }).toList();

      _ProyectosCache.setEventos(eventos);
      setState(() => _eventos = eventos);
    } catch (e) {
      debugPrint('Error cargando eventos: $e');

      final cached = _ProyectosCache.eventos;
      if (cached != null && mounted) {
        setState(() => _eventos = List.from(cached));
      }
    } finally {
      if (mounted) setState(() => _isLoadingEvents = false);
    }
  }

  Future<void> _loadProyectos(String eventoId,
      {bool forceRefresh = false}) async {
    setState(() {
      _isLoadingProjects = true;
      _proyectos = [];
      _proyectosPorCategoria = {};
      _searchQuery = '';
      _searchCtrl.clear();
    });




    if (!forceRefresh && _ProyectosCache.proyectosVigentes(eventoId)) {
      final cached = _ProyectosCache.proyectos(eventoId)!;
      debugPrint('Proyectos cargados desde caché: ${cached.length} docs');
      if (mounted) {
        setState(() {
          _proyectos = List.from(cached);
          _proyectosPorCategoria = _agruparPorCategoria(cached);
          _isLoadingProjects = false;
        });
      }
      return;
    }

    try {



      final snap = await _firestore
          .collection('events')
          .doc(eventoId)
          .collection('proyectos')
          .get(const GetOptions(source: Source.server));

      if (!mounted) return;

      final lista = snap.docs.map((doc) {
        final d = doc.data();
        d['docId'] = doc.id;
        return d;
      }).toList();


      lista.sort((a, b) {
        final tA = a['importedAt'];
        final tB = b['importedAt'];
        if (tA == null && tB == null) return 0;
        if (tA == null) return 1;
        if (tB == null) return -1;
        if (tA is Timestamp && tB is Timestamp) {
          return tA.compareTo(tB);
        }
        return 0;
      });

      _ProyectosCache.setProyectos(eventoId, lista);
      setState(() {
        _proyectos = lista;
        _proyectosPorCategoria = _agruparPorCategoria(lista);
      });
    } catch (e) {
      debugPrint('Error cargando proyectos: $e');

      final cached = _ProyectosCache.proyectos(eventoId);
      if (cached != null && mounted) {
        setState(() {
          _proyectos = List.from(cached);
          _proyectosPorCategoria = _agruparPorCategoria(cached);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingProjects = false);
    }
  }

  Map<String, List<Map<String, dynamic>>> _agruparPorCategoria(
      List<Map<String, dynamic>> proyectos) {
    final Map<String, List<Map<String, dynamic>>> grupos = {};
    for (final p in proyectos) {
      final cat = p['Clasificación']?.toString().trim();
      final key = (cat != null && cat.isNotEmpty) ? cat : 'Sin categoría';
      grupos.putIfAbsent(key, () => []).add(p);
    }
    return grupos;
  }

  List<Map<String, dynamic>> get _proyectosFiltrados {
    if (_searchQuery.isEmpty) return _proyectos;
    final q = _searchQuery.toLowerCase();
    return _proyectos.where((p) {
      final codigo = (p['Código'] ?? '').toString().toLowerCase();
      final titulo = (p['Título'] ?? '').toString().toLowerCase();
      final sala = (p['Sala'] ?? '').toString().toLowerCase();
      final clasif = (p['Clasificación'] ?? '').toString().toLowerCase();
      final nombres =
          _resolver.resolverLista(p['Integrantes']).join(' ').toLowerCase();
      return codigo.contains(q) ||
          titulo.contains(q) ||
          sala.contains(q) ||
          clasif.contains(q) ||
          nombres.contains(q);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _categoriasFiltradas {
    if (_searchQuery.isEmpty) return _proyectosPorCategoria;
    return _agruparPorCategoria(_proyectosFiltrados);
  }

  void _seleccionarEvento(Map<String, dynamic> evento) {
    final id = evento['id'] as String;
    final nombre = (evento['name'] as String? ?? '').trim().isEmpty
        ? 'Sin nombre'
        : evento['name'] as String;
    setState(() {
      _selectedEventoId = id;
      _selectedEventoNombre = nombre;
    });
    _loadProyectos(id);
  }

  void _volverASeleccion() {
    _searchFocus.unfocus();
    setState(() {
      _selectedEventoId = null;
      _selectedEventoNombre = null;
      _proyectos = [];
      _proyectosPorCategoria = {};
      _searchQuery = '';
      _searchCtrl.clear();
      _isLoadingProjects = false;
    });
  }



  Future<void> _forceRefreshEventos() async {
    _ProyectosCache.invalidateEventos();
    await _loadEventos(forceRefresh: true);
  }

  Future<void> _forceRefreshProyectos() async {
    if (_selectedEventoId == null) return;
    _ProyectosCache.invalidateProyectos(_selectedEventoId!);
    await _loadProyectos(_selectedEventoId!, forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        title: Text(
          _selectedEventoNombre ?? 'Ver Proyectos',
          style: const TextStyle(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: _selectedEventoId != null
              ? _volverASeleccion
              : () => Navigator.of(context).pop(),
          tooltip: _selectedEventoId != null ? 'Volver a eventos' : 'Volver',
        ),
        actions: [
          if (_selectedEventoId == null)
            IconButton(
              icon: const Icon(Icons.refresh, size: 22),
              onPressed: _forceRefreshEventos,
              tooltip: 'Actualizar',
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, size: 22),
              onPressed: _forceRefreshProyectos,
              tooltip: 'Actualizar proyectos',
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isLoadingSession
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : SizedBox.expand(
                child: Container(
                  decoration: const BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: _selectedEventoId == null
                      ? _buildPantallaSeleccionEvento()
                      : _buildContent(),
                ),
              ),
      ),
    );
  }

  Widget _buildPantallaSeleccionEvento() {
    if (_isLoadingEvents) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _navy),
            SizedBox(height: 16),
            Text(
              'Cargando eventos...',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_eventos.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _navy.withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.event_busy_outlined,
                    size: 52, color: _navy.withValues(alpha: 0.4)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Sin eventos disponibles',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _navy),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'No hay eventos registrados para tu carrera.',
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: _forceRefreshEventos,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  side: const BorderSide(color: _navy, width: 1.5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_navy, _navyLight],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _navy.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_month,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Eventos disponibles',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Elige un evento para ver los proyectos y sus salas',
                      style: TextStyle(
                          color: Color(0xCCFFFFFF), fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          ...List.generate(_eventos.length, (index) {
            final evento = _eventos[index];
            final eventDate =
                (evento['createdAt'] as Timestamp?)?.toDate() ??
                    (evento['fecha'] as Timestamp?)?.toDate();
            final periodo = evento['periodoNombre'] as String? ?? '';
            final nombre = (evento['name'] as String? ?? '').trim().isEmpty
                ? 'Sin nombre'
                : evento['name'] as String;

            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 180 + (index * 70)),
              curve: Curves.easeOutCubic,
              builder: (ctx, val, _) => Transform.translate(
                offset: Offset(0, 16 * (1 - val)),
                child: Opacity(
                  opacity: val,
                  child: GestureDetector(
                    onTap: () => _seleccionarEvento(evento),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => _seleccionarEvento(evento),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _navy.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.folder_open_outlined,
                                    color: _navy, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nombre,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _navy,
                                          height: 1.3),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    Wrap(
                                      spacing: 10,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if (eventDate != null)
                                          _buildMetaChip(
                                            icon: Icons.calendar_today,
                                            label:
                                                '${eventDate.day}/${eventDate.month}/${eventDate.year}',
                                          ),
                                        if (periodo.isNotEmpty)
                                          _buildMetaChip(
                                            icon: Icons.layers_outlined,
                                            label: periodo,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: _navy.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.chevron_right,
                                    color: _navy, size: 20),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMetaChip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.grey.shade500),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final totalFiltrados = _proyectosFiltrados.length;
    final totalAll = _proyectos.length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _buildSearchBar(totalFiltrados, totalAll),
          ),
        ),
        if (_isLoadingProjects)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildLoadingProjects(),
          )
        else if (_proyectos.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyProjects(),
          )
        else if (_proyectosFiltrados.isEmpty && _searchQuery.isNotEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildNoSearchResults(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                _buildCategoriasSections(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBar(int found, int total) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              style: const TextStyle(fontSize: 13, color: _navy),
              decoration: InputDecoration(
                hintText: 'Buscar proyecto, sala, integrante...',
                hintStyle:
                    TextStyle(fontSize: 12, color: Colors.grey.shade400),
                prefixIcon:
                    Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close,
                            color: Colors.grey.shade400, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                        tooltip: 'Limpiar',
                        constraints: const BoxConstraints(
                            minWidth: 40, minHeight: 40),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                isDense: true,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$found',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _navy),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildCategoriasSections() {
    final categorias = _categoriasFiltradas;
    if (categorias.isEmpty) return [];
    return categorias.entries.toList().asMap().entries.map((entry) {
      final idx = entry.key;
      final categoria = entry.value.key;
      final proyectos = entry.value.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildCategoriaCard(categoria, proyectos, idx),
      );
    }).toList();
  }

  Widget _buildCategoriaCard(
    String categoria,
    List<Map<String, dynamic>> proyectos,
    int idx,
  ) {
    final color = _colorForIndex(idx);
    final conSala = proyectos
        .where((p) => (p['Sala']?.toString().trim() ?? '').isNotEmpty)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          maintainState: true,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${proyectos.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ),
          ),
          title: Text(
            categoria,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: _navy),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                if (conSala > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _greenLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: _greenBorder.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.meeting_room_outlined,
                            size: 10, color: _green),
                        const SizedBox(width: 3),
                        Text(
                          '$conSala con sala',
                          style: const TextStyle(
                              fontSize: 10,
                              color: _green,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (conSala < proyectos.length)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _amberLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: _amberBorder.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.hourglass_top_outlined,
                            size: 10, color: _amber),
                        const SizedBox(width: 3),
                        Text(
                          '${proyectos.length - conSala} pendiente${proyectos.length - conSala != 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: _amber,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          children: proyectos.map((p) => _buildProyectoTile(p)).toList(),
        ),
      ),
    );
  }

  Widget _buildProyectoTile(Map<String, dynamic> proyecto) {
    final codigo = proyecto['Código']?.toString() ?? 'Sin código';
    final titulo = proyecto['Título']?.toString() ?? '';
    final sala = proyecto['Sala']?.toString().trim() ?? '';
    final integrantes = _resolver.resolverLista(proyecto['Integrantes']);
    final totalIntegrantes =
        proyecto['totalIntegrantes'] as int? ?? integrantes.length;
    final tieneSala = sala.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _mostrarDetalleProyecto(proyecto),
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: tieneSala
                    ? _greenBorder.withValues(alpha: 0.4)
                    : Colors.grey.shade200,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _navy,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    codigo,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Colors.white,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (titulo.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                titulo,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  height: 1.35,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right,
                          size: 18, color: Color(0xFF94A3B8)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  tieneSala ? _buildSalaChip(sala) : _buildPendienteChip(),
                  if (integrantes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(Icons.people_outline,
                              size: 12, color: Colors.grey.shade400),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '$totalIntegrantes integrante${totalIntegrantes != 1 ? 's' : ''}: '
                            '${integrantes.take(2).join(', ')}'
                            '${integrantes.length > 2 ? ' +${integrantes.length - 2}' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSalaChip(String sala) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _greenLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _greenBorder.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.meeting_room_outlined, size: 15, color: _green),
          const SizedBox(width: 7),
          const Text(
            'SALA',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _green,
                letterSpacing: 0.8),
          ),
          const SizedBox(width: 8),
          Container(
              width: 1,
              height: 14,
              color: _greenBorder.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              sala,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF065F46)),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendienteChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _amberLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _amberBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hourglass_top_outlined, size: 14, color: _amber),
          const SizedBox(width: 6),
          Text(
            'Sala pendiente de asignación',
            style: TextStyle(
                fontSize: 11,
                color: Colors.amber.shade800,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalleProyecto(Map<String, dynamic> proyecto) {
    final codigo = proyecto['Código']?.toString() ?? 'Sin código';
    final titulo = proyecto['Título']?.toString() ?? 'Sin título';
    final clasificacion =
        proyecto['Clasificación']?.toString().trim() ?? 'Sin categoría';
    final sala = proyecto['Sala']?.toString().trim() ?? '';
    final integrantes = _resolver.resolverLista(proyecto['Integrantes']);
    final totalIntegrantes =
        proyecto['totalIntegrantes'] as int? ?? integrantes.length;
    final tieneSala = sala.isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final maxH = mq.size.height * 0.88;
        return Container(
          constraints: BoxConstraints(maxHeight: maxH),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (tieneSala)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _greenLight,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _greenBorder, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: _green.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
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
                              color: _green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.meeting_room_outlined,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'LUGAR DE PONENCIA',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _green,
                                letterSpacing: 1.0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        sala,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF065F46),
                            height: 1.25),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _amberLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _amberBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _amber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.hourglass_top_outlined,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SALA PENDIENTE',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _amber,
                                  letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'El lugar de ponencia aún no fue asignado.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade800,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _navy,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                codigo,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.4),
                              ),
                            ),
                            if (titulo.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                titulo,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _navy,
                                    height: 1.4),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildSheetSection(
                        icon: Icons.category_outlined,
                        label: 'CATEGORÍA',
                        child: Text(
                          clasificacion,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.4),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildSheetSection(
                        icon: Icons.people_outline,
                        label: 'INTEGRANTES ($totalIntegrantes)',
                        child: integrantes.isEmpty
                            ? Text('Sin integrantes registrados',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade400))
                            : Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: integrantes.map((nombre) {
                                  return Container(
                                    constraints: const BoxConstraints(
                                        maxWidth: 300),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _navy.withValues(alpha: 0.06),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      border: Border.all(
                                          color: _navy.withValues(
                                              alpha: 0.15)),
                                    ),
                                    child: Text(
                                      nombre,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _navy),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16, 16 + mq.padding.bottom),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size(double.infinity, 50),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Cerrar',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetSection({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.8),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }

  Widget _buildLoadingProjects() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_navy),
            ),
            const SizedBox(height: 20),
            Text(
              'Cargando proyectos...',
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade600, height: 1.5),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyProjects() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.assignment_outlined,
                size: 52, color: Colors.orange.shade300),
          ),
          const SizedBox(height: 20),
          const Text(
            'Sin proyectos aún',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold, color: _navy),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Este evento todavía no tiene proyectos importados.',
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade500, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_outlined,
              size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Sin resultados',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: _navy),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'No hay proyectos que coincidan con tu búsqueda.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _colorForIndex(int index) {
    const colors = [
      Color(0xFF1E3A5F),
      Color(0xFF00875A),
      Color(0xFF6A1B9A),
      Color(0xFF00695C),
      Color(0xFFC62828),
      Color(0xFF1565C0),
      Color(0xFFE65100),
      Color(0xFF37474F),
    ];
    return colors[index % colors.length];
  }
}