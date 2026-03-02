import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'reportes_asistencias_excel.dart';

class AsistenciasEstudiantesResultadosScreen extends StatefulWidget {
  final String eventoId;
  final String eventoNombre;
  final String filialId; // ✅ NUEVO
  final String facultad;
  final String? carrera;

  const AsistenciasEstudiantesResultadosScreen({
    super.key,
    required this.eventoId,
    required this.eventoNombre,
    required this.filialId, // ✅ NUEVO
    required this.facultad,
    this.carrera,
  });

  @override
  State<AsistenciasEstudiantesResultadosScreen> createState() =>
      _AsistenciasEstudiantesResultadosScreenState();
}

class _AsistenciasEstudiantesResultadosScreenState
    extends State<AsistenciasEstudiantesResultadosScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ReportesAsistenciasExcelService _excelService =
      ReportesAsistenciasExcelService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<Map<String, dynamic>> _estudiantes = [];
  List<Map<String, dynamic>> _estudiantesFiltrados = [];
  bool _isLoading = false;
  bool _isGeneratingExcel = false;

  String _busqueda = '';
  String _ordenamiento = 'nombre';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
    _cargarAsistencias();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _cargarAsistencias() async {
    setState(() => _isLoading = true);

    try {
      print('🔍 Cargando asistencias del evento: ${widget.eventoId}');

      final asistenciasSnapshot = await _firestore
          .collection('events')
          .doc(widget.eventoId)
          .collection('asistencias')
          .get();

      print('📊 ${asistenciasSnapshot.docs.length} estudiantes encontrados');

      if (asistenciasSnapshot.docs.isEmpty) {
        print('⚠️ No hay asistencias en este evento');
        if (mounted) {
          setState(() {
            _estudiantes = [];
            _estudiantesFiltrados = [];
            _isLoading = false;
          });
        }
        return;
      }

      // ✅ Cargar estudiantes con búsqueda de ciclo/grupo
      final futures = asistenciasSnapshot.docs.map((estudianteDoc) async {
        final estudianteData = estudianteDoc.data();

        // Obtener scans
        final scansSnapshot = await _firestore
            .collection('events')
            .doc(widget.eventoId)
            .collection('asistencias')
            .doc(estudianteDoc.id)
            .collection('scans')
            .get();

        final totalScans = scansSnapshot.docs.length;

        // ✅ Intentar obtener ciclo y grupo del resumen primero
        String? ciclo = estudianteData['ciclo'];
        String? grupo = estudianteData['grupo'];

        // ✅ Si NO están en el resumen, buscar en el perfil
        if (ciclo == null || grupo == null) {
          try {
            final carreraPath = estudianteData['carrera'];
            final username = estudianteData['studentUsername'];

            if (carreraPath != null && username != null) {
              final studentQuery = await _firestore
                  .collection('users')
                  .doc(carreraPath)
                  .collection('students')
                  .where('username', isEqualTo: username)
                  .limit(1)
                  .get();

              if (studentQuery.docs.isNotEmpty) {
                final studentData = studentQuery.docs.first.data();
                ciclo ??= studentData['ciclo'];
                grupo ??= studentData['grupo'];
              }
            }
          } catch (e) {
            print('⚠️ Error buscando ciclo/grupo: $e');
          }
        }

        // Convertir scans a lista
        final List<Map<String, dynamic>> scans = scansSnapshot.docs.map((
          scanDoc,
        ) {
          final scanData = scanDoc.data();
          return {
            'id': scanDoc.id,
            'codigoProyecto': scanData['codigoProyecto'] ?? 'Sin código',
            'tituloProyecto': scanData['tituloProyecto'] ?? 'Sin título',
            'categoria': scanData['categoria'] ?? 'Sin categoría',
            'grupo': scanData['grupo'],
            'timestamp': scanData['timestamp'],
          };
        }).toList();

        scans.sort((a, b) {
          final timestampA = (a['timestamp'] as Timestamp?)?.toDate();
          final timestampB = (b['timestamp'] as Timestamp?)?.toDate();
          if (timestampA == null || timestampB == null) return 0;
          return timestampB.compareTo(timestampA);
        });

        return {
          'id': estudianteDoc.id,
          'nombre': estudianteData['studentName'] ?? 'Sin nombre',
          'username': estudianteData['studentUsername'] ?? '',
          'dni': estudianteData['studentDNI'] ?? '',
          'codigo': estudianteData['studentCodigo'] ?? '',
          'facultad': estudianteData['facultad'] ?? '',
          'carrera': estudianteData['carrera'] ?? '',
          'ciclo': ciclo ?? 'N/A',
          'grupo': grupo ?? 'N/A',
          'totalScans': totalScans,
          'lastScan': estudianteData['lastScan'],
          'scans': scans,
        };
      }).toList();

      final estudiantesList = await Future.wait(futures);

      print('✅ ${estudiantesList.length} estudiantes cargados');

      if (mounted) {
        setState(() {
          _estudiantes = estudiantesList;
          _ordenamiento = 'ciclo-grupo';
          _aplicarFiltrosYOrdenamiento();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error al cargar asistencias: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error al cargar asistencias: $e', isError: true);
      }
    }
  }

  void _aplicarFiltrosYOrdenamiento() {
    List<Map<String, dynamic>> filtrados = List.from(_estudiantes);

    // Aplicar búsqueda
    if (_busqueda.isNotEmpty) {
      filtrados = filtrados.where((estudiante) {
        final nombre = (estudiante['nombre'] as String).toLowerCase();
        final username = (estudiante['username'] as String).toLowerCase();
        final codigo = (estudiante['codigo'] as String).toLowerCase();
        final dni = (estudiante['dni'] as String).toLowerCase();
        final busquedaLower = _busqueda.toLowerCase();

        return nombre.contains(busquedaLower) ||
            username.contains(busquedaLower) ||
            codigo.contains(busquedaLower) ||
            dni.contains(busquedaLower);
      }).toList();
    }

    // ✅ APLICAR ORDENAMIENTO MEJORADO
    switch (_ordenamiento) {
      case 'nombre':
        filtrados.sort(
          (a, b) => (a['nombre'] as String).compareTo(b['nombre'] as String),
        );
        break;

      case 'asistencias':
        filtrados.sort(
          (a, b) => (b['totalScans'] as int).compareTo(a['totalScans'] as int),
        );
        break;

      case 'codigo':
        filtrados.sort(
          (a, b) => (a['codigo'] as String).compareTo(b['codigo'] as String),
        );
        break;

      case 'ciclo-grupo':
        // ✅ ORDENAMIENTO ESPECIAL: CICLO → GRUPO → NOMBRE
        filtrados.sort((a, b) {
          // 1. Primero por CICLO
          final cicloA = _parseCiclo(a['ciclo']);
          final cicloB = _parseCiclo(b['ciclo']);

          if (cicloA != cicloB) {
            return cicloA.compareTo(cicloB);
          }

          // 2. Luego por GRUPO (si el ciclo es igual)
          final grupoA = _parseGrupo(a['grupo']);
          final grupoB = _parseGrupo(b['grupo']);

          if (grupoA != grupoB) {
            return grupoA.compareTo(grupoB);
          }

          // 3. Finalmente por NOMBRE (si ciclo y grupo son iguales)
          return (a['nombre'] as String).compareTo(b['nombre'] as String);
        });
        break;
    }

    setState(() {
      _estudiantesFiltrados = filtrados;
    });
  }

  Future<void> _descargarExcel() async {
    if (_estudiantes.isEmpty) {
      _showSnackBar('No hay asistencias para exportar', isError: true);
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
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text(
                  'Generando reporte de asistencias...',
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

      // ✅ ORDENAR LA LISTA ANTES DE EXPORTAR
      final estudiantesOrdenados = List<Map<String, dynamic>>.from(
        _estudiantes,
      );

      estudiantesOrdenados.sort((a, b) {
        // 1. Primero por CICLO
        final cicloA = _parseCiclo(a['ciclo']);
        final cicloB = _parseCiclo(b['ciclo']);

        if (cicloA != cicloB) {
          return cicloA.compareTo(cicloB);
        }

        // 2. Luego por GRUPO
        final grupoA = _parseGrupo(a['grupo']);
        final grupoB = _parseGrupo(b['grupo']);

        if (grupoA != grupoB) {
          return grupoA.compareTo(grupoB);
        }

        // 3. Finalmente por NOMBRE
        return (a['nombre'] as String).compareTo(b['nombre'] as String);
      });

      print('✅ Lista ordenada: ${estudiantesOrdenados.length} estudiantes');
      print(
        '   Primero: Ciclo ${estudiantesOrdenados.first['ciclo']}, Grupo ${estudiantesOrdenados.first['grupo']}',
      );
      print(
        '   Último: Ciclo ${estudiantesOrdenados.last['ciclo']}, Grupo ${estudiantesOrdenados.last['grupo']}',
      );

      // ✅ EXPORTAR LA LISTA ORDENADA
      final resultado = await _excelService.generarReporteAsistencias(
        estudiantes: estudiantesOrdenados, // ← USAR LISTA ORDENADA
        eventoNombre: widget.eventoNombre,
        facultad: widget.facultad,
        carrera: widget.carrera,
      );

      if (mounted) {
        Navigator.pop(context);
        setState(() => _isGeneratingExcel = false);

        if (resultado) {
          _showSnackBar('✅ Reporte Excel generado exitosamente');
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

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _mostrarDetalleEstudiante(Map<String, dynamic> estudiante) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
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
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A5F), Color(0xFF2C5F7C)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              estudiante['nombre'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                            if (estudiante['username'].isNotEmpty)
                              Text(
                                '@${estudiante['username']}',
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

                // Información del estudiante
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.badge, 'DNI', estudiante['dni']),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.numbers,
                        'Código',
                        estudiante['codigo'],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.school,
                        'Facultad',
                        estudiante['facultad'],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.menu_book,
                        'Carrera',
                        estudiante['carrera'],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.class_, 'Ciclo', estudiante['ciclo']),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.group, 'Grupo', estudiante['grupo']),
                    ],
                  ),
                ),

                // Lista de scans
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history,
                        color: Color(0xFF1E3A5F),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Asistencias Registradas (${estudiante['totalScans']})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: (estudiante['scans'] as List).length,
                    itemBuilder: (context, index) {
                      final scan = (estudiante['scans'] as List)[index];
                      final timestamp = (scan['timestamp'] as Timestamp?)
                          ?.toDate();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4A90E2,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.qr_code_scanner,
                                    color: Color(0xFF4A90E2),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    scan['codigoProyecto'],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A5F),
                                    ),
                                  ),
                                ),
                                if (timestamp != null)
                                  Text(
                                    '${timestamp.day}/${timestamp.month}/${timestamp.year}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                            if (scan['tituloProyecto'] != 'Sin título') ...[
                              const SizedBox(height: 8),
                              Text(
                                scan['tituloProyecto'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: [
                                _buildChip(
                                  scan['categoria'],
                                  Icons.category,
                                  Colors.orange,
                                ),
                                if (scan['grupo'] != null)
                                  _buildChip(
                                    scan['grupo'],
                                    Icons.group,
                                    Colors.purple,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF1E3A5F)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E3A5F),
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : 'No disponible',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Asistencias',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              widget.eventoNombre,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarAsistencias,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Resumen
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.groups,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_estudiantes.length} Estudiantes',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        _busqueda.isEmpty
                                            ? 'Total registrado'
                                            : '${_estudiantesFiltrados.length} en resultados',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Buscador
                          TextField(
                            onChanged: (value) {
                              setState(() {
                                _busqueda = value;
                                _aplicarFiltrosYOrdenamiento();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Buscar por nombre, código o DNI...',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Ordenamiento
                          Row(
                            children: [
                              const Icon(
                                Icons.sort,
                                size: 18,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Ordenar por:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    _buildOrdenChip(
                                      'Ciclo/Grupo',
                                      'ciclo-grupo',
                                    ),
                                    _buildOrdenChip('Nombre', 'nombre'),
                                    _buildOrdenChip(
                                      'Asistencias',
                                      'asistencias',
                                    ),
                                    _buildOrdenChip('Código', 'codigo'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Botón descargar Excel
                    if (_estudiantes.isNotEmpty && !_isLoading) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
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
                                : const Icon(Icons.file_download, size: 24),
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
                              backgroundColor: const Color(0xFF27AE60),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[300],
                              disabledForegroundColor: Colors.grey[500],
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Lista de estudiantes
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF1E3A5F),
                              ),
                            )
                          : _estudiantesFiltrados.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_off,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _busqueda.isEmpty
                                        ? 'No hay asistencias registradas'
                                        : 'No se encontraron resultados',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              itemCount: _estudiantesFiltrados.length,
                              itemBuilder: (context, index) {
                                final estudiante = _estudiantesFiltrados[index];
                                return TweenAnimationBuilder(
                                  tween: Tween<double>(begin: 0, end: 1),
                                  duration: Duration(
                                    milliseconds: 300 + (index * 50),
                                  ),
                                  curve: Curves.easeOut,
                                  builder: (context, double value, child) {
                                    return Transform.translate(
                                      offset: Offset(0, 20 * (1 - value)),
                                      child: Opacity(
                                        opacity: value,
                                        child: _buildEstudianteCard(estudiante),
                                      ),
                                    );
                                  },
                                );
                              },
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
  }

  Widget _buildOrdenChip(String label, String valor) {
    final isSelected = _ordenamiento == valor;

    return InkWell(
      onTap: () {
        setState(() {
          _ordenamiento = valor;
          _aplicarFiltrosYOrdenamiento();
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A5F) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildEstudianteCard(Map<String, dynamic> estudiante) {
    final lastScan = (estudiante['lastScan'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _mostrarDetalleEstudiante(estudiante),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF2C5F7C)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        estudiante['nombre'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (estudiante['codigo'].isNotEmpty)
                        Text(
                          estudiante['codigo'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (lastScan != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Última: ${lastScan.day}/${lastScan.month}/${lastScan.year}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90E2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${estudiante['totalScans']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'asistencias',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _parseCiclo(String? ciclo) {
    if (ciclo == null || ciclo.isEmpty || ciclo == 'N/A') {
      return 999;
    }

    try {
      final match = RegExp(r'\d+').firstMatch(ciclo);
      if (match != null) {
        return int.parse(match.group(0)!);
      }
    } catch (e) {
      // Si falla, devolver un valor alto
    }

    return 999;
  }

  int _parseGrupo(String? grupo) {
    if (grupo == null || grupo.isEmpty || grupo == 'N/A') {
      return 999;
    }

    final grupoLower = grupo.toLowerCase();
    if (grupoLower.contains('único') || grupoLower.contains('unico')) {
      return 0;
    }

    try {
      final match = RegExp(r'\d+').firstMatch(grupo);
      if (match != null) {
        return int.parse(match.group(0)!);
      }
    } catch (e) {
      // Si falla, devolver un valor alto
    }

    return 999;
  }
}
