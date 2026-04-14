import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import '/admin/logica/periodos_helper.dart';
import 'dart:math' as math;

class AsistenciasScreen extends StatefulWidget {
  const AsistenciasScreen({super.key});

  @override
  State<AsistenciasScreen> createState() => _AsistenciasScreenState();
}

class _AsistenciasScreenState extends State<AsistenciasScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserId;
  String? _currentUserName;
  bool _isLoadingAsistencias = false;

  // ✅ Datos académicos del estudiante (sede, facultad, carrera)
  String? _studentSede;
  String? _studentFacultad;
  String? _studentCarrera;
  String? _studentCiclo;
  String? _studentGrupo;

  List<Map<String, dynamic>> _eventosConAsistencias = [];
  List<Map<String, dynamic>> _asistenciasFiltradas = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String? _periodoSeleccionado;
  List<Map<String, dynamic>> _periodosDisponibles = [];
  String? _eventoSeleccionado;
  List<Map<String, dynamic>> _eventosDisponibles = [];

  final Map<String, Map<String, dynamic>> _eventosCache = {};
  final Map<String, List<Map<String, dynamic>>> _asistenciasPorEventoCache = {};
  static const int _eventosPorPagina = 10;
  DocumentSnapshot? _ultimoEventoCargado;
  bool _hayMasEventos = true;

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

  // ═══════════════════════════════════════════════════════════════
  // ✅ OBTENER USUARIO Y DATOS ACADÉMICOS
  // ═══════════════════════════════════════════════════════════════
  Future<void> _getCurrentUserId() async {
    try {
      final userId = await PrefsHelper.getCurrentUserId();
      final userName = await PrefsHelper.getUserName();
      final userData = await PrefsHelper.getCurrentUserData();

      if (userId != null) {
        setState(() {
          _currentUserId = userId;
          _currentUserName = userName;

          if (userData != null) {
            // Sede: priorizar 'sede', fallback a 'filial'
            final sede = userData['sede']?.toString() ?? '';
            final filial = userData['filial']?.toString() ?? '';
            _studentSede = sede.isNotEmpty
                ? sede
                : filial.isNotEmpty
                ? filial
                : null;

            _studentFacultad = userData['facultad']?.toString();
            _studentCarrera = userData['carrera']?.toString();
            _studentCiclo = userData['ciclo']?.toString();
            _studentGrupo = userData['grupo']?.toString();
          }
        });
      } else {
        _showSnackBar('No se pudo obtener el usuario actual', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error al obtener usuario: $e', isError: true);
    }
  }

  void _calcularEventosDisponibles() {
    final Map<String, Map<String, dynamic>> eventosMap = {};
    for (var eventoData in _eventosConAsistencias) {
      final eventId = eventoData['eventId'];
      final eventName = eventoData['eventName'];
      if (eventId != null &&
          eventName != null &&
          eventName != 'Sin nombre' &&
          eventName != 'Evento eliminado') {
        if (!eventosMap.containsKey(eventId)) {
          eventosMap[eventId] = {'id': eventId, 'name': eventName};
        }
      }
    }
    setState(() {
      _eventosDisponibles = eventosMap.values.toList()
        ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    });
  }

  Future<void> _cargarPeriodosActivos() async {
    if (_periodosDisponibles.isNotEmpty) {
      _filtrarAsistencias();
      return;
    }
    try {
      final periodos = await PeriodosHelper.getPeriodosActivos();
      setState(() {
        _periodosDisponibles = periodos;
        if (_periodoSeleccionado == null && _periodosDisponibles.isNotEmpty) {
          _periodoSeleccionado = _periodosDisponibles.first['id'];
        }
      });
      _filtrarAsistencias();
    } catch (e) {
      _showSnackBar('Error al cargar períodos: $e', isError: true);
    }
  }

  bool _asistenciaPerteneceAPeriodo(
    Map<String, dynamic> asistencia,
    Map<String, dynamic> periodo,
  ) {
    final timestamp = (asistencia['timestamp'] as Timestamp?)?.toDate();
    if (timestamp == null) return false;
    final fechaInicio = (periodo['fechaInicio'] as Timestamp?)?.toDate();
    final fechaFin = (periodo['fechaFin'] as Timestamp?)?.toDate();
    if (fechaInicio == null || fechaFin == null) return false;
    return timestamp.isAfter(fechaInicio.subtract(const Duration(days: 1))) &&
        timestamp.isBefore(fechaFin.add(const Duration(days: 1)));
  }

  void _filtrarAsistencias() {
    setState(() {
      _asistenciasFiltradas = [];
      for (var eventoData in _eventosConAsistencias) {
        for (var asistencia in eventoData['asistencias'] ?? []) {
          bool cumplePeriodo = true;
          if (_periodoSeleccionado != null) {
            final periodo = _periodosDisponibles.firstWhere(
              (p) => p['id'] == _periodoSeleccionado,
              orElse: () => {},
            );
            if (periodo.isNotEmpty) {
              cumplePeriodo = _asistenciaPerteneceAPeriodo(asistencia, periodo);
            }
          }
          bool cumpleEvento = true;
          if (_eventoSeleccionado != null) {
            cumpleEvento = eventoData['eventId'] == _eventoSeleccionado;
          }
          if (cumplePeriodo && cumpleEvento) {
            _asistenciasFiltradas.add({
              ...asistencia,
              'eventId': eventoData['eventId'],
              'eventName': eventoData['eventName'],
              'eventDescription': eventoData['eventDescription'],
              'eventDate': eventoData['eventDate'],
              'eventFacultad': eventoData['eventFacultad'],
              'eventCarrera': eventoData['eventCarrera'],
              // ✅ Sede del evento (si existe)
              'eventSede': eventoData['eventSede'],
            });
          }
        }
      }
      _asistenciasFiltradas.sort((a, b) {
        final tA = (a['timestamp'] as Timestamp?)?.toDate();
        final tB = (b['timestamp'] as Timestamp?)?.toDate();
        if (tA == null || tB == null) return 0;
        return tB.compareTo(tA);
      });
    });
  }

  Future<void> _cargarMisAsistencias({bool cargarMas = false}) async {
    if (_currentUserId == null) return;

    if (!cargarMas) {
      setState(() {
        _isLoadingAsistencias = true;
        _eventosConAsistencias.clear();
        _ultimoEventoCargado = null;
        _hayMasEventos = true;
      });
    }

    try {
      final parts = _currentUserId!.split('/');
      if (parts.length != 2) throw Exception('ID de usuario inválido');
      final studentId = parts[1];

      final hoy = DateTime.now();
      final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);

      Query eventosQuery = _firestore
          .collection('events')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              inicioHoy.subtract(const Duration(days: 30)),
            ),
          )
          .orderBy('createdAt', descending: true)
          .limit(_eventosPorPagina);

      if (cargarMas && _ultimoEventoCargado != null) {
        eventosQuery = eventosQuery.startAfterDocument(_ultimoEventoCargado!);
      }

      final eventosSnapshot = await eventosQuery.get();

      if (eventosSnapshot.docs.isEmpty) {
        setState(() => _hayMasEventos = false);
      } else {
        _ultimoEventoCargado = eventosSnapshot.docs.last;
        if (eventosSnapshot.docs.length < _eventosPorPagina) {
          _hayMasEventos = false;
        }

        final List<Future<void>> cargaEventos = [];
        for (var eventDoc in eventosSnapshot.docs) {
          cargaEventos.add(_cargarAsistenciasDeEvento(eventDoc, studentId));
        }
        await Future.wait(cargaEventos);

        _eventosConAsistencias.sort((a, b) {
          final dateA = (a['eventDate'] as Timestamp?)?.toDate();
          final dateB = (b['eventDate'] as Timestamp?)?.toDate();
          if (dateA == null || dateB == null) return 0;
          return dateB.compareTo(dateA);
        });

        if (!cargarMas) {
          await _cargarPeriodosActivos();
          _calcularEventosDisponibles();
        } else {
          _filtrarAsistencias();
          _calcularEventosDisponibles();
        }

        int totalAsistencias = 0;
        for (var evento in _eventosConAsistencias) {
          totalAsistencias += (evento['asistencias'] as List).length;
        }
        if (totalAsistencias > 0) {
          _showSnackBar(
            'Se cargaron $totalAsistencias asistencia(s) de ${_eventosConAsistencias.length} evento(s)',
          );
        }
      }
    } catch (e) {
      _showSnackBar('Error al cargar asistencias: $e', isError: true);
    } finally {
      setState(() => _isLoadingAsistencias = false);
    }
  }

  Future<void> _cargarAsistenciasDeEvento(
    DocumentSnapshot eventDoc,
    String studentId,
  ) async {
    try {
      final eventId = eventDoc.id;
      final eventData = eventDoc.data() as Map<String, dynamic>;

      final resumenDoc = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias')
          .doc(studentId)
          .get();

      if (!resumenDoc.exists) return;

      final scansSnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias')
          .doc(studentId)
          .collection('scans')
          .orderBy('timestamp', descending: true)
          .get();

      if (scansSnapshot.docs.isEmpty) return;

      final List<Map<String, dynamic>> asistencias = [];
      for (var scanDoc in scansSnapshot.docs) {
        final scanData = scanDoc.data();
        if (scanData['timestamp'] == null) continue;
        asistencias.add({
          'id': scanDoc.id,
          'timestamp': scanData['timestamp'],
          'categoria': scanData['categoria'] ?? 'Sin categoría',
          'tipoInvestigacion': scanData['categoria'] ?? 'Sin categoría',
          'codigoProyecto': scanData['codigoProyecto'] ?? 'Sin código',
          'tituloProyecto': scanData['tituloProyecto'] ?? 'Sin título',
          'grupo': scanData['grupo'],
          'qrId': scanData['qrId'],
          'registrationMethod': scanData['registrationMethod'] ?? 'qr_scan',
        });
      }

      if (asistencias.isEmpty) return;

      _asistenciasPorEventoCache[eventId] = asistencias;

      // ✅ Extraer sede del evento
      final eventSede =
          eventData['sede']?.toString() ??
          eventData['filialNombre']?.toString() ??
          '';

      _eventosConAsistencias.add({
        'eventId': eventId,
        'eventName': eventData['name'] ?? 'Sin nombre',
        'eventDescription': eventData['description'] ?? '',
        'eventDate': eventData['date'],
        'eventFacultad': eventData['facultad'] ?? '',
        'eventCarrera': eventData['carrera'] ?? '',
        'eventSede': eventSede,
        'asistencias': asistencias,
      });

      _eventosCache[eventId] = {
        'name': eventData['name'],
        'description': eventData['description'],
        'date': eventData['date'],
        'facultad': eventData['facultad'],
        'carrera': eventData['carrera'],
        'sede': eventSede,
      };
    } catch (e) {
      debugPrint('Error cargando evento ${eventDoc.id}: $e');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _getColorByCategoria(String? categoria) {
    if (categoria == null || categoria.isEmpty) return const Color(0xFF5A6C7D);
    final hash = categoria.hashCode;
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
    return colors[hash.abs() % colors.length];
  }

  IconData _getIconByCategoria(String? categoria) {
    if (categoria == null || categoria.isEmpty) return Icons.help;
    final c = categoria.toLowerCase();
    if (c.contains('revisión') || c.contains('revision')) {
      return Icons.library_books;
    }
    if (c.contains('empírico') || c.contains('empirico')) {
      return Icons.science;
    }
    if (c.contains('innovación') ||
        c.contains('innovacion') ||
        c.contains('tecnológica')) {
      return Icons.lightbulb;
    }
    if (c.contains('narrativa')) {
      return Icons.auto_stories;
    }
    if (c.contains('descriptiv')) {
      return Icons.description;
    }
    if (c.contains('experimental')) {
      return Icons.biotech;
    }
    if (c.contains('teóric') || c.contains('teorico')) {
      return Icons.psychology;
    }
    if (c.contains('cualitativ')) {
      return Icons.forum;
    }
    if (c.contains('cuantitativ')) {
      return Icons.analytics;
    }
    return Icons.assignment;
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ BANNER DE DATOS ACADÉMICOS DEL ESTUDIANTE (sede + carrera)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBannerAcademico() {
    if (_studentSede == null && _studentFacultad == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Mi Información Académica',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_studentSede != null)
                _buildAcademicoChip(
                  icon: Icons.location_city,
                  label: _studentSede!,
                  bgColor: Colors.blue.shade700,
                ),
              if (_studentFacultad != null)
                _buildAcademicoChip(
                  icon: Icons.account_balance,
                  label: _studentFacultad!,
                  bgColor: Colors.purple.shade700,
                ),
              if (_studentCarrera != null)
                _buildAcademicoChip(
                  icon: Icons.menu_book,
                  label: _studentCarrera!,
                  bgColor: Colors.teal.shade700,
                ),
              if (_studentCiclo != null)
                _buildAcademicoChip(
                  icon: Icons.layers,
                  label: 'Ciclo $_studentCiclo',
                  bgColor: Colors.orange.shade700,
                ),
              if (_studentGrupo != null)
                _buildAcademicoChip(
                  icon: Icons.groups,
                  label: 'Grupo $_studentGrupo',
                  bgColor: Colors.green.shade700,
                ),
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
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
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelloAsistencia(Map<String, dynamic> asistencia) {
    final timestamp = (asistencia['timestamp'] as Timestamp?)?.toDate();
    final categoria =
        asistencia['categoria'] ??
        asistencia['tipoInvestigacion'] ??
        'Sin categoría';
    final color = _getColorByCategoria(categoria);

    return Tooltip(
      message: '${asistencia['eventName'] ?? ''}\n$categoria',
      child: Container(
        width: 80,
        height: 80,
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
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: color.withValues(alpha: 0.8),
            width: 3,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: SelloPainter(color: color.withValues(alpha: 0.2)),
              ),
            ),
            Center(
              child: Icon(
                _getIconByCategoria(categoria),
                color: Colors.white,
                size: 22,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
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
                          blurRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned.fill(child: CustomPaint(painter: TextoCurvadoPainter())),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltroPeriodo() {
    if (_periodosDisponibles.isEmpty && _eventosDisponibles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          if (_periodosDisponibles.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_month,
                    color: Color(0xFF1E3A5F),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Filtrar por periodo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _periodosDisponibles
                  .map(
                    (p) =>
                        _buildPeriodoChip(p['nombre'] ?? 'Sin nombre', p['id']),
                  )
                  .toList(),
            ),
          ],
          if (_periodosDisponibles.isNotEmpty &&
              _eventosDisponibles.isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 20),
          ],
          if (_eventosDisponibles.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.event,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Filtrar por evento',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildEventoDropdown(),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodoChip(String label, String? valor) {
    final isSelected = _periodoSeleccionado == valor;
    return InkWell(
      onTap: () {
        setState(() => _periodoSeleccionado = valor);
        _filtrarAsistencias();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1E3A5F)
                : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildEventoDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _eventoSeleccionado != null
              ? const Color(0xFF2563EB)
              : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _eventoSeleccionado,
          isExpanded: true,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Todos los eventos',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          icon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
          ),
          items: [
            DropdownMenuItem<String>(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.all_inclusive,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Todos los eventos',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ..._eventosDisponibles.map((evento) {
              return DropdownMenuItem<String>(
                value: evento['id'],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          evento['name'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E3A5F),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          onChanged: (value) {
            setState(() => _eventoSeleccionado = value);
            _filtrarAsistencias();
          },
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildColeccionSellos() {
    final totalSellos = _asistenciasFiltradas.length;
    return AnimatedOpacity(
      opacity: _isLoadingAsistencias ? 0.0 : 1.0,
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.workspace_premium,
                    color: Colors.amber.shade600,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mis Sellos de Asistencia',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      // ✅ Mostrar sede del estudiante en la colección de sellos
                      if (_studentSede != null)
                        Row(
                          children: [
                            Icon(
                              Icons.location_city,
                              size: 12,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _studentSede!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      if (_periodoSeleccionado != null)
                        Text(
                          _periodosDisponibles.firstWhere(
                                (p) => p['id'] == _periodoSeleccionado,
                                orElse: () => {'nombre': ''},
                              )['nombre'] ??
                              '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A5F).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '$totalSellos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (totalSellos == 0)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.workspace_premium_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aún no tienes sellos',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Escanea códigos QR en eventos para ganar sellos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: totalSellos,
                itemBuilder: (context, index) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 300 + (index * 50)),
                    curve: Curves.elasticOut,
                    builder: (context, double value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Hero(
                          tag: 'sello_${_asistenciasFiltradas[index]['id']}',
                          child: _buildSelloAsistencia(
                            _asistenciasFiltradas[index],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            if (totalSellos > 0) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade50, Colors.orange.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.celebration,
                      color: Colors.amber.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Excelente trabajo!',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Has ganado $totalSellos ${totalSellos == 1 ? 'sello' : 'sellos'} de asistencia${_studentSede != null ? ' en ${_studentSede!}' : ''}',
                            style: TextStyle(
                              color: Colors.amber.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Volver',
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.verified_user,
                      color: Color(0xFF1E3A5F),
                      size: 30,
                    ),
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
                            color: Colors.white,
                          ),
                        ),
                        if (_currentUserName != null)
                          Text(
                            _currentUserName!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        // ✅ Sede del estudiante en el header
                        if (_studentSede != null)
                          Row(
                            children: [
                              Icon(
                                Icons.location_city,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _studentSede!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => _cargarMisAsistencias(),
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
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
                    : _eventosConAsistencias.isEmpty && !_isLoadingAsistencias
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_available,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 24),
                              // ✅ Mostrar sede en pantalla vacía
                              if (_studentSede != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.blue.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.location_city,
                                        size: 16,
                                        color: Colors.blue.shade700,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _studentSede!,
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              const Text(
                                'Tus asistencias están guardadas',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A5F),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Presiona el botón para cargarlas cuando lo necesites',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),
                              ElevatedButton.icon(
                                onPressed: _cargarMisAsistencias,
                                icon: const Icon(
                                  Icons.cloud_download,
                                  size: 24,
                                ),
                                label: const Text(
                                  'Cargar Mis Asistencias',
                                  style: TextStyle(fontSize: 16),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A5490),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _cargarMisAsistencias(),
                        color: const Color(0xFF1E3A5F),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20.0),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ✅ Banner académico con sede
                                _buildBannerAcademico(),
                                _buildFiltroPeriodo(),
                                _buildColeccionSellos(),
                                _buildAsistenciasCard(),
                                if (_hayMasEventos && !_isLoadingAsistencias)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 20),
                                    child: Center(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _cargarMisAsistencias(
                                          cargarMas: true,
                                        ),
                                        icon: const Icon(Icons.expand_more),
                                        label: const Text('Cargar más eventos'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFF1E3A5F,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFF1E3A5F),
                                            width: 2,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAsistenciasCard() {
    return AnimatedOpacity(
      opacity: _isLoadingAsistencias ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.all(20.0),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.history,
                    color: Color(0xFF1E3A5F),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Historial Detallado',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
                if (_asistenciasFiltradas.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EDF2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_asistenciasFiltradas.length}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isLoadingAsistencias)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: Color(0xFF1E3A5F)),
                      SizedBox(height: 16),
                      Text(
                        'Cargando asistencias...',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_asistenciasFiltradas.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.event_busy,
                        size: 64,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _periodoSeleccionado != null
                            ? 'No hay asistencias en este período'
                            : 'No tienes asistencias registradas',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF1E3A5F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _periodoSeleccionado != null
                            ? 'Selecciona otro periodo o registra nuevas asistencias'
                            : 'Escanea un código QR para registrar tu primera asistencia',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _asistenciasFiltradas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 300 + (index * 100)),
                    curve: Curves.easeOut,
                    builder: (context, double value, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: _buildAsistenciaCard(
                            _asistenciasFiltradas[index],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAsistenciaCard(Map<String, dynamic> asistencia) {
    final timestamp = (asistencia['timestamp'] as Timestamp?)?.toDate();
    final eventDate = (asistencia['eventDate'] as Timestamp?)?.toDate();
    final categoria =
        asistencia['categoria'] ??
        asistencia['tipoInvestigacion'] ??
        'Sin categoría';
    final codigoProyecto = asistencia['codigoProyecto'];
    final tituloProyecto = asistencia['tituloProyecto'];
    final grupo = asistencia['grupo'];
    // ✅ Sede del evento
    final eventSede = asistencia['eventSede']?.toString() ?? '';

    final hasValidCode = _esValorValido(codigoProyecto);
    final hasValidGroup = _esValorValido(grupo);
    final hasValidTitle = _esValorValido(tituloProyecto);
    final hasEventSede = eventSede.isNotEmpty;

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
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _getColorByCategoria(categoria).withValues(alpha: 0.1),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera de la card ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getColorByCategoria(categoria).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getColorByCategoria(categoria),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: _getColorByCategoria(
                          categoria,
                        ).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getIconByCategoria(categoria),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asistencia['eventName'] ?? 'Sin nombre',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // ✅ Sede del evento debajo del nombre
                      if (hasEventSede) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_city,
                              size: 12,
                              color: Colors.blue.shade600,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                eventSede,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (hasValidCode) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.qr_code_2,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                codigoProyecto.toString().toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF059669),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),

          // ── Cuerpo de la card ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chips de categoría y grupo
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getColorByCategoria(
                          categoria,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getColorByCategoria(
                            categoria,
                          ).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getIconByCategoria(categoria),
                            size: 14,
                            color: _getColorByCategoria(categoria),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            categoria,
                            style: TextStyle(
                              color: _getColorByCategoria(categoria),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasValidGroup)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.group,
                              size: 14,
                              color: Color(0xFF7C3AED),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              grupo.toString().toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF7C3AED),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // Título del proyecto
                if (hasValidTitle) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.article_outlined,
                            size: 18,
                            color: Color(0xFF4F46E5),
                          ),
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
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tituloProyecto.toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF312E81),
                                  height: 1.3,
                                ),
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

                // Info facultad/carrera del evento
                if ((asistencia['eventFacultad']?.isNotEmpty == true) &&
                    (asistencia['eventCarrera']?.isNotEmpty == true)) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${asistencia['eventFacultad']} • ${asistencia['eventCarrera']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Divider(color: Colors.grey.shade200, height: 1),
                const SizedBox(height: 12),

                // Chips de fecha
                Row(
                  children: [
                    if (eventDate != null)
                      Expanded(
                        child: _buildInfoChip(
                          icon: Icons.event_outlined,
                          label: 'Evento',
                          value:
                              '${eventDate.day}/${eventDate.month}/${eventDate.year}',
                          color: const Color(0xFF0891B2),
                        ),
                      ),
                    if (eventDate != null) const SizedBox(width: 8),
                    if (timestamp != null)
                      Expanded(
                        child: _buildInfoChip(
                          icon: Icons.check_circle_outline,
                          label: 'Registrado',
                          value:
                              '${timestamp.day}/${timestamp.month}/${timestamp.year}',
                          color: const Color(0xFF059669),
                        ),
                      ),
                  ],
                ),
              ],
            ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PAINTERS (sin cambios)
// ══════════════════════════════════════════════════════════════════
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
      final start = Offset(
        center.dx + radius * 0.6 * math.cos(angle),
        center.dy + radius * 0.6 * math.sin(angle),
      );
      final end = Offset(
        center.dx + radius * 0.9 * math.cos(angle),
        center.dy + radius * 0.9 * math.sin(angle),
      );
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
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 8,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}