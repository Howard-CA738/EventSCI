import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/logica/filiales_service.dart';
import 'package:flutter/foundation.dart';   // compute
import 'package:archive/archive.dart';      // descomprimir el .xlsx
import 'package:xml/xml_events.dart';       // leer el XML en streaming

class ImportacionPagosScreen extends StatefulWidget {
  const ImportacionPagosScreen({super.key});

  @override
  State<ImportacionPagosScreen> createState() => _ImportacionPagosScreenState();
}

class _ImportacionPagosScreenState extends State<ImportacionPagosScreen>
    with SingleTickerProviderStateMixin {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FilialesService _filialesService = FilialesService();

  Map<String, dynamic> _estructuraFiliales = {};
  bool _estructuraCargada = false;

  String? _selectedFilialId;
  String? _selectedFilialNombre;
  String? _selectedFacultad;
  String? _selectedCarrera;
  String? _selectedCarreraId;

  List<Map<String, dynamic>> _eventos = [];
  bool _loadingEventos = false;
  String? _selectedEventoId;
  String? _selectedEventoNombre;

  bool _isLoading = false;
  bool _isParsing = false; // ← NUEVO: lectura del Excel en curso
  bool _fileSelected = false;
  String? _fileName;
  List<Map<String, dynamic>> _previewData = [];
  List<Map<String, dynamic>> _allData = [];
  int _totalRows = 0;
  int _successCount = 0;
  int _notFoundCount = 0;
  int _currentProgress = 0;
  List<String> _notFoundList = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final Map<String, String> _columnMapping = {
    'Ciclo'             : 'ciclo',
    'Grupo'             : 'grupo',
    'Código estudiante' : 'codigoUniversitario',
    'Código Estudiante' : 'codigoUniversitario',
    'Estudiante'        : 'name',
    'Documento'         : 'dni',
    'Correo'            : 'email',
    'Celular'           : 'celular',
    'Programa estudio'  : 'carrera',
    'Usuario'           : 'username',
    'Unidad académica'  : 'facultad',
    'Filial'            : 'filial',
    'Sede'              : 'filial',
  };

  bool get _destinoListo =>
      _selectedFilialNombre != null &&
      _selectedFacultad != null &&
      _selectedCarrera != null;

  bool get _todoListo => _destinoListo && _selectedEventoId != null;

  String get _carreraPath => '${_selectedFilialNombre}_$_selectedCarrera';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
        );
    _animationController.forward();
    _initEstructura();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initEstructura() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _filialesService.inicializarSiEsNecesario();
      final estructura = await _filialesService.getEstructuraCompleta();
      if (!mounted) return;
      setState(() {
        _estructuraFiliales = estructura;
        _estructuraCargada  = true;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error cargando estructura: $e');
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  List<String> get _filialesDisponibles => _estructuraFiliales.keys.toList();

  List<String> _getFacultades(String filialId) {
    final filial = _estructuraFiliales[filialId];
    if (filial == null) return [];
    return (filial['facultades'] as Map<String, dynamic>).keys.toList();
  }

  List<Map<String, dynamic>> _getCarreras(String filialId, String facultad) {
    final filial = _estructuraFiliales[filialId];
    if (filial == null) return [];
    final facs = filial['facultades'] as Map<String, dynamic>;
    final facData = facs[facultad];
    if (facData == null) return [];
    return List<Map<String, dynamic>>.from(facData['carreras'] ?? []);
  }

  String _getNombreFilial(String filialId) =>
      _estructuraFiliales[filialId]?['nombre'] ?? filialId;

  Future<void> _cargarEventos() async {
    if (_selectedFilialId == null ||
        _selectedFacultad == null ||
        _selectedCarreraId == null) return;

    if (!mounted) return;
    setState(() {
      _loadingEventos    = true;
      _eventos           = [];
      _selectedEventoId  = null;
      _selectedEventoNombre = null;
    });

    try {
      final snapshot = await _firestore
          .collection('events')
          .where('filialId',  isEqualTo: _selectedFilialId)
          .where('facultad',  isEqualTo: _selectedFacultad)
          .where('carreraId', isEqualTo: _selectedCarreraId)
          .orderBy('createdAt', descending: true)
          .get();

      if (!mounted) return;
      setState(() {
        _eventos = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id'    : doc.id,
            'nombre': data['name'] ?? 'Sin nombre',
            'periodo': data['periodoNombre'] ?? '',
          };
        }).toList();
      });

      if (_eventos.isEmpty) {
        _showMessage('⚠️ No hay eventos para esta carrera');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error cargando eventos: $e');
    }

    if (!mounted) return;
    setState(() => _loadingEventos = false);
  }

  void _onFilialChanged(String? filialId) {
    setState(() {
      _selectedFilialId     = filialId;
      _selectedFilialNombre = filialId != null ? _getNombreFilial(filialId) : null;
      _selectedFacultad     = null;
      _selectedCarrera      = null;
      _selectedCarreraId    = null;
      _eventos              = [];
      _selectedEventoId     = null;
      _selectedEventoNombre = null;
      _resetFile();
    });
  }

  void _onFacultadChanged(String? facultad) {
    setState(() {
      _selectedFacultad  = facultad;
      _selectedCarrera   = null;
      _selectedCarreraId = null;
      _eventos           = [];
      _selectedEventoId  = null;
      _selectedEventoNombre = null;
      _resetFile();
    });
  }

  void _onCarreraChanged(String? carrera, String? carreraId) {
    setState(() {
      _selectedCarrera   = carrera;
      _selectedCarreraId = carreraId;
      _eventos           = [];
      _selectedEventoId  = null;
      _selectedEventoNombre = null;
      _resetFile();
    });
    if (carreraId != null) _cargarEventos();
  }

  void _onEventoChanged(String? eventoId) {
    if (eventoId == null) return;
    final eventoList = List<Map<String, dynamic>>.from(_eventos);
    final idx = eventoList.indexWhere((e) => e['id'] == eventoId);
    if (idx == -1) return;
    final evento = eventoList[idx];
    setState(() {
      _selectedEventoId    = eventoId;
      _selectedEventoNombre = evento['nombre']?.toString() ?? '';
      _resetFile();
    });
  }

  void _resetFile() {
    _fileSelected    = false;
    _fileName        = null;
    _allData         = [];
    _previewData     = [];
    _totalRows       = 0;
    _successCount    = 0;
    _notFoundCount   = 0;
    _currentProgress = 0;
    _notFoundList    = [];
  }

  void _showFilialSelector() {
    _showSelectorSheet(
      title: 'Seleccionar Sede',
      icon: Icons.location_city,
      items: _filialesDisponibles.map((id) => _SheetItem(
        value: id,
        label: _getNombreFilial(id),
        subtitle: _estructuraFiliales[id]?['ubicacion']?.toString() ?? '',
        isSelected: _selectedFilialId == id,
      )).toList(),
      onSelected: (v, [_]) { _onFilialChanged(v); Navigator.pop(context); },
    );
  }

  void _showFacultadSelector() {
    if (_selectedFilialId == null) {
      _showMessage('⚠️ Selecciona una sede primero');
      return;
    }
    final facs = _getFacultades(_selectedFilialId!);
    _showSelectorSheet(
      title: 'Seleccionar Facultad',
      icon: Icons.business,
      items: facs.map((f) => _SheetItem(
        value: f,
        label: f,
        subtitle: '${_getCarreras(_selectedFilialId!, f).length} carreras',
        isSelected: _selectedFacultad == f,
      )).toList(),
      onSelected: (v, [_]) { _onFacultadChanged(v); Navigator.pop(context); },
    );
  }

  void _showCarreraSelector() {
    if (_selectedFilialId == null || _selectedFacultad == null) {
      _showMessage('⚠️ Selecciona una facultad primero');
      return;
    }
    final carreras = _getCarreras(_selectedFilialId!, _selectedFacultad!);
    _showSelectorSheet(
      title: 'Seleccionar Carrera',
      icon: Icons.school,
      items: carreras.map((c) => _SheetItem(
        value: c['nombre'] as String,
        label: c['nombre'] as String,
        subtitle: '',
        isSelected: _selectedCarrera == c['nombre'],
        extra: c['id'] as String?,
      )).toList(),
      onSelected: (v, [extra]) { _onCarreraChanged(v, extra); Navigator.pop(context); },
    );
  }

  void _showEventoSelector() {
    if (_eventos.isEmpty) {
      _showMessage('⚠️ No hay eventos disponibles para esta carrera');
      return;
    }
    _showSelectorSheet(
      title: 'Seleccionar Evento',
      icon: Icons.event,
      items: _eventos.map((e) => _SheetItem(
        value: e['id'] as String,
        label: e['nombre'] as String,
        subtitle: e['periodo']?.toString() ?? '',
        isSelected: _selectedEventoId == e['id'],
      )).toList(),
      onSelected: (v, [_]) { _onEventoChanged(v); Navigator.pop(context); },
    );
  }

  void _showSelectorSheet({
    required String title,
    required IconData icon,
    required List<_SheetItem> items,
    required void Function(String v, [String? extra]) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50, height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: const Color(0xFF1E3A5F), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A5F),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              'No hay opciones disponibles',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: item.isSelected
                                  ? const Color(0xFF1E3A5F).withValues(alpha: 0.08)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: item.isSelected
                                    ? const Color(0xFF1E3A5F)
                                    : Colors.grey.shade300,
                                width: item.isSelected ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              title: Text(
                                item.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: item.isSelected
                                      ? const Color(0xFF1E3A5F)
                                      : Colors.black87,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                              subtitle: item.subtitle.isNotEmpty
                                  ? Text(
                                      item.subtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: item.isSelected
                                            ? const Color(0xFF1E3A5F).withValues(alpha: 0.7)
                                            : Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              trailing: item.isSelected
                                  ? const Icon(Icons.check_circle,
                                      color: Color(0xFF1E3A5F))
                                  : const Icon(Icons.arrow_forward_ios,
                                      size: 14, color: Colors.grey),
                              onTap: () => onSelected(item.value, item.extra),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickExcelFile() async {
    if (!_todoListo) {
      _showMessage('⚠️ Completa la selección de carrera y evento primero');
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result != null && mounted) {
        setState(() {
          _isParsing       = true; // ← muestra el indicador de lectura
          _fileName        = result.files.single.name;
          _notFoundList    = [];
          _successCount    = 0;
          _notFoundCount   = 0;
          _currentProgress = 0;
        });
        final file = File(result.files.single.path!);
        await _readExcelFile(file);
        if (!mounted) return;
        setState(() {
          _fileSelected = true;
          _isParsing    = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isParsing = false);
      _showMessage('Error al seleccionar archivo: $e');
    }
  }

  Future<void> _readExcelFile(File file) async {
    try {
      // Todo el trabajo pesado corre en un isolate aparte (no congela la UI).
      final resultado = await compute(
        _parseExcelPagosIsolate,
        (file.path, _columnMapping),
      );

      if (!resultado.headersValidos) {
        _showMessage('El archivo debe tener la columna "Código estudiante"');
        return;
      }

      _allData     = resultado.data;
      _totalRows   = _allData.length;
      _previewData = _allData.take(5).toList();

      if (_totalRows == 0) {
        _showMessage('No se encontraron registros con "Código estudiante"');
      } else {
        _showMessage('✅ $_totalRows estudiantes detectados');
      }
    } catch (e) {
      _showMessage('Error al leer el archivo Excel: $e');
      debugPrint('Error detallado: $e');
    }
  }

  Future<void> _importarPagos() async {
    if (_allData.isEmpty) {
      _showMessage('No hay datos para importar');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.payments, color: Colors.green.shade700),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Confirmar Importación de Pagos',
                style: TextStyle(
                  color: Color(0xFF1E3A5F),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoBox(
                  children: [
                    _miniInfoRow(Icons.location_city, _selectedFilialNombre!),
                    const SizedBox(height: 4),
                    _miniInfoRow(Icons.school, _selectedCarrera!),
                    const SizedBox(height: 4),
                    _miniInfoRow(Icons.event, _selectedEventoNombre!),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '¿Marcar $_totalRows estudiantes como pagados y BLOQUEAR '
                  'a todos los demás de esta carrera?',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.green.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Los estudiantes del Excel quedarán como pagados y con acceso. '
                          'Los que NO estén en el archivo quedarán BLOQUEADOS y no podrán '
                          'iniciar sesión hasta regularizar su pago.',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    setState(() {
      _isLoading       = true;
      _successCount    = 0;
      _notFoundCount   = 0;
      _currentProgress = 0;
      _notFoundList    = [];
    });

    await _procesarPagos();

    if (!mounted) return;
    setState(() => _isLoading = false);
    _showResultsDialog();
  }

 Future<void> _procesarPagos() async {
  final carreraPath = _carreraPath;
  final eventoId    = _selectedEventoId!;

  debugPrint('💳 Procesando (modo aditivo) → "$carreraPath" | evento "$eventoId"');

  // 1) Códigos del Excel = los que pagaron en esta importación
  final Set<String> pagaron = _allData
      .map((r) => (r['codigoUniversitario'] ?? '').toString().trim())
      .where((c) => c.isNotEmpty)
      .toSet();

  // 2) TODOS los estudiantes de la carrera (para poder matchear por código)
  final snapshot = await _firestore
      .collection('users')
      .doc(carreraPath)
      .collection('students')
      .get();

  if (!mounted) return;

  setState(() {
    _totalRows       = pagaron.length; // referencia: cuántos códigos trae el Excel
    _currentProgress = 0;
  });

  // Set para saber qué códigos del Excel sí se encontraron en la BD
  final Set<String> encontrados = {};

  const batchSize = 450;
  var batch = _firestore.batch();
  int opsInBatch = 0;

  for (final doc in snapshot.docs) {
    if (!mounted) break;

    final data   = doc.data();
    final codigo = (data['codigoUniversitario'] ?? '').toString().trim();

    // Solo tocamos al estudiante si su código está en el Excel
    if (codigo.isNotEmpty && pagaron.contains(codigo)) {
      encontrados.add(codigo);

      batch.update(doc.reference, {
        'pagos.$eventoId' : true,
        'bloqueadoPorPago': false,
      });
      opsInBatch++;
      _successCount++;

      if (opsInBatch >= batchSize) {
        await batch.commit();
        batch = _firestore.batch();
        opsInBatch = 0;
      }
    }

    _currentProgress++;
    if (mounted && _currentProgress % 25 == 0) setState(() {});
  }

  if (opsInBatch > 0) await batch.commit();

  // 3) Códigos del Excel que NO se encontraron en la BD (para reportar)
  final noEncontrados = pagaron.difference(encontrados);
  _notFoundCount = noEncontrados.length;
  _notFoundList  = noEncontrados
      .map((c) => 'Código $c — no encontrado en el sistema')
      .toList();

  if (mounted) setState(() {});

  debugPrint('✅ $_successCount marcados como pagados / $_notFoundCount códigos no encontrados');
}

  void _showResultsDialog() {
    if (!mounted) return;
    final notFoundDisplay = _notFoundList.length > 20
        ? _notFoundList.sublist(0, 20)
        : _notFoundList;
    final extraCount = _notFoundList.length - notFoundDisplay.length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _notFoundCount == 0
                    ? Colors.green.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _notFoundCount == 0 ? Icons.check_circle : Icons.assessment,
                color: _notFoundCount == 0
                    ? Colors.green.shade600
                    : Colors.blue.shade600,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Resultados de Pagos',
                style: TextStyle(
                  color: Color(0xFF1E3A5F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoBox(
                  children: [
                    _miniInfoRow(Icons.location_city, _selectedFilialNombre!),
                    const SizedBox(height: 4),
                    _miniInfoRow(Icons.school, _selectedCarrera!),
                    const SizedBox(height: 4),
                    _miniInfoRow(Icons.event, _selectedEventoNombre!),
                  ],
                ),
                const SizedBox(height: 14),
                _buildResultCard('Total en Excel', '$_totalRows',
                    Icons.list_alt, Colors.blue.shade600, Colors.blue.shade50),
                const SizedBox(height: 10),
                _buildResultCard('Pagos registrados', '$_successCount',
                    Icons.payments, Colors.green.shade600, Colors.green.shade50),
                const SizedBox(height: 10),
                _buildResultCard('Bloqueados (no pagaron)', '$_notFoundCount',
                    Icons.lock_person, Colors.red.shade600, Colors.red.shade50),
                if (_notFoundList.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Estudiantes bloqueados:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: notFoundDisplay.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 5),
                              width: 4, height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                notFoundDisplay[index],
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (extraCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '... y $extraCount más',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (mounted) Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _infoBox({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A5F).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _miniInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF1E3A5F)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1E3A5F),
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(String label, String value, IconData icon,
      Color iconColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: iconColor,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF1E3A5F),
      ));
    }
  }

  Widget _filterBtn({
    required String label,
    required String? value,
    required IconData icon,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    final isSelected = value != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected && enabled
                  ? const Color(0xFF1E3A5F)
                  : Colors.grey.shade300,
              width: isSelected && enabled ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected && enabled
                ? const Color(0xFF1E3A5F).withValues(alpha: 0.04)
                : enabled ? Colors.white : Colors.grey.shade50,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: enabled ? const Color(0xFF1E3A5F) : Colors.grey.shade400,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value ?? 'Seleccionar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected && enabled
                            ? const Color(0xFF1E3A5F)
                            : enabled ? Colors.grey : Colors.grey.shade400,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: enabled ? const Color(0xFF1E3A5F) : Colors.grey.shade400,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
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
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.payments,
                        color: Color(0xFF1E3A5F), size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Importar Pagos',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Marcar estudiantes pagados por evento',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Cerrar',
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
                child: !_estructuraCargada && _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF1E3A5F)))
                    : _isParsing
                        ? _buildParsingView()
                        : _isLoading && _fileSelected
                            ? _buildLoadingView()
                            : FadeTransition(
                                opacity: _fadeAnimation,
                                child: SlideTransition(
                                  position: _slideAnimation,
                                  child: _buildMainContent(),
                                ),
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Indicador mientras se lee el Excel (en isolate)
  Widget _buildParsingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A5F)),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Leyendo archivo Excel...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _fileName ?? 'Procesando datos...',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A5F)),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Procesando pagos...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '$_currentProgress / $_totalRows registros',
            style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _totalRows > 0 ? _currentProgress / _totalRows : 0,
              backgroundColor: Colors.grey[200],
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF1E3A5F)),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${(_totalRows > 0 ? (_currentProgress / _totalRows * 100) : 0).toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _statCol('$_successCount', 'Marcados',
                      Icons.check_circle, Colors.green),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                Expanded(
                  child: _statCol('$_notFoundCount', 'Bloqueados',
                      Icons.lock_person, Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String value, String label, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          _buildFiltrosCard(),
          const SizedBox(height: 16),

          Card(
            elevation: 4,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: _todoListo
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.payments,
                      size: 40,
                      color: _todoListo
                          ? Colors.green.shade700
                          : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Importar Lista de Pagos',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E3A5F),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _todoListo
                        ? 'Selecciona el archivo Excel con los estudiantes que pagaron'
                        : 'Completa la selección de carrera y evento primero',
                    style: TextStyle(
                      fontSize: 13,
                      color: _todoListo
                          ? const Color(0xFF64748B)
                          : Colors.orange.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureRow(Icons.search, 'Busca por código universitario'),
                  const SizedBox(height: 6),
                  _buildFeatureRow(Icons.update, 'Actualiza campo de pago en el evento'),
                  const SizedBox(height: 6),
                  _buildFeatureRow(Icons.warning_amber, 'Reporta códigos no encontrados'),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _todoListo ? _pickExcelFile : null,
                      icon: const Icon(Icons.file_open),
                      label: const Text('Seleccionar Archivo Excel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (_fileName != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300, width: 2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.check_circle,
                                color: Colors.green.shade700, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Archivo seleccionado',
                                  style: TextStyle(
                                      fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _fileName!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A5F),
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
          ),

          if (_fileSelected && _previewData.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildPreviewCard(),
          ],

          if (_fileSelected && _previewData.isEmpty) ...[
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.warning_amber_rounded,
                          color: Colors.orange.shade700, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'No se encontraron registros con "Código estudiante". '
                        'Verifica que el archivo tenga esa columna.',
                        style: TextStyle(
                            color: Color(0xFF1E3A5F), fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltrosCard() {
    return Card(
      elevation: 3,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.filter_alt,
                      color: Colors.green.shade700, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Destino del pago',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_todoListo)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: Colors.green.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Listo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            _filterBtn(
              label: 'Sede',
              value: _selectedFilialNombre,
              icon: Icons.location_city,
              onTap: _estructuraCargada ? _showFilialSelector : null,
              enabled: _estructuraCargada,
            ),
            const SizedBox(height: 10),

            _filterBtn(
              label: 'Facultad',
              value: _selectedFacultad != null
                  ? _selectedFacultad!.replaceFirst('Facultad de ', '')
                  : null,
              icon: Icons.business,
              onTap: _selectedFilialId != null ? _showFacultadSelector : null,
              enabled: _selectedFilialId != null,
            ),
            const SizedBox(height: 10),

            _filterBtn(
              label: 'Carrera',
              value: _selectedCarrera,
              icon: Icons.school,
              onTap: _selectedFacultad != null ? _showCarreraSelector : null,
              enabled: _selectedFacultad != null,
            ),
            const SizedBox(height: 10),

            _loadingEventos
                ? Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.green.shade700),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Cargando eventos...',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  )
                : _filterBtn(
                    label: 'Evento',
                    value: _selectedEventoNombre,
                    icon: Icons.event,
                    onTap: (_destinoListo && _eventos.isNotEmpty)
                        ? _showEventoSelector
                        : null,
                    enabled: _destinoListo && _eventos.isNotEmpty,
                  ),

            if (_destinoListo && !_loadingEventos && _eventos.isEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber,
                        color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'No hay eventos para esta carrera. El admin de carrera debe crear uno primero.',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF1E3A5F)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_todoListo) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder_open,
                        size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_carreraPath › $_selectedEventoNombre',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade800,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
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

  Widget _buildPreviewCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
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
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.preview, color: Colors.green.shade600, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Estudiantes detectados',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_totalRows est.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.event, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_selectedCarrera › $_selectedEventoNombre',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _previewData.length,
              itemBuilder: (context, index) {
                final student = _previewData[index];
                final codigo = student['codigoUniversitario']?.toString() ?? '—';
                final nombre = student['name']?.toString() ?? 'Sin nombre';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.badge,
                              size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Código: $codigo',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Icon(Icons.payments,
                        color: Colors.green.shade600, size: 20),
                  ),
                );
              },
            ),
            if (_totalRows > 5) ...[
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Y ${_totalRows - 5} más...',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _importarPagos,
                icon: const Icon(Icons.payments, size: 22),
                label: const Text(
                  'Importar y marcar como Pagados',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.green.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetItem {
  final String  value;
  final String  label;
  final String  subtitle;
  final bool    isSelected;
  final String? extra;

  const _SheetItem({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    this.extra,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// PARSEO DEL EXCEL EN ISOLATE (fuera de la clase)
// No bloquea la UI. Detección de columnas tolerante a tildes, mayúsculas
// y espacios. La estructura de salida es idéntica a la original.
// ═══════════════════════════════════════════════════════════════════════════
typedef _ParseResult = ({bool headersValidos, List<Map<String, dynamic>> data});

// Normaliza un encabezado: minúsculas, sin tildes, espacios colapsados.
String _normalizarHeader(String? h) {
  if (h == null) return '';
  var s = h.trim().toLowerCase();
  const acentos = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c',
  };
  acentos.forEach((a, r) => s = s.replaceAll(a, r));
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  return s;
}

// Quita el prefijo de namespace de un nombre de elemento/atributo XML.
String _local(String name) =>
    name.contains(':') ? name.split(':').last : name;

// Convierte la parte de letras de una referencia de celda (ej. "AB12") a
// índice de columna base 0 (A=0, B=1, ... Z=25, AA=26 ...).
int _colIndex(String cellRef) {
  int idx = 0;
  bool huboLetra = false;
  for (int i = 0; i < cellRef.length; i++) {
    final ch = cellRef.codeUnitAt(i);
    if (ch >= 65 && ch <= 90) {        // A-Z
      idx = idx * 26 + (ch - 64);
      huboLetra = true;
    } else if (ch >= 97 && ch <= 122) { // a-z
      idx = idx * 26 + (ch - 96);
      huboLetra = true;
    } else {
      break; // llegó a los dígitos
    }
  }
  return huboLetra ? idx - 1 : -1;
}

// Busca un archivo dentro del zip por su ruta exacta.
ArchiveFile? _findFile(Archive a, String name) {
  for (final f in a.files) {
    if (f.name == name) return f;
  }
  return null;
}

// Ubica la ruta de la primera hoja del libro (con respaldo a sheet1.xml).
String _firstSheetPath(Archive archive) {
  try {
    final wbFile   = _findFile(archive, 'xl/workbook.xml');
    final relsFile = _findFile(archive, 'xl/_rels/workbook.xml.rels');
    if (wbFile != null && relsFile != null) {
      final wbXml = utf8.decode(wbFile.content as List<int>,
          allowMalformed: true);
      String? rid;
      for (final ev in parseEvents(wbXml)) {
        if (ev is XmlStartElementEvent && _local(ev.name) == 'sheet') {
          for (final at in ev.attributes) {
            if (_local(at.name) == 'id') { rid = at.value; break; }
          }
          break; // primera hoja
        }
      }
      if (rid != null) {
        final relsXml = utf8.decode(relsFile.content as List<int>,
            allowMalformed: true);
        for (final ev in parseEvents(relsXml)) {
          if (ev is XmlStartElementEvent && _local(ev.name) == 'Relationship') {
            String? id, target;
            for (final at in ev.attributes) {
              final n = _local(at.name);
              if (n == 'Id')     id = at.value;
              if (n == 'Target') target = at.value;
            }
            if (id == rid && target != null) {
              return target.startsWith('/')
                  ? target.substring(1)
                  : 'xl/$target';
            }
          }
        }
      }
    }
  } catch (_) {/* respaldo abajo */}

  final sheets = archive.files
      .map((f) => f.name)
      .where((n) => n.startsWith('xl/worksheets/') && n.endsWith('.xml'))
      .toList()
    ..sort();
  return sheets.isNotEmpty ? sheets.first : 'xl/worksheets/sheet1.xml';
}

// ───────────────────────────────────────────────────────────────────────────
// LECTOR EN STREAMING — recorre el XML del .xlsx leyendo SOLO las celdas con
// valor. Ignora por completo las filas vacías (aunque haya un millón), por lo
// que no se cuelga ni consume memoria de más. La salida es idéntica a la
// versión anterior: List<Map> con los mismos campos, deduplicada por código.
// ───────────────────────────────────────────────────────────────────────────
_ParseResult _parseExcelPagosIsolate(
    (String path, Map<String, String> mapping) args) {
  final (path, columnMapping) = args;

  // Mapeo normalizado: tolera mayúsculas/tildes/espacios en los encabezados.
  final normMapping = <String, String>{};
  columnMapping.forEach((k, v) => normMapping[_normalizarHeader(k)] = v);

  final bytes = File(path).readAsBytesSync();
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    return (headersValidos: true, data: <Map<String, dynamic>>[]);
  }

  // 1) Cadenas compartidas (para celdas de texto, ej. nombres).
  final sharedStrings = <String>[];
  final ssFile = _findFile(archive, 'xl/sharedStrings.xml');
  if (ssFile != null) {
    final ssXml = utf8.decode(ssFile.content as List<int>,
        allowMalformed: true);
    final sb = StringBuffer();
    var inSi = false, inT = false;
    for (final ev in parseEvents(ssXml)) {
      if (ev is XmlStartElementEvent) {
        final n = _local(ev.name);
        if (n == 'si') {
          inSi = true;
          sb.clear();
          if (ev.isSelfClosing) { sharedStrings.add(''); inSi = false; }
        } else if (n == 't' && inSi) {
          inT = true;
        }
      } else if (ev is XmlTextEvent && inT) {
        sb.write(ev.value);
      } else if (ev is XmlEndElementEvent) {
        final n = _local(ev.name);
        if (n == 't') {
          inT = false;
        } else if (n == 'si') {
          sharedStrings.add(sb.toString());
          inSi = false;
        }
      }
    }
  }

  // 2) Hoja de cálculo (primera hoja).
  final sheetPath = _firstSheetPath(archive);
  final wsFile = _findFile(archive, sheetPath) ??
      _findFile(archive, 'xl/worksheets/sheet1.xml');
  if (wsFile == null) {
    return (headersValidos: true, data: <Map<String, dynamic>>[]);
  }
  final wsXml = utf8.decode(wsFile.content as List<int>, allowMalformed: true);

  final colToField = <int, String>{}; // índice de columna -> campo
  bool headersListos = false;
  bool tieneCodigo   = false;
  final out = <Map<String, dynamic>>[];

  // Estado de la celda en curso.
  int curCol = -1;
  String curType = '';
  bool inV = false;
  bool inInlineT = false;
  final cellBuf = StringBuffer();
  int autoCol = 0;

  // Celdas con valor de la fila en curso: índiceCol -> valor (texto).
  var rowCells = <int, String>{};

  for (final ev in parseEvents(wsXml)) {
    if (ev is XmlStartElementEvent) {
      final n = _local(ev.name);
      if (n == 'row') {
        rowCells = <int, String>{};
        autoCol  = 0;
      } else if (n == 'c') {
        curType = '';
        curCol  = -1;
        inV = false;
        inInlineT = false;
        cellBuf.clear();
        for (final at in ev.attributes) {
          final an = _local(at.name);
          if (an == 'r') curCol = _colIndex(at.value);
          else if (an == 't') curType = at.value;
        }
        if (curCol < 0) curCol = autoCol;
        autoCol = curCol + 1;
        if (ev.isSelfClosing) curCol = -1; // celda vacía
      } else if (n == 'v') {
        inV = true;
      } else if (n == 't' && curType == 'inlineStr') {
        inInlineT = true;
      }
    } else if (ev is XmlTextEvent) {
      if (inV || inInlineT) cellBuf.write(ev.value);
    } else if (ev is XmlEndElementEvent) {
      final n = _local(ev.name);
      if (n == 'v') {
        inV = false;
      } else if (n == 't' && inInlineT) {
        inInlineT = false;
      } else if (n == 'c') {
        if (curCol >= 0) {
          final raw = cellBuf.toString();
          String value;
          if (curType == 's') {
            final idx = int.tryParse(raw.trim());
            value = (idx != null && idx >= 0 && idx < sharedStrings.length)
                ? sharedStrings[idx]
                : '';
          } else {
            value = raw;
          }
          value = value.trim();
          if (value.isNotEmpty) rowCells[curCol] = value;
        }
        curCol = -1;
      } else if (n == 'row') {
        if (!headersListos) {
          // Primera fila no vacía = encabezados.
          if (rowCells.isNotEmpty) {
            rowCells.forEach((col, val) {
              final field = normMapping[_normalizarHeader(val)];
              if (field != null) {
                colToField[col] = field;
                if (field == 'codigoUniversitario') tieneCodigo = true;
              }
            });
            headersListos = true;
          }
        } else {
          // Fila de datos.
          final rowData = <String, dynamic>{};
          rowCells.forEach((col, val) {
            final field = colToField[col];
            if (field != null) rowData[field] = val;
          });
          if (rowData.containsKey('codigoUniversitario')) out.add(rowData);
        }
      }
    }
  }

  if (!tieneCodigo) {
    return (headersValidos: false, data: <Map<String, dynamic>>[]);
  }

  // Dedupe por código universitario (igual que antes).
  final uniqueMap = <String, Map<String, dynamic>>{};
  for (final row in out) {
    final codigo = (row['codigoUniversitario'] ?? '').toString().trim();
    if (codigo.isNotEmpty) uniqueMap.putIfAbsent(codigo, () => row);
  }
  return (headersValidos: true, data: uniqueMap.values.toList());
}