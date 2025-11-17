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

  // ✅ NUEVA ESTRUCTURA: Guardamos eventos con sus asistencias
  List<Map<String, dynamic>> _eventosConAsistencias = [];
  List<Map<String, dynamic>> _asistenciasFiltradas = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Variables para el filtro de periodo
  String? _periodoSeleccionado;
  List<Map<String, dynamic>> _periodosDisponibles = [];
  String? _eventoSeleccionado;
  List<Map<String, dynamic>> _eventosDisponibles = [];

  // ✅ CACHÉ DE EVENTOS (evita recargar eventos repetidamente)
  final Map<String, Map<String, dynamic>> _eventosCache = {};
  final Map<String, List<Map<String, dynamic>>> _asistenciasPorEventoCache = {};
  // ✅ OPTIMIZACIÓN: Paginación para eventos
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

  // Cargar períodos activos de la base de datos
  Future<void> _cargarPeriodosActivos() async {
    if (_periodosDisponibles.isNotEmpty) {
      print('✅ Períodos ya cargados desde caché');
      _filtrarAsistencias();
      return;
    }
    try {
      final periodos = await PeriodosHelper.getPeriodosActivos();

      setState(() {
        _periodosDisponibles = periodos;
        // Seleccionar el primer período activo si no hay ninguno seleccionado
        if (_periodoSeleccionado == null && _periodosDisponibles.isNotEmpty) {
          _periodoSeleccionado = _periodosDisponibles.first['id'];
        }
      });

      _filtrarAsistencias();
    } catch (e) {
      print('Error cargando períodos activos: $e');
      _showSnackBar('Error al cargar períodos: $e', isError: true);
    }
  }

  // Verificar si una asistencia pertenece a un período
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
          // Filtro por periodo
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

          // Filtro por evento
          bool cumpleEvento = true;
          if (_eventoSeleccionado != null) {
            cumpleEvento = eventoData['eventId'] == _eventoSeleccionado;
          }

          if (cumplePeriodo && cumpleEvento) {
            // ✅ Agregar datos del evento a la asistencia
            _asistenciasFiltradas.add({
              ...asistencia,
              'eventId': eventoData['eventId'],
              'eventName': eventoData['eventName'],
              'eventDescription': eventoData['eventDescription'],
              'eventDate': eventoData['eventDate'],
              'eventFacultad': eventoData['eventFacultad'],
              'eventCarrera': eventoData['eventCarrera'],
            });
          }
        }
      }

      // Ordenar por fecha (más reciente primero)
      _asistenciasFiltradas.sort((a, b) {
        final timestampA = (a['timestamp'] as Timestamp?)?.toDate();
        final timestampB = (b['timestamp'] as Timestamp?)?.toDate();
        if (timestampA == null || timestampB == null) return 0;
        return timestampB.compareTo(timestampA);
      });
    });
  }

  Future<void> _getCurrentUserId() async {
    try {
      final userId = await PrefsHelper.getCurrentUserId();
      final userName = await PrefsHelper.getUserName();
      if (userId != null) {
        setState(() {
          _currentUserId = userId;
          _currentUserName = userName;
        });
      } else {
        _showSnackBar('No se pudo obtener el usuario actual', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error al obtener usuario: $e', isError: true);
    }
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
      if (parts.length != 2) {
        throw Exception('ID de usuario inválido');
      }

      final studentId = parts[1];

      print('═══════════════════════════════════════════════════════');
      print('👤 USER ID COMPLETO: $_currentUserId');
      print('   📂 Carrera Path: ${parts[0]}');
      print('   🆔 Student ID: $studentId');
      print('═══════════════════════════════════════════════════════');

      // ═══════════════════════════════════════════════════════════════
      // PASO 1: OBTENER TODOS LOS EVENTOS (sin orderBy para evitar índices)
      // ═══════════════════════════════════════════════════════════════
      print('🔍 Buscando eventos...');

      final hoy = DateTime.now();
      final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);

      Query eventosQuery = _firestore
          .collection('events')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              inicioHoy.subtract(Duration(days: 30)),
            ),
          )
          .orderBy('createdAt', descending: true)
          .limit(_eventosPorPagina);

      if (cargarMas && _ultimoEventoCargado != null) {
        eventosQuery = eventosQuery.startAfterDocument(_ultimoEventoCargado!);
      }

      final eventosSnapshot = await eventosQuery.get();

      print('📊 Eventos encontrados: ${eventosSnapshot.docs.length}');

      if (eventosSnapshot.docs.isEmpty) {
        setState(() {
          _hayMasEventos = false;
        });
        if (!cargarMas) {
          print('⚠️ No hay eventos en la base de datos');
        }
      } else {
        _ultimoEventoCargado = eventosSnapshot.docs.last;

        if (eventosSnapshot.docs.length < _eventosPorPagina) {
          _hayMasEventos = false;
        }

        // ═══════════════════════════════════════════════════════════════
        // PASO 2: POR CADA EVENTO, VERIFICAR SI EL ESTUDIANTE TIENE ASISTENCIAS
        // ═══════════════════════════════════════════════════════════════
        final List<Future<void>> cargaEventos = [];

        for (var eventDoc in eventosSnapshot.docs) {
          cargaEventos.add(_cargarAsistenciasDeEvento(eventDoc, studentId));
        }

        // ✅ EJECUTAR TODAS LAS CONSULTAS EN PARALELO
        await Future.wait(cargaEventos);

        print(
          '✅ Total de eventos con asistencias: ${_eventosConAsistencias.length}',
        );

        // Ordenar por fecha después de cargar (en memoria)
        _eventosConAsistencias.sort((a, b) {
          final dateA = (a['eventDate'] as Timestamp?)?.toDate();
          final dateB = (b['eventDate'] as Timestamp?)?.toDate();
          if (dateA == null || dateB == null) return 0;
          return dateB.compareTo(dateA);
        });

        // ═══════════════════════════════════════════════════════════════
        // PASO 3: CARGAR PERÍODOS Y FILTRAR
        // ═══════════════════════════════════════════════════════════════
        // PASO 3: CARGAR PERÍODOS Y FILTRAR
        if (!cargarMas) {
          await _cargarPeriodosActivos();
          _calcularEventosDisponibles();
        } else {
          _filtrarAsistencias();
          _calcularEventosDisponibles();
        }

        // Contar total de asistencias
        int totalAsistencias = 0;
        for (var evento in _eventosConAsistencias) {
          totalAsistencias += (evento['asistencias'] as List).length;
        }

        if (totalAsistencias > 0) {
          _showSnackBar(
            'Se cargaron $totalAsistencias asistencia(s) de ${_eventosConAsistencias.length} evento(s)',
          );
        } else {
          print('⚠️ No se encontraron asistencias para este estudiante');
        }
      }
    } catch (e) {
      _showSnackBar('Error al cargar asistencias: $e', isError: true);
      print('❌ Error detallado: $e');
    } finally {
      setState(() {
        _isLoadingAsistencias = false;
      });
    }
  }

  Future<void> _cargarAsistenciasDeEvento(
    DocumentSnapshot eventDoc,
    String studentId,
  ) async {
    try {
      final eventId = eventDoc.id;
      final eventData = eventDoc.data() as Map<String, dynamic>;

      print('🔍 Buscando asistencias en evento: $eventId');
      print('   👤 Estudiante: $studentId');
      final resumenDoc = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias')
          .doc(studentId)
          .get();

      if (!resumenDoc.exists) {
        // No hay asistencias de este estudiante en este evento
        return;
      }

      print('📄 Resumen encontrado para evento: $eventId');

      // Ahora cargar todos los scans
      final scansSnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias')
          .doc(studentId)
          .collection('scans')
          .orderBy('timestamp', descending: true)
          .get();

      print('   📊 Scans encontrados: ${scansSnapshot.docs.length}');

      if (scansSnapshot.docs.isEmpty) {
        print('   ⚠️ No se encontraron escaneos en evento $eventId');
        return;
      }

      // ═══════════════════════════════════════════════════════════════
      // CONVERTIR LOS ESCANEOS A FORMATO DE ASISTENCIAS
      // ═══════════════════════════════════════════════════════════════
      final List<Map<String, dynamic>> asistencias = [];

      for (var scanDoc in scansSnapshot.docs) {
        final scanData = scanDoc.data();

        print('   📄 Scan ID: ${scanDoc.id}');
        print('      - Timestamp: ${scanData['timestamp']}');
        print('      - Categoria: ${scanData['categoria']}');

        // ✅ Validar que tenga timestamp
        if (scanData['timestamp'] == null) {
          print('   ⚠️ Escaneo sin timestamp: ${scanDoc.id}');
          continue;
        }

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

      if (asistencias.isEmpty) {
        print(
          '   ⚠️ Todos los escaneos fueron filtrados (sin timestamp válido)',
        );
        return;
      }
      _asistenciasPorEventoCache[eventId] = asistencias;
      // ═══════════════════════════════════════════════════════════════
      // GUARDAR EL EVENTO CON SUS ASISTENCIAS
      // ═══════════════════════════════════════════════════════════════
      _eventosConAsistencias.add({
        'eventId': eventId,
        'eventName': eventData['name'] ?? 'Sin nombre',
        'eventDescription': eventData['description'] ?? '',
        'eventDate': eventData['date'],
        'eventFacultad': eventData['facultad'] ?? '',
        'eventCarrera': eventData['carrera'] ?? '',
        'asistencias': asistencias,
      });

      // ✅ CACHEAR DATOS DEL EVENTO
      _eventosCache[eventId] = {
        'name': eventData['name'],
        'description': eventData['description'],
        'date': eventData['date'],
        'facultad': eventData['facultad'],
        'carrera': eventData['carrera'],
      };

      print('   ✅ Evento $eventId cargado: ${asistencias.length} asistencias');
    } catch (e) {
      print('❌ Error cargando evento ${eventDoc.id}: $e');
      print('   Stack trace: ${StackTrace.current}');
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
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF059669),
      const Color(0xFFD97706),
      const Color(0xFF7C3AED),
      const Color(0xFF0891B2),
      const Color(0xFF4F46E5),
      const Color(0xFF6366F1),
      const Color(0xFF0D9488),
      const Color(0xFF1E40AF),
      const Color(0xFF15803D),
    ];
    return colors[hash.abs() % colors.length];
  }

  IconData _getIconByCategoria(String? categoria) {
    if (categoria == null || categoria.isEmpty) return Icons.help;

    final categoriaLower = categoria.toLowerCase();

    if (categoriaLower.contains('revisión') ||
        categoriaLower.contains('revision')) {
      return Icons.library_books;
    } else if (categoriaLower.contains('empírico') ||
        categoriaLower.contains('empirico')) {
      return Icons.science;
    } else if (categoriaLower.contains('innovación') ||
        categoriaLower.contains('innovacion') ||
        categoriaLower.contains('tecnológica') ||
        categoriaLower.contains('tecnologica')) {
      return Icons.lightbulb;
    } else if (categoriaLower.contains('narrativa')) {
      return Icons.auto_stories;
    } else if (categoriaLower.contains('descriptiv')) {
      return Icons.description;
    } else if (categoriaLower.contains('experimental')) {
      return Icons.biotech;
    } else if (categoriaLower.contains('teóric') ||
        categoriaLower.contains('teorico')) {
      return Icons.psychology;
    } else if (categoriaLower.contains('cualitativ')) {
      return Icons.forum;
    } else if (categoriaLower.contains('cuantitativ')) {
      return Icons.analytics;
    } else {
      return Icons.assignment;
    }
  }

  Widget _buildSelloAsistencia(Map<String, dynamic> asistencia) {
    final timestamp = (asistencia['timestamp'] as Timestamp?)?.toDate();
    final categoria =
        asistencia['categoria'] ??
        asistencia['tipoInvestigacion'] ??
        'Sin categoría';
    final color = _getColorByCategoria(categoria);

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.6),
            color.withOpacity(0.4),
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.8), width: 3),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: SelloPainter(color: color.withOpacity(0.2)),
            ),
          ),
          Center(
            child: Icon(
              _getIconByCategoria(categoria),
              color: Colors.white,
              size: 22,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
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
    );
  }

  Widget _buildSelloVacio(int index) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade100,
        border: Border.all(
          color: Colors.grey.shade300,
          width: 2,
          style: BorderStyle.solid,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: SelloPainter(
                color: Colors.grey.shade300.withOpacity(0.3),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.lock_outline,
              color: Colors.grey.shade400,
              size: 24,
            ),
          ),
        ],
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
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtro de Periodo
          if (_periodosDisponibles.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.1),
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
                    (periodo) => _buildPeriodoChip(
                      periodo['nombre'] ?? 'Sin nombre',
                      periodo['id'],
                    ),
                  )
                  .toList(),
            ),
          ],

          // Separador
          if (_periodosDisponibles.isNotEmpty &&
              _eventosDisponibles.isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 20),
          ],

          // Filtro de Eventos
          if (_eventosDisponibles.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
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
        setState(() {
          _periodoSeleccionado = valor;
        });
        _filtrarAsistencias();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey.shade300,
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
                  'Seleccionar evento',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          icon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
          ),
          items: _eventosDisponibles.map((evento) {
            return DropdownMenuItem<String>(
              value: evento['id'],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.event, size: 18, color: const Color(0xFF2563EB)),
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
          }).toList(),
          onChanged: (value) {
            setState(() {
              _eventoSeleccionado = value;
            });
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
    final totalSellos = _asistenciasFiltradas.length; // ✅ SIN LÍMITE

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
              color: Colors.black.withOpacity(0.05),
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
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1E3A5F),
                        const Color(0xFF2563EB),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A5F).withOpacity(0.3),
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

            // ✅ MOSTRAR MENSAJE SI NO HAY SELLOS
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
              // ✅ MOSTRAR TODOS LOS SELLOS
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
                  return TweenAnimationBuilder(
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

            // ✅ MENSAJE DE FELICITACIÓN
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
                            'Has ganado $totalSellos ${totalSellos == 1 ? 'sello' : 'sellos'} de asistencia',
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

  void _mostrarTodosLosSellos() {
    final periodoNombre = _periodoSeleccionado != null
        ? _periodosDisponibles.firstWhere(
                (p) => p['id'] == _periodoSeleccionado,
                orElse: () => {'nombre': 'Todos los Sellos'},
              )['nombre'] ??
              'Todos los Sellos'
        : 'Todos los Sellos';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.workspace_premium,
                            color: const Color(0xFFD97706),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                periodoNombre,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A5F),
                                ),
                              ),
                              Text(
                                '${_asistenciasFiltradas.length} sellos de asistencia',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                      itemCount: _asistenciasFiltradas.length,
                      itemBuilder: (context, index) {
                        return TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: Duration(milliseconds: 200 + (index * 30)),
                          curve: Curves.easeOutCubic,
                          builder: (context, double value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Hero(
                                tag:
                                    'sello_modal_${_asistenciasFiltradas[index]['id']}',
                                child: _buildSelloAsistencia(
                                  _asistenciasFiltradas[index],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool _esValorValido(dynamic valor) {
    if (valor == null) return false;
    final valorStr = valor.toString().trim().toLowerCase();
    return valorStr.isNotEmpty &&
        valorStr != 'sin código' &&
        valorStr != 'sin codigo' &&
        valorStr != 'sin título' &&
        valorStr != 'sin titulo' &&
        valorStr != 'sin grupo' &&
        valorStr != 'null';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
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
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
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
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
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
                              Text(
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
                                _buildFiltroPeriodo(),
                                _buildColeccionSellos(),
                                _buildAsistenciasCard(),

                                // ✅ Botón "Cargar más eventos"
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
              color: Colors.black.withOpacity(0.05),
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
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return TweenAnimationBuilder(
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

    final hasValidCode = _esValorValido(codigoProyecto);
    final hasValidGroup = _esValorValido(grupo);
    final hasValidTitle = _esValorValido(tituloProyecto);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            _getColorByCategoria(categoria).withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getColorByCategoria(categoria).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _getColorByCategoria(categoria).withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getColorByCategoria(categoria).withOpacity(0.08),
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
                        color: _getColorByCategoria(categoria).withOpacity(0.3),
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        ).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getColorByCategoria(
                            categoria,
                          ).withOpacity(0.3),
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
                          color: const Color(0xFF7C3AED).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF7C3AED).withOpacity(0.3),
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
                if (hasValidTitle) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4F46E5).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withOpacity(0.15),
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
                if (asistencia['eventDescription']?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    asistencia['eventDescription'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if ((asistencia['eventFacultad']?.isNotEmpty == true ||
                        asistencia['facultad']?.isNotEmpty == true) &&
                    (asistencia['eventCarrera']?.isNotEmpty == true ||
                        asistencia['carrera']?.isNotEmpty == true)) ...[
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
                            '${asistencia['eventFacultad'] ?? asistencia['facultad'] ?? ''} • ${asistencia['eventCarrera'] ?? asistencia['carrera'] ?? ''}',
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
                Row(
                  children: [
                    if (eventDate != null) ...[
                      Expanded(
                        child: _buildInfoChip(
                          icon: Icons.event_outlined,
                          label: 'Evento',
                          value:
                              '${eventDate.day}/${eventDate.month}/${eventDate.year}',
                          color: const Color(0xFF0891B2),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
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

class SelloPainter extends CustomPainter {
  final Color color;

  SelloPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * (3.14159 / 180);
      final startRadius = radius * 0.6;
      final endRadius = radius * 0.9;

      final start = Offset(
        center.dx + startRadius * math.cos(angle),
        center.dy + startRadius * math.sin(angle),
      );
      final end = Offset(
        center.dx + endRadius * math.cos(angle),
        center.dy + endRadius * math.sin(angle),
      );

      canvas.drawLine(start, end, paint..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class TextoCurvadoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
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
