import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/admin/logica/filiales_service.dart';
import '/device_helper.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'encryption_helper.dart';
import 'password_helper.dart';
import 'dart:convert';

class PrefsHelper {

  static const String userTypeAdmin        = 'admin';
  static const String userTypeStudent      = 'student';
  static const String userTypeJurado       = 'jurado';
  static const String userTypeAdminCarrera = 'admin_carrera';

  static const String _keyUserType                  = 'user_type';
  static const String _keyUserName                  = 'user_name';
  static const String _keyUserId                    = 'user_id';
  static const String _keyIsLoggedIn                = 'is_logged_in';
  static const String _keySessionToken              = 'session_token';


  static const String _keyAdminCarreraFilial        = 'admin_carrera_filial';
  static const String _keyAdminCarreraFilialNombre  = 'admin_carrera_filial_nombre';
  static const String _keyAdminCarreraFacultad      = 'admin_carrera_facultad';
  static const String _keyAdminCarreraCarrera       = 'admin_carrera_carrera';
  static const String _keyAdminCarreraCarreraId     = 'admin_carrera_carrera_id';
  static const String _keyAdminCarreraPermisos      = 'admin_carrera_permisos';
  static const String _keyStudentData = 'student_data_cache';


  static const String _keyJuradoFacultad            = 'jurado_facultad';
  static const String _keyJuradoCarrera             = 'jurado_carrera';
  static const String _keyJuradoFilial              = 'jurado_filial';
  static const String _keyJuradoEventoId            = 'jurado_evento_id';
  static const String _keyJuradoCategorias          = 'jurado_categorias';


  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
static Future<void> ensureAuthActiva({bool esperarRestauracion = false}) async {
    if (FirebaseAuth.instance.currentUser != null) return;
    if (esperarRestauracion) {
      try {
        await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      if (FirebaseAuth.instance.currentUser != null) return;
    }
    await reautenticarAnonimo();
  }

  static Future<void> reautenticarAnonimo() async {
  try {
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {

      await u.getIdToken(true);
      return;
    }
    await FirebaseAuth.instance.signInAnonymously();
    debugPrint('🔁 Sesión anónima creada');
  } on FirebaseAuthException catch (e) {
    if (e.code == 'too-many-requests') {


      debugPrint('⏳ too-many-requests: esperando antes de reintentar');
      await Future.delayed(const Duration(seconds: 2));
      try {
        if (FirebaseAuth.instance.currentUser == null) {
          await FirebaseAuth.instance.signInAnonymously();
        }
      } catch (e2) {
        debugPrint('⚠️ Reintento de auth falló: $e2');
      }
    } else {
      debugPrint('⚠️ No se pudo (re)autenticar: ${e.code}');
    }
  } catch (e) {

    debugPrint('⚠️ Error de red al (re)autenticar: $e');
  }
}

  static final Map<String, Map<String, dynamic>> _userCache        = {};
  static DateTime?                               _cacheTimestamp;
  static const Duration                          _cacheDuration     = Duration(hours: 24);

  static List<Map<String, dynamic>>? _studentsCache;
  static DateTime?                   _studentsCacheTimestamp;
  static const Duration              _studentsCacheDuration = Duration(hours: 1);

  static SharedPreferences? _prefs;
  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }




  static String _generateToken() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }




  static Future<void> _activarAuthAnonima() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
        debugPrint('✅ Auth anónima activada');
      }
    } catch (e) {
      debugPrint('⚠️ Auth anónima fallida: $e');
    }
  }
static Future<void> _persistStudentData(Map<String, dynamic> data) async {
  try {
    final prefs = await _getPrefs();
    await prefs.setString(_keyStudentData, jsonEncode({
      'name':                data['name'],
      'username':            data['username'],
      'filial':              data['filial'],
      'facultad':            data['facultad'],
      'carrera':             data['carrera'],
      'dni':                 data['dni'],
      'documento':           data['documento'],
      'codigoUniversitario': data['codigoUniversitario'],
      'ciclo':               data['ciclo'],
      'grupo':               data['grupo'],
      'carreraPath':         data['carreraPath'],
      'id':                  data['id'],
    }));
  } catch (e) {
    debugPrint('⚠️ No se pudo persistir datos del estudiante: $e');
  }
}

static Future<Map<String, dynamic>?> getPersistedStudentData() async {
  try {
    final prefs = await _getPrefs();
    final raw   = prefs.getString(_keyStudentData);
    if (raw == null || raw.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } catch (e) {
    debugPrint('⚠️ Error leyendo datos persistidos: $e');
    return null;
  }
}
  static Future<void> _cerrarAuthAnonima() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.isAnonymous) {
        await FirebaseAuth.instance.signOut();
        debugPrint('✅ Auth anónima cerrada');
      }
    } catch (e) {
      debugPrint('⚠️ Error cerrando auth anónima: $e');
    }
  }
static Future<bool> verificarBloqueoporPago({
  required String carreraPath,
  required String studentId,
}) async {
  try {
    final doc = await _firestore
        .collection('users')
        .doc(carreraPath)
        .collection('students')
        .doc(studentId)
        .get();

    if (!doc.exists) return false;



    return doc.data()?['bloqueadoPorPago'] == true;
  } catch (e) {


    debugPrint('⚠️ Error verificando bloqueo por pago: $e');
    return false;
  }
}
 static Future<Map<String, dynamic>?> detectarRolConDoc(String username) async {
  debugPrint('🔐 Auth state antes de query: ${FirebaseAuth.instance.currentUser?.uid}');
  try {
    final norm = username.trim().toLowerCase();
    final results = await Future.wait([
      _firestore
          .collection('admins_carrera')
          .where('usuario', isEqualTo: norm)
          .where('activo', isEqualTo: true)
          .limit(1)
          .get(),
      _firestore
          .collection('users')
          .where('userType', isEqualTo: 'jurado')
          .where('usuario', isEqualTo: norm)
          .limit(1)
          .get(),

      _firestore
          .collection('student_index')
          .doc(norm)
          .collection('entries')
          .limit(1)
          .get(),
    ]);

    final adminSnap   = results[0] as QuerySnapshot;
    final juradoSnap  = results[1] as QuerySnapshot;
    final studentSnap = results[2] as QuerySnapshot;

    if (adminSnap.docs.isNotEmpty)  return {'rol': 'admin_carrera', 'doc': adminSnap.docs.first};
    if (juradoSnap.docs.isNotEmpty) return {'rol': 'jurado',        'doc': juradoSnap.docs.first};
    if (studentSnap.docs.isNotEmpty) return {'rol': 'student',      'doc': studentSnap.docs.first};

    debugPrint('❌ No se encontró rol para: "$norm"');
    return null;
  } catch (e) {
    debugPrint('❌ Error detectando rol: $e');
    return null;
  }
}

  static void clearStudentsCache() {
    _studentsCache          = null;
    _studentsCacheTimestamp = null;
    debugPrint('🗑️ Caché de estudiantes limpiado');
  }




  static Future<void> saveUserData({
    required String userType,
    required String userName,
    required String userId,
  }) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyUserType,  userType);
    await prefs.setString(_keyUserName,  userName);
    await prefs.setString(_keyUserId,    userId);
    await prefs.setBool(_keyIsLoggedIn,  true);
  }

  static Future<bool>    isLoggedIn()       async => (await _getPrefs()).getBool(_keyIsLoggedIn)   ?? false;
  static Future<String?> getCurrentUserId() async => (await _getPrefs()).getString(_keyUserId);
  static Future<String?> getUserType()      async => (await _getPrefs()).getString(_keyUserType);
  static Future<String?> getUserName()      async => (await _getPrefs()).getString(_keyUserName);




  static Future<void> saveAdminCarreraData({
    required String userId,
    required String userName,
    required String filial,
    required String filialNombre,
    required String facultad,
    required String carrera,
    required String carreraId,
    required List<String> permisos,
  }) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyUserType,                userTypeAdminCarrera);
    await prefs.setString(_keyUserName,                userName);
    await prefs.setString(_keyUserId,                  userId);
    await prefs.setString(_keyAdminCarreraFilial,       filial);
    await prefs.setString(_keyAdminCarreraFilialNombre, filialNombre);
    await prefs.setString(_keyAdminCarreraFacultad,     facultad);
    await prefs.setString(_keyAdminCarreraCarrera,      carrera);
    await prefs.setString(_keyAdminCarreraCarreraId,    carreraId);
    await prefs.setString(_keyAdminCarreraPermisos,     permisos.join(','));
    await prefs.setBool(_keyIsLoggedIn,                true);


    await _activarAuthAnonima();

    debugPrint('✅ Datos de admin carrera guardados en sesión');
  }

  static Future<String?> getAdminCarreraFilial()       async => (await _getPrefs()).getString(_keyAdminCarreraFilial);
  static Future<String?> getAdminCarreraFilialNombre() async => (await _getPrefs()).getString(_keyAdminCarreraFilialNombre);
  static Future<String?> getAdminCarreraFacultad()     async => (await _getPrefs()).getString(_keyAdminCarreraFacultad);
  static Future<String?> getAdminCarreraCarrera()      async => (await _getPrefs()).getString(_keyAdminCarreraCarrera);
  static Future<String?> getAdminCarreraCarreraId()    async => (await _getPrefs()).getString(_keyAdminCarreraCarreraId);

  static Future<List<String>> getAdminCarreraPermisos() async {
    final prefs          = await _getPrefs();
    final permisosString = prefs.getString(_keyAdminCarreraPermisos);
    if (permisosString == null || permisosString.isEmpty) return [];
    return permisosString.split(',');
  }

  static Future<bool> isAdminCarrera() async =>
      (await getUserType()) == userTypeAdminCarrera;

  static Future<bool> tienePermiso(String permiso) async =>
      (await getAdminCarreraPermisos()).contains(permiso);

  static Future<Map<String, dynamic>?> getAdminCarreraData() async {
    if (!await isAdminCarrera()) return null;
    return {
      'userId':       await getCurrentUserId(),
      'userName':     await getUserName(),
      'filial':       await getAdminCarreraFilial(),
      'filialNombre': await getAdminCarreraFilialNombre(),
      'facultad':     await getAdminCarreraFacultad(),
      'carrera':      await getAdminCarreraCarrera(),
      'carreraId':    await getAdminCarreraCarreraId(),
      'permisos':     await getAdminCarreraPermisos(),
    };
  }




  static Future<bool> loginJurado(String usuario, String password) async {
    try {
      debugPrint('🔍 Intentando login jurado: $usuario');

      final query = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'jurado')
          .where('usuario',  isEqualTo: usuario.trim().toLowerCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        debugPrint('❌ Jurado no encontrado: $usuario');
        return false;
      }

      final doc  = query.docs.first;
      final data = doc.data();

      final stored = data['password']?.toString() ?? '';
      if (!PasswordHelper.verifyPassword(password, stored)) {
        debugPrint('❌ Contraseña incorrecta para jurado: $usuario');
        return false;
      }

      if (!_isSha256(stored)) {
        final hash = PasswordHelper.hashPassword(password);
        await _firestore.collection('users').doc(doc.id).update({'password': hash});
        debugPrint('✅ Contraseña de jurado migrada a hash');
      }

      await saveUserData(
        userType: userTypeJurado,
        userName: data['name'] ?? 'Jurado',
        userId:   doc.id,
      );

      final prefs = await _getPrefs();
      await prefs.setString(_keyJuradoFacultad, data['facultad'] ?? '');
      await prefs.setString(_keyJuradoCarrera,  data['carrera']  ?? '');
      await prefs.setString(_keyJuradoFilial,   data['filial']   ?? '');
      await prefs.setString(_keyJuradoEventoId, data['eventoId'] ?? '');
      final categorias = (data['categorias'] as List?)
              ?.map((e) => e.toString()).join(',') ?? '';
      await prefs.setString(_keyJuradoCategorias, categorias);


      await _activarAuthAnonima();

      debugPrint('✅ Login jurado exitoso: ${data['name']}');
      return true;
    } catch (e) {
      debugPrint('❌ Error en login de jurado: $e');
      return false;
    }
  }

  static Future<String?> getJuradoFacultad()   async => (await _getPrefs()).getString(_keyJuradoFacultad);
  static Future<String?> getJuradoCarrera()    async => (await _getPrefs()).getString(_keyJuradoCarrera);
  static Future<String?> getJuradoFilial()     async => (await _getPrefs()).getString(_keyJuradoFilial);
  static Future<String?> getJuradoEventoId()   async => (await _getPrefs()).getString(_keyJuradoEventoId);
  static Future<List<String>> getJuradoCategorias() async {
    final prefs = await _getPrefs();
    final raw   = prefs.getString(_keyJuradoCategorias) ?? '';
    if (raw.isEmpty) return [];
    return raw.split(',');
  }




  static Future<bool> loginStudent(String username, String password) async {
  try {
    debugPrint('🔐 Intentando login de estudiante: $username');
    final usernameNorm = username.trim().toLowerCase();


    QuerySnapshot entriesSnap;
    try {
      entriesSnap = await _firestore
          .collection('student_index')
          .doc(usernameNorm)
          .collection('entries')
          .get();
          debugPrint('🔍 Buscando en índice username: "$usernameNorm"');
debugPrint('   Entries encontradas: ${entriesSnap.docs.length}');
for (var doc in entriesSnap.docs) {
  debugPrint('   Entry data: ${doc.data()}');
}
    } catch (e) {
      debugPrint('⚠️ Error leyendo student_index, usando fallback: $e');
      return await _loginStudentFallback(usernameNorm, password);
    }

    if (entriesSnap.docs.isEmpty) {
      debugPrint('ℹ️ No encontrado en índice. Buscando en subcolecciones...');
      return await _loginStudentFallback(usernameNorm, password);
    }


    if (entriesSnap.docs.length == 1) {
      final entryData   = entriesSnap.docs.first.data() as Map<String, dynamic>;
      final carreraPath = entryData['carreraPath'] as String?;
      final studentId   = entryData['studentId']   as String?;

      if (carreraPath == null || studentId == null) {
        debugPrint('⚠️ Índice corrupto, usando fallback');
        await entriesSnap.docs.first.reference.delete();
        return await _loginStudentFallback(usernameNorm, password);
      }

      DocumentSnapshot studentDoc;
      try {
        studentDoc = await _firestore
            .collection('users')
            .doc(carreraPath)
            .collection('students')
            .doc(studentId)
            .get();
            debugPrint('   carreraPath: "$carreraPath"');
debugPrint('   studentId: "$studentId"');
debugPrint('   studentDoc.exists: ${studentDoc.exists}');
if (studentDoc.exists) {
  final d = studentDoc.data() as Map<String, dynamic>;
  debugPrint('   username en Firestore: "${d['username']}"');
  debugPrint('   dni en Firestore: "${d['dni']}"');
}
      } catch (e) {
        debugPrint('⚠️ Error leyendo estudiante, usando fallback: $e');
        return await _loginStudentFallback(usernameNorm, password);
      }

      if (!studentDoc.exists) {
        debugPrint('⚠️ Índice apunta a estudiante inexistente. Limpiando...');
        await entriesSnap.docs.first.reference.delete();
        return await _loginStudentFallback(usernameNorm, password);
      }

      final studentData    = studentDoc.data() as Map<String, dynamic>;
      final storedPassword = studentData['dni'] ?? studentData['documento'];

      if (storedPassword == null) {
        return await _loginStudentFallback(usernameNorm, password);
      }

      if (!PasswordHelper.verifyPassword(password, storedPassword.toString())) {
        debugPrint('⚠️ Contraseña no coincide, buscando en otras carreras...');
        return await _loginStudentFallback(usernameNorm, password);
      }

      if (!_isSha256(storedPassword.toString())) {
        final hash = PasswordHelper.hashPassword(password);
        await _firestore
            .collection('users')
            .doc(carreraPath)
            .collection('students')
            .doc(studentId)
            .update({'dni': hash, 'documento': hash});
        debugPrint('✅ Contraseña migrada a hash automáticamente');
      }

      await saveUserData(
        userType: userTypeStudent,
        userName: studentData['name'] ?? 'Estudiante',
        userId:   '$carreraPath/$studentId',
      );

      studentData['id']          = studentId;
      studentData['carreraPath'] = carreraPath;
      _userCache[studentId]      = studentData;
      _cacheTimestamp            = DateTime.now();
await _persistStudentData(studentData);
      await _activarAuthAnonima();
      debugPrint('✅ Login exitoso vía índice (username único)');
      return true;
    }


    debugPrint('⚠️ Username duplicado detectado: ${entriesSnap.docs.length} entradas');

    for (var entry in entriesSnap.docs) {
      final entryData   = entry.data() as Map<String, dynamic>;
      final carreraPath = entryData['carreraPath'] as String?;
      final studentId   = entryData['studentId']   as String?;

      if (carreraPath == null || studentId == null) {
        debugPrint('⚠️ Entry corrupta, saltando...');
        continue;
      }

      DocumentSnapshot studentDoc;
      try {
        studentDoc = await _firestore
            .collection('users')
            .doc(carreraPath)
            .collection('students')
            .doc(studentId)
            .get();
      } catch (e) {
        debugPrint('⚠️ Error leyendo estudiante en loop: $e');
        continue;
      }

      if (!studentDoc.exists) {
        debugPrint('⚠️ Entry huérfana detectada, saltando...');
        continue;
      }

      final studentData    = studentDoc.data() as Map<String, dynamic>;
      final storedPassword = studentData['dni'] ?? studentData['documento'];

      if (storedPassword == null) continue;

      if (!PasswordHelper.verifyPassword(password, storedPassword.toString())) {
        debugPrint('⚠️ DNI no coincide con $carreraPath, probando siguiente...');
        continue;
      }


      if (!_isSha256(storedPassword.toString())) {
        final hash = PasswordHelper.hashPassword(password);
        await _firestore
            .collection('users')
            .doc(carreraPath)
            .collection('students')
            .doc(studentId)
            .update({'dni': hash, 'documento': hash});
        debugPrint('✅ Contraseña migrada a hash automáticamente');
      }

      await saveUserData(
        userType: userTypeStudent,
        userName: studentData['name'] ?? 'Estudiante',
        userId:   '$carreraPath/$studentId',
      );

      studentData['id']          = studentId;
      studentData['carreraPath'] = carreraPath;
      _userCache[studentId]      = studentData;
      _cacheTimestamp            = DateTime.now();
await _persistStudentData(studentData);
      await _activarAuthAnonima();
      debugPrint('✅ Login exitoso — duplicado resuelto por DNI en $carreraPath');
      return true;
    }


    debugPrint('❌ Ningún estudiante coincidió con el DNI proporcionado');
    return await _loginStudentFallback(usernameNorm, password);

  } catch (e) {
    debugPrint('❌ Error en login estudiante: $e');
    try {
      return await _loginStudentFallback(username.trim().toLowerCase(), password);
    } catch (_) {
      return false;
    }
  }
}

  static Future<bool> _loginStudentFallback(String username, String password) async {
    try {
      debugPrint('🔄 Fallback: buscando "$username" en todas las carreras...');

      final carrerasSnapshot = await _firestore.collection('users').get();

      for (var carreraDoc in carrerasSnapshot.docs) {
        final carreraName = carreraDoc.id;
        final carreraData = carreraDoc.data();
        if (carreraData.containsKey('userType')) continue;

        try {
          final studentQuery = await _firestore
              .collection('users')
              .doc(carreraName)
              .collection('students')
              .where('username', isEqualTo: username)
              .limit(1)
              .get();

          if (studentQuery.docs.isEmpty) continue;

          final studentDoc  = studentQuery.docs.first;
          final studentData = studentDoc.data();
          final stored      = studentData['dni'] ?? studentData['documento'];

          if (stored == null) continue;

          if (!PasswordHelper.verifyPassword(password, stored.toString())) continue;

          if (!_isSha256(stored.toString())) {
            final hash = PasswordHelper.hashPassword(password);
            await _firestore
                .collection('users')
                .doc(carreraName)
                .collection('students')
                .doc(studentDoc.id)
                .update({'dni': hash, 'documento': hash});
            debugPrint('✅ Contraseña migrada a hash en fallback');
          }

          await saveUserData(
            userType: userTypeStudent,
            userName: studentData['name'] ?? 'Estudiante',
            userId:   '$carreraName/${studentDoc.id}',
          );

          await createStudentIndex(
            username:    username,
            carreraPath: carreraName,
            studentId:   studentDoc.id,
          );

          studentData['id']          = studentDoc.id;
          studentData['carreraPath'] = carreraName;
          _userCache[studentDoc.id]  = studentData;
          _cacheTimestamp            = DateTime.now();

await _persistStudentData(studentData);
          await _activarAuthAnonima();

          debugPrint('✅ Login exitoso vía fallback en "$carreraName"');
          return true;
        } catch (e) {
          debugPrint('⚠️ Error buscando en $carreraName: $e');
          continue;
        }
      }

      debugPrint('❌ Estudiante "$username" no encontrado en ninguna carrera');
      return false;
    } catch (e) {
      debugPrint('❌ Error en fallback login: $e');
      return false;
    }
  }

  static Future<void> createStudentIndex({
  required String username,
  required String carreraPath,
  required String studentId,
}) async {
  try {
    await _firestore
        .collection('student_index')
        .doc(username)
        .collection('entries')
        .add({
      'username':    username,
      'carreraPath': carreraPath,
      'studentId':   studentId,
      'createdAt':   FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Índice creado para $username');
  } catch (e) {
    debugPrint('⚠️ Error creando índice: $e');
  }
}




  static Future<String> verificarSesionEstudiante({
    required String carreraPath,
    required String studentId,
    DocumentSnapshot? cachedDoc,
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .doc(studentId)
          .get(const GetOptions(source: Source.server));

      if (!doc.exists) return 'error';

      final data               = doc.data()!;
      final currentDeviceId    = await DeviceHelper.getDeviceId();
      final bloqueadoPermanente = data['bloqueadoPermanente'] ?? false;
      final sessionActive       = data['sessionActive']       ?? false;

      if (bloqueadoPermanente == true) return 'dispositivo_bloqueado';

      final cuentasEnEsteDispositivo = await _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .where('deviceId', isEqualTo: currentDeviceId)
          .limit(1)
          .get();

      if (cuentasEnEsteDispositivo.docs.isNotEmpty &&
          cuentasEnEsteDispositivo.docs.first.id != studentId) {
        return 'celular_bloqueado';
      }

      if (sessionActive == true) return 'bloqueado';

      return 'libre';
    } catch (e) {
      debugPrint('❌ Error verificando sesión: $e');
      return 'error';
    }
  }

  static Future<bool> activarSesionEstudiante({
    required String carreraPath,
    required String studentId,
  }) async {
    try {
      final token           = _generateToken();
      final currentDeviceId = await DeviceHelper.getDeviceId();

      final doc = await _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .doc(studentId)
          .get();

      final esPrimeraVez =
          doc.exists ? (doc.data()?['primeraVez'] ?? true) == true : true;

      await _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .doc(studentId)
          .update({
        'sessionActive': true,
        'sessionToken':  token,
        'lastLogin':     FieldValue.serverTimestamp(),
        'primeraVez':    false,
        'deviceId':      currentDeviceId,
      });

      final prefs = await _getPrefs();
      await prefs.setString(_keySessionToken, token);
      await prefs.setBool('es_primera_vez_advertencia', esPrimeraVez);

      debugPrint('✅ Sesión activada. Dispositivo: $currentDeviceId');
      return true;
    } catch (e) {
      debugPrint('❌ Error activando sesión estudiante: $e');
      return false;
    }
  }

  static Future<bool> debemostrarAdvertenciaPrimeraVez() async {
    final prefs = await _getPrefs();
    final valor = prefs.getBool('es_primera_vez_advertencia') ?? false;
    await prefs.remove('es_primera_vez_advertencia');
    return valor;
  }

  static Future<void> cerrarSesionEstudiante() async {
    try {
      final userIdPath = await getCurrentUserId();
      if (userIdPath == null || !userIdPath.contains('/')) return;

      final parts           = userIdPath.split('/');
      final carreraPath     = parts[0];
      final studentId       = parts[1];
      final currentDeviceId = await DeviceHelper.getDeviceId();

      await _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .doc(studentId)
          .update({
        'sessionActive':       false,
        'sessionToken':        null,
        'bloqueadoPermanente': true,
        'deviceId':            currentDeviceId,
        'bloqueadoEn':         FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error cerrando sesión: $e');
    }
  }




  static Future<bool> isSessionValid() async {
    try {
      final userType = await getUserType();

      if (userType == 'superAdmin') return true;

      if (userType == userTypeJurado       ||
          userType == userTypeAdminCarrera ||
          userType == userTypeStudent) {
        return true;
      }

      final prefs      = await _getPrefs();
      final localToken = prefs.getString(_keySessionToken);
      final userId     = await getCurrentUserId();

      if (localToken == null || userId == null) return false;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final currentPassword = userDoc.data()?['password'];
      final isValid         = localToken == currentPassword;

      if (!isValid) {
        debugPrint('🔒 Sesión invalidada: contraseña cambiada en otro dispositivo');
      }

      return isValid;
    } catch (e) {
      debugPrint('Error validando sesión: $e');
      return false;
    }
  }
 static Future<T> _conReintento<T>(
  Future<T> Function() operacion, {
  int maxIntentos = 4,
}) async {
  int intento = 0;
  while (true) {
    try {
      return await operacion();
    } on FirebaseException catch (e) {
      intento++;

      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        if (intento >= maxIntentos) rethrow;
        debugPrint('🔁 Auth perdida ("${e.code}") → recreando sesión');
        await reautenticarAnonimo();
        await Future.delayed(const Duration(milliseconds: 300));
        continue;
      }
      const transitorios = {
        'unavailable',
        'deadline-exceeded',
        'aborted',
        'internal',
        'resource-exhausted',
      };
      if (!transitorios.contains(e.code) || intento >= maxIntentos) {
        rethrow;
      }
      final espera = Duration(milliseconds: 400 * (1 << (intento - 1)));
      debugPrint('🔁 Reintento $intento tras "${e.code}"');
      await Future.delayed(espera);
    }
  }
}



  static Future<Map<String, dynamic>?> getCurrentUserData({
  bool forceRefresh = false,
}) async {
  try {
    final userIdPath = await getCurrentUserId();
    if (userIdPath == null) return null;

    if (!forceRefresh &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      final parts = userIdPath.split('/');
      if (parts.length == 2) {
        final studentId = parts[1];
        if (_userCache.containsKey(studentId)) {
          debugPrint('✅ Datos obtenidos del caché');
          return _userCache[studentId];
        }
      }
    }
if (userIdPath.contains('/')) {
      await ensureAuthActiva();
      final parts = userIdPath.split('/');
      if (parts.length != 2) return null;
      final carreraPath = parts[0];
      final studentId = parts[1];

      final userDoc = await _conReintento(() => _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .doc(studentId)
          .get());

      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      userData['id'] = userDoc.id;
      userData['carreraPath'] = carreraPath;

     _userCache[studentId] = userData;
      _cacheTimestamp = DateTime.now();
      await _persistStudentData(userData);

      return userData;
    } else {
      final userDoc = await _conReintento(
          () => _firestore.collection('users').doc(userIdPath).get());
      if (!userDoc.exists) return null;
      final userData = userDoc.data()!;
      userData['id'] = userDoc.id;
      return userData;
    }
  } catch (e) {
    debugPrint('Error obteniendo datos del usuario: $e');
    final persisted = await getPersistedStudentData();
    if (persisted != null) {
      debugPrint('✅ Usando datos persistidos (fallback)');
      return persisted;
    }
    return null;
  }
}




  static Future<bool> createStudentAccountWithUsername({
    required String email,
    required String name,
    required String username,
    required String codigoUniversitario,
    required String dni,
    required String facultad,
    required String carrera,
    required String filial,
    String? modoContrato,
    String? modalidadEstudio,
    String? sede,
    String? ciclo,
    String? grupo,
    String? correoInstitucional,
    String? celular,
    String? pago,
  }) async {
    try {
      final carreraPath = '${filial}_$carrera';

      final studentsRef = _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students');

      final existingUsername = await studentsRef
          .where('username', isEqualTo: username.trim().toLowerCase())
          .limit(1)
          .get();
      if (existingUsername.docs.isNotEmpty) {
        debugPrint('❌ Username ya existe en esta carrera');
        return false;
      }

      if (email.trim().isNotEmpty) {
        final existingEmail = await studentsRef
            .where('email', isEqualTo: email.trim())
            .limit(1)
            .get();
        if (existingEmail.docs.isNotEmpty) {
          debugPrint('❌ Email ya existe');
          return false;
        }
      }

      if (codigoUniversitario.trim().isNotEmpty) {
        final existingCode = await studentsRef
            .where('codigoUniversitario', isEqualTo: codigoUniversitario.trim())
            .limit(1)
            .get();
        if (existingCode.docs.isNotEmpty) {
          debugPrint('❌ Código universitario ya existe');
          return false;
        }
      }

      if (dni.trim().isNotEmpty) {
        final dniHash = PasswordHelper.hashPassword(dni.trim());
        final existingDni = await studentsRef
            .where('dni', isEqualTo: dniHash)
            .limit(1)
            .get();
        if (existingDni.docs.isNotEmpty) {
          debugPrint('❌ DNI ya existe');
          return false;
        }
      }

      final dniHash      = PasswordHelper.hashPassword(dni.trim());
      final dniEncrypted = EncryptionHelper.encryptDni(dni.trim());

      final studentData = <String, dynamic>{
        'email':                email.trim(),
        'name':                 name.trim(),
        'username':             username.toLowerCase().trim(),
        'codigoUniversitario':  codigoUniversitario.trim(),
        'dni':                  dniHash,
        'documento':            dniHash,
        'filial':               filial,
        'facultad':             facultad,
        'carrera':              carrera,
        'userType':             userTypeStudent,
        'esAsisteQR':           false,
        'dniEncrypted':         dniEncrypted,
        'createdAt':            FieldValue.serverTimestamp(),
      };

      if (modoContrato        != null && modoContrato.isNotEmpty)        studentData['modoContrato']        = modoContrato;
      if (modalidadEstudio    != null && modalidadEstudio.isNotEmpty)    studentData['modalidadEstudio']    = modalidadEstudio;
      if (ciclo               != null && ciclo.isNotEmpty)               studentData['ciclo']               = ciclo;
      if (grupo               != null && grupo.isNotEmpty)               studentData['grupo']               = grupo;
      if (correoInstitucional != null && correoInstitucional.isNotEmpty) studentData['correoInstitucional'] = correoInstitucional.trim();
      if (celular             != null && celular.isNotEmpty)             studentData['celular']             = celular.trim();
      if (pago                != null && pago.isNotEmpty)                studentData['pago']                = pago;

      final studentDoc = await studentsRef.add(studentData);

      await createStudentIndex(
        username:    username.toLowerCase().trim(),
        carreraPath: carreraPath,
        studentId:   studentDoc.id,
      );

      await _firestore.collection('users').doc(carreraPath).set({
        'name':        carreraPath,
        'filial':      filial,
        'facultad':    facultad,
        'carrera':     carrera,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Estudiante creado en "$carreraPath": ${studentDoc.id}');
      clearStudentsCache();
      return true;
    } catch (e) {
      debugPrint('❌ Error creando estudiante: $e');
      return false;
    }
  }




  static Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final userIdPath = await getCurrentUserId();
      if (userIdPath == null) return false;

      final parts = userIdPath.split('/');
      if (parts.length != 2) return false;

      final carreraPath = parts[0];
      final studentId   = parts[1];

      final userDoc = await _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .doc(studentId)
          .get();

      if (!userDoc.exists) return false;

      final stored = userDoc.data()!['dni'] ?? userDoc.data()!['documento'];

      if (!PasswordHelper.verifyPassword(currentPassword, stored.toString())) {
        return false;
      }

      final newHash = PasswordHelper.hashPassword(newPassword);

      await _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .doc(studentId)
          .update({
        'dni':       newHash,
        'documento': newHash,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _userCache.remove(studentId);
      debugPrint('✅ Contraseña actualizada y hasheada');
      return true;
    } catch (e) {
      debugPrint('Error cambiando contraseña: $e');
      return false;
    }
  }




  static String generateUsername(String fullName) {
    final nameParts = fullName.trim().toLowerCase().split(' ');
    if (nameParts.length >= 3) return '${nameParts[0]}.${nameParts[2]}';
    if (nameParts.length == 2) return '${nameParts[0]}.${nameParts[1]}';
    if (nameParts.length == 1) return nameParts[0];
    return fullName.toLowerCase().replaceAll(' ', '.');
  }

  static Future<List<Map<String, dynamic>>> getStudentsByCarrera(String carrera) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(carrera)
          .collection('students')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((doc) {
        final data          = doc.data();
        data['id']          = doc.id;
        data['carreraPath'] = carrera;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error obteniendo estudiantes de $carrera: $e');
      return [];
    }
  }

  static Future<List<String>> getCarreras() async {
    try {
      final snap = await _firestore.collection('users').get();
      return snap.docs
          .map((doc) => doc.id)
          .where((id) => id != 'admin')
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo carreras: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getStudents() async {
    try {
      if (_studentsCache != null &&
          _studentsCacheTimestamp != null &&
          DateTime.now().difference(_studentsCacheTimestamp!) < _studentsCacheDuration) {
        return _studentsCache!;
      }

      List<Map<String, dynamic>> allStudents = [];
      final snap = await _firestore.collection('users').get();

      for (var carreraDoc in snap.docs) {
        final data = carreraDoc.data();
        if (data.containsKey('userType')) continue;

        final studentsQuery = await _firestore
            .collection('users')
            .doc(carreraDoc.id)
            .collection('students')
            .orderBy('createdAt', descending: true)
            .get();

        for (var studentDoc in studentsQuery.docs) {
          final d          = studentDoc.data();
          d['id']          = studentDoc.id;
          d['carreraPath'] = carreraDoc.id;
          allStudents.add(d);
        }
      }

      _studentsCache          = allStudents;
      _studentsCacheTimestamp = DateTime.now();
      return allStudents;
    } catch (e) {
      debugPrint('Error obteniendo estudiantes: $e');
      return [];
    }
  }

  static Future<bool> deleteStudent(String carreraPath, String studentId) async {
    try {
      final studentDoc = await _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .doc(studentId)
          .get();

      if (studentDoc.exists) {
  final username = studentDoc.data()?['username'];
  if (username != null) {
    final entriesSnap = await _firestore
        .collection('student_index')
        .doc(username)
        .collection('entries')
        .where('studentId', isEqualTo: studentId)
        .get();

    for (var entry in entriesSnap.docs) {
      await entry.reference.delete();
    }
  }
}

      await _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .doc(studentId)
          .delete();

      _userCache.remove(studentId);
      clearStudentsCache();
      return true;
    } catch (e) {
      debugPrint('Error eliminando estudiante: $e');
      return false;
    }
  }

  static Future<Map<String, int>> deleteMultipleStudents(
      List<Map<String, String>> students) async {
    int successCount = 0;
    int errorCount   = 0;

    try {

      final List<Future<String?>> usernameFutures = students.map((student) async {
        final studentId   = student['studentId']!;
        final carreraPath = student['carreraPath']!;


        final cached = _userCache[studentId]?['username']?.toString();
        if (cached != null && cached.isNotEmpty) return cached;


        try {
          final doc = await _firestore
              .collection('users')
              .doc(carreraPath)
              .collection('students')
              .doc(studentId)
              .get();
          return doc.data()?['username']?.toString();
        } catch (_) {
          return null;
        }
      }).toList();

      final usernames = await Future.wait(usernameFutures);


      final Set<String> uniqueUsernames = usernames
          .where((u) => u != null && u.isNotEmpty)
          .cast<String>()
          .toSet();

      final entriesFutures = uniqueUsernames.map((username) =>
          _firestore
              .collection('student_index')
              .doc(username)
              .collection('entries')
              .get());

      final entriesResults = await Future.wait(entriesFutures);


      final studentIds = students.map((s) => s['studentId']!).toSet();


      const batchSize = 500;
      var batch = _firestore.batch();
      int opsInBatch = 0;

      Future<void> commitIfFull() async {
        if (opsInBatch >= batchSize) {
          await batch.commit();
          batch = _firestore.batch();
          opsInBatch = 0;
        }
      }


      for (var snap in entriesResults) {
        for (var entry in snap.docs) {
          final entryStudentId = entry.data()['studentId']?.toString();
          if (entryStudentId != null && studentIds.contains(entryStudentId)) {
            batch.delete(entry.reference);
            opsInBatch++;
            await commitIfFull();
          }
        }
      }


      for (var student in students) {
        try {
          final studentRef = _firestore
              .collection('users')
              .doc(student['carreraPath'])
              .collection('students')
              .doc(student['studentId']);
          batch.delete(studentRef);
          opsInBatch++;
          successCount++;
          await commitIfFull();
        } catch (e) {
          debugPrint('❌ Error preparando eliminación: $e');
          errorCount++;
        }
      }


      if (opsInBatch > 0) {
        await batch.commit();
      }

      debugPrint('✅ Eliminados $successCount estudiantes con sus índices en batch');

      _userCache.clear();
      _cacheTimestamp = null;
      clearStudentsCache();
      return {'success': successCount, 'errors': errorCount};
    } catch (e) {
      debugPrint('❌ Error en eliminación masiva: $e');
      return {'success': successCount, 'errors': errorCount};
    }
  }

  static Future<bool> updateStudent({
    required String carreraPath,
    required String studentId,
    String? name,
    String? email,
    String? codigoUniversitario,
    String? dni,
    String? facultad,
    String? carrera,
    String? modoContrato,
    String? modalidadEstudio,
    String? sede,
    String? ciclo,
    String? grupo,
    String? correoInstitucional,
    String? celular,
    String? pago,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name                != null) updateData['name']                = name.trim();
      if (email               != null) updateData['email']               = email.trim();
      if (codigoUniversitario != null) updateData['codigoUniversitario'] = codigoUniversitario.trim();
      if (dni                 != null) {
        final dniHash      = PasswordHelper.hashPassword(dni.trim());
        final dniEncrypted = EncryptionHelper.encryptDni(dni.trim());
        updateData['dni']          = dniHash;
        updateData['documento']    = dniHash;
        updateData['dniEncrypted'] = dniEncrypted;
      }
      if (facultad            != null) updateData['facultad']            = facultad;
      if (carrera             != null) updateData['carrera']             = carrera;
      if (modoContrato        != null) updateData['modoContrato']        = modoContrato;
      if (modalidadEstudio    != null) updateData['modalidadEstudio']    = modalidadEstudio;
      if (sede                != null) updateData['sede']                = sede;
      if (ciclo               != null) updateData['ciclo']               = ciclo;
      if (grupo               != null) updateData['grupo']               = grupo;
      if (correoInstitucional != null) updateData['correoInstitucional'] = correoInstitucional.trim();
      if (celular             != null) updateData['celular']             = celular.trim();

      await _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .doc(studentId)
          .update(updateData);

      _userCache.remove(studentId);
      clearStudentsCache();
      return true;
    } catch (e) {
      debugPrint('Error actualizando estudiante: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> searchStudents({
    String? facultad,
    String? carrera,
    String? ciclo,
    String? grupo,
    String? sede,
    String? searchTerm,
  }) async {
    try {
      List<Map<String, dynamic>> allStudents = [];

      if (carrera != null && carrera.isNotEmpty) {
        Query query = _firestore
            .collection('users')
            .doc(carrera)
            .collection('students');

        if (ciclo != null && ciclo.isNotEmpty) query = query.where('ciclo', isEqualTo: ciclo);
        if (grupo != null && grupo.isNotEmpty) query = query.where('grupo', isEqualTo: grupo);
        if (sede  != null && sede.isNotEmpty)  query = query.where('sede',  isEqualTo: sede);

        final results = await query.get();
        allStudents = results.docs.map((doc) {
          final data          = doc.data() as Map<String, dynamic>;
          data['id']          = doc.id;
          data['carreraPath'] = carrera;
          return data;
        }).toList();
      } else {
        final snap = await _firestore.collection('users').get();
        for (var carreraDoc in snap.docs) {
          final data = carreraDoc.data();
          if (data.containsKey('userType')) continue;

          Query query = _firestore
              .collection('users')
              .doc(carreraDoc.id)
              .collection('students');

          if (ciclo != null && ciclo.isNotEmpty) query = query.where('ciclo', isEqualTo: ciclo);
          if (grupo != null && grupo.isNotEmpty) query = query.where('grupo', isEqualTo: grupo);
          if (sede  != null && sede.isNotEmpty)  query = query.where('sede',  isEqualTo: sede);

          final results = await query.get();
          for (var doc in results.docs) {
            final d          = doc.data() as Map<String, dynamic>;
            d['id']          = doc.id;
            d['carreraPath'] = carreraDoc.id;
            allStudents.add(d);
          }
        }
      }

      if (facultad != null && facultad.isNotEmpty) {
        allStudents = allStudents.where((s) => s['facultad'] == facultad).toList();
      }

      if (searchTerm != null && searchTerm.isNotEmpty) {
        final q = searchTerm.toLowerCase();
        allStudents = allStudents.where((s) {
          final name   = (s['name']                ?? '').toString().toLowerCase();
          final user   = (s['username']            ?? '').toString().toLowerCase();
          final codigo = (s['codigoUniversitario'] ?? '').toString().toLowerCase();
          return name.contains(q) || user.contains(q) || codigo.contains(q);
        }).toList();
      }

      return allStudents;
    } catch (e) {
      debugPrint('Error buscando estudiantes: $e');
      return [];
    }
  }

  static Future<Map<String, int>> deleteAllStudents() async {
    try {
      int successCount = 0;
      int errorCount   = 0;

      final snap = await _firestore.collection('users').get();

      for (var carreraDoc in snap.docs) {
        final data = carreraDoc.data();
        if (data.containsKey('userType')) continue;

        final studentsQuery = await _firestore
            .collection('users')
            .doc(carreraDoc.id)
            .collection('students')
            .get();

        if (studentsQuery.docs.isEmpty) continue;


        final usernames = studentsQuery.docs
            .map((d) => d.data()['username']?.toString())
            .where((u) => u != null && u.isNotEmpty)
            .cast<String>()
            .toSet();


        final entriesFutures = usernames.map((username) =>
            _firestore
                .collection('student_index')
                .doc(username)
                .collection('entries')
                .get());

        final entriesResults = await Future.wait(entriesFutures);


        const batchSize = 500;
        var batch = _firestore.batch();
        int opsInBatch = 0;

        Future<void> commitIfFull() async {
          if (opsInBatch >= batchSize) {
            await batch.commit();
            batch = _firestore.batch();
            opsInBatch = 0;
          }
        }


        for (var snap in entriesResults) {
          for (var entry in snap.docs) {
            batch.delete(entry.reference);
            opsInBatch++;
            await commitIfFull();
          }
        }


        for (var studentDoc in studentsQuery.docs) {
          batch.delete(studentDoc.reference);
          opsInBatch++;
          await commitIfFull();
          successCount++;
        }


        if (opsInBatch > 0) {
          await batch.commit();
        }

        debugPrint('✅ Carrera ${carreraDoc.id}: ${studentsQuery.docs.length} estudiantes eliminados');
      }

      _userCache.clear();
      _cacheTimestamp = null;
      clearStudentsCache();
      return {'success': successCount, 'errors': errorCount};
    } catch (e) {
      debugPrint('Error eliminando todos los estudiantes: $e');
      return {'success': 0, 'errors': -1};
    }
  }




  static Future<void> logout() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyUserType);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keySessionToken);
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyAdminCarreraFilial);
    await prefs.remove(_keyAdminCarreraFilialNombre);
    await prefs.remove(_keyAdminCarreraFacultad);
    await prefs.remove(_keyAdminCarreraCarrera);
    await prefs.remove(_keyAdminCarreraCarreraId);
    await prefs.remove(_keyAdminCarreraPermisos);
    await prefs.remove(_keyJuradoFacultad);
    await prefs.remove(_keyJuradoCarrera);
    await prefs.remove(_keyJuradoFilial);
    await prefs.remove(_keyJuradoEventoId);
    await prefs.remove(_keyJuradoCategorias);

    clearStudentsCache();
    _userCache.clear();
    _cacheTimestamp = null;
    _prefs          = null;

    FilialesService.clearCache();


    await _cerrarAuthAnonima();

    debugPrint('✅ Sesión cerrada y caché limpiado');
  }




  static bool _isSha256(String value) {
    return value.length == 64 && RegExp(r'^[a-f0-9]+$').hasMatch(value);
  }
}