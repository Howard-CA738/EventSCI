import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';

class StudentGroup {
  final String normalizedName;
  final List<Map<String, dynamic>> records;
  Map<String, dynamic> mergedData;

  StudentGroup({
    required this.normalizedName,
    required this.records,
    required this.mergedData,
  });
}

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

  // ── Columnas del Excel ────────────────────────────────────────────────────
  // Se agrega 'Filial' / 'Sede' para que el super admin también lea la filial
  // desde el propio archivo. 'Sede' se mantiene como alias por compatibilidad
  // con archivos viejos, pero internamente todo se guarda como 'filial'.
  final Map<String, String> _columnMapping = {
    'Ciclo'             : 'ciclo',
    'Grupo'             : 'grupo',
    'Código estudiante' : 'codigoUniversitario',
    'Estudiante'        : 'name',
    'Documento'         : 'dni',
    'Correo'            : 'email',
    'Celular'           : 'celular',
    'Programa estudio'  : 'carrera',      // → carrera
    'Usuario'           : 'username',
    'Unidad académica'  : 'facultad',     // → facultad
    'Pago'              : 'pago',
    'Filial'            : 'filial',       // ← NUEVO: filial del estudiante
    'Sede'              : 'filial',       // ← alias para archivos anteriores
  };

  @override
  void initState() {
    super.initState();
    _checkIfAdminCarrera();

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ── Normalizar nombre para detección de duplicados ────────────────────────
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
    accents.forEach((accent, replacement) {
      normalized = normalized.replaceAll(accent, replacement);
    });
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    return normalized;
  }

  // ── Eliminar duplicados dentro del propio Excel ───────────────────────────
  Map<String, Map<String, dynamic>> _removeDuplicateStudents(
    List<Map<String, dynamic>> allData,
  ) {
    final Map<String, Map<String, dynamic>> uniqueStudents = {};
    for (var studentData in allData) {
      final fullName = _getFieldValue(studentData, 'name', '');
      if (fullName.isEmpty) continue;
      final normalizedName = _normalizeStudentName(fullName);
      uniqueStudents.putIfAbsent(normalizedName, () => studentData);
    }
    return uniqueStudents;
  }

  // ── Detectar si es admin de carrera ──────────────────────────────────────
  Future<void> _checkIfAdminCarrera() async {
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
        print('✅ Admin de carrera detectado en importación Excel');
        print('   Filial   : $_adminCarreraFilial');
        print('   Facultad : $_adminCarreraFacultad');
        print('   Carrera  : $_adminCarreraCarrera');
      }
    }
  }

  // ── Seleccionar archivo Excel ─────────────────────────────────────────────
  Future<void> _pickExcelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result != null) {
        setState(() {
          _isLoading = true;
          _fileName = result.files.single.name;
          _errors.clear();
          _successCount = 0;
          _errorCount = 0;
          _currentProgress = 0;
          _duplicatesDetected = 0;
        });
        final file = File(result.files.single.path!);
        await _readExcelFile(file);
        setState(() {
          _fileSelected = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('Error al seleccionar archivo: $e');
    }
  }

  // ── Leer Excel y mapear columnas ──────────────────────────────────────────
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
        final row    = table.rows[i];
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
                  // Para 'filial' solo guarda si aún no hay valor
                  // (evita que 'Sede' sobreescriba 'Filial' si ambas existen)
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
        _showMessage('✅ Se encontraron $_totalRows registros para importar');
      }
    } catch (e) {
      _showMessage('Error al leer el archivo Excel: $e');
      print('Error detallado: $e');
    }
  }

  bool _validateHeaders(List<String?> headers) {
    final requiredColumns = ['Estudiante', 'Documento'];
    final hasAtLeastOne = requiredColumns.any((col) => headers.contains(col));
    if (!hasAtLeastOne) {
      _showMessage(
        'El archivo debe tener al menos la columna "Estudiante" o "Documento"',
      );
      return false;
    }
    return true;
  }

  // ── Confirmar e iniciar importación ──────────────────────────────────────
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
                color: const Color(0xFF1E3A5F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.rocket_launch, color: Color(0xFF1E3A5F)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Confirmar Importación',
                style: TextStyle(
                  color: Color(0xFF1E3A5F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Deseas importar $_totalRows registros?',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF1E3A5F), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se eliminarán automáticamente los registros duplicados '
                      '(solo se importará el primero de cada estudiante)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E3A5F)),
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
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  // ── Proceso principal de importación ─────────────────────────────────────
  // Clave del documento en Firestore: "filial_carrera"
  // · Admin de carrera → usa SU filial y carrera (ignora Excel)
  // · Super admin      → lee filial y carrera del Excel por cada fila
  Future<void> _processBatchImport() async {
    // key = "filial_carrera"
    final Map<String, List<Map<String, dynamic>>> studentsByKey = {};

    if (_isAdminCarrera) {
      final key = '${_adminCarreraFilial}_$_adminCarreraCarrera';
      print('🔒 Modo admin de carrera: Importando todo a "$key"');
      studentsByKey[key] = List.from(_allData);
    } else {
      // Super admin: agrupar por filial + carrera leídos del Excel
      for (var studentData in _allData) {
        final filial  = _getFieldValue(studentData, 'filial',  'Sin filial');
        final carrera = _getFieldValue(studentData, 'carrera', 'Sin asignar');
        final key     = '${filial}_$carrera';
        studentsByKey.putIfAbsent(key, () => []).add(studentData);
      }
    }

    int totalProcessed = 0;

    for (final entry in studentsByKey.entries) {
      final docKey   = entry.key;
      final students = entry.value;

      print('📚 Procesando: "$docKey"');
      print('   Total registros en Excel: ${students.length}');

      final uniqueMap   = _removeDuplicateStudents(students);
      final uniqueList  = uniqueMap.values.toList();
      final dupsInGroup = students.length - uniqueList.length;
      _duplicatesDetected += dupsInGroup;

      print('   Estudiantes únicos: ${uniqueList.length}');
      if (dupsInGroup > 0) print('   🗑️ Duplicados en Excel: $dupsInGroup');

      final existingUsers = await _getExistingUsersInCarrera(docKey);
      final List<Map<String, dynamic>> validStudents = [];

      for (int i = 0; i < uniqueList.length; i++) {
        final prepared    = _prepareStudentData(uniqueList[i], totalProcessed);
        final isDuplicate = _checkDuplicate(prepared, existingUsers);

        if (isDuplicate) {
          _errorCount++;
          _errors.add(
            'Estudiante ${prepared['name']} - '
            'Ya existe en "$docKey" (DNI: ${prepared['dni']})',
          );
        } else {
          validStudents.add(prepared);
        }

        setState(() => _currentProgress++);
        totalProcessed++;
      }

      setState(() => _currentProgress += dupsInGroup);
      await _batchWriteToFirestore(docKey, validStudents);
    }

    if (_duplicatesDetected > 0) {
      _showMessage(
        '✅ Se eliminaron $_duplicatesDetected registros duplicados del Excel',
      );
    }
  }

  // ── Obtener usuarios existentes en Firestore ──────────────────────────────
  Future<Set<Map<String, String>>> _getExistingUsersInCarrera(
    String docKey,
  ) async {
    try {
      print('🔎 Buscando usuarios existentes en: "$docKey"');
      final snapshot = await _firestore
          .collection('users')
          .doc(docKey)
          .collection('students')
          .get();
      print('   📊 Encontrados ${snapshot.docs.length} en Firestore');

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'dni'     : (data['dni']                  ?? '').toString().toLowerCase(),
          'email'   : (data['email']                ?? '').toString().toLowerCase(),
          'codigo'  : (data['codigoUniversitario']  ?? '').toString().toLowerCase(),
          'username': (data['username']             ?? '').toString().toLowerCase(),
        };
      }).toSet();
    } catch (e) {
      print('❌ Error obteniendo existentes en "$docKey": $e');
      return {};
    }
  }

  bool _checkDuplicate(
    Map<String, dynamic> studentData,
    Set<Map<String, String>> existingUsers,
  ) {
    final dni      = studentData['dni'].toString().toLowerCase();
    final email    = studentData['email'].toString().toLowerCase();
    final codigo   = studentData['codigoUniversitario'].toString().toLowerCase();
    final username = studentData['username'].toString().toLowerCase();

    return existingUsers.any((e) =>
        e['dni']      == dni      ||
        e['email']    == email    ||
        e['codigo']   == codigo   ||
        e['username'] == username);
  }

  // ── Preparar datos del estudiante ─────────────────────────────────────────
  // Se elimina por completo el campo 'sede'. Todo usa 'filial'.
  // La clave del documento padre se construye como "filial_carrera".
  Map<String, dynamic> _prepareStudentData(
    Map<String, dynamic> rawData,
    int index,
  ) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final name  = _getFieldValue(rawData, 'name', 'Estudiante ${index + 1}');
    final dni   = _getFieldValue(rawData, 'dni', 'DNI${timestamp % 100000000}');

    String username = _getFieldValue(rawData, 'username', '');
    if (username.isEmpty) username = _generateUsernameFromName(name);

    final codigoUniversitario = _getFieldValue(
      rawData, 'codigoUniversitario', 'COD${timestamp % 1000000}',
    );

    // ── Filial / Facultad / Carrera ───────────────────────────────────────
    // Admin de carrera → SIEMPRE usa los datos de su sesión.
    // Super admin      → Lee del Excel; si falta algún campo, usa fallback.
    final String filial;
    final String facultad;
    final String carrera;

    if (_isAdminCarrera) {
      filial   = _adminCarreraFilial!;
      facultad = _adminCarreraFacultad!;
      carrera  = _adminCarreraCarrera!;
      print('🔒 Forzando: filial=$filial | facultad=$facultad | carrera=$carrera');
    } else {
      filial   = _getFieldValue(rawData, 'filial',   'Sin filial');
      facultad = _getFieldValue(rawData, 'facultad', 'Sin asignar');
      carrera  = _getFieldValue(rawData, 'carrera',  'Sin asignar');
    }

    // ── Documento final (sin 'sede', sin duplicados de filial) ───────────
    return {
      'name'                : name,
      'username'            : username.toLowerCase(),
      'codigoUniversitario' : codigoUniversitario,
      'dni'                 : dni,
      'documento'           : dni,          // alias para compatibilidad
      'filial'              : filial,       // ← único campo de sede/filial
      'facultad'            : facultad,
      'carrera'             : carrera,
      'ciclo'               : _getFieldValue(rawData, 'ciclo',   null),
      'grupo'               : _getFieldValue(rawData, 'grupo',   null),
      'celular'             : _getFieldValue(rawData, 'celular', null),
      'email'               : _getFieldValue(rawData, 'email',   ''),
      'pago'                : _getFieldValue(rawData, 'pago',    null),
      'userType'            : 'student',
      'createdAt'           : FieldValue.serverTimestamp(),
    };
  }

  // ── Escribir en Firestore bajo users/{filial_carrera}/students/ ───────────
  // El documento padre guarda filial, facultad y carrera para que
  // EstudianteScreen pueda leerlos aunque el doc del estudiante no los tenga.
  Future<void> _batchWriteToFirestore(
    String docKey,
    List<Map<String, dynamic>> students,
  ) async {
    try {
      final carreraDocRef = _firestore.collection('users').doc(docKey);

      // Determinar filial/facultad/carrera para el doc padre
      String filialParaPadre;
      String facultadParaPadre;
      String carreraParaPadre;

      if (_isAdminCarrera) {
        filialParaPadre   = _adminCarreraFilial!;
        facultadParaPadre = _adminCarreraFacultad!;
        carreraParaPadre  = _adminCarreraCarrera!;
      } else {
        // Derivar del docKey: "filial_carrera"
        final parts = docKey.split('_');
        filialParaPadre   = parts.first;
        carreraParaPadre  = parts.length > 1 ? parts.skip(1).join('_') : docKey;
        // Facultad: tomar del primer estudiante válido
        facultadParaPadre = students.isNotEmpty
            ? (students.first['facultad'] ?? 'Sin asignar')
            : 'Sin asignar';
      }

      // Crear/actualizar doc padre con campos limpios y unificados
      await carreraDocRef.set({
        'name'      : docKey,
        'filial'    : filialParaPadre,
        'facultad'  : facultadParaPadre,
        'carrera'   : carreraParaPadre,
        'updatedAt' : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('📁 Doc padre actualizado: "$docKey"');

      // Escribir estudiantes en lotes
      for (int i = 0; i < students.length; i += BATCH_SIZE) {
        final batch = _firestore.batch();
        final end   = (i + BATCH_SIZE < students.length)
            ? i + BATCH_SIZE
            : students.length;

        for (int j = i; j < end; j++) {
          final docRef = carreraDocRef.collection('students').doc();
          batch.set(docRef, students[j]);
        }

        await batch.commit();
        _successCount += (end - i);
        setState(() {});
      }

      print('✅ Importados ${students.length} estudiantes en "$docKey"');
    } catch (e) {
      print('❌ Error en batch write para "$docKey": $e');
      _showMessage('Error durante la importación en "$docKey": $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _getFieldValue(
    Map<String, dynamic> data,
    String field,
    String? defaultValue,
  ) {
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
    final totalRegistros      = _totalRows;
    final usuariosCreados     = _successCount;
    final duplicadosOmitidos  = _errorCount;
    final registrosEliminados = _duplicatesDetected;

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
                color: _errorCount == 0
                    ? Colors.green.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _errorCount == 0 ? Icons.check_circle : Icons.assessment,
                color: _errorCount == 0
                    ? Colors.green.shade600
                    : Colors.blue.shade600,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Resultados de Importación',
                style: TextStyle(
                  color: Color(0xFF1E3A5F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultCard(
                'Total de registros en Excel',
                '$totalRegistros',
                Icons.list_alt,
                Colors.blue.shade600,
                Colors.blue.shade50,
              ),
              if (registrosEliminados > 0) ...[
                const SizedBox(height: 12),
                _buildResultCard(
                  'Duplicados eliminados del Excel',
                  '$registrosEliminados',
                  Icons.delete_outline,
                  Colors.red.shade600,
                  Colors.red.shade50,
                ),
              ],
              const SizedBox(height: 12),
              _buildResultCard(
                'Estudiantes únicos detectados',
                '${totalRegistros - registrosEliminados}',
                Icons.people_outline,
                Colors.purple.shade600,
                Colors.purple.shade50,
              ),
              const SizedBox(height: 12),
              _buildResultCard(
                'Usuarios creados exitosamente',
                '$usuariosCreados',
                Icons.person_add,
                Colors.green.shade600,
                Colors.green.shade50,
              ),
              const SizedBox(height: 12),
              _buildResultCard(
                'Ya existentes (omitidos)',
                '$duplicadosOmitidos',
                Icons.info_outline,
                Colors.orange.shade600,
                Colors.orange.shade50,
              ),
              if (registrosEliminados > 0) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.red.shade700, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Se detectaron estudiantes repetidos en el Excel y '
                          'se eliminaron automáticamente, manteniendo solo el '
                          'primer registro de cada uno.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_errors.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Detalles de estudiantes ya existentes:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _errors.take(20).length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errors[index],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (_errors.length > 20)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '... y ${_errors.length - 20} más',
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

  Widget _buildResultCard(
    String label,
    String value,
    IconData icon,
    Color iconColor,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: const Color(0xFF1E3A5F),
        ),
      );
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
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
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.upload_file,
                      color: Color(0xFF1E3A5F),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Importar desde Excel',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
                child: _isLoading
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
                  color: Colors.black.withOpacity(0.1),
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
          Text(
            _currentProgress < _totalRows
                ? 'Detectando duplicados...'
                : 'Guardando en base de datos...',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_currentProgress / $_totalRows registros',
            style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
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
                ),
                const SizedBox(height: 12),
                Text(
                  '${(_totalRows > 0 ? (_currentProgress / _totalRows * 100) : 0).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      '$_successCount',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16,
                      ),
                    ),
                    const Text('Creados',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                Column(
                  children: [
                    const Icon(Icons.delete_outline,
                        color: Colors.red, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      '$_duplicatesDetected',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),
                    const Text('Eliminados',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Banner admin de carrera ───────────────────────────────────────
          if (_isAdminCarrera) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade50, Colors.orange.shade100],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade300, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        const Icon(Icons.lock, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠️ Modo: Admin de Carrera',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Filial: $_adminCarreraFilial',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Carrera: $_adminCarreraCarrera',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange.shade700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Los datos de carrera/filial del Excel serán ignorados',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Card principal ────────────────────────────────────────────────
          Card(
            elevation: 4,
            shadowColor: Colors.black26,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.upload_file,
                        size: 40, color: Color(0xFF1E3A5F)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Importar Estudiantes desde Excel',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E3A5F),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Selecciona un archivo Excel (.xlsx o .xls)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _buildFeatureRow(Icons.check_circle_outline, 'Acepta celdas vacías'),
                  const SizedBox(height: 8),
                  _buildFeatureRow(Icons.bolt, 'Importación ultra rápida'),
                  const SizedBox(height: 8),
                  _buildFeatureRow(Icons.delete_sweep, 'Elimina duplicados'),
                  const SizedBox(height: 8),
                  _buildFeatureRow(
                      Icons.folder_special, 'Separado por filial y carrera'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _pickExcelFile,
                    icon: const Icon(Icons.file_open),
                    label: const Text('Seleccionar Archivo Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                  if (_fileName != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.green.shade300, width: 2),
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
                                color: Colors.green.shade700, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Archivo seleccionado',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _fileName!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A5F),
                                    fontSize: 14,
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

          // ── Vista previa ──────────────────────────────────────────────────
          if (_fileSelected && _previewData.isNotEmpty) ...[
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
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
                              color: Colors.blue.shade600, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Vista Previa',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_totalRows registros',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _previewData.length,
                      itemBuilder: (context, index) {
                        final student = _previewData[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A5F),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              student['name'] ?? 'Sin nombre',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Filial
                                  if (student['filial'] != null)
                                    Row(children: [
                                      Icon(Icons.location_city,
                                          size: 14,
                                          color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Filial: ${student['filial']}',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700),
                                        ),
                                      ),
                                    ]),
                                  const SizedBox(height: 2),
                                  // Carrera
                                  Row(children: [
                                    Icon(Icons.school,
                                        size: 14,
                                        color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Carrera: ${student['carrera'] ?? "Sin dato"}',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700),
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 2),
                                  // DNI
                                  Row(children: [
                                    Icon(Icons.badge,
                                        size: 14,
                                        color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      'DNI: ${student['dni'] ?? "Sin dato"}',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700),
                                    ),
                                  ]),
                                  const SizedBox(height: 2),
                                  // Pago
                                  Row(children: [
                                    Icon(Icons.payment,
                                        size: 14,
                                        color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Pago: ${student['pago'] ?? "Sin dato"}',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700),
                                    ),
                                  ]),
                                ],
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child:
                                  Icon(Icons.person, color: Colors.blue.shade600),
                            ),
                          ),
                        );
                      },
                    ),
                    if (_totalRows > 5) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Y ${_totalRows - 5} registros más...',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                            ),
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
                        label: const Text(
                          'Importar Eliminando Duplicados',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
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
            ),
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
                        'archivo tenga al menos la columna "Estudiante" o '
                        '"Documento".',
                        style:
                            TextStyle(color: Color(0xFF1E3A5F), fontSize: 14),
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

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1E3A5F)),
        const SizedBox(width: 10),
        Text(text,
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
      ],
    );
  }
}