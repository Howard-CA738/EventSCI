import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:io';
import '/password_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import '/encryption_helper.dart';
import '/shared/logica/filiales_service.dart';

class DatosExcelScreen extends StatefulWidget {
  const DatosExcelScreen({super.key});

  @override
  State<DatosExcelScreen> createState() => _DatosExcelScreenState();
}

class _DatosExcelScreenState extends State<DatosExcelScreen>
    with SingleTickerProviderStateMixin {


  bool _isAdminCarrera = false;


  String? _adminCarreraFilial;
  String? _adminCarreraFacultad;
  String? _adminCarreraCarrera;


  final FilialesService _filialesService = FilialesService();
  Map<String, dynamic> _estructuraFiliales = {};
  bool _estructuraCargada = false;

  String? _selectedFilialId;
  String? _selectedFilialNombre;
  String? _selectedFacultad;
  String? _selectedCarrera;


  bool get _destinoListo {
    if (_isAdminCarrera) return true;
    return _selectedFilialNombre != null &&
        _selectedFacultad != null &&
        _selectedCarrera != null;
  }


  String get _filialEfectiva =>
      _isAdminCarrera ? _adminCarreraFilial! : _selectedFilialNombre!;
  String get _facultadEfectiva =>
      _isAdminCarrera ? _adminCarreraFacultad! : _selectedFacultad!;
  String get _carreraEfectiva =>
      _isAdminCarrera ? _adminCarreraCarrera! : _selectedCarrera!;
  String get _carreraPathEfectiva => '${_filialEfectiva}_$_carreraEfectiva';


  bool _isLoading = false;
  bool _fileSelected = false;
  String? _fileName;
  List<Map<String, dynamic>> _previewData = [];
  List<Map<String, dynamic>> _allData = [];
  int _totalRows = 0;
  int _successCount = 0;
  int _errorCount = 0;
  int _currentProgress = 0;
  List<String> _errors = [];
  int _duplicatesDetected = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int BATCH_SIZE = 500;


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
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
    _initSession();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }


  Future<void> _initSession() async {
    final isAdminCarrera = await PrefsHelper.isAdminCarrera();
    if (isAdminCarrera) {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData != null) {
        setState(() {
          _isAdminCarrera       = true;
          _adminCarreraFilial   = adminData['filialNombre'];
          _adminCarreraFacultad = adminData['facultad'];
          _adminCarreraCarrera  = adminData['carrera'];
        });
        debugPrint('✅ Admin carrera detectado. Filial: $_adminCarreraFilial');
      }
    } else {

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


  void _onFilialChanged(String? filialId) {
    setState(() {
      _selectedFilialId     = filialId;
      _selectedFilialNombre = filialId != null ? _getNombreFilial(filialId) : null;
      _selectedFacultad     = null;
      _selectedCarrera      = null;

      _fileSelected  = false;
      _fileName      = null;
      _allData       = [];
      _previewData   = [];
      _totalRows     = 0;
    });
  }

  void _onFacultadChanged(String? facultad) {
    setState(() {
      _selectedFacultad = facultad;
      _selectedCarrera  = null;
      _fileSelected     = false;
      _fileName         = null;
      _allData          = [];
      _previewData      = [];
      _totalRows        = 0;
    });
  }

  void _onCarreraChanged(String? carrera) {
    setState(() {
      _selectedCarrera = carrera;
      _fileSelected    = false;
      _fileName        = null;
      _allData         = [];
      _previewData     = [];
      _totalRows       = 0;
    });
  }


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
      onSelected: (v) { _onFilialChanged(v); Navigator.pop(context); },
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
      onSelected: (v) { _onFacultadChanged(v); Navigator.pop(context); },
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
      )).toList(),
      onSelected: (v) { _onCarreraChanged(v); Navigator.pop(context); },
    );
  }

  void _showSelectorSheet({
    required String title,
    required IconData icon,
    required List<_SheetItem> items,
    required ValueChanged<String> onSelected,
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
                  child: ListView.builder(
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
                                          ? const Color(0xFF1E3A5F)
                                              .withValues(alpha: 0.7)
                                          : Colors.grey))
                              : null,
                          trailing: item.isSelected
                              ? const Icon(Icons.check_circle,
                                  color: Color(0xFF1E3A5F))
                              : const Icon(Icons.arrow_forward_ios,
                                  size: 14, color: Colors.grey),
                          onTap: () => onSelected(item.value),
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


  String _normalizeStudentName(String name) {
    String normalized = name.trim().toLowerCase();
    const accents = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n', 'ç': 'c',
    };
    accents.forEach((a, r) => normalized = normalized.replaceAll(a, r));
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    return normalized;
  }

  // Dedupe dentro del mismo Excel por nombre normalizado Y por
  // dni/codigoUniversitario/email/username, para que filas del mismo
  // estudiante con el nombre escrito distinto no generen duplicados.
  List<Map<String, dynamic>> _removeDuplicateStudents(
      List<Map<String, dynamic>> allData) {
    final List<Map<String, dynamic>> unique = [];
    final Set<String> seenNames = {};
    final Set<String> seenDni = {};
    final Set<String> seenCodigo = {};
    final Set<String> seenEmail = {};
    final Set<String> seenUsername = {};

    for (var s in allData) {
      final name = _getFieldValue(s, 'name', '');
      if (name.isEmpty) continue;

      final nameKey  = _normalizeStudentName(name);
      final dni      = _getFieldValue(s, 'dni', '').toLowerCase();
      final codigo   =
          _getFieldValue(s, 'codigoUniversitario', '').toLowerCase();
      final email    = _getFieldValue(s, 'email', '').toLowerCase();
      final username = _getFieldValue(s, 'username', '').toLowerCase();

      final isDuplicate = seenNames.contains(nameKey) ||
          (dni.isNotEmpty && seenDni.contains(dni)) ||
          (codigo.isNotEmpty && seenCodigo.contains(codigo)) ||
          (email.isNotEmpty && seenEmail.contains(email)) ||
          (username.isNotEmpty && seenUsername.contains(username));

      if (isDuplicate) continue;

      seenNames.add(nameKey);
      if (dni.isNotEmpty) seenDni.add(dni);
      if (codigo.isNotEmpty) seenCodigo.add(codigo);
      if (email.isNotEmpty) seenEmail.add(email);
      if (username.isNotEmpty) seenUsername.add(username);

      unique.add(s);
    }
    return unique;
  }


  Future<void> _pickExcelFile() async {
    if (!_destinoListo) {
      _showMessage('⚠️ Completa la selección de carrera destino primero');
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result != null) {
        setState(() {
          _isLoading          = true;
          _fileName           = result.files.single.name;
          _errors.clear();
          _successCount       = 0;
          _errorCount         = 0;
          _currentProgress    = 0;
          _duplicatesDetected = 0;
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
                  if (fieldName == 'filial' && rowData.containsKey('filial')) {
                    continue;
                  }
                  rowData[fieldName] = value;
                }
              }
            }
          }
        }

        if (hasAnyData &&
            (rowData.containsKey('name') || rowData.containsKey('dni'))) {
          _allData.add(rowData);
        }
      }

      _totalRows   = _allData.length;
      _previewData = _allData.take(5).toList();

      if (_totalRows == 0) {
        _showMessage('No se encontraron datos válidos en el archivo');
      } else {
        _showMessage('✅ $_totalRows registros encontrados');
      }
    } catch (e) {
      _showMessage('Error al leer el archivo Excel: $e');
      debugPrint('Error detallado: $e');
    }
  }

  bool _validateHeaders(List<String?> headers) {
    final required = ['Estudiante', 'Documento'];
    if (!required.any((col) => headers.contains(col))) {
      _showMessage(
          'El archivo debe tener al menos "Estudiante" o "Documento"');
      return false;
    }
    return true;
  }


  Future<void> _importData() async {
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
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.rocket_launch,
                  color: Color(0xFF1E3A5F)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Confirmar Importación',
                  style: TextStyle(
                      color: Color(0xFF1E3A5F),
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF1E3A5F).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Destino de importación:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  _miniInfoRow(Icons.location_city, _filialEfectiva),
                  const SizedBox(height: 4),
                  _miniInfoRow(Icons.business,
                      _facultadEfectiva.replaceFirst('Facultad de ', '')),
                  const SizedBox(height: 4),
                  _miniInfoRow(Icons.school, _carreraEfectiva),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '¿Importar $_totalRows registros a esta carrera?',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A5F)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Color(0xFF1E3A5F), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Los duplicados dentro del Excel se omitirán '
                      'automáticamente.',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFF1E3A5F)),
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
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B)),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Importar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading          = true;
      _successCount       = 0;
      _errorCount         = 0;
      _currentProgress    = 0;
      _duplicatesDetected = 0;
      _errors.clear();
    });

    await _processBatchImport();
    setState(() => _isLoading = false);
    _showResultsDialog();
  }




  Future<void> _processBatchImport() async {
    final docKey = _carreraPathEfectiva;
    debugPrint('📦 Importando todo a: "$docKey"');

    final uniqueList = _removeDuplicateStudents(_allData);
    _duplicatesDetected = _allData.length - uniqueList.length;

    debugPrint('   Registros en Excel : ${_allData.length}');
    debugPrint('   Únicos             : ${uniqueList.length}');
    if (_duplicatesDetected > 0) {
      debugPrint('   Duplicados omitidos: $_duplicatesDetected');
    }

    final existingUsers = await _getExistingUsersInCarrera(docKey);
    final List<Map<String, dynamic>> validStudents = [];

    for (int i = 0; i < uniqueList.length; i++) {
      final prepared    = _prepareStudentData(uniqueList[i], i);
      final isDuplicate = _checkDuplicate(prepared, existingUsers);

      if (isDuplicate) {
        _errorCount++;
        _errors.add(
          '${prepared['name']} - ya existe en "$docKey"',
        );
      } else {
        validStudents.add(prepared);
      }

      setState(() => _currentProgress++);
    }


    setState(() => _currentProgress += _duplicatesDetected);

    await _batchWriteToFirestore(docKey, validStudents);

    if (_duplicatesDetected > 0) {
      _showMessage(
          '✅ $_duplicatesDetected duplicados del Excel omitidos');
    }
  }


  Future<Set<Map<String, String>>> _getExistingUsersInCarrera(
      String docKey) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(docKey)
          .collection('students')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'dni'     : (data['dni']                 ?? '').toString().toLowerCase(),
          'email'   : (data['email']               ?? '').toString().toLowerCase(),
          'codigo'  : (data['codigoUniversitario'] ?? '').toString().toLowerCase(),
          'username': (data['username']            ?? '').toString().toLowerCase(),
        };
      }).toSet();
    } catch (e) {
      debugPrint('❌ Error obteniendo existentes en "$docKey": $e');
      return {};
    }
  }

  bool _checkDuplicate(
    Map<String, dynamic> studentData,
    Set<Map<String, String>> existing,
  ) {
    final dni      = studentData['dni'].toString().toLowerCase();
    final email    = studentData['email'].toString().toLowerCase();
    final codigo   = studentData['codigoUniversitario'].toString().toLowerCase();
    final username = studentData['username'].toString().toLowerCase();

    return existing.any((e) =>
        e['dni']      == dni      ||
        e['email']    == email    ||
        e['codigo']   == codigo   ||
        e['username'] == username);
  }




  Map<String, dynamic> _prepareStudentData(
      Map<String, dynamic> rawData, int index) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final name = _getFieldValue(rawData, 'name', 'Estudiante ${index + 1}');
    final dniPlano =
        _getFieldValue(rawData, 'dni', 'DNI${timestamp % 100000000}');
    final dniHash      = PasswordHelper.hashPassword(dniPlano);
    final dniEncrypted = EncryptionHelper.encryptDni(dniPlano);

    String username = _getFieldValue(rawData, 'username', '');
    if (username.isEmpty) username = _generateUsernameFromName(name);

    final codigoUniversitario = _getFieldValue(
        rawData, 'codigoUniversitario', 'COD${timestamp % 1000000}');

    return {
      'name'                : name,
      'username'            : username.toLowerCase(),
      'codigoUniversitario' : codigoUniversitario,
      'dni'                 : dniHash,
      'documento'           : dniHash,
      'dniEncrypted'        : dniEncrypted,

      'filial'              : _filialEfectiva,
      'facultad'            : _facultadEfectiva,
      'carrera'             : _carreraEfectiva,
      'ciclo'               : _getFieldValue(rawData, 'ciclo',   null),
      'grupo'               : _getFieldValue(rawData, 'grupo',   null),
      'celular'             : _getFieldValue(rawData, 'celular', null),
      'email'               : _getFieldValue(rawData, 'email',   ''),
      'userType'            : 'student',
      'createdAt'           : FieldValue.serverTimestamp(),
    };
  }


  Future<void> _batchWriteToFirestore(
      String docKey, List<Map<String, dynamic>> students) async {
    try {
      final carreraDocRef = _firestore.collection('users').doc(docKey);


      await carreraDocRef.set({
        'name'      : docKey,
        'filial'    : _filialEfectiva,
        'facultad'  : _facultadEfectiva,
        'carrera'   : _carreraEfectiva,
        'updatedAt' : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('📁 Doc padre actualizado: "$docKey"');

      for (int i = 0; i < students.length; i += BATCH_SIZE) {
        final batch = _firestore.batch();
        final end   = (i + BATCH_SIZE < students.length)
            ? i + BATCH_SIZE
            : students.length;

        final List<Map<String, String>> indexQueue = [];

        for (int j = i; j < end; j++) {
          final docRef = carreraDocRef.collection('students').doc();
          batch.set(docRef, students[j]);
          final username = students[j]['username'] as String?;
          if (username != null && username.isNotEmpty) {
            indexQueue.add({
              'username' : username,
              'studentId': docRef.id,
            });
          }
        }

        await batch.commit();
        _successCount += (end - i);
        setState(() {});


        final indexBatch = _firestore.batch();
        for (final item in indexQueue) {
          final entryRef = _firestore
              .collection('student_index')
              .doc(item['username'])
              .collection('entries')
              .doc();
          indexBatch.set(entryRef, {
            'username'   : item['username'],
            'carreraPath': docKey,
            'studentId'  : item['studentId'],
            'createdAt'  : FieldValue.serverTimestamp(),
          });
        }
        await indexBatch.commit();
        debugPrint(
            '✅ ${indexQueue.length} índices creados en batch para "$docKey"');
      }

      debugPrint('✅ ${students.length} estudiantes importados a "$docKey"');
    } catch (e) {
      debugPrint('❌ Error en batch write: $e');
      _showMessage('Error durante la importación: $e');
    }
  }


  String _getFieldValue(
      Map<String, dynamic> data, String field, String? defaultValue) {
    final value = data[field];
    if (value == null || value.toString().trim().isEmpty) {
      return defaultValue ?? '';
    }
    return value.toString().trim();
  }

  String _generateUsernameFromName(String fullName) {
    if (fullName.isEmpty || fullName == 'Sin nombre') {
      return 'usuario${DateTime.now().millisecondsSinceEpoch % 10000}';
    }
    final parts = fullName
        .toLowerCase()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) return '${parts[0]}.${parts[parts.length - 1]}';
    return parts.isNotEmpty ? parts[0] : 'usuario';
  }


  void _showResultsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _errorCount == 0
                    ? Colors.green.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _errorCount == 0
                    ? Icons.check_circle
                    : Icons.assessment,
                color: _errorCount == 0
                    ? Colors.green.shade600
                    : Colors.blue.shade600,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Resultados de Importación',
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

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color:
                          const Color(0xFF1E3A5F).withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Importado a:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    _miniInfoRow(Icons.location_city, _filialEfectiva),
                    const SizedBox(height: 4),
                    _miniInfoRow(Icons.school, _carreraEfectiva),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildResultCard('Total en Excel', '$_totalRows',
                  Icons.list_alt, Colors.blue.shade600, Colors.blue.shade50),
              if (_duplicatesDetected > 0) ...[
                const SizedBox(height: 10),
                _buildResultCard('Duplicados en Excel', '$_duplicatesDetected',
                    Icons.delete_outline, Colors.red.shade600, Colors.red.shade50),
              ],
              const SizedBox(height: 10),
              _buildResultCard(
                  'Creados exitosamente',
                  '$_successCount',
                  Icons.person_add,
                  Colors.green.shade600,
                  Colors.green.shade50),
              const SizedBox(height: 10),
              _buildResultCard(
                  'Ya existentes (omitidos)',
                  '$_errorCount',
                  Icons.info_outline,
                  Colors.orange.shade600,
                  Colors.orange.shade50),
              if (_errors.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Detalle de omitidos:',
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
                    itemCount: _errors.take(20).length,
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
                            child: Text(_errors[index],
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B))),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_errors.length > 20)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('... y ${_errors.length - 20} más',
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Cerrar'),
          ),
        ],
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
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF64748B)))),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                  fontSize: 18)),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF1E3A5F),
      ));
    }
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
                    child: const Icon(Icons.upload_file,
                        color: Color(0xFF1E3A5F), size: 30),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text('Importar desde Excel',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 28),
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
                child: _isLoading && !_estructuraCargada && !_isAdminCarrera
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF1E3A5F)))
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
              valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFF1E3A5F)),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _currentProgress < _totalRows
                ? 'Detectando duplicados...'
                : 'Guardando en base de datos...',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F)),
          ),
          const SizedBox(height: 8),
          Text('$_currentProgress / $_totalRows registros',
              style: const TextStyle(
                  fontSize: 16, color: Color(0xFF64748B))),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _totalRows > 0
                        ? _currentProgress / _totalRows
                        : 0,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF1E3A5F)),
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
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCol('$_successCount', 'Creados',
                    Icons.check_circle, Colors.green),
                Container(
                    width: 1, height: 40, color: Colors.grey.shade300),
                _statCol('$_duplicatesDetected', 'Omitidos',
                    Icons.delete_outline, Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(
      String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16)),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF64748B))),
      ],
    );
  }


  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [


          if (!_isAdminCarrera) ...[
            _buildDestinoCard(),
            const SizedBox(height: 16),
          ],


          Card(
            elevation: 4,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: _destinoListo
                          ? const Color(0xFF1E3A5F).withValues(alpha: 0.1)
                          : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.upload_file,
                        size: 40,
                        color: _destinoListo
                            ? const Color(0xFF1E3A5F)
                            : Colors.grey.shade400),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Importar Estudiantes desde Excel',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E3A5F),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _destinoListo
                        ? 'Selecciona un archivo .xlsx o .xls'
                        : 'Primero selecciona la sede, facultad y carrera de destino',
                    style: TextStyle(
                        fontSize: 13,
                        color: _destinoListo
                            ? const Color(0xFF64748B)
                            : Colors.orange.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureRow(
                      Icons.check_circle_outline, 'Acepta celdas vacías'),
                  const SizedBox(height: 6),
                  _buildFeatureRow(Icons.bolt, 'Importación ultra rápida'),
                  const SizedBox(height: 6),
                  _buildFeatureRow(
                      Icons.delete_sweep, 'Elimina duplicados automáticamente'),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _destinoListo ? _pickExcelFile : null,
                    icon: const Icon(Icons.file_open),
                    label: const Text('Seleccionar Archivo Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
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
                        border: Border.all(
                            color: Colors.green.shade300, width: 2),
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
                                        fontSize: 11,
                                        color: Color(0xFF64748B))),
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
                        'No se encontraron datos válidos. Verifica que el '
                        'archivo tenga al menos "Estudiante" o "Documento".',
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


  Widget _buildDestinoCard() {
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
                    color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on,
                      color: Color(0xFF1E3A5F), size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Carrera destino',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F))),
                const Spacer(),
                if (_destinoListo)
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


            _filterBtn(
              label:   'Sede',
              value:   _selectedFilialNombre,
              icon:    Icons.location_city,
              onTap:   _estructuraCargada ? _showFilialSelector : null,
              enabled: _estructuraCargada,
            ),
            const SizedBox(height: 10),


            _filterBtn(
              label:   'Facultad',
              value:   _selectedFacultad != null
                  ? _selectedFacultad!.replaceFirst('Facultad de ', '')
                  : null,
              icon:    Icons.business,
              onTap:   _selectedFilialId != null ? _showFacultadSelector : null,
              enabled: _selectedFilialId != null,
            ),
            const SizedBox(height: 10),


            _filterBtn(
              label:   'Carrera',
              value:   _selectedCarrera,
              icon:    Icons.school,
              onTap:   _selectedFacultad != null ? _showCarreraSelector : null,
              enabled: _selectedFacultad != null,
            ),


            if (_destinoListo) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color:
                          const Color(0xFF1E3A5F).withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_open,
                        size: 16, color: Color(0xFF1E3A5F)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _carreraPathEfectiva,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1E3A5F),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                : enabled
                    ? Colors.white
                    : Colors.grey.shade50,
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: enabled
                      ? const Color(0xFF1E3A5F)
                      : Colors.grey.shade400,
                  size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500)),
                    const SizedBox(height: 2),
                    Text(
                      value ?? 'Seleccionar',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected && enabled
                              ? const Color(0xFF1E3A5F)
                              : enabled
                                  ? Colors.grey
                                  : Colors.grey.shade400),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_drop_down,
                  color: enabled
                      ? const Color(0xFF1E3A5F)
                      : Colors.grey.shade400,
                  size: 18),
            ],
          ),
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
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.preview,
                      color: Colors.blue.shade600, size: 22),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$_totalRows registros',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ],
            ),


            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color:
                        const Color(0xFF1E3A5F).withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_right_alt,
                      size: 18, color: Color(0xFF1E3A5F)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_filialEfectiva › $_carreraEfectiva',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E3A5F),
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
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
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
                    title: Text(
                      student['name'] ?? 'Sin nombre',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                          fontSize: 14),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (student['ciclo'] != null)
                            Text('Ciclo ${student['ciclo']}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600)),
                          Row(children: [
                            Icon(Icons.badge,
                                size: 13, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'DNI: ${student['dni'] ?? "Sin dato"}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600),
                            ),
                          ]),
                        ],
                      ),
                    ),
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
                    'Y ${_totalRows - 5} registros más...',
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
                onPressed: _importData,
                icon: const Icon(Icons.rocket_launch, size: 22),
                label: const Text('Importar eliminando duplicados',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF1E3A5F),
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
          Icon(icon, size: 18, color: const Color(0xFF1E3A5F)),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}


class _SheetItem {
  final String value;
  final String label;
  final String subtitle;
  final bool   isSelected;
  const _SheetItem({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.isSelected,
  });
}