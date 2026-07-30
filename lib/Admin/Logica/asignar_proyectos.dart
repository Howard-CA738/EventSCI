import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'crear_jurados.dart';
import 'gestion_criterios.dart';

class AsignarProyectosScreen extends StatefulWidget {
  const AsignarProyectosScreen({super.key});

  @override
  State<AsignarProyectosScreen> createState() => _AsignarProyectosScreenState();
}

class _AsignarProyectosScreenState extends State<AsignarProyectosScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RubricasService _rubricasService = RubricasService();

  String? _filialSeleccionada;
  String? _facultadSeleccionada;
  String? _carreraSeleccionada;

  List<String> _filialesDisponibles = [];
  List<String> _facultadesDisponibles = [];
  List<Map<String, dynamic>> _carrerasDisponibles = [];

  String? _eventoSeleccionado;
  Map<String, dynamic>? _eventoData;
  String? _juradoSeleccionado;
  Map<String, dynamic>? _juradoData;

  List<Rubrica> _rubricasDelJurado = [];
  Rubrica? _rubricaSeleccionada;

  List<Map<String, dynamic>> _eventosDisponibles = [];
  List<Map<String, dynamic>> _eventosFiltrados = [];
  List<Map<String, dynamic>> _juradosDisponibles = [];
  List<Map<String, dynamic>> _proyectosDisponibles = [];
  Map<String, List<Map<String, dynamic>>> _proyectosPorCategoria = {};
  Set<String> _proyectosSeleccionados = {};

  bool _isLoadingInitial = true;
  bool _isLoadingJurados = false;
  bool _isLoadingProyectos = false;
  bool _isAsignando = false;

  final Map<String, String> _filialNombresCache = {};

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    if (!mounted) return;
    setState(() => _isLoadingInitial = true);
    try {
      final filiales = await _rubricasService.getFiliales();
      if (mounted) {
        setState(() => _filialesDisponibles = filiales);
      }
      await _cargarEventos();
    } catch (e) {
      debugPrint('Error al cargar datos iniciales: $e');
      if (mounted) {
        _mostrarSnackBar('Error al cargar datos: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

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
      final facultades = await _rubricasService.getFacultadesByFilial(filial);
      if (mounted) {
        setState(() => _facultadesDisponibles = facultades);
      }
      _filtrarEventos();
    }
  }

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
        setState(() => _carrerasDisponibles = carreras);
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

    final filtrados = _eventosDisponibles.where((evento) {
      if (evento['filialId'] != _filialSeleccionada) return false;
      if (_facultadSeleccionada != null) {
        if (evento['facultad'] != _facultadSeleccionada) return false;
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
        setState(() => _eventosDisponibles = eventos);
      }
    } catch (e) {
      debugPrint('Error al cargar eventos: $e');
    }
  }

  Future<void> _onEventoChanged(String? eventoId) async {
    if (eventoId == null) return;

    final eventoIndex = _eventosFiltrados.indexWhere((e) => e['id'] == eventoId);
    if (eventoIndex == -1) return;

    final eventoData = _eventosFiltrados[eventoIndex];

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
      final filialEvento = _eventoData!['filialId'] as String? ?? '';
      final facultadEvento = _eventoData!['facultad'] as String? ?? '';
      final carreraEvento = _eventoData!['carreraNombre'] as String? ?? '';

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
          _mostrarSnackBar(
            'No hay jurados disponibles para esta ubicación',
            isWarning: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Error al cargar jurados: $e');
      if (mounted) setState(() => _isLoadingJurados = false);
    }
  }

  Future<void> _onJuradoChanged(String? juradoId) async {
    if (juradoId == null) return;

    final juradoIndex = _juradosDisponibles.indexWhere((j) => j['id'] == juradoId);
    if (juradoIndex == -1) return;

    setState(() {
      _juradoSeleccionado = juradoId;
      _juradoData = _juradosDisponibles[juradoIndex];
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
      final todasRubricas = await _rubricasService.obtenerRubricas();
      final rubricasJurado = todasRubricas
          .where((r) => r.juradosAsignados.contains(juradoId))
          .toList();

      if (rubricasJurado.isEmpty) {
        if (mounted) {
          _mostrarSnackBar(
            'Este jurado no tiene rúbricas asignadas.',
            isWarning: true,
          );
        }
        return;
      }

      final eventoFilial = _eventoData!['filialId'] as String? ?? '';
      final eventoFacultad = _eventoData!['facultad'] as String? ?? '';
      final eventoCarrera = _eventoData!['carreraNombre'] as String? ?? '';

      final rubricasCompatibles = rubricasJurado.where((rubrica) {
        if (eventoFilial != rubrica.filial) return false;
        if (eventoFacultad.trim().toLowerCase() !=
            rubrica.facultad.trim().toLowerCase()) return false;
        if (rubrica.carrera != null && rubrica.carrera!.isNotEmpty) {
          return eventoCarrera.trim().toLowerCase() ==
              rubrica.carrera!.trim().toLowerCase();
        }
        return true;
      }).toList();

      if (rubricasCompatibles.isEmpty) {
        if (mounted) {
          _mostrarSnackBar(
            'El jurado tiene rúbricas pero ninguna es compatible con el evento',
            isWarning: true,
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
      debugPrint('Error al cargar rúbricas: $e');
      if (mounted) {
        _mostrarSnackBar('Error al cargar rúbricas: $e', isError: true);
      }
    }
  }

  Future<void> _onRubricaChanged(String? rubricaId) async {
    if (rubricaId == null) return;

    final rubricaIndex = _rubricasDelJurado.indexWhere((r) => r.id == rubricaId);
    if (rubricaIndex == -1) return;

    final rubrica = _rubricasDelJurado[rubricaIndex];

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
      final juradoDoc = await _firestore
          .collection('users')
          .doc(_juradoSeleccionado)
          .get();

      List<String> categoriasJurado = [];
      if (juradoDoc.exists) {
        final juradoData = juradoDoc.data();
        if (juradoData != null && juradoData.containsKey('categorias')) {
          final rawCats = juradoData['categorias'];
          categoriasJurado = rawCats is List
              ? rawCats
                  .map((e) => e?.toString() ?? '')
                  .where((e) => e.isNotEmpty)
                  .toList()
              : [];
        }
      }

      if (categoriasJurado.isEmpty) {
        if (mounted) {
          setState(() => _isLoadingProyectos = false);
          _mostrarSnackBar(
            'Este jurado no tiene categorías asignadas',
            isWarning: true,
          );
        }
        return;
      }

      final proyectosSnapshot = await _firestore
          .collection('events')
          .doc(_eventoSeleccionado)
          .collection('proyectos')
          .get();

      final evaluacionesSnapshot = await _firestore
          .collectionGroup('evaluaciones')
          .where('juradoId', isEqualTo: _juradoSeleccionado)
          .where('rubricaId', isEqualTo: rubrica.id)
          .get();

      final proyectosAsignados = <String>{};
      for (var doc in evaluacionesSnapshot.docs) {
        final parts = doc.reference.path.split('/');
        if (parts.length >= 4) {
          proyectosAsignados.add(parts[3]);
        }
      }

      final Map<String, Map<String, dynamic>> proyectosMap = {};
      final eventoFilial = (_eventoData!['filialId'] ?? '').toString();
      final eventoFacultad = (_eventoData!['facultad'] ?? '').toString();
      final eventoCarrera = (_eventoData!['carreraNombre'] ?? '').toString();
      int proyectosFiltrados = 0;

      for (var proyectoDoc in proyectosSnapshot.docs) {
        final data = proyectoDoc.data();
        final codigo = (data['Código'] ?? '').toString();
        final clasificacion =
            (data['Clasificación'] ?? 'Sin categoría').toString();

        if (codigo.isEmpty) continue;

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
            'titulo': (data['Título'] ?? '').toString(),
            'integrantes': (data['Integrantes'] ?? '').toString(),
            'sala': (data['Sala'] ?? '').toString(),
            'clasificacion': clasificacion,
            'filialId': eventoFilial,
            'facultad': eventoFacultad,
            'carreraNombre': eventoCarrera,
            'yaAsignado': yaAsignado,
          };
        }
      }

      final proyectosList = proyectosMap.values.toList()
        ..sort((a, b) =>
            a['codigo'].toString().compareTo(b['codigo'].toString()));

      final Map<String, List<Map<String, dynamic>>> grupos = {};
      for (final proyecto in proyectosList) {
        final categoria = proyecto['clasificacion'].toString();
        grupos.putIfAbsent(categoria, () => []).add(proyecto);
      }

      if (mounted) {
        _proyectosSeleccionados.clear();
        for (var proyecto in proyectosList) {
          if (proyecto['yaAsignado'] == true) {
            _proyectosSeleccionados.add(proyecto['codigo'].toString());
          }
        }

        setState(() {
          _proyectosDisponibles = proyectosList;
          _proyectosPorCategoria = grupos;
          _isLoadingProyectos = false;
        });

        if (proyectosList.isEmpty && proyectosFiltrados > 0) {
          _mostrarSnackBar(
            'No hay proyectos de las categorías: ${categoriasJurado.join(", ")}',
            isWarning: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        setState(() => _isLoadingProyectos = false);
        _mostrarSnackBar('Error al cargar proyectos: $e', isError: true);
      }
    }
  }

  Future<void> _asignarProyectos() async {
    if (_proyectosSeleccionados.isEmpty) {
      _mostrarSnackBar('Debes seleccionar al menos un proyecto',
          isWarning: true);
      return;
    }

    if (_rubricaSeleccionada == null) {
      _mostrarSnackBar('Debes seleccionar una rúbrica', isWarning: true);
      return;
    }

    final proyectosReasignados = _proyectosDisponibles
        .where((p) =>
            _proyectosSeleccionados.contains(p['codigo']) &&
            p['yaAsignado'] == true)
        .length;

    final proyectosAEliminar = _proyectosDisponibles
        .where((p) =>
            !_proyectosSeleccionados.contains(p['codigo']) &&
            p['yaAsignado'] == true)
        .length;

    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildConfirmDialog(
        proyectosReasignados: proyectosReasignados,
        proyectosAEliminar: proyectosAEliminar,
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
        final codigo = proyecto['codigo'].toString();
        final yaAsignado = proyecto['yaAsignado'] == true;
        final estaSeleccionado = _proyectosSeleccionados.contains(codigo);

        final docRef = _firestore
            .collection('events')
            .doc(proyecto['eventId'] as String)
            .collection('proyectos')
            .doc(proyecto['id'] as String)
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

        final mensajes = <String>[];
        if (asignados > 0) mensajes.add('$asignados nuevo(s)');
        if (actualizados > 0) mensajes.add('$actualizados actualizado(s)');
        if (eliminados > 0) mensajes.add('$eliminados eliminado(s)');

        _mostrarSnackBar(
          mensajes.isEmpty ? 'Sin cambios' : mensajes.join(' + '),
        );

        await _cargarProyectosConRubrica(_rubricaSeleccionada!);
      }
    } catch (e) {
      debugPrint('Error al asignar proyectos: $e');
      if (mounted) {
        setState(() => _isAsignando = false);
        _mostrarSnackBar('Error: $e', isError: true);
      }
    }
  }

  void _mostrarSnackBar(
    String mensaje, {
    bool isError = false,
    bool isWarning = false,
  }) {
    if (!mounted) return;
    final color = isError
        ? Colors.red
        : isWarning
            ? Colors.orange
            : Colors.green;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(fontSize: 13),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _getColorForCategory(int index) {
    const colors = [
      Color(0xFF1565C0),
      Color(0xFF2E7D32),
      Color(0xFFE65100),
      Color(0xFF6A1B9A),
      Color(0xFFC62828),
      Color(0xFF00695C),
      Color(0xFFF9A825),
      Color(0xFF283593),
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
                child: _isLoadingInitial
                    ? const _LoadingWidget(mensaje: 'Cargando datos...')
                    : SingleChildScrollView(
                        primary: false,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            MediaQuery.of(context).viewPadding.bottom + 32,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFiltrosCard(),
                              if (_filialSeleccionada != null &&
                                  _facultadSeleccionada != null) ...[
                                const SizedBox(height: 16),
                                _buildEventoCard(),
                              ],
                              if (_eventoSeleccionado != null) ...[
                                const SizedBox(height: 16),
                                _buildJuradoCard(),
                              ],
                              if (_rubricasDelJurado.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildRubricasCard(),
                              ],
                              if (_rubricaSeleccionada != null) ...[
                                const SizedBox(height: 16),
                                _buildRubricaInfoCard(),
                                const SizedBox(height: 16),
                                _buildProyectosPorCategoriaCard(),
                              ],
                              const SizedBox(height: 24),
                              if (_rubricaSeleccionada != null)
                                _buildBotonAsignar(),
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
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 12.0),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Volver',
              padding: EdgeInsets.zero,
            ),
          ),
          Expanded(
            child: Text(
              'Asignar Proyectos a Jurados',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              icon: const Icon(Icons.people, color: Colors.white, size: 26),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CrearJuradosScreen(),
                  ),
                );
              },
              tooltip: 'Gestionar jurados',
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltrosCard() {
    return _StepCard(
      gradientColors: const [Color(0xFF1E3A5F), Color(0xFF2C5F7C)],
      icon: Icons.filter_list,
      titulo: '1. Filtrar Ubicación',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdownFilial(),
          if (_filialSeleccionada != null) ...[
            const SizedBox(height: 14),
            _buildDropdownFacultad(),
          ],
          if (_facultadSeleccionada != null &&
              _carrerasDisponibles.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildDropdownCarrera(),
          ],
          if (_filialSeleccionada != null &&
              _facultadSeleccionada != null) ...[
            const SizedBox(height: 12),
            _buildInfoEventos(),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownFilial() {
    return DropdownButtonFormField<String>(
      initialValue: _filialSeleccionada,
      isExpanded: true,
      menuMaxHeight: 300,
      decoration: _inputDecoration('Filial', Icons.location_city),
      items: _filialesDisponibles.map((filialId) {
        final nombre = _filialNombresCache[filialId] ?? filialId;
        return DropdownMenuItem<String>(
          value: filialId,
          child: Text(
            nombre,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }).toList(),
      onChanged: _onFilialChanged,
    );
  }

  Widget _buildDropdownFacultad() {
    return DropdownButtonFormField<String>(
      initialValue: _facultadSeleccionada,
      isExpanded: true,
      menuMaxHeight: 300,
      decoration: _inputDecoration('Facultad', Icons.school),
      items: _facultadesDisponibles.map((facultad) {
        return DropdownMenuItem<String>(
          value: facultad,
          child: Text(
            facultad,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }).toList(),
      onChanged: _onFacultadChanged,
    );
  }

  Widget _buildDropdownCarrera() {
    return DropdownButtonFormField<String>(
      initialValue: _carreraSeleccionada,
      isExpanded: true,
      menuMaxHeight: 300,
      decoration: _inputDecoration('Carrera (opcional)', Icons.menu_book),
      items: _carrerasDisponibles.map((carrera) {
        return DropdownMenuItem<String>(
          value: carrera['nombre'] as String,
          child: Text(
            carrera['nombre'] as String,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }).toList(),
      onChanged: _onCarreraChanged,
    );
  }

  Widget _buildInfoEventos() {
    return Container(
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
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventoCard() {
    return _StepCard(
      gradientColors: const [Color(0xFF4CAF50), Color(0xFF45A049)],
      icon: Icons.event,
      titulo: '2. Seleccionar Evento',
      child: DropdownButtonFormField<String>(
        initialValue: _eventoSeleccionado,
        isExpanded: true,
        menuMaxHeight: 300,
        decoration: _inputDecoration('Evento', Icons.event_note),
        items: _eventosFiltrados.map((evento) {
          return DropdownMenuItem<String>(
            value: evento['id'] as String,
            child: Text(
              evento['name'] as String,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          );
        }).toList(),
        onChanged: _eventosFiltrados.isEmpty ? null : _onEventoChanged,
      ),
    );
  }

  Widget _buildJuradoCard() {
    return _StepCard(
      gradientColors: const [Color(0xFFFF9800), Color(0xFFFF6F00)],
      icon: Icons.person,
      titulo: '3. Seleccionar Jurado',
      child: _isLoadingJurados
          ? const _LoadingWidget(mensaje: 'Cargando jurados...')
          : _juradosDisponibles.isEmpty
              ? _buildEmptyState(
                  icon: Icons.person_off_outlined,
                  mensaje: 'No hay jurados para este evento',
                )
              : DropdownButtonFormField<String>(
                  initialValue: _juradoSeleccionado,
                  isExpanded: true,
                  menuMaxHeight: 300,
                  decoration: _inputDecoration('Jurado', Icons.badge),
                  items: _juradosDisponibles.map((jurado) {
                    return DropdownMenuItem<String>(
                      value: jurado['id'] as String,
                      child: Text(
                        (jurado['nombre'] as String?) ?? '',
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: _onJuradoChanged,
                ),
    );
  }

  Widget _buildRubricasCard() {
    final titulo = _rubricasDelJurado.length > 1
        ? '4. Seleccionar Rúbrica (${_rubricasDelJurado.length})'
        : '4. Rúbrica del Jurado';

    return _StepCard(
      gradientColors: const [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
      icon: Icons.checklist,
      titulo: titulo,
      child: _rubricasDelJurado.length == 1
          ? _buildRubricaUnica()
          : _buildDropdownRubricas(),
    );
  }

  Widget _buildRubricaUnica() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle, color: Colors.green[700], size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _rubricasDelJurado.first.nombre,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_rubricasDelJurado.first.totalCriterios} criterios · '
                  '${_rubricasDelJurado.first.puntajeMaximo.toStringAsFixed(0)} pts',
                  style: TextStyle(fontSize: 12, color: Colors.green[800]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRubricas() {
    return DropdownButtonFormField<String>(
      initialValue: _rubricaSeleccionada?.id,
      isExpanded: true,
      menuMaxHeight: 300,
      decoration: _inputDecoration('Selecciona una rúbrica', Icons.assignment),
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
              const SizedBox(height: 2),
              Text(
                '${rubrica.totalCriterios} criterios · ${rubrica.facultad}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: _onRubricaChanged,
    );
  }

  Widget _buildRubricaInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rúbrica Seleccionada',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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
    );
  }

  Widget _buildProyectosPorCategoriaCard() {
    final stepTitle = _rubricasDelJurado.length > 1
        ? '5. Seleccionar Proyectos'
        : '4. Seleccionar Proyectos';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.folder_open,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stepTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_proyectosSeleccionados.length} sel.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingProyectos)
              const _LoadingWidget(mensaje: 'Cargando proyectos...')
            else if (_proyectosPorCategoria.isEmpty)
              _buildEmptyProyectos()
            else
              _buildCategoriasList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyProyectos() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No hay proyectos disponibles',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String mensaje,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriasList() {
    final categorias = _proyectosPorCategoria.keys.toList();
    return ListView.builder(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categorias.length,
      itemBuilder: (context, index) {
        final categoria = categorias[index];
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
    final color = _getColorForCategory(index);
    final count = proyectos.length;
    final countLabel = count > 99 ? '99+' : count.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            categoria,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF2C3E50),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '$count proyecto${count != 1 ? 's' : ''}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          leading: SizedBox(
            width: 40,
            height: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  countLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
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
    final codigo = proyecto['codigo'].toString();
    final yaAsignado = proyecto['yaAsignado'] == true;
    final isSelected = _proyectosSeleccionados.contains(codigo);
    final integrantes = (proyecto['integrantes'] ?? '').toString();
    final titulo = (proyecto['titulo'] ?? '').toString();

    return Semantics(
      label: 'Proyecto $titulo, código $codigo${yaAsignado ? ', ya asignado' : ''}',
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      titulo,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: yaAsignado
                            ? Colors.amber[900]
                            : const Color(0xFF2C3E50),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (yaAsignado) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      flex: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber[700],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Asignado',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
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
                  Flexible(
                    child: Text(
                      codigo,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              if (integrantes.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.people, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        integrantes,
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[600]),
                        maxLines: 2,
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          minVerticalPadding: 8,
        ),
      ),
    );
  }

  Widget _buildBotonAsignar() {
    final seleccionados = _proyectosSeleccionados.length;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed:
            _isAsignando || seleccionados == 0 ? null : _asignarProyectos,
        icon: _isAsignando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle, size: 22),
        label: Flexible(
          child: Text(
            _isAsignando
                ? 'Asignando...'
                : 'Asignar $seleccionados Proyecto${seleccionados != 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          elevation: seleccionados > 0 ? 4 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: Colors.green[700]),
        ),
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
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmDialog({
    required int proyectosReasignados,
    required int proyectosAEliminar,
  }) {
    final nombreJurado = _juradoData?['nombre'] as String? ?? 'jurado';
    final screenHeight = MediaQuery.of(context).size.height;

    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: const Text(
        'Confirmar Asignación',
        style: TextStyle(fontSize: 17),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: screenHeight * 0.5,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Asignar ${_proyectosSeleccionados.length} proyecto(s) a $nombreJurado?',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.assignment,
                        color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rúbrica: ${_rubricaSeleccionada!.nombre}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                      ),
                    ),
                  ],
                ),
              ),
              if (proyectosReasignados > 0) ...[
                const SizedBox(height: 10),
                _buildDialogWarningBox(
                  icon: Icons.info_outline,
                  backgroundColor: Colors.orange.shade50,
                  borderColor: Colors.orange.shade200,
                  iconColor: Colors.orange.shade700,
                  textColor: Colors.orange.shade900,
                  texto: '$proyectosReasignados ya asignado(s)',
                ),
              ],
              if (proyectosAEliminar > 0) ...[
                const SizedBox(height: 10),
                _buildDialogWarningBox(
                  icon: Icons.delete_outline,
                  backgroundColor: Colors.red.shade50,
                  borderColor: Colors.red.shade200,
                  iconColor: Colors.red.shade700,
                  textColor: Colors.red.shade900,
                  texto: '$proyectosAEliminar se eliminarán',
                ),
              ],
            ],
          ),
        ),
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
    );
  }

  Widget _buildDialogWarningBox({
    required IconData icon,
    required Color backgroundColor,
    required Color borderColor,
    required Color iconColor,
    required Color textColor,
    required String texto,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 12, color: textColor),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.gradientColors,
    required this.icon,
    required this.titulo,
    required this.child,
  });

  final List<Color> gradientColors;
  final IconData icon;
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradientColors),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1A5490)),
            const SizedBox(height: 12),
            Text(
              mensaje,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}