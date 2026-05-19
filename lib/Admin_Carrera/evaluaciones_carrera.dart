import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/logica/gestion_criterios.dart';
import '/prefs_helper.dart';
import 'detalle_evaluaciones_carrera.dart';

// Archivo: lib/admin/interfaz/evaluaciones_carrera.dart

class EvaluacionesCarreraScreen extends StatefulWidget {
  const EvaluacionesCarreraScreen({super.key});

  @override
  State<EvaluacionesCarreraScreen> createState() =>
      _EvaluacionesCarreraScreenState();
}

class _EvaluacionesCarreraScreenState
    extends State<EvaluacionesCarreraScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RubricasService _rubricasService = RubricasService();

  // ═══════════════════════════════════════════════════════════════
  // DATOS DE SESIÓN
  // ═══════════════════════════════════════════════════════════════
  String? _filialId;
  String? _filialNombre;
  String? _facultad;
  String? _carrera;
  String? _carreraId;

  List<Map<String, dynamic>> _eventosFiltrados = [];
  bool _isLoadingInit = true;
  bool _isLoadingEventos = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _init();
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
    setState(() => _isLoadingInit = false);
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
          'facultad': data['facultad'] ?? '',
          'carrera': data['carrera'] ?? '',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _eventosFiltrados = eventos;
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
  // AL TOCAR EVENTO: cargar evaluaciones y navegar
  // ═══════════════════════════════════════════════════════════════
  Future<void> _abrirEvento(Map<String, dynamic> evento) async {
    setState(() => _isNavigating = true);
    try {
      final evaluaciones =
          await _cargarEvaluacionesDeEvento(evento['id'] as String);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleEvaluacionesCarreraScreen(
              eventoId: evento['id'] as String,
              eventoNombre: evento['name'] as String,
              evaluaciones: evaluaciones,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al abrir evento: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isNavigating = false);
  }

  Future<List<Map<String, dynamic>>> _cargarEvaluacionesDeEvento(
      String eventoId) async {
    final rubricasFuture = _rubricasService.obtenerRubricas();

    final proyectosSnapshot = await _firestore
        .collection('events')
        .doc(eventoId)
        .collection('proyectos')
        .get();

    if (proyectosSnapshot.docs.isEmpty) return [];

    final todasRubricas = await rubricasFuture;
    final rubricasCache = {for (var r in todasRubricas) r.id: r};

    final futures = proyectosSnapshot.docs.map((proyectoDoc) async {
      try {
        final proyectoData = proyectoDoc.data();
        final evalSnapshot = await _firestore
            .collection('events')
            .doc(eventoId)
            .collection('proyectos')
            .doc(proyectoDoc.id)
            .collection('evaluaciones')
            .get();

        return evalSnapshot.docs.map((evalDoc) {
          final evalData = evalDoc.data();
          final notasRaw = evalData['notas'];
          final Map<String, dynamic> notas = {};
          if (notasRaw != null && notasRaw is Map) {
            notasRaw.forEach((k, v) => notas[k.toString()] = v);
          }
          final rubricaId = evalData['rubricaId'] as String?;
          Rubrica? rubrica;
          if (rubricaId != null && rubricasCache.containsKey(rubricaId)) {
            rubrica = rubricasCache[rubricaId];
          }
          return {
            'proyectoId': proyectoDoc.id,
            'codigo': proyectoData['Código'] ?? 'Sin código',
            'titulo': proyectoData['Título'] ?? 'Sin título',
            'integrantes': proyectoData['Integrantes'] ?? '',
            'sala': proyectoData['Sala'] ?? '',
            'clasificacion':
                proyectoData['Clasificación'] ?? 'Sin categoría',
            'juradoId': evalDoc.id,
            'juradoNombre': evalData['juradoNombre'] ?? 'Jurado',
            'rubricaId': rubricaId,
            'rubricaNombre': evalData['rubricaNombre'] ?? 'Sin rúbrica',
            'rubrica': rubrica,
            'evaluada': evalData['evaluada'] ?? false,
            'bloqueada': evalData['bloqueada'] ?? false,
            'notaTotal': (evalData['notaTotal'] ?? 0.0).toDouble(),
            'notas': notas,
            'fechaAsignacion': evalData['fechaAsignacion'],
            'fechaEvaluacion': evalData['fechaEvaluacion'],
          };
        }).toList();
      } catch (e) {
        debugPrint('❌ Error procesando proyecto ${proyectoDoc.id}: $e');
        return <Map<String, dynamic>>[];
      }
    }).toList();

    final resultados = await Future.wait(futures);
    final lista = <Map<String, dynamic>>[];
    for (var r in resultados) {
      lista.addAll(r);
    }
    lista.sort((a, b) => a['codigo'].compareTo(b['codigo']));
    return lista;
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
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Evaluaciones',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Colors.white, size: 26),
                    onPressed: _isLoadingEventos ? null : _cargarEventos,
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────────────
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                                color: Color(0xFF1E3A5F)),
                            SizedBox(height: 16),
                            Text('Cargando datos...',
                                style: TextStyle(
                                    color: Color(0xFF1E3A5F),
                                    fontSize: 16)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoAdminCard(),
                            const SizedBox(height: 20),
                            _buildEventosSection(),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CARD: Info del admin de carrera
  // ═══════════════════════════════════════════════════════════════
  Widget _buildInfoAdminCard() {
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
              color: Colors.white.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.admin_panel_settings,
                color: Colors.white, size: 24),
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
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    Text(_filialNombre ?? '—',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30),
            ),
            child: const Text('Tu carrera',
                style:
                    TextStyle(color: Colors.white70, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SECCIÓN: Lista de eventos
  // ═══════════════════════════════════════════════════════════════
  Widget _buildEventosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado con contador
        Row(
          children: [
            const Text(
              'Eventos disponibles',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_eventosFiltrados.length}',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1E3A5F),
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Aviso
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha:0.08),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: Colors.blue.withValues(alpha:0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 16, color: Colors.blue[700]),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Toca un evento para ver y gestionar sus evaluaciones',
                  style:
                      TextStyle(fontSize: 12, color: Colors.blue[700]),
                ),
              ),
            ],
          ),
        ),

        // Lista
        if (_isLoadingEventos)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child:
                  CircularProgressIndicator(color: Color(0xFF1E3A5F)),
            ),
          )
        else if (_eventosFiltrados.isEmpty)
          _buildEmptyState()
        else
          ...(_eventosFiltrados
              .map((e) => _buildEventoCard(e))
              .toList()),
      ],
    );
  }

  Widget _buildEventoCard(Map<String, dynamic> evento) {
    final nombre = evento['name'] as String;
    return GestureDetector(
      onTap: _isNavigating ? null : () => _abrirEvento(evento),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
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
                      fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Nombre y subtítulo
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
                  Row(
                    children: [
                      Icon(Icons.assessment,
                          size: 13, color: Colors.purple[400]),
                      const SizedBox(width: 4),
                      Text('Ver evaluaciones',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple[400])),
                    ],
                  ),
                ],
              ),
            ),

            // Flecha o spinner
            _isNavigating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF9C27B0)),
                  )
                : Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF9C27B0).withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF9C27B0),
                      size: 14,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF3E5F5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_busy_rounded,
                size: 48, color: Color(0xFF9C27B0)),
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
}