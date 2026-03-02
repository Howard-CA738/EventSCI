import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import 'reportes_ganadores_excel.dart';
import 'filiales_service.dart'; // ✅ IMPORTAR
import 'gestion_criterios.dart'; // ✅ IMPORTAR

class GanadoresEstudiantesScreen extends StatefulWidget {
  const GanadoresEstudiantesScreen({super.key});

  @override
  State<GanadoresEstudiantesScreen> createState() =>
      _GanadoresEstudiantesScreenState();
}

class _GanadoresEstudiantesScreenState extends State<GanadoresEstudiantesScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ReportesGanadoresExcelService _excelService =
      ReportesGanadoresExcelService();
  final RubricasService _rubricasService = RubricasService(); // ✅ NUEVO

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false;
  bool _isInitializing = true;
  bool _isCalculando = false;
  bool _isGeneratingExcel = false;
  bool _isLoadingInitial = true; // ✅ NUEVO
  String? _currentUserType;

  // ✅ NUEVO: Sistema de filiales
  String? _filialSeleccionada;
  String? _facultadSeleccionada;
  String? _carreraSeleccionada;

  List<String> _filialesDisponibles = [];
  List<String> _facultadesDisponibles = [];
  List<Map<String, dynamic>> _carrerasDisponibles = [];

  List<Map<String, dynamic>> _ganadores = [];
  int _totalEventos = 0;
  Map<String, List<Map<String, dynamic>>> _ganadoresPorCategoria = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _inicializar();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    await _getCurrentUserType();
    await _cargarDatosIniciales(); // ✅ NUEVO
    setState(() {
      _isInitializing = false;
    });
    _animationController.forward();
  }

  Future<void> _getCurrentUserType() async {
    try {
      final userType = await PrefsHelper.getUserType();
      setState(() {
        _currentUserType = userType;
      });
    } catch (e) {
      _showSnackBar('Error al obtener usuario: $e');
    }
  }

  // ✅ NUEVO: Cargar datos iniciales
  Future<void> _cargarDatosIniciales() async {
    if (!mounted) return;

    setState(() => _isLoadingInitial = true);

    try {
      final filiales = await _rubricasService.getFiliales();

      if (mounted) {
        setState(() {
          _filialesDisponibles = filiales;
          _isLoadingInitial = false;
        });
      }
    } catch (e) {
      print('Error al cargar datos iniciales: $e');
      if (mounted) {
        setState(() => _isLoadingInitial = false);
        _showSnackBar('Error al cargar datos: $e', isError: true);
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
      _ganadores.clear();
      _ganadoresPorCategoria.clear();
      _totalEventos = 0;
    });

    if (filial != null) {
      final facultades = await _rubricasService.getFacultadesByFilial(filial);
      if (mounted) {
        setState(() {
          _facultadesDisponibles = facultades;
        });
      }
    }
  }

  // ✅ NUEVO: Cuando cambia la facultad
  Future<void> _onFacultadChanged(String? facultad) async {
    setState(() {
      _facultadSeleccionada = facultad;
      _carreraSeleccionada = null;
      _carrerasDisponibles = [];
      _ganadores.clear();
      _ganadoresPorCategoria.clear();
      _totalEventos = 0;
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
  }

  // ✅ ACTUALIZADO: Cuando cambia la carrera
  void _onCarreraChanged(String? carrera) {
    setState(() {
      _carreraSeleccionada = carrera;
      _ganadores.clear();
      _ganadoresPorCategoria.clear();
      _totalEventos = 0;
    });
  }

  // ============================================================================
  // 🔥 FUNCIÓN: Descargar Excel
  // ============================================================================
  Future<void> _descargarExcel() async {
    if (_ganadoresPorCategoria.isEmpty) {
      _showSnackBar('No hay ganadores para exportar', isError: true);
      return;
    }

    if (_filialSeleccionada == null ||
        _facultadSeleccionada == null ||
        _carreraSeleccionada == null) {
      _showSnackBar(
        'Debes seleccionar filial, facultad y carrera',
        isError: true,
      );
      return;
    }

    setState(() => _isGeneratingExcel = true);

    try {
      // Mostrar diálogo de progreso
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF1E3A5F)),
                const SizedBox(height: 20),
                const Text(
                  'Generando reporte de ganadores...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Esto puede tomar unos momentos',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      // Generar el Excel
      final resultado = await _excelService.generarReporteGanadores(
        ganadoresPorCategoria: _ganadoresPorCategoria,
        facultad: _facultadSeleccionada!,
        carrera: _carreraSeleccionada!,
        totalEventos: _totalEventos,
      );

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de progreso
        setState(() => _isGeneratingExcel = false);

        if (resultado) {
          _mostrarDialogoExito();
        } else {
          _showSnackBar('❌ Error al generar el reporte Excel', isError: true);
        }
      }
    } catch (e) {
      print('Error al generar Excel: $e');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isGeneratingExcel = false);
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  void _mostrarDialogoExito() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Reporte Generado', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '✅ El archivo Excel se ha generado exitosamente',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 18,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ubicación:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Carpeta de Descargas / Documentos',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.description,
                        size: 18,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Archivo:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reporte_Ganadores_${_carreraSeleccionada!.replaceAll(' ', '_')}.xlsx',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.amber.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Busca el archivo en tu administrador de archivos',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );

    _showSnackBar(
      '✅ Reporte de ganadores generado exitosamente',
      isSuccess: true,
    );
  }

  // ============================================================================
  // FUNCIÓN: Calcular ganadores automáticamente por categoría
  // ============================================================================
  Future<void> _calcularGanadoresAutomaticos() async {
    if (_filialSeleccionada == null ||
        _facultadSeleccionada == null ||
        _carreraSeleccionada == null) {
      _showSnackBar('Debes seleccionar filial, facultad y carrera');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Calcular Ganadores'),
        content: const Text(
          '¿Deseas calcular automáticamente los TOP 3 ganadores de cada categoría?\n\n'
          'Se seleccionarán los proyectos con mejor promedio de evaluaciones.',
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
            child: const Text('Calcular'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isCalculando = true);

    try {
      print('🏆 Iniciando cálculo de ganadores automático');

      // ✅ ACTUALIZADO: Query con filialId
      final eventosSnapshot = await _firestore
          .collection('events')
          .where('filialId', isEqualTo: _filialSeleccionada)
          .where('facultad', isEqualTo: _facultadSeleccionada)
          .where('carreraNombre', isEqualTo: _carreraSeleccionada)
          .get();

      if (eventosSnapshot.docs.isEmpty) {
        _showSnackBar('No hay eventos para esta ubicación');
        setState(() => _isCalculando = false);
        return;
      }

      int totalProyectosProcesados = 0;
      int totalGanadoresAsignados = 0;

      for (var eventoDoc in eventosSnapshot.docs) {
        print('\n📌 Procesando evento: ${eventoDoc.id}');

        final proyectosSnapshot = await _firestore
            .collection('events')
            .doc(eventoDoc.id)
            .collection('proyectos')
            .get();

        if (proyectosSnapshot.docs.isEmpty) {
          print('   ⚠️ Sin proyectos');
          continue;
        }

        Map<String, Map<String, dynamic>> proyectosConPuntaje = {};

        for (var proyectoDoc in proyectosSnapshot.docs) {
          final proyectoData = proyectoDoc.data();
          final clasificacion =
              proyectoData['Clasificación'] ?? 'Sin categoría';

          final evaluacionesSnapshot = await _firestore
              .collection('events')
              .doc(eventoDoc.id)
              .collection('proyectos')
              .doc(proyectoDoc.id)
              .collection('evaluaciones')
              .where('evaluada', isEqualTo: true)
              .where('bloqueada', isEqualTo: false)
              .get();

          if (evaluacionesSnapshot.docs.isEmpty) {
            print('   ⚠️ Proyecto ${proyectoDoc.id} sin evaluaciones válidas');
            continue;
          }

          double sumaNotas = 0;
          int totalEvaluaciones = 0;

          for (var evaluacionDoc in evaluacionesSnapshot.docs) {
            final notaTotal = (evaluacionDoc.data()['notaTotal'] ?? 0.0) as num;
            sumaNotas += notaTotal.toDouble();
            totalEvaluaciones++;
          }

          final promedioFinal = totalEvaluaciones > 0
              ? sumaNotas / totalEvaluaciones
              : 0.0;

          proyectosConPuntaje[proyectoDoc.id] = {
            'id': proyectoDoc.id,
            'data': proyectoData,
            'clasificacion': clasificacion,
            'promedio': promedioFinal,
            'totalEvaluaciones': totalEvaluaciones,
          };

          totalProyectosProcesados++;
        }

        Map<String, List<MapEntry<String, Map<String, dynamic>>>> porCategoria =
            {};

        for (var entry in proyectosConPuntaje.entries) {
          final categoria = entry.value['clasificacion'] as String;
          if (!porCategoria.containsKey(categoria)) {
            porCategoria[categoria] = [];
          }
          porCategoria[categoria]!.add(entry);
        }

        for (var categoria in porCategoria.keys) {
          print('\n   🏅 Categoría: $categoria');

          final proyectosCategoria = porCategoria[categoria]!;

          proyectosCategoria.sort((a, b) {
            final promedioA = a.value['promedio'] as double;
            final promedioB = b.value['promedio'] as double;
            return promedioB.compareTo(promedioA);
          });

          final top3 = proyectosCategoria.take(3).toList();

          print('   📊 ${proyectosCategoria.length} proyectos encontrados');
          print('   🏆 Asignando TOP 3 ganadores:');

          int posicion = 1;
          for (var proyecto in top3) {
            final proyectoId = proyecto.key;
            final promedio = proyecto.value['promedio'] as double;
            final codigo = proyecto.value['data']['Código'] ?? 'Sin código';

            print(
              '      $posicion° lugar: $codigo - Promedio: ${promedio.toStringAsFixed(2)}',
            );

            await _firestore
                .collection('events')
                .doc(eventoDoc.id)
                .collection('proyectos')
                .doc(proyectoId)
                .update({
                  'isWinner': true,
                  'posicion': posicion,
                  'promedioFinal': promedio,
                  'winnerDate': FieldValue.serverTimestamp(),
                });

            totalGanadoresAsignados++;
            posicion++;
          }

          for (var proyecto in proyectosCategoria.skip(3)) {
            await _firestore
                .collection('events')
                .doc(eventoDoc.id)
                .collection('proyectos')
                .doc(proyecto.key)
                .update({
                  'isWinner': false,
                  'posicion': FieldValue.delete(),
                  'promedioFinal': FieldValue.delete(),
                  'winnerDate': FieldValue.delete(),
                });
          }
        }
      }

      print('\n✅ Proceso completado:');
      print('   📦 Proyectos procesados: $totalProyectosProcesados');
      print('   🏆 Ganadores asignados: $totalGanadoresAsignados');

      if (mounted) {
        _showSnackBar(
          '✅ Ganadores calculados: $totalGanadoresAsignados proyectos',
          isSuccess: true,
        );
        await _cargarGanadores();
      }
    } catch (e) {
      print('❌ Error al calcular ganadores: $e');
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isCalculando = false);
      }
    }
  }

  // ✅ ACTUALIZADO: Cargar ganadores con filialId
  Future<void> _cargarGanadores() async {
    if (_filialSeleccionada == null ||
        _facultadSeleccionada == null ||
        _carreraSeleccionada == null) {
      _showSnackBar('Debes seleccionar filial, facultad y carrera');
      return;
    }

    setState(() {
      _isLoading = true;
      _ganadores.clear();
      _ganadoresPorCategoria.clear();
      _totalEventos = 0;
    });

    try {
      final eventosSnapshot = await _firestore
          .collection('events')
          .where('filialId', isEqualTo: _filialSeleccionada)
          .where('facultad', isEqualTo: _facultadSeleccionada)
          .where('carreraNombre', isEqualTo: _carreraSeleccionada)
          .get();

      setState(() {
        _totalEventos = eventosSnapshot.docs.length;
      });

      List<Map<String, dynamic>> ganadoresList = [];

      for (var eventoDoc in eventosSnapshot.docs) {
        final eventoData = eventoDoc.data();

        final proyectosSnapshot = await _firestore
            .collection('events')
            .doc(eventoDoc.id)
            .collection('proyectos')
            .where('isWinner', isEqualTo: true)
            .get();

        for (var proyectoDoc in proyectosSnapshot.docs) {
          final proyectoData = proyectoDoc.data();
          ganadoresList.add({
            'id': proyectoDoc.id,
            'eventId': eventoDoc.id,
            'eventName': eventoData['name'] ?? 'Evento sin nombre',
            'eventFacultad': eventoData['facultad'],
            'eventCarrera': eventoData['carreraNombre'],
            'projectName': proyectoData['Título'] ?? 'Proyecto sin nombre',
            'integrantes': proyectoData['Integrantes'],
            'codigo': proyectoData['Código'] ?? 'Sin código',
            'clasificacion':
                proyectoData['Clasificación'] ?? 'Sin clasificación',
            'sala': proyectoData['Sala'] ?? 'Sin sala',
            'isWinner': proyectoData['isWinner'] ?? false,
            'posicion': proyectoData['posicion'] ?? 0,
            'promedioFinal': (proyectoData['promedioFinal'] ?? 0.0).toDouble(),
            'winnerDate': proyectoData['winnerDate'],
          });
        }
      }

      Map<String, List<Map<String, dynamic>>> porCategoria = {};
      for (var ganador in ganadoresList) {
        final categoria = ganador['clasificacion'] as String;
        if (!porCategoria.containsKey(categoria)) {
          porCategoria[categoria] = [];
        }
        porCategoria[categoria]!.add(ganador);
      }

      porCategoria.forEach((categoria, lista) {
        lista.sort(
          (a, b) => (a['posicion'] as int).compareTo(b['posicion'] as int),
        );
      });

      setState(() {
        _ganadores = ganadoresList;
        _ganadoresPorCategoria = porCategoria;
      });

      _showSnackBar(
        'Se encontraron ${_ganadores.length} ganador(es) en ${_totalEventos} evento(s)',
        isSuccess: true,
      );
    } catch (e) {
      _showSnackBar('Error cargando ganadores: $e');
      print('Error detallado: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> _parseIntegrantes(dynamic integrantesData) {
    if (integrantesData == null) return [];
    String integrantesStr = integrantesData.toString();
    if (integrantesStr.contains(',')) {
      return integrantesStr
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return integrantesStr.isNotEmpty ? [integrantesStr.trim()] : [];
  }

  void _showSnackBar(
    String message, {
    bool isSuccess = false,
    bool isError = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle
                  : (isError ? Icons.error : Icons.info),
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess
            ? Colors.green[600]
            : (isError ? Colors.red[600] : const Color(0xFF1E3A5F)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarDetallesGanador(Map<String, dynamic> ganador) {
    final projectName = ganador['projectName'] ?? 'Proyecto sin nombre';
    final integrantes = _parseIntegrantes(ganador['integrantes']);
    final codigo = ganador['codigo'] ?? 'Sin código';
    final clasificacion = ganador['clasificacion'] ?? 'Sin clasificación';
    final sala = ganador['sala'] ?? 'Sin sala';
    final eventName = ganador['eventName'] ?? 'Sin evento';
    final posicion = ganador['posicion'] ?? 0;
    final promedio = ganador['promedioFinal'] ?? 0.0;
    final winnerDate = (ganador['winnerDate'] as Timestamp?)?.toDate();

    IconData medalla = Icons.emoji_events;
    Color colorMedalla = Colors.amber;
    String textoLugar = '${posicion}° Lugar';

    if (posicion == 1) {
      medalla = Icons.emoji_events;
      colorMedalla = Colors.amber;
    } else if (posicion == 2) {
      colorMedalla = Colors.grey[400]!;
    } else if (posicion == 3) {
      colorMedalla = Colors.brown[300]!;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
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
                          color: colorMedalla,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(medalla, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PROYECTO GANADOR',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              textoLugar,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (promedio > 0)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade400,
                                  Colors.green.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Promedio: ${promedio.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorMedalla.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorMedalla.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Proyecto',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                projectName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A5F),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(Icons.event, 'Evento', eventName),
                        _buildDetailRow(Icons.qr_code, 'Código', codigo),
                        _buildDetailRow(
                          Icons.category,
                          'Clasificación',
                          clasificacion,
                        ),
                        _buildDetailRow(Icons.meeting_room, 'Sala', sala),
                        if (winnerDate != null)
                          _buildDetailRow(
                            Icons.calendar_today,
                            'Fecha',
                            '${winnerDate.day}/${winnerDate.month}/${winnerDate.year}',
                          ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A5F).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.group,
                                color: Color(0xFF1E3A5F),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Integrantes: ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...integrantes.map(
                          (i) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1E3A5F),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    i,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF1E3A5F), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _limpiarFiltros() {
    setState(() {
      _filialSeleccionada = null;
      _facultadSeleccionada = null;
      _carreraSeleccionada = null;
      _facultadesDisponibles.clear();
      _carrerasDisponibles.clear();
      _ganadores.clear();
      _ganadoresPorCategoria.clear();
      _totalEventos = 0;
    });
    _showSnackBar('Filtros reiniciados', isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _isLoadingInitial) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E3A5F),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Cargando datos...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentUserType != PrefsHelper.userTypeAdmin &&
        _currentUserType != PrefsHelper.userTypeAsistente) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E3A5F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E3A5F),
          elevation: 0,
          title: const Text('Proyectos Ganadores'),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text(
            'Acceso Denegado',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Color(0xFF1E3A5F),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Proyectos Ganadores',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'TOP 3 por categoría',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: _limpiarFiltros,
                      tooltip: 'Limpiar Filtros',
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
                  child: _isLoading || _isCalculando
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                color: Color(0xFF1E3A5F),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isCalculando
                                    ? 'Calculando ganadores...'
                                    : 'Cargando ganadores...',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sección de filtros
                              _buildFiltrosCard(),
                              const SizedBox(height: 20),
                              // Resultados por categoría
                              if (_filialSeleccionada != null &&
                                  _facultadSeleccionada != null &&
                                  _carreraSeleccionada != null) ...[
                                _buildResultadosHeader(),
                                const SizedBox(height: 16),

                                // ✅ BOTÓN DESCARGAR EXCEL
                                if (_ganadoresPorCategoria.isNotEmpty) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton.icon(
                                      onPressed: _isGeneratingExcel
                                          ? null
                                          : _descargarExcel,
                                      icon: _isGeneratingExcel
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.file_download,
                                              size: 24,
                                            ),
                                      label: Text(
                                        _isGeneratingExcel
                                            ? 'Generando Excel...'
                                            : 'Descargar Reporte en Excel',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF27AE60,
                                        ),
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor:
                                            Colors.grey[300],
                                        disabledForegroundColor:
                                            Colors.grey[500],
                                        elevation: 4,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Lista de ganadores por categoría
                                if (_ganadoresPorCategoria.isEmpty)
                                  _buildEmptyState()
                                else
                                  ..._ganadoresPorCategoria.entries.map((
                                    entry,
                                  ) {
                                    final categoria = entry.key;
                                    final ganadores = entry.value;
                                    return _buildCategoriaSection(
                                      categoria,
                                      ganadores,
                                    );
                                  }).toList(),
                              ],
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ NUEVO: Card de filtros con sistema de filiales
  Widget _buildFiltrosCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                  color: const Color(0xFF1E3A5F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.filter_list,
                  color: Color(0xFF1E3A5F),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Filtros de Búsqueda',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ✅ Filtro Filial
          DropdownButtonFormField<String>(
            value: _filialSeleccionada,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Seleccionar Filial',
              prefixIcon: const Icon(
                Icons.location_city,
                color: Color(0xFF1E3A5F),
              ),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF1E3A5F),
                  width: 2,
                ),
              ),
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

          // ✅ Filtro Facultad
          if (_filialSeleccionada != null) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _facultadSeleccionada,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Seleccionar Facultad',
                prefixIcon: const Icon(Icons.school, color: Color(0xFF1E3A5F)),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E3A5F),
                    width: 2,
                  ),
                ),
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

          // ✅ Filtro Carrera
          if (_facultadSeleccionada != null) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _carreraSeleccionada,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Seleccionar Carrera',
                prefixIcon: const Icon(
                  Icons.menu_book,
                  color: Color(0xFF1E3A5F),
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E3A5F),
                    width: 2,
                  ),
                ),
              ),
              items: _carrerasDisponibles.map((carrera) {
                return DropdownMenuItem(
                  value: carrera['nombre'] as String,
                  child: Text(
                    carrera['nombre'] as String,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _onCarreraChanged,
            ),
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _calcularGanadoresAutomaticos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calculate),
                        SizedBox(width: 8),
                        Text(
                          'Calcular',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _cargarGanadores,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility),
                        SizedBox(width: 8),
                        Text(
                          'Ver',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultadosHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resultados',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${_ganadores.length} ganador(es) • ${_ganadoresPorCategoria.length} categoría(s)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
          ),
          if (_totalEventos > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_totalEventos evento(s)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No se encontraron ganadores',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Presiona "Calcular" para generar ganadores',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriaSection(
    String categoria,
    List<Map<String, dynamic>> ganadores,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E3A5F),
                  const Color(0xFF1E3A5F).withOpacity(0.8),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.category, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    categoria,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'TOP ${ganadores.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: ganadores.map((ganador) {
                return _buildGanadorCard(ganador);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGanadorCard(Map<String, dynamic> ganador) {
    final posicion = ganador['posicion'] as int;
    final promedio = ganador['promedioFinal'] as double;
    final integrantes = _parseIntegrantes(ganador['integrantes']);

    Color colorPosicion = Colors.amber;
    IconData iconPosicion = Icons.emoji_events;

    if (posicion == 1) {
      colorPosicion = Colors.amber;
    } else if (posicion == 2) {
      colorPosicion = Colors.grey[400]!;
    } else if (posicion == 3) {
      colorPosicion = Colors.brown[300]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: colorPosicion.withOpacity(0.3), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _mostrarDetallesGanador(ganador),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: colorPosicion.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(iconPosicion, color: colorPosicion, size: 28),
                      Text(
                        '$posicion°',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorPosicion,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ganador['projectName'] ?? 'Proyecto sin nombre',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A5F).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.qr_code,
                                  size: 12,
                                  color: Color(0xFF1E3A5F),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  ganador['codigo'] ?? 'Sin código',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E3A5F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.group,
                                  size: 12,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${integrantes.length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (promedio > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Promedio: ${promedio.toStringAsFixed(2)} pts',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[800],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
