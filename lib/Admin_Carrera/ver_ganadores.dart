import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';

// Archivo: lib/admin/interfaz/ver_ganadores.dart

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

  List<Map<String, dynamic>> _eventos = [];
  Map<String, dynamic>? _eventoSeleccionado;
  Map<String, List<Map<String, dynamic>>> _ganadoresPorCategoria = {};

  bool _isLoadingInit = true;
  bool _isLoadingEventos = false;
  bool _isLoadingGanadores = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const _podioIconos = ['🥇', '🥈', '🥉'];
  static const _podioEtiquetas = ['1er lugar', '2do lugar', '3er lugar'];
  static const _podioColores = [
    Color(0xFFFFD700),
    Color(0xFFB0BEC5),
    Color(0xFFCD7F32),
  ];
  static const _podioFondos = [
    Color(0xFFFFFDE7),
    Color(0xFFF5F5F5),
    Color(0xFFFBE9E7),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _animationController, curve: Curves.easeOutCubic),
    );
    _init();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // INICIALIZAR
  // ═══════════════════════════════════════════════════════════════
  Future<void> _init() async {
    setState(() => _isLoadingInit = true);
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontró información de sesión'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoadingInit = false);
        return;
      }
      _filialId = adminData['filial'] as String?;
      _filialNombre = adminData['filialNombre'] as String?;
      _facultad = adminData['facultad'] as String?;
      _carrera = adminData['carrera'] as String?;
      _carreraId = adminData['carreraId'] ?? adminData['carrera'];
      await _cargarEventos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al iniciar: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isLoadingInit = false);
  }

  // ═══════════════════════════════════════════════════════════════
  // CARGAR EVENTOS
  // ═══════════════════════════════════════════════════════════════
  Future<void> _cargarEventos() async {
    setState(() => _isLoadingEventos = true);
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('filialId', isEqualTo: _filialId)
          .where('facultad', isEqualTo: _facultad)
          .where('carreraId', isEqualTo: _carreraId)
          .orderBy('createdAt', descending: true)
          .get();

      final eventos = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Sin nombre',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _eventos = eventos;
          _isLoadingEventos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEventos = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al cargar eventos: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // SELECCIONAR EVENTO
  // ═══════════════════════════════════════════════════════════════
  Future<void> _seleccionarEvento(Map<String, dynamic> evento) async {
    setState(() {
      _eventoSeleccionado = evento;
      _ganadoresPorCategoria = {};
      _isLoadingGanadores = true;
    });
    _animationController.reset();

    try {
      final ganadores = await _calcularGanadores(evento['id'] as String);
      if (mounted) {
        setState(() {
          _ganadoresPorCategoria = ganadores;
          _isLoadingGanadores = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingGanadores = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al calcular ganadores: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CALCULAR GANADORES — evaluaciones en paralelo con Future.wait
  // ═══════════════════════════════════════════════════════════════
  Future<Map<String, List<Map<String, dynamic>>>> _calcularGanadores(
      String eventoId) async {
    final proyectosSnapshot = await _firestore
        .collection('events')
        .doc(eventoId)
        .collection('proyectos')
        .get();

    if (proyectosSnapshot.docs.isEmpty) return {};

    // Lanzar todas las consultas de evaluaciones en paralelo
    final results = await Future.wait(
      proyectosSnapshot.docs.map((proyectoDoc) async {
        final evalSnapshot = await _firestore
            .collection('events')
            .doc(eventoId)
            .collection('proyectos')
            .doc(proyectoDoc.id)
            .collection('evaluaciones')
            .where('evaluada', isEqualTo: true)
            .get();

        if (evalSnapshot.docs.isEmpty) return null;

        final pData = proyectoDoc.data();
        final notas = evalSnapshot.docs
            .map((e) => (e.data()['notaTotal'] ?? 0.0) as num)
            .toList();
        final promedio = notas.reduce((a, b) => a + b) / notas.length;

        return {
          'proyectoId': proyectoDoc.id,
          'codigo': pData['Código'] ?? 'Sin código',
          'titulo': pData['Título'] ?? 'Sin título',
          'integrantes': pData['Integrantes'] ?? '',
          'sala': pData['Sala'] ?? '',
          'clasificacion': pData['Clasificación'] ?? 'Sin categoría',
          'promedio': promedio.toDouble(),
          'cantidadJurados': notas.length,
        };
      }),
    );

    final promedios = results.whereType<Map<String, dynamic>>().toList();
    if (promedios.isEmpty) return {};

    // Agrupar por categoría
    final Map<String, List<Map<String, dynamic>>> porCategoria = {};
    for (final p in promedios) {
      final cat = p['clasificacion'] as String;
      porCategoria.putIfAbsent(cat, () => []).add(p);
    }

    // Ordenar y tomar top 3
    final Map<String, List<Map<String, dynamic>>> resultado = {};
    porCategoria.forEach((categoria, lista) {
      lista.sort((a, b) =>
          (b['promedio'] as double).compareTo(a['promedio'] as double));
      resultado[categoria] = lista.take(3).toList();
    });

    return resultado;
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 20, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ganadores',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Text(
                          'Top 3 por categoría',
                          style:
                              TextStyle(fontSize: 13, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  if (_eventoSeleccionado != null)
                    IconButton(
                      icon: const Icon(Icons.refresh,
                          color: Colors.white, size: 24),
                      onPressed: _isLoadingGanadores
                          ? null
                          : () => _seleccionarEvento(_eventoSeleccionado!),
                      tooltip: 'Actualizar',
                    ),
                ],
              ),
            ),

            // Contenido
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _isLoadingInit
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF1E3A5F)),
                      )
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

  // ═══════════════════════════════════════════════════════════════
  // PASO 1: Seleccionar evento
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSeleccionEvento() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCarreraCard(),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event,
                    color: Color(0xFF1E3A5F), size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Selecciona un evento',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Text(
              'Elige el evento para ver su podio por categoría',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingEventos)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child:
                    CircularProgressIndicator(color: Color(0xFF1E3A5F)),
              ),
            )
          else if (_eventos.isEmpty)
            _buildEmptyEventos()
          else
            ..._eventos.map((e) => _buildEventoCard(e)),
        ],
      ),
    );
  }

  Widget _buildInfoCarreraCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.emoji_events,
                color: Colors.amber, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _carrera ?? '—',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(_facultad ?? '—',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on,
                      color: Colors.white54, size: 12),
                  const SizedBox(width: 4),
                  Text(_filialNombre ?? '—',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventoCard(Map<String, dynamic> evento) {
    final nombre = evento['name'] as String;
    return GestureDetector(
      onTap: () => _seleccionarEvento(evento),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  nombre.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1E3A5F)),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.emoji_events,
                        size: 13, color: Colors.amber[700]),
                    const SizedBox(width: 4),
                    Text('Ver ganadores',
                        style: TextStyle(
                            fontSize: 12, color: Colors.amber[700])),
                  ]),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.amber, size: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyEventos() {
    return Container(
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
              color: Color(0xFFFFF8E1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_busy_rounded,
                size: 48, color: Colors.amber),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay eventos disponibles',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F)),
          ),
          const SizedBox(height: 8),
          Text(
            'No se encontraron eventos para tu carrera.',
            style: TextStyle(
                fontSize: 13, color: Colors.grey[500], height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PASO 2: Resultados
  // ═══════════════════════════════════════════════════════════════
  Widget _buildResultados() {
    return Column(
      children: [
        _buildEventoSeleccionadoBanner(),
        Expanded(
          child: _isLoadingGanadores
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF1E3A5F)),
                      SizedBox(height: 16),
                      Text(
                        'Calculando ganadores...',
                        style: TextStyle(
                            color: Color(0xFF1E3A5F), fontSize: 15),
                      ),
                    ],
                  ),
                )
              : _ganadoresPorCategoria.isEmpty
                  ? _buildSinEvaluaciones()
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: ListView(
                          padding:
                              const EdgeInsets.fromLTRB(20, 16, 20, 30),
                          children: _ganadoresPorCategoria.entries
                              .map((entry) => _buildCategoriaSection(
                                  entry.key, entry.value))
                              .toList(),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEventoSeleccionadoBanner() {
    return GestureDetector(
      onTap: () => setState(() {
        _eventoSeleccionado = null;
        _ganadoresPorCategoria = {};
      }),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _eventoSeleccionado!['name'] as String,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Toca para cambiar de evento',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_ganadoresPorCategoria.length} categ.',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSinEvaluaciones() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF8E1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_empty_rounded,
                  size: 56, color: Colors.amber),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sin evaluaciones completadas',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ningún proyecto tiene evaluaciones finalizadas en este evento todavía.',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey[600], height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SECCIÓN POR CATEGORÍA
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCategoriaSection(
      String categoria, List<Map<String, dynamic>> ganadores) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado categoría
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E3A5F),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.category,
                      color: Colors.amber, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    categoria,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${ganadores.length} proyecto${ganadores.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // Lista de ganadores (sin podio visual)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: List.generate(
                  ganadores.length,
                  (i) => _buildGanadorCard(ganadores[i], i)),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CARD DE GANADOR — Flexible en chips para evitar overflow
  // ═══════════════════════════════════════════════════════════════
  Widget _buildGanadorCard(Map<String, dynamic> proyecto, int posicion) {
    final promedio = proyecto['promedio'] as double;
    final cantidadJurados = proyecto['cantidadJurados'] as int;
    final colorMedalla =
        posicion < 3 ? _podioColores[posicion] : Colors.grey;
    final fondoMedalla =
        posicion < 3 ? _podioFondos[posicion] : const Color(0xFFF5F5F5);
    final etiqueta =
        posicion < 3 ? _podioEtiquetas[posicion] : '${posicion + 1}° lugar';
    final icono = posicion < 3 ? _podioIconos[posicion] : '🏅';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondoMedalla,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorMedalla.withOpacity(posicion == 0 ? 0.5 : 0.3),
          width: posicion == 0 ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Medalla
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorMedalla.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: colorMedalla.withOpacity(0.5), width: 2),
            ),
            child: Center(
              child: Text(icono, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),

          // Info — Expanded para ocupar el espacio disponible
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chips con Flexible para que nunca desborden
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          proyecto['codigo'] as String,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorMedalla.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          etiqueta,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colorMedalla),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  proyecto['titulo'] as String,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((proyecto['integrantes'] as String).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.people, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        proyecto['integrantes'] as String,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],
                if ((proyecto['sala'] as String).isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.room, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Sala: ${proyecto["sala"]}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                  ]),
                ],
              ],
            ),
          ),

          // Nota promedio
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorMedalla,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  promedio.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'pts prom.',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.how_to_vote,
                      size: 11, color: Colors.grey[500]),
                  const SizedBox(width: 3),
                  Text(
                    '$cantidadJurados jur.',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}