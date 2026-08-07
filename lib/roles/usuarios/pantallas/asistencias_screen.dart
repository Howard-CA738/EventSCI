import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../logica/asistencias_service.dart';

class AsistenciasScreen extends StatefulWidget {
  const AsistenciasScreen({super.key});

  @override
  State<AsistenciasScreen> createState() => _AsistenciasScreenState();
}

class _AsistenciasScreenState extends State<AsistenciasScreen>
    with TickerProviderStateMixin {
  final AsistenciasService _service = AsistenciasService();
  StudentInfo? _studentInfo;

  String? _currentUserId;
  String? _currentUserName;

  String? _studentFilial;
  String? _studentFacultad;
  String? _studentCarrera;
  String? _studentCiclo;
  String? _studentGrupo;

  List<Map<String, dynamic>> _todosLosEventos = [];
  List<Map<String, dynamic>> _eventosConAsistencias = [];

  bool _isLoadingEventos = false;

  String? _eventoSeleccionadoId;
  String? _eventoSeleccionadoNombre;

  List<Map<String, dynamic>> _asistenciasDelEvento = [];
  List<Map<String, dynamic>> _asistenciasPersonalesDelEvento = [];

  int _tabSeleccionado = 0;

  int? _metaSellos;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _getCurrentUserId();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUserId() async {
    try {
      final info = await _service.cargarEstudiante();
      if (info == null) {
        _showSnackBar('No se pudo obtener el usuario actual', isError: true);
        return;
      }
      setState(() {
        _studentInfo = info;
        _currentUserId = info.userId;
        _currentUserName = info.userName;
        _studentFilial = info.filial;
        _studentFacultad = info.facultad;
        _studentCarrera = info.carrera;
        _studentCiclo = info.ciclo;
        _studentGrupo = info.grupo;
      });
      await _cargarEventosYAsistencias();
    } catch (e) {
      _showSnackBar('Error al obtener usuario: $e', isError: true);
    }
  }

  Future<void> _cargarEventosYAsistencias() async {
    if (_studentInfo == null) return;

    setState(() {
      _isLoadingEventos = true;
      _todosLosEventos.clear();
      _eventosConAsistencias.clear();
      _eventoSeleccionadoId = null;
      _eventoSeleccionadoNombre = null;
      _asistenciasDelEvento.clear();
      _asistenciasPersonalesDelEvento.clear();
      _metaSellos = null;
      _tabSeleccionado = 0;
    });

    try {
      final conAsistencias =
          await _service.cargarEventosConAsistencias(_studentInfo!);
      if (mounted) {
        setState(() {
          _eventosConAsistencias = conAsistencias;
          _isLoadingEventos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEventos = false);
        _showSnackBar('Error al cargar asistencias: $e', isError: true);
      }
    }
  }

  Future<void> _seleccionarEvento(Map<String, dynamic> eventoData) async {
    final selected = await _service.seleccionarEvento(
        eventoData, _studentInfo?.userId ?? '');
    setState(() {
      _eventoSeleccionadoId = selected.eventoId;
      _eventoSeleccionadoNombre = selected.nombre;
      _asistenciasDelEvento = selected.scans;
      _asistenciasPersonalesDelEvento = selected.personales;
      _metaSellos = selected.meta > 0 ? selected.meta : null;
      _tabSeleccionado = selected.tabInicial;
    });
    _animationController
      ..reset()
      ..forward();
  }

  void _volverASeleccion() {
    setState(() {
      _eventoSeleccionadoId = null;
      _eventoSeleccionadoNombre = null;
      _asistenciasDelEvento.clear();
      _asistenciasPersonalesDelEvento.clear();
      _metaSellos = null;
      _tabSeleccionado = 0;
    });
    _animationController
      ..reset()
      ..forward();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ]),
        backgroundColor:
            isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _getColorByCategoria(String? categoria) {
    if (categoria == null || categoria.isEmpty) return const Color(0xFF5A6C7D);
    const colors = [
      Color(0xFF2563EB),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFF7C3AED),
      Color(0xFF0891B2),
      Color(0xFF4F46E5),
      Color(0xFF6366F1),
      Color(0xFF0D9488),
      Color(0xFF1E40AF),
      Color(0xFF15803D),
    ];
    return colors[categoria.hashCode.abs() % colors.length];
  }

  IconData _getIconByCategoria(String? categoria) {
    if (categoria == null || categoria.isEmpty) return Icons.help;
    final c = categoria.toLowerCase();
    if (c.contains('revisión') || c.contains('revision'))
      return Icons.library_books;
    if (c.contains('empírico') || c.contains('empirico')) return Icons.science;
    if (c.contains('innovación') ||
        c.contains('innovacion') ||
        c.contains('tecnológica')) return Icons.lightbulb;
    if (c.contains('narrativa')) return Icons.auto_stories;
    if (c.contains('descriptiv')) return Icons.description;
    if (c.contains('experimental')) return Icons.biotech;
    if (c.contains('teóric') || c.contains('teorico')) return Icons.psychology;
    if (c.contains('cualitativ')) return Icons.forum;
    if (c.contains('cuantitativ')) return Icons.analytics;
    return Icons.assignment;
  }

  bool _esValorValido(dynamic valor) {
    if (valor == null) return false;
    final v = valor.toString().trim().toLowerCase();
    return v.isNotEmpty &&
        v != 'sin código' &&
        v != 'sin codigo' &&
        v != 'sin título' &&
        v != 'sin titulo' &&
        v != 'sin grupo' &&
        v != 'null';
  }

  List<Map<String, dynamic>> get _todosLosSellos {
    final List<Map<String, dynamic>> todos = [];

    for (final s in _asistenciasDelEvento) {
      todos.add({...s, 'tipoSello': 'proyecto'});
    }
    for (final p in _asistenciasPersonalesDelEvento) {
      todos.add({...p, 'tipoSello': 'personal'});
    }

    todos.sort((a, b) {
      final tA = (a['timestamp'] as Timestamp?)?.toDate();
      final tB = (b['timestamp'] as Timestamp?)?.toDate();
      if (tA == null || tB == null) return 0;
      return tB.compareTo(tA);
    });

    return todos;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: _eventoSeleccionadoId != null
                    ? _volverASeleccion
                    : () => Navigator.of(context).pop(),
                tooltip:
                    _eventoSeleccionadoId != null ? 'Volver a eventos' : 'Volver',
              ),
              const SizedBox(width: 8),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.verified_user,
                    color: Color(0xFF1E3A5F), size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mis Asistencias',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_eventoSeleccionadoNombre != null)
                      Text(
                        _eventoSeleccionadoNombre!,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else if (_currentUserName != null)
                      Text(
                        _currentUserName!,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
                onPressed: _cargarEventosYAsistencias,
                tooltip: 'Actualizar',
              ),
            ]),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFE8EDF2),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: _currentUserId == null
                  ? const Center(child: CircularProgressIndicator())
                  : _isLoadingEventos
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                  color: Color(0xFF1E3A5F)),
                              SizedBox(height: 16),
                              Text(
                                'Cargando tus asistencias...',
                                style: TextStyle(
                                    color: Color(0xFF64748B), fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : _eventoSeleccionadoId == null
                          ? _buildPantallaSeleccionEvento()
                          : _buildPantallaEvento(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildPantallaSeleccionEvento() {
    if (_todosLosEventos.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_available, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 24),
              const Text(
                'No hay eventos disponibles',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'No hay eventos registrados para tu carrera',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _cargarEventosYAsistencias,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3A5F),
                  side: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.touch_app, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Eventos de tu carrera',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Selecciona un evento para ver tus asistencias',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_todosLosEventos.length} evento${_todosLosEventos.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
          ...List.generate(_todosLosEventos.length, (index) {
            final evento = _todosLosEventos[index];
            final eventDate =
                (evento['eventDate'] as Timestamp?)?.toDate();
            final scans = (evento['asistencias'] as List);
            final personales = (evento['asistenciasPersonales'] as List);
            final totalSellos = scans.length + personales.length;
            final tieneAsistencia = totalSellos > 0;

            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 200 + (index * 80)),
              curve: Curves.easeOut,
              builder: (ctx, val, _) => Transform.translate(
                offset: Offset(0, 20 * (1 - val)),
                child: Opacity(
                  opacity: val,
                  child: GestureDetector(
                    onTap: () => _seleccionarEvento(evento),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: tieneAsistencia
                            ? Border.all(
                                color: const Color(0xFF059669)
                                    .withValues(alpha: 0.4),
                                width: 1.5)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: tieneAsistencia
                                ? const Color(0xFF059669).withValues(alpha: 0.12)
                                : const Color(0xFF1E3A5F).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            tieneAsistencia
                                ? Icons.event_available
                                : Icons.event,
                            color: tieneAsistencia
                                ? const Color(0xFF059669)
                                : const Color(0xFF1E3A5F),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                evento['eventName']?.toString() ?? 'Sin nombre',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A5F)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(children: [
                                if (eventDate != null) ...[
                                  Icon(Icons.calendar_today,
                                      size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${eventDate.day}/${eventDate.month}/${eventDate.year}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Icon(Icons.workspace_premium,
                                    size: 12,
                                    color: tieneAsistencia
                                        ? Colors.amber.shade600
                                        : Colors.grey.shade400),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    tieneAsistencia
                                        ? '$totalSellos sello${totalSellos != 1 ? 's' : ''}'
                                        : 'Sin asistencias aún',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: tieneAsistencia
                                            ? Colors.amber.shade700
                                            : Colors.grey.shade400,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right,
                            color: Color(0xFF1E3A5F)),
                      ]),
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

  Widget _buildPantallaEvento() {
    final tieneProyectos = _asistenciasDelEvento.isNotEmpty;
    final tienePersonales = _asistenciasPersonalesDelEvento.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _cargarEventosYAsistencias,
      color: const Color(0xFF1E3A5F),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBannerAcademico(),
              _buildColeccionSellos(),
              _buildTabs(tieneProyectos, tienePersonales),
              const SizedBox(height: 16),
              if (_tabSeleccionado == 0) ...[
                if (tieneProyectos)
                  _buildHistorialCard()
                else
                  _buildEstadoVacio(
                    icon: Icons.workspace_premium_outlined,
                    titulo: 'Sin sellos de proyectos',
                    subtitulo:
                        'Aún no has escaneado ningún QR de proyecto en este evento',
                  ),
              ] else ...[
                if (tienePersonales)
                  _buildListaAsistenciasPersonales()
                else
                  _buildEstadoVacio(
                    icon: Icons.how_to_reg_outlined,
                    titulo: 'Sin asistencias personales',
                    subtitulo:
                        'Aún no has registrado ninguna asistencia personal en este evento',
                  ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs(bool tieneProyectos, bool tienePersonales) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _tabSeleccionado = 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _tabSeleccionado == 0
                    ? const Color(0xFF1E3A5F)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium,
                      size: 18,
                      color: _tabSeleccionado == 0
                          ? Colors.amber
                          : Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Proyectos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _tabSeleccionado == 0
                                  ? Colors.white
                                  : Colors.grey.shade600),
                        ),
                        if (tieneProyectos)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: _tabSeleccionado == 0
                                  ? Colors.amber
                                  : Colors.amber.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_asistenciasDelEvento.length}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _tabSeleccionado == 0
                                      ? const Color(0xFF1E3A5F)
                                      : Colors.amber.shade800),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _tabSeleccionado = 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _tabSeleccionado == 1
                    ? Colors.deepPurple.shade600
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.how_to_reg_rounded,
                      size: 18,
                      color: _tabSeleccionado == 1
                          ? Colors.white
                          : Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Personales',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _tabSeleccionado == 1
                                  ? Colors.white
                                  : Colors.grey.shade600),
                        ),
                        if (tienePersonales)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: _tabSeleccionado == 1
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : Colors.deepPurple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_asistenciasPersonalesDelEvento.length}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _tabSeleccionado == 1
                                      ? Colors.white
                                      : Colors.deepPurple.shade700),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildEstadoVacio({
    required IconData icon,
    required String titulo,
    required String subtitulo,
  }) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Icon(icon, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(
          titulo,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A5F)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitulo,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  Widget _buildBannerAcademico() {
    if (_studentFilial == null && _studentFacultad == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1E3A5F).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.school, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Mi Información Académica',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_studentFilial != null)
                _buildAcademicoChip(
                    icon: Icons.location_city,
                    label: _studentFilial!,
                    bgColor: Colors.blue.shade700),
              if (_studentFacultad != null)
                _buildAcademicoChip(
                    icon: Icons.account_balance,
                    label: _studentFacultad!,
                    bgColor: Colors.purple.shade700),
              if (_studentCarrera != null)
                _buildAcademicoChip(
                    icon: Icons.menu_book,
                    label: _studentCarrera!,
                    bgColor: Colors.teal.shade700),
              if (_studentCiclo != null)
                _buildAcademicoChip(
                    icon: Icons.layers,
                    label: 'Ciclo $_studentCiclo',
                    bgColor: Colors.orange.shade700),
              if (_studentGrupo != null)
                _buildAcademicoChip(
                    icon: Icons.groups,
                    label: 'Grupo $_studentGrupo',
                    bgColor: Colors.green.shade700),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicoChip({
    required IconData icon,
    required String label,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColeccionSellos() {
    final sellos = _todosLosSellos;
    final totalGanados = sellos.length;
    final metaFija = _metaSellos != null && _metaSellos! > 0;
    final meta = metaFija ? _metaSellos! : 0;
    final totalCeldas =
        metaFija ? math.max(meta, totalGanados) : totalGanados;

    final tieneProyectos = _asistenciasDelEvento.isNotEmpty;
    final tienePersonales = _asistenciasPersonalesDelEvento.isNotEmpty;

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.workspace_premium,
                      color: Colors.amber.shade600, size: 26),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Mis Sellos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F)),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        metaFija
                            ? '$totalGanados / $meta'
                            : '$totalGanados',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (tieneProyectos || tienePersonales) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (tieneProyectos)
                    _buildLeyendaChip(
                        color: Colors.amber.shade600,
                        icon: Icons.workspace_premium,
                        label:
                            '${_asistenciasDelEvento.length} Proyectos'),
                  if (tienePersonales)
                    _buildLeyendaChip(
                        color: Colors.deepPurple.shade600,
                        icon: Icons.how_to_reg_rounded,
                        label:
                            '${_asistenciasPersonalesDelEvento.length} Personal'),
                ],
              ),
            ],
            if (metaFija) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progreso',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${((totalGanados / meta) * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1E3A5F),
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (totalGanados / meta).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    totalGanados >= meta
                        ? Colors.green.shade500
                        : const Color(0xFF2563EB),
                  ),
                ),
              ),
              if (totalGanados < meta) ...[
                const SizedBox(height: 6),
                Text(
                  '${meta - totalGanados} sello${meta - totalGanados == 1 ? '' : 's'} restante${meta - totalGanados == 1 ? '' : 's'}',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ],
            const SizedBox(height: 20),
            if (totalCeldas == 0)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16)),
                child: Center(
                  child: Column(children: [
                    Icon(Icons.workspace_premium_outlined,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Aún no tienes sellos en este evento',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: totalCeldas,
                itemBuilder: (context, index) {
                  final esGanado = index < totalGanados;
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(
                        milliseconds:
                            esGanado ? 300 + (index * 50) : 200),
                    curve:
                        esGanado ? Curves.elasticOut : Curves.easeOut,
                    builder: (ctx, val, _) => Transform.scale(
                      scale: val,
                      child: esGanado
                          ? _buildSelloGanado(sellos[index])
                          : _buildSelloVacio(index + 1),
                    ),
                  );
                },
              ),
            if (totalGanados > 0) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.amber.shade50,
                    Colors.orange.shade50
                  ]),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.amber.shade200, width: 2),
                ),
                child: Row(children: [
                  Icon(Icons.celebration,
                      color: Colors.amber.shade700, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metaFija && totalGanados >= meta
                              ? '¡Meta completada!'
                              : '¡Excelente trabajo!',
                          style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metaFija
                              ? 'Has ganado $totalGanados de $meta sellos'
                              : 'Has ganado $totalGanados sello${totalGanados == 1 ? '' : 's'}',
                          style: TextStyle(
                              color: Colors.amber.shade800, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeyendaChip({
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 9, color: color, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }

  Widget _buildSelloGanado(Map<String, dynamic> sello) {
    final timestamp = (sello['timestamp'] as Timestamp?)?.toDate();
    final esPersonal = sello['tipoSello'] == 'personal';

    final String etiqueta;
    final Color color;
    final IconData icono;

    if (esPersonal) {
      etiqueta =
          sello['asistenciaNombre']?.toString() ?? 'Asistencia personal';
      color = Colors.deepPurple.shade600;
      icono = Icons.how_to_reg_rounded;
    } else {
      final categoria =
          (sello['categoria'] ?? sello['tipoInvestigacion'] ?? 'Sin categoría')
              .toString();
      etiqueta = categoria;
      color = _getColorByCategoria(categoria);
      icono = _getIconByCategoria(categoria);
    }

    return Tooltip(
      message: etiqueta,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.8),
              color.withValues(alpha: 0.6),
              color.withValues(alpha: 0.4),
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 2,
                offset: const Offset(0, 4)),
          ],
          border: Border.all(color: color.withValues(alpha: 0.8), width: 3),
        ),
        child: Stack(children: [
          Positioned.fill(
            child: CustomPaint(
                painter:
                    SelloPainter(color: color.withValues(alpha: 0.2))),
          ),
          Center(
            child: Icon(icono, color: Colors.white, size: 22, shadows: [
              Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  offset: const Offset(1, 1),
                  blurRadius: 2)
            ]),
          ),
          if (timestamp != null)
            Positioned(
              bottom: 6,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '${timestamp.day}/${timestamp.month}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                            color: Colors.black54,
                            offset: Offset(0.5, 0.5),
                            blurRadius: 1)
                      ]),
                ),
              ),
            ),
          Positioned.fill(
              child: CustomPaint(painter: const TextoCurvadoPainter())),
        ]),
      ),
    );
  }

  Widget _buildSelloVacio(int numero) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: Stack(children: [
        Center(
          child: Icon(Icons.workspace_premium_outlined,
              size: 24, color: Colors.grey.shade300),
        ),
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              '$numero',
              style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 9,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHistorialCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12)),
              child:
                  const Icon(Icons.history, color: Color(0xFF1E3A5F), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Historial de Proyectos',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F)),
              ),
            ),
            if (_asistenciasDelEvento.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFE8EDF2),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${_asistenciasDelEvento.length}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F)),
                ),
              ),
          ]),
          const SizedBox(height: 20),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _asistenciasDelEvento.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 300 + (index * 100)),
                curve: Curves.easeOut,
                builder: (ctx, val, _) => Transform.translate(
                  offset: Offset(0, 20 * (1 - val)),
                  child: Opacity(
                      opacity: val,
                      child: _buildAsistenciaCard(
                          _asistenciasDelEvento[index])),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAsistenciaCard(Map<String, dynamic> asistencia) {
    final timestamp = (asistencia['timestamp'] as Timestamp?)?.toDate();
    final categoria =
        (asistencia['categoria'] ?? asistencia['tipoInvestigacion'] ?? 'Sin categoría')
            .toString();
    final codigoProyecto = asistencia['codigoProyecto'];
    final tituloProyecto = asistencia['tituloProyecto'];
    final grupo = asistencia['grupo'];

    final hasValidCode = _esValorValido(codigoProyecto);
    final hasValidGroup = _esValorValido(grupo);
    final hasValidTitle = _esValorValido(tituloProyecto);

    final maxChipWidth = MediaQuery.sizeOf(context).width * 0.7;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            _getColorByCategoria(categoria).withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _getColorByCategoria(categoria).withValues(alpha: 0.3),
            width: 1.5),
        boxShadow: [
          BoxShadow(
              color: _getColorByCategoria(categoria).withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  _getColorByCategoria(categoria).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: _getColorByCategoria(categoria),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(_getIconByCategoria(categoria),
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasValidCode)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            Color(0xFF1E40AF),
                            Color(0xFF2563EB)
                          ]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.qr_code_2,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                codigoProyecto.toString().toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                    color: Color(0xFF059669), shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 18),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxChipWidth),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getColorByCategoria(categoria)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _getColorByCategoria(categoria)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getIconByCategoria(categoria),
                                size: 14,
                                color: _getColorByCategoria(categoria)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                categoria,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: _getColorByCategoria(categoria),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (hasValidGroup)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxChipWidth),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFF7C3AED)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.group,
                                  size: 14, color: Color(0xFF7C3AED)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  grupo.toString().toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Color(0xFF7C3AED),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (hasValidTitle) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF4F46E5)
                              .withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.article_outlined,
                              size: 18, color: Color(0xFF4F46E5)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Proyecto Presentado',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4F46E5),
                                    letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tituloProyecto.toString(),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF312E81),
                                    height: 1.3),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Divider(color: Colors.grey.shade200, height: 1),
                const SizedBox(height: 12),
                if (timestamp != null)
                  _buildInfoChip(
                    icon: Icons.check_circle_outline,
                    label: 'Registrado',
                    value:
                        '${timestamp.day}/${timestamp.month}/${timestamp.year}',
                    color: const Color(0xFF059669),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaAsistenciasPersonales() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.how_to_reg_rounded,
                  color: Colors.deepPurple.shade600, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Asistencias Personales',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade600,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_asistenciasPersonalesDelEvento.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _asistenciasPersonalesDelEvento.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final asistencia = _asistenciasPersonalesDelEvento[index];
              final timestamp =
                  (asistencia['timestamp'] as Timestamp?)?.toDate();
              final nombre =
                  asistencia['asistenciaNombre'] as String? ?? 'Asistencia personal';
              final tipo =
                  asistencia['asistenciaTipo'] as String? ?? 'Asistencia Personal';

              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 250 + (index * 80)),
                curve: Curves.easeOut,
                builder: (ctx, val, _) => Opacity(
                  opacity: val,
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - val)),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.deepPurple.shade100, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.deepPurple.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade600,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.how_to_reg_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade600,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'PERSONAL',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    tipo,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.deepPurple.shade400),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 5),
                              Text(
                                nombre,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E3A5F)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (timestamp != null) ...[
                                const SizedBox(height: 6),
                                Row(children: [
                                  Icon(Icons.schedule,
                                      size: 12,
                                      color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${timestamp.day}/${timestamp.month}/${timestamp.year}  '
                                      '${timestamp.hour.toString().padLeft(2, '0')}:'
                                      '${timestamp.minute.toString().padLeft(2, '0')}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500),
                                    ),
                                  ),
                                ]),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(
                              color: Color(0xFF059669),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 16),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w600, color: color),
              ),
              Text(
                value,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SelloPainter extends CustomPainter {
  final Color color;
  const SelloPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * (3.14159 / 180);
      final start = Offset(center.dx + radius * 0.6 * math.cos(angle),
          center.dy + radius * 0.6 * math.sin(angle));
      final end = Offset(center.dx + radius * 0.9 * math.cos(angle),
          center.dy + radius * 0.9 * math.sin(angle));
      canvas.drawLine(start, end, paint..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class TextoCurvadoPainter extends CustomPainter {
  const TextoCurvadoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width / 2 - 8, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}