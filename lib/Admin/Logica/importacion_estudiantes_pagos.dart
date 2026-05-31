import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/logica/filiales_service.dart';

class ImportacionPagosScreen extends StatefulWidget {
  const ImportacionPagosScreen({super.key});

  @override
  State<ImportacionPagosScreen> createState() => _ImportacionPagosScreenState();
}

class _ImportacionPagosScreenState extends State<ImportacionPagosScreen>
    with SingleTickerProviderStateMixin {

  // ── Servicios ──────────────────────────────────────────────────────
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FilialesService _filialesService = FilialesService();

  // ── Estructura de filiales ─────────────────────────────────────────
  Map<String, dynamic> _estructuraFiliales = {};
  bool _estructuraCargada = false;

  // ── Selección de destino ───────────────────────────────────────────
  String? _selectedFilialId;
  String? _selectedFilialNombre;
  String? _selectedFacultad;
  String? _selectedCarrera;
  String? _selectedCarreraId;

  // ── Eventos de la carrera seleccionada ────────────────────────────
  List<Map<String, dynamic>> _eventos = [];
  bool _loadingEventos = false;
  String? _selectedEventoId;
  String? _selectedEventoNombre;

  // ── Estado de importación ──────────────────────────────────────────
  bool _isLoading = false;
  bool _fileSelected = false;
  String? _fileName;
  List<Map<String, dynamic>> _previewData = [];
  List<Map<String, dynamic>> _allData = [];
  int _totalRows = 0;
  int _successCount = 0;
  int _notFoundCount = 0;
  int _currentProgress = 0;
  List<String> _notFoundList = [];

  // ── Animaciones ────────────────────────────────────────────────────
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ── Columnas del Excel (mismo formato que importación completa) ────
  final Map<String, String> _columnMapping = {
    'Ciclo'             : 'ciclo',
    'Grupo'             : 'grupo',
    'Código estudiante' : 'codigoUniversitario',
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

  // ── Getters de destino ─────────────────────────────────────────────
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

  // ── Inicializar estructura ─────────────────────────────────────────
  Future<void> _initEstructura() async {
    setState(() => _isLoading = true);
    try {
      await _filialesService.inicializarSiEsNecesario();
      final estructura = await _filialesService.getEstructuraCompleta();
      setState(() {
        _estructuraFiliales = estructura;
        _estructuraCargada  = true;
      });
    } catch (e) {
      _showMessage('Error cargando estructura: $e');
    }
    setState(() => _isLoading = false);
  }

  // ── Helpers de estructura ──────────────────────────────────────────
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

  // ── Cargar eventos de la carrera seleccionada ──────────────────────
  Future<void> _cargarEventos() async {
    if (_selectedFilialId == null ||
        _selectedFacultad == null ||
        _selectedCarreraId == null) return;

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
      _showMessage('Error cargando eventos: $e');
    }

    setState(() => _loadingEventos = false);
  }

  // ── Cambios de selección ───────────────────────────────────────────
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
    final evento = _eventos.firstWhere((e) => e['id'] == eventoId,
        orElse: () => {});
    setState(() {
      _selectedEventoId    = eventoId;
      _selectedEventoNombre = evento['nombre'] ?? '';
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

  // ── Selectores bottom sheet ────────────────────────────────────────
  void _showFilialSelector() {
    _showSelectorSheet(
      title: 'Seleccionar Sede',
      icon: Icons.location_city,
      items: _filialesDisponibles.map((id) => _SheetItem(
        value: id,
        label: _getNombreFilial(id),
        subtitle: _estructuraFiliales[id]?['ubicacion'] ?? '',
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
        subtitle: e['periodo'] as String? ?? '',
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
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
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
                    Text(title,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F))),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('No hay opciones disponibles',
                                  style: TextStyle(color: Colors.grey[500])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
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
                                title: Text(item.label,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: item.isSelected
                                            ? const Color(0xFF1E3A5F)
                                            : Colors.black87,
                                        fontSize: 14)),
                                subtitle: item.subtitle.isNotEmpty
                                    ? Text(item.subtitle,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: item.isSelected
                                                ? const Color(0xFF1E3A5F).withValues(alpha: 0.7)
                                                : Colors.grey))
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
      ),
    );
  }

  // ── Selección de archivo ───────────────────────────────────────────
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
      if (result != null) {
        setState(() {
          _isLoading       = true;
          _fileName        = result.files.single.name;
          _notFoundList    = [];
          _successCount    = 0;
          _notFoundCount   = 0;
          _currentProgress = 0;
        });
        final file = File(result.files.single.path!);
        await _readExcelFile(file);
        setState(() {
          _fileSelected = true;
          _isLoading    = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('Error al seleccionar archivo: $e');
    }
  }

  // ── Leer Excel ─────────────────────────────────────────────────────
  Future<void> _readExcelFile(File file) async {
    try {
      final bytes     = file.readAsBytesSync();
      final excelFile = excel_pkg.Excel.decodeBytes(bytes);
      final sheet     = excelFile.tables.keys.first;
      final table     = excelFile.tables[sheet];

      if (table == null || table.rows.isEmpty) {
        _showMessage('El archivo Excel está vacío');
        return;
      }

      final headers = table.rows.first
          .map((cell) => cell?.value?.toString().trim())
          .toList();

      if (!_validateHeaders(headers)) return;

      _allData.clear();
      for (int i = 1; i < table.rows.length; i++) {
        final row     = table.rows[i];
        final rowData = <String, dynamic>{};
        bool hasAnyData = false;

        for (int j = 0; j < headers.length; j++) {
          if (j < row.length) {
            final header = headers[j];
            if (header != null && _columnMapping.containsKey(header)) {
              final fieldName = _columnMapping[header]!;
              final cellValue = row[j]?.value;
              if (cellValue != null) {
                String value;
                if (cellValue is int || cellValue is double) {
                  value = cellValue.toString();
                } else {
                  value = cellValue.toString().trim();
                }
                if (value.isNotEmpty) {
                  hasAnyData = true;
                  rowData[fieldName] = value;
                }
              }
            }
          }
        }

        // Para pagos solo necesitamos código universitario (o nombre como fallback)
        if (hasAnyData && rowData.containsKey('codigoUniversitario')) {
          _allData.add(rowData);
        }
      }

      // Eliminar duplicados de código en el mismo Excel
      final Map<String, Map<String, dynamic>> uniqueMap = {};
      for (var row in _allData) {
        final codigo = row['codigoUniversitario']?.toString().trim() ?? '';
        if (codigo.isNotEmpty) uniqueMap.putIfAbsent(codigo, () => row);
      }
      _allData = uniqueMap.values.toList();

      _totalRows   = _allData.length;
      _previewData = _allData.take(5).toList();

      if (_totalRows == 0) {
        _showMessage('No se encontraron registros con "Código estudiante"');
      } else {
        _showMessage('✅ $_totalRows registros encontrados');
      }
    } catch (e) {
      _showMessage('Error al leer el archivo Excel: $e');
      debugPrint('Error detallado: $e');
    }
  }

  bool _validateHeaders(List<String?> headers) {
    if (!headers.contains('Código estudiante')) {
      _showMessage('El archivo debe tener la columna "Código estudiante"');
      return false;
    }
    return true;
  }

  // ── Confirmar e importar ───────────────────────────────────────────
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
              child: Text('Confirmar Importación de Pagos',
                  style: TextStyle(
                      color: Color(0xFF1E3A5F),
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ],
        ),
        content: Column(
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
              '¿Marcar $_totalRows estudiantes como pagados?',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A5F)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se buscará por código universitario y se actualizará '
                      'el campo de pago en el evento seleccionado.',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

    setState(() {
      _isLoading       = true;
      _successCount    = 0;
      _notFoundCount   = 0;
      _currentProgress = 0;
      _notFoundList    = [];
    });

    await _procesarPagos();
    setState(() => _isLoading = false);
    _showResultsDialog();
  }

  // ── Procesar pagos ─────────────────────────────────────────────────
  Future<void> _procesarPagos() async {
    final carreraPath = _carreraPath;
    final eventoId    = _selectedEventoId!;

    debugPrint('💳 Importando pagos → carrera: "$carreraPath" | evento: "$eventoId"');

    for (int i = 0; i < _allData.length; i++) {
      final row    = _allData[i];
      final codigo = (row['codigoUniversitario'] ?? '').toString().trim();

      if (codigo.isEmpty) {
        _notFoundCount++;
        _notFoundList.add('Fila ${i + 2}: sin código universitario');
        setState(() => _currentProgress++);
        continue;
      }

      try {
        // Buscar estudiante por codigoUniversitario (texto plano)
        final query = await _firestore
            .collection('users')
            .doc(carreraPath)
            .collection('students')
            .where('codigoUniversitario', isEqualTo: codigo)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final studentRef = query.docs.first.reference;
          // Actualizar campo pagos.{eventoId} = true
          await studentRef.update({'pagos.$eventoId': true});
          _successCount++;
          debugPrint('  ✅ Código $codigo → pago marcado');
        } else {
          _notFoundCount++;
          final nombre = row['name'] ?? codigo;
          _notFoundList.add('$nombre ($codigo) — no encontrado');
          debugPrint('  ⚠️ Código $codigo → no encontrado en "$carreraPath"');
        }
      } catch (e) {
        _notFoundCount++;
        _notFoundList.add('$codigo — error: $e');
        debugPrint('  ❌ Error con código $codigo: $e');
      }

      setState(() => _currentProgress++);
    }

    debugPrint('✅ Pagos procesados: $_successCount exitosos, $_notFoundCount no encontrados');
  }

  // ── Diálogo de resultados ──────────────────────────────────────────
  void _showResultsDialog() {
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
              child: Text('Resultados de Pagos',
                  style: TextStyle(
                      color: Color(0xFF1E3A5F),
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SingleChildScrollView(
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
              _buildResultCard('No encontrados', '$_notFoundCount',
                  Icons.person_search, Colors.orange.shade600, Colors.orange.shade50),
              if (_notFoundList.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Estudiantes no encontrados:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                        fontSize: 13)),
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
                    itemCount: _notFoundList.take(20).length,
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
                            child: Text(_notFoundList[index],
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF64748B))),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_notFoundList.length > 20)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('... y ${_notFoundList.length - 20} más',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontStyle: FontStyle.italic)),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
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

  // ── Widgets helpers ────────────────────────────────────────────────
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
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1E3A5F),
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
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
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: iconColor, fontSize: 18)),
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
              Icon(icon,
                  color: enabled ? const Color(0xFF1E3A5F) : Colors.grey.shade400,
                  size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    const SizedBox(height: 2),
                    Text(
                      value ?? 'Seleccionar',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected && enabled
                              ? const Color(0xFF1E3A5F)
                              : enabled ? Colors.grey : Colors.grey.shade400),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_drop_down,
                  color: enabled ? const Color(0xFF1E3A5F) : Colors.grey.shade400,
                  size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                        Text('Importar Pagos',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        Text('Marcar estudiantes pagados por evento',
                            style: TextStyle(fontSize: 12, color: Colors.white70)),
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

            // Body
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
                        child: CircularProgressIndicator(color: Color(0xFF1E3A5F)))
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

  // ── Loading view ───────────────────────────────────────────────────
  Widget _buildLoadingView() {
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
                    offset: const Offset(0, 10))
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A5F)),
            ),
          ),
          const SizedBox(height: 32),
          const Text('Procesando pagos...',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F))),
          const SizedBox(height: 8),
          Text('$_currentProgress / $_totalRows registros',
              style: const TextStyle(fontSize: 16, color: Color(0xFF64748B))),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
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
                      color: Color(0xFF1E3A5F)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(16),
            decoration:
                BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCol('$_successCount', 'Marcados',
                    Icons.check_circle, Colors.green),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                _statCol('$_notFoundCount', 'No encontrados',
                    Icons.person_search, Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      ],
    );
  }

  // ── Contenido principal ────────────────────────────────────────────
  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── Card de filtros ────────────────────────────────────────
          _buildFiltrosCard(),
          const SizedBox(height: 16),

          // ── Card principal de carga ────────────────────────────────
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
                    child: Icon(Icons.payments,
                        size: 40,
                        color: _todoListo
                            ? Colors.green.shade700
                            : Colors.grey.shade400),
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
                            : Colors.orange.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureRow(Icons.search, 'Busca por código universitario'),
                  const SizedBox(height: 6),
                  _buildFeatureRow(Icons.update, 'Actualiza campo de pago en el evento'),
                  const SizedBox(height: 6),
                  _buildFeatureRow(Icons.warning_amber, 'Reporta códigos no encontrados'),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _todoListo ? _pickExcelFile : null,
                    icon: const Icon(Icons.file_open),
                    label: const Text('Seleccionar Archivo Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                                const Text('Archivo seleccionado',
                                    style: TextStyle(
                                        fontSize: 11, color: Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Text(_fileName!,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E3A5F),
                                        fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
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

          // ── Vista previa ───────────────────────────────────────────
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
                        style: TextStyle(color: Color(0xFF1E3A5F), fontSize: 14),
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

  // ── Card de filtros ────────────────────────────────────────────────
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
                const Text('Destino del pago',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F))),
                const Spacer(),
                if (_todoListo)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
                        const SizedBox(width: 4),
                        Text('Listo',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Sede
            _filterBtn(
              label: 'Sede',
              value: _selectedFilialNombre,
              icon: Icons.location_city,
              onTap: _estructuraCargada ? _showFilialSelector : null,
              enabled: _estructuraCargada,
            ),
            const SizedBox(height: 10),

            // Facultad
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

            // Carrera
            _filterBtn(
              label: 'Carrera',
              value: _selectedCarrera,
              icon: Icons.school,
              onTap: _selectedFacultad != null ? _showCarreraSelector : null,
              enabled: _selectedFacultad != null,
            ),
            const SizedBox(height: 10),

            // Evento
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
                        const Text('Cargando eventos...',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
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

            // Aviso sin eventos
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
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'No hay eventos para esta carrera. El admin de carrera debe crear uno primero.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1E3A5F)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Path resumen
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
                    Icon(Icons.folder_open, size: 16, color: Colors.green.shade700),
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

  // ── Vista previa ───────────────────────────────────────────────────
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
                  child: Text('Vista Previa',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$_totalRows estudiantes',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ],
            ),

            // Banner destino + evento
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
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
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
                final codigo = student['codigoUniversitario'] ?? '—';
                final nombre = student['name'] ?? 'Sin nombre';
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
                        child: Text('${index + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                      ),
                    ),
                    title: Text(nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                            fontSize: 14)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.badge, size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('Código: $codigo',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Y ${_totalRows - 5} más...',
                    style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontStyle: FontStyle.italic,
                        fontSize: 12),
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
                label: const Text('Marcar como Pagados',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
          Text(text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

// ── Helper para items del bottom sheet ─────────────────────────────────
class _SheetItem {
  final String  value;
  final String  label;
  final String  subtitle;
  final bool    isSelected;
  final String? extra; // para carreraId

  const _SheetItem({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    this.extra,
  });
}