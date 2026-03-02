import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'crear_jurados.dart';
import 'gestion_criterios.dart';
import 'filiales_service.dart';

class AsignarProyectosScreen extends StatefulWidget {
  const AsignarProyectosScreen({super.key});

  @override
  State<AsignarProyectosScreen> createState() => _AsignarProyectosScreenState();
}

class _AsignarProyectosScreenState extends State<AsignarProyectosScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RubricasService _rubricasService = RubricasService();
  final FilialesService _filialesService = FilialesService();

  // ✅ NUEVO: Filtros con sistema de filiales
  String? _filialSeleccionada;
  String? _facultadSeleccionada;
  String? _carreraSeleccionada;

  // ✅ NUEVO: Listas dinámicas
  List<String> _filialesDisponibles = [];
  List<String> _facultadesDisponibles = [];
  List<Map<String, dynamic>> _carrerasDisponibles = [];

  // Selección
  String? _eventoSeleccionado;
  Map<String, dynamic>? _eventoData;
  String? _juradoSeleccionado;
  Map<String, dynamic>? _juradoData;

  // Variables para manejar múltiples rúbricas
  List<Rubrica> _rubricasDelJurado = [];
  Rubrica? _rubricaSeleccionada;

  // Listas dinámicas
  List<Map<String, dynamic>> _eventosDisponibles = [];
  List<Map<String, dynamic>> _eventosFiltrados = [];
  List<Map<String, dynamic>> _juradosDisponibles = [];
  List<Map<String, dynamic>> _proyectosDisponibles = [];
  Map<String, List<Map<String, dynamic>>> _proyectosPorCategoria = {};
  Set<String> _proyectosSeleccionados = {};

  // ✅ OPTIMIZACIÓN: Estado de carga inicial
  bool _isLoadingInitial = true;
  bool _isLoadingEventos = false;
  bool _isLoadingJurados = false;
  bool _isLoadingProyectos = false;
  bool _isAsignando = false;

  String _nombreFilialSeleccionada = '';

  @override
  void initState() {
    super.initState();
    // ✅ OPTIMIZACIÓN: Carga inmediata
    _cargarDatosIniciales();
  }

  // ✅ OPTIMIZACIÓN: Función mejorada que muestra loading
  Future<void> _cargarDatosIniciales() async {
    if (!mounted) return;

    setState(() {
      _isLoadingInitial = true;
    });

    try {
      // Cargar filiales primero (rápido)
      final filiales = await _rubricasService.getFiliales();

      if (mounted) {
        setState(() {
          _filialesDisponibles = filiales;
        });
      }

      // Cargar todos los eventos en segundo plano
      await _cargarEventos();

      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
        });
      }
    } catch (e) {
      print('Error al cargar datos iniciales: $e');
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ NUEVO: Cuando cambia la filial
  Future<void> _onFilialChanged(String? filial) async {
    setState(() {
      _filialSeleccionada = filial;
      _facultadSeleccionada = null;
      _carreraSeleccionada = null;
      _facultadesDisponibles = [];
      _carrerasDisponibles = [];
      _eventoSeleccionado = null;
      _eventoData = null;
      _juradoSeleccionado = null;
      _juradoData = null;
      _rubricasDelJurado = [];
      _rubricaSeleccionada = null;
      _proyectosSeleccionados.clear();
      _proyectosDisponibles.clear();
      _proyectosPorCategoria.clear();
      _juradosDisponibles.clear();
    });

    if (filial != null) {
      _nombreFilialSeleccionada = await _rubricasService.getNombreFilial(
        filial,
      );
      final facultades = await _rubricasService.getFacultadesByFilial(filial);
      if (mounted) {
        setState(() {
          _facultadesDisponibles = facultades;
        });
      }
      _filtrarEventos();
    }
  }

  // ✅ NUEVO: Cuando cambia la facultad
  Future<void> _onFacultadChanged(String? facultad) async {
    setState(() {
      _facultadSeleccionada = facultad;
      _carreraSeleccionada = null;
      _carrerasDisponibles = [];
      _eventoSeleccionado = null;
      _eventoData = null;
      _juradoSeleccionado = null;
      _juradoData = null;
      _rubricasDelJurado = [];
      _rubricaSeleccionada = null;
      _proyectosSeleccionados.clear();
      _proyectosDisponibles.clear();
      _proyectosPorCategoria.clear();
      _juradosDisponibles.clear();
    });

    if (_filialSeleccionada != null && facultad != null) {
      final carreras = await _rubricasService.getCarrerasByFacultad(
        _filialSeleccionada!,
        facultad,
      );
      if (mounted) {
        setState(() {
          _carrerasDisponibles = carreras;
        });
      }
    }

    _filtrarEventos();
  }

  void _onCarreraChanged(String? carrera) {
    setState(() {
      _carreraSeleccionada = carrera;
      _eventoSeleccionado = null;
      _eventoData = null;
      _juradoSeleccionado = null;
      _juradoData = null;
      _rubricasDelJurado = [];
      _rubricaSeleccionada = null;
      _proyectosSeleccionados.clear();
      _proyectosDisponibles.clear();
      _proyectosPorCategoria.clear();
      _juradosDisponibles.clear();
    });

    _filtrarEventos();
  }

  void _filtrarEventos() {
    if (_filialSeleccionada == null) {
      setState(() => _eventosFiltrados = []);
      return;
    }

    List<Map<String, dynamic>> filtrados = _eventosDisponibles.where((evento) {
      final filialMatch = evento['filialId'] == _filialSeleccionada;

      if (!filialMatch) return false;

      if (_facultadSeleccionada != null) {
        final facultadMatch = evento['facultad'] == _facultadSeleccionada;
        if (!facultadMatch) return false;

        if (_carreraSeleccionada != null) {
          return evento['carreraNombre'] == _carreraSeleccionada;
        }

        return true;
      }

      return true;
    }).toList();

    setState(() => _eventosFiltrados = filtrados);
  }

  Future<void> _cargarEventos() async {
    setState(() {
      _isLoadingEventos = true;
      _eventosDisponibles = [];
    });

    try {
      final eventosSnapshot = await _firestore
          .collection('events')
          .orderBy('createdAt', descending: true)
          .get();

      final eventos = eventosSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Sin nombre',
          'filialId': data['filialId'] ?? 'lima',
          'filialNombre': data['filialNombre'] ?? '',
          'facultad': data['facultad'] ?? '',
          'carreraId': data['carreraId'] ?? '',
          'carreraNombre': data['carreraNombre'] ?? '',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _eventosDisponibles = eventos;
          _isLoadingEventos = false;
        });
      }
    } catch (e) {
      print('Error al cargar eventos: $e');
      if (mounted) {
        setState(() => _isLoadingEventos = false);
      }
    }
  }

  Future<void> _onEventoChanged(String? eventoId) async {
    if (eventoId == null) return;

    final eventoData = _eventosFiltrados.firstWhere((e) => e['id'] == eventoId);

    setState(() {
      _eventoSeleccionado = eventoId;
      _eventoData = eventoData;
      _juradoSeleccionado = null;
      _juradoData = null;
      _rubricasDelJurado = [];
      _rubricaSeleccionada = null;
      _proyectosSeleccionados.clear();
      _proyectosDisponibles.clear();
      _proyectosPorCategoria.clear();
      _juradosDisponibles.clear();
    });

    await _cargarJuradosParaEvento();
  }

  Future<void> _cargarJuradosParaEvento() async {
    if (_eventoData == null) return;

    setState(() {
      _isLoadingJurados = true;
      _juradosDisponibles = [];
    });

    try {
      final filialEvento = _eventoData!['filialId'];
      final facultadEvento = _eventoData!['facultad'];
      final carreraEvento = _eventoData!['carreraNombre'];

      print('🔍 Buscando jurados para:');
      print('   Filial: $filialEvento');
      print('   Facultad: $facultadEvento');
      print('   Carrera: $carreraEvento');

      final jurados = await _rubricasService.obtenerJurados(
        filial: filialEvento,
        facultad: facultadEvento,
        carrera: carreraEvento.isNotEmpty ? carreraEvento : null,
      );

      if (mounted) {
        setState(() {
          _juradosDisponibles = jurados;
          _isLoadingJurados = false;
        });

        if (jurados.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay jurados disponibles para esta ubicación'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error al cargar jurados: $e');
      if (mounted) {
        setState(() => _isLoadingJurados = false);
      }
    }
  }

  Future<void> _onJuradoChanged(String? juradoId) async {
    if (juradoId == null) return;

    setState(() {
      _juradoSeleccionado = juradoId;
      _juradoData = _juradosDisponibles.firstWhere((j) => j['id'] == juradoId);
      _rubricasDelJurado = [];
      _rubricaSeleccionada = null;
      _proyectosSeleccionados.clear();
      _proyectosDisponibles.clear();
      _proyectosPorCategoria.clear();
    });

    await _cargarRubricasDelJurado(juradoId);
  }

  Future<void> _cargarRubricasDelJurado(String juradoId) async {
    try {
      print('🔍 Buscando rúbricas del jurado...');

      final todasRubricas = await _rubricasService.obtenerRubricas();
      final rubricasJurado = todasRubricas
          .where((r) => r.juradosAsignados.contains(juradoId))
          .toList();

      print('📚 Rúbricas encontradas: ${rubricasJurado.length}');

      if (rubricasJurado.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este jurado no tiene rúbricas asignadas.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Filtrar rúbricas compatibles con el evento
      final eventoFilial = _eventoData!['filialId'];
      final eventoFacultad = _eventoData!['facultad'];
      final eventoCarrera = _eventoData!['carreraNombre'];

      final rubricasCompatibles = rubricasJurado.where((rubrica) {
        final filialMatch = eventoFilial == rubrica.filial;
        if (!filialMatch) return false;

        final facultadMatch =
            eventoFacultad.trim().toLowerCase() ==
            rubrica.facultad.trim().toLowerCase();
        if (!facultadMatch) return false;

        if (rubrica.carrera != null && rubrica.carrera!.isNotEmpty) {
          return eventoCarrera.trim().toLowerCase() ==
              rubrica.carrera!.trim().toLowerCase();
        }

        return true;
      }).toList();

      print('✅ Rúbricas compatibles: ${rubricasCompatibles.length}');

      if (rubricasCompatibles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠️ El jurado tiene rúbricas pero ninguna es compatible con el evento',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _rubricasDelJurado = rubricasCompatibles;

          if (rubricasCompatibles.length == 1) {
            _rubricaSeleccionada = rubricasCompatibles.first;
            _cargarProyectosConRubrica(_rubricaSeleccionada!);
          }
        });
      }
    } catch (e) {
      print('❌ Error al cargar rúbricas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar rúbricas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onRubricaChanged(String? rubricaId) async {
    if (rubricaId == null) return;

    final rubrica = _rubricasDelJurado.firstWhere((r) => r.id == rubricaId);

    setState(() {
      _rubricaSeleccionada = rubrica;
      _proyectosSeleccionados.clear();
      _proyectosDisponibles.clear();
      _proyectosPorCategoria.clear();
    });

    await _cargarProyectosConRubrica(rubrica);
  }

  Future<void> _cargarProyectosConRubrica(Rubrica rubrica) async {
    if (_eventoSeleccionado == null || _juradoSeleccionado == null) return;

    setState(() => _isLoadingProyectos = true);

    try {
      print('📦 Cargando proyectos del evento con rúbrica: ${rubrica.nombre}');

      // Obtener las categorías del jurado
      final juradoDoc = await _firestore
          .collection('users')
          .doc(_juradoSeleccionado)
          .get();

      List<String> categoriasJurado = [];
      if (juradoDoc.exists) {
        final juradoData = juradoDoc.data();
        if (juradoData != null && juradoData.containsKey('categorias')) {
          categoriasJurado = List<String>.from(juradoData['categorias'] ?? []);
          print('🏷️ Categorías del jurado: $categoriasJurado');
        }
      }

      if (categoriasJurado.isEmpty) {
        if (mounted) {
          setState(() => _isLoadingProyectos = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este jurado no tiene categorías asignadas'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final proyectosSnapshot = await _firestore
          .collection('events')
          .doc(_eventoSeleccionado)
          .collection('proyectos')
          .get();

      print('✅ ${proyectosSnapshot.docs.length} proyectos encontrados');

      // Cargar evaluaciones del jurado CON ESTA RÚBRICA
      final evaluacionesSnapshot = await _firestore
          .collectionGroup('evaluaciones')
          .where('juradoId', isEqualTo: _juradoSeleccionado)
          .where('rubricaId', isEqualTo: rubrica.id)
          .get();

      final proyectosAsignados = <String>{};
      for (var doc in evaluacionesSnapshot.docs) {
        final path = doc.reference.path;
        final parts = path.split('/');
        if (parts.length >= 4) {
          final proyectoId = parts[3];
          proyectosAsignados.add(proyectoId);
        }
      }

      print(
        '🔒 ${proyectosAsignados.length} proyectos ya asignados con esta rúbrica',
      );

      // Construir lista de proyectos
      final Map<String, Map<String, dynamic>> proyectosMap = {};
      final eventoFilial = _eventoData!['filialId'];
      final eventoFacultad = _eventoData!['facultad'];
      final eventoCarrera = _eventoData!['carreraNombre'];
      int proyectosFiltrados = 0;

      for (var proyectoDoc in proyectosSnapshot.docs) {
        final data = proyectoDoc.data();
        final codigo = data['Código'] ?? '';
        final clasificacion = data['Clasificación'] ?? 'Sin categoría';

        if (codigo.isEmpty) continue;

        // Filtrar por categorías del jurado
        if (!categoriasJurado.contains(clasificacion)) {
          proyectosFiltrados++;
          continue;
        }

        final yaAsignado = proyectosAsignados.contains(proyectoDoc.id);

        if (!proyectosMap.containsKey(codigo)) {
          proyectosMap[codigo] = {
            'id': proyectoDoc.id,
            'eventId': _eventoSeleccionado,
            'codigo': codigo,
            'titulo': data['Título'] ?? '',
            'integrantes': data['Integrantes'] ?? '',
            'sala': data['Sala'] ?? '',
            'clasificacion': clasificacion,
            'filialId': eventoFilial,
            'facultad': eventoFacultad,
            'carreraNombre': eventoCarrera,
            'yaAsignado': yaAsignado,
          };
        }
      }

      print(
        '🚫 $proyectosFiltrados proyectos filtrados (categorías no asignadas)',
      );

      // Agrupar proyectos por categoría
      final proyectosList = proyectosMap.values.toList()
        ..sort(
          (a, b) => (a['codigo'] as String).compareTo(b['codigo'] as String),
        );

      final Map<String, List<Map<String, dynamic>>> grupos = {};
      for (final proyecto in proyectosList) {
        final categoria = proyecto['clasificacion'] as String;
        if (!grupos.containsKey(categoria)) {
          grupos[categoria] = [];
        }
        grupos[categoria]!.add(proyecto);
      }

      if (mounted) {
        _proyectosSeleccionados.clear();
        for (var proyecto in proyectosList) {
          if (proyecto['yaAsignado'] == true) {
            _proyectosSeleccionados.add(proyecto['codigo'] as String);
          }
        }

        setState(() {
          _proyectosDisponibles = proyectosList;
          _proyectosPorCategoria = grupos;
          _isLoadingProyectos = false;
        });

        print('✅ ${_proyectosDisponibles.length} proyectos disponibles');
        print('📂 ${_proyectosPorCategoria.length} categorías');

        if (proyectosList.isEmpty && proyectosFiltrados > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No hay proyectos de las categorías: ${categoriasJurado.join(", ")}',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error: $e');
      if (mounted) {
        setState(() => _isLoadingProyectos = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar proyectos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _asignarProyectos() async {
    if (_proyectosSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar al menos un proyecto'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_rubricaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar una rúbrica'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final proyectosReasignados = _proyectosDisponibles
        .where(
          (p) =>
              _proyectosSeleccionados.contains(p['codigo']) &&
              p['yaAsignado'] == true,
        )
        .length;
    final proyectosAEliminar = _proyectosDisponibles
        .where(
          (p) =>
              !_proyectosSeleccionados.contains(p['codigo']) &&
              p['yaAsignado'] == true,
        )
        .length;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Asignación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Asignar ${_proyectosSeleccionados.length} proyecto(s) a ${_juradoData!['nombre']}?',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.assignment, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rúbrica: ${_rubricaSeleccionada!.nombre}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (proyectosReasignados > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ $proyectosReasignados ya asignados',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (proyectosAEliminar > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Colors.red[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ $proyectosAEliminar se eliminarán',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
            ),
            child: const Text('Asignar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isAsignando = true);

    try {
      final batch = _firestore.batch();
      int asignados = 0;
      int actualizados = 0;
      int eliminados = 0;

      for (var proyecto in _proyectosDisponibles) {
        final codigo = proyecto['codigo'] as String;
        final yaAsignado = proyecto['yaAsignado'] as bool;
        final estaSeleccionado = _proyectosSeleccionados.contains(codigo);

        final docRef = _firestore
            .collection('events')
            .doc(proyecto['eventId'])
            .collection('proyectos')
            .doc(proyecto['id'])
            .collection('evaluaciones')
            .doc(_juradoSeleccionado);

        if (yaAsignado && !estaSeleccionado) {
          batch.delete(docRef);
          eliminados++;
        } else if (yaAsignado && estaSeleccionado) {
          batch.update(docRef, {
            'rubricaId': _rubricaSeleccionada!.id,
            'rubricaNombre': _rubricaSeleccionada!.nombre,
            'fechaActualizacion': FieldValue.serverTimestamp(),
          });
          actualizados++;
        } else if (!yaAsignado && estaSeleccionado) {
          batch.set(docRef, {
            'juradoId': _juradoSeleccionado,
            'juradoNombre': _juradoData!['nombre'],
            'rubricaId': _rubricaSeleccionada!.id,
            'rubricaNombre': _rubricaSeleccionada!.nombre,
            'filialId': _rubricaSeleccionada!.filial,
            'facultad': _rubricaSeleccionada!.facultad,
            'carreraNombre': _rubricaSeleccionada!.carrera,
            'evaluada': false,
            'bloqueada': false,
            'notaTotal': 0.0,
            'fechaAsignacion': FieldValue.serverTimestamp(),
          });
          asignados++;
        }
      }

      await batch.commit();

      if (mounted) {
        setState(() => _isAsignando = false);

        List<String> mensajes = [];
        if (asignados > 0) mensajes.add('$asignados nuevo(s)');
        if (actualizados > 0) mensajes.add('$actualizados actualizado(s)');
        if (eliminados > 0) mensajes.add('$eliminados eliminado(s)');

        String mensajeExito = mensajes.isEmpty
            ? '✅ Sin cambios'
            : '✅ ${mensajes.join(' + ')}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeExito),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        await _cargarProyectosConRubrica(_rubricaSeleccionada!);
      }
    } catch (e) {
      print('Error al asignar proyectos: $e');
      if (mounted) {
        setState(() => _isAsignando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _getColorForCategory(int index) {
    final colors = [
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFFF44336),
      const Color(0xFF009688),
      const Color(0xFFFFEB3B),
      const Color(0xFF3F51B5),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                // ✅ OPTIMIZACIÓN: Mostrar loading mientras carga datos iniciales
                child: _isLoadingInitial
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF1A5490)),
                            SizedBox(height: 16),
                            Text(
                              'Cargando datos...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // PASO 1: Filtros
                              _buildFiltrosCard(),

                              // PASO 2: Evento
                              if (_filialSeleccionada != null &&
                                  _facultadSeleccionada != null) ...[
                                const SizedBox(height: 16),
                                _buildEventoCard(),
                              ],

                              // PASO 3: Jurado
                              if (_eventoSeleccionado != null) ...[
                                const SizedBox(height: 16),
                                _buildJuradoCard(),
                              ],

                              // PASO 4: Selector de Rúbrica
                              if (_rubricasDelJurado.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildRubricasCard(),
                              ],

                              // Info Rúbrica seleccionada
                              if (_rubricaSeleccionada != null) ...[
                                const SizedBox(height: 16),
                                _buildRubricaInfoCard(),
                              ],

                              // Proyectos
                              if (_rubricaSeleccionada != null) ...[
                                const SizedBox(height: 16),
                                _buildProyectosPorCategoriaCard(),
                              ],

                              const SizedBox(height: 24),

                              // Botón Asignar
                              if (_rubricaSeleccionada != null)
                                _buildBotonAsignar(),

                              const SizedBox(height: 20),
                            ],
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Asignar Proyectos a Jurados',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.people, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CrearJuradosScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFiltrosCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF2C5F7C)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.filter_list,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '1. Filtrar Ubicación',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ✅ Filial
            DropdownButtonFormField<String>(
              value: _filialSeleccionada,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Filial',
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _filialesDisponibles.map((filialId) {
                return DropdownMenuItem(
                  value: filialId,
                  child: FutureBuilder<String>(
                    future: _rubricasService.getNombreFilial(filialId),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? filialId,
                        style: const TextStyle(fontSize: 14),
                      );
                    },
                  ),
                );
              }).toList(),
              onChanged: _onFilialChanged,
            ),

            // ✅ Facultad
            if (_filialSeleccionada != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _facultadSeleccionada,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Facultad',
                  prefixIcon: const Icon(Icons.school),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _facultadesDisponibles.map((facultad) {
                  return DropdownMenuItem(
                    value: facultad,
                    child: Text(
                      facultad,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _onFacultadChanged,
              ),
            ],

            // ✅ Carrera (opcional)
            if (_facultadSeleccionada != null &&
                _carrerasDisponibles.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _carreraSeleccionada,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Carrera (opcional)',
                  prefixIcon: const Icon(Icons.menu_book),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _carrerasDisponibles.map((carrera) {
                  return DropdownMenuItem(
                    value: carrera['nombre'] as String,
                    child: Text(
                      carrera['nombre'] as String,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _onCarreraChanged,
              ),
            ],

            // Info
            if (_filialSeleccionada != null &&
                _facultadSeleccionada != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_eventosFiltrados.length} evento(s) disponible(s)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[900],
                        ),
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

  Widget _buildEventoCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.event, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  '2. Seleccionar Evento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _eventoSeleccionado,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Evento',
                prefixIcon: const Icon(Icons.event_note),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _eventosFiltrados.map((evento) {
                return DropdownMenuItem(
                  value: evento['id'] as String,
                  child: Text(
                    evento['name'] as String,
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: _eventosFiltrados.isEmpty ? null : _onEventoChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJuradoCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFFF6F00)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '3. Seleccionar Jurado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _juradoSeleccionado,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Jurado',
                prefixIcon: const Icon(Icons.badge),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _juradosDisponibles.map((jurado) {
                return DropdownMenuItem<String>(
                  value: jurado['id'] as String,
                  child: Text(
                    jurado['nombre'] as String,
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: _juradosDisponibles.isEmpty ? null : _onJuradoChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRubricasCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.checklist,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _rubricasDelJurado.length > 1
                        ? '4. Seleccionar Rúbrica (${_rubricasDelJurado.length} disponibles)'
                        : '4. Rúbrica del Jurado',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_rubricasDelJurado.length == 1)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[700],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _rubricasDelJurado.first.nombre,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[900],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_rubricasDelJurado.first.totalCriterios} criterios • ${_rubricasDelJurado.first.puntajeMaximo.toStringAsFixed(0)} pts',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _rubricaSeleccionada?.id,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Selecciona una rúbrica',
                  prefixIcon: const Icon(Icons.assignment),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                selectedItemBuilder: (BuildContext context) {
                  return _rubricasDelJurado.map((rubrica) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        rubrica.nombre,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList();
                },
                items: _rubricasDelJurado.map((rubrica) {
                  return DropdownMenuItem<String>(
                    value: rubrica.id,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rubrica.nombre,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${rubrica.totalCriterios} criterios • ${rubrica.facultad}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                onChanged: _onRubricaChanged,
                menuMaxHeight: 300,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRubricaInfoCard() {
    return Card(
      elevation: 2,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Rúbrica Seleccionada',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.assignment,
              'Rúbrica',
              _rubricaSeleccionada!.nombre,
            ),
            const SizedBox(height: 6),
            _buildInfoRow(
              Icons.checklist,
              'Criterios',
              '${_rubricaSeleccionada!.totalCriterios} criterios',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProyectosPorCategoriaCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.folder_open,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _rubricasDelJurado.length > 1
                        ? '5. Seleccionar Proyectos'
                        : '4. Seleccionar Proyectos',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_proyectosSeleccionados.length} seleccionados',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingProyectos)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_proyectosPorCategoria.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No hay proyectos disponibles',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              _buildCategoriasList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriasList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _proyectosPorCategoria.keys.length,
      itemBuilder: (context, index) {
        final categoria = _proyectosPorCategoria.keys.elementAt(index);
        final proyectos = _proyectosPorCategoria[categoria]!;
        return _buildCategoryCard(categoria, proyectos, index);
      },
    );
  }

  Widget _buildCategoryCard(
    String categoria,
    List<Map<String, dynamic>> proyectos,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getColorForCategory(index).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            categoria,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF2C3E50),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${proyectos.length} proyecto${proyectos.length != 1 ? 's' : ''}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getColorForCategory(index),
                  _getColorForCategory(index).withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                proyectos.length.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          children: proyectos
              .map((proyecto) => _buildProjectItem(proyecto))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildProjectItem(Map<String, dynamic> proyecto) {
    final codigo = proyecto['codigo'] as String;
    final yaAsignado = proyecto['yaAsignado'] as bool;
    final isSelected = _proyectosSeleccionados.contains(codigo);

    return Card(
      margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      color: yaAsignado
          ? Colors.amber.shade50
          : (isSelected ? Colors.blue.shade50 : const Color(0xFFF8F9FA)),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (bool? value) {
          setState(() {
            if (value == true) {
              _proyectosSeleccionados.add(codigo);
            } else {
              _proyectosSeleccionados.remove(codigo);
            }
          });
        },
        title: Row(
          children: [
            Expanded(
              child: Text(
                proyecto['titulo'] as String,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: yaAsignado
                      ? Colors.amber[900]
                      : const Color(0xFF2C3E50),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (yaAsignado)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: 10, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Ya asignado',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.qr_code, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  codigo,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
            if ((proyecto['integrantes'] as String).isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.people, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      proyecto['integrantes'] as String,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        activeColor: const Color(0xFF1E3A5F),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildBotonAsignar() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isAsignando || _proyectosSeleccionados.isEmpty
            ? null
            : _asignarProyectos,
        icon: _isAsignando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle, size: 24),
        label: Text(
          _isAsignando
              ? 'Asignando...'
              : 'Asignar ${_proyectosSeleccionados.length} Proyecto(s)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          elevation: _proyectosSeleccionados.isNotEmpty ? 4 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.green[700]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.green[900],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: Colors.green[800]),
          ),
        ),
      ],
    );
  }
}
