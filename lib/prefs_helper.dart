import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/logica/filiales_service.dart';

class PrefsHelper {
  static const String userTypeAdminCarrera = 'admin_carrera';
  static const String _keyAdminCarreraFilial = 'admin_carrera_filial';
  static const String _keyAdminCarreraFilialNombre =
      'admin_carrera_filial_nombre';
  static const String _keyAdminCarreraFacultad = 'admin_carrera_facultad';
  static const String _keyAdminCarreraCarrera = 'admin_carrera_carrera';
  static const String _keyAdminCarreraCarreraId = 'admin_carrera_carrera_id';
  static const String _keyAdminCarreraPermisos = 'admin_carrera_permisos';
  static const String _keyUserType = 'user_type';
  static const String _keyUserName = 'user_name';
  static const String _keyUserId = 'user_id';
  static const String _keyIsLoggedIn = 'is_logged_in';
  // ✅ NUEVO: Token de sesión para invalidar sesiones antiguas
  static const String _keySessionToken = 'session_token';

  static const String userTypeAdmin = 'admin';
  static const String userTypeStudent = 'student';
  static const String userTypeAsistente = 'asistente';
  static const String userTypeJurado = 'jurado';

  static const String adminEmail = 'admin';
  static const String adminPassword = 'admin_2025*.';
  static const String asistenteEmail = 'society';
  static const String asistentePassword = 'society@2025';
  static const String juradoEmail = 'jurado';
  static const String juradoPassword = 'jurado123';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final Map<String, Map<String, dynamic>> _userCache = {};
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(hours: 24);
  static List<Map<String, dynamic>>? _studentsCache;
  static DateTime? _studentsCacheTimestamp;
  static const Duration _studentsCacheDuration = Duration(hours: 1);

  static void clearStudentsCache() {
    _studentsCache = null;
    _studentsCacheTimestamp = null;
    print('🗑️ Caché de estudiantes limpiado');
  }
static String _generateToken() {
  return DateTime.now().millisecondsSinceEpoch.toString();
}
static Future<String> verificarSesionEstudiante({
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

    if (!doc.exists) return 'error';

    final data = doc.data()!;
    final sessionActive = data['sessionActive'] ?? false;

    if (sessionActive == true) {
      return 'bloqueado';
    }
    return 'libre';
  } catch (e) {
    print('❌ Error verificando sesión estudiante: $e');
    return 'error';
  }
}
static Future<bool> activarSesionEstudiante({
  required String carreraPath,
  required String studentId,
}) async {
  try {
    final token = _generateToken();

    // Verificar si es primera vez ANTES de activar
    final doc = await _firestore
        .collection('users')
        .doc(carreraPath)
        .collection('students')
        .doc(studentId)
        .get();

    final esPrimeraVez = doc.exists
        ? (doc.data()?['primeraVez'] ?? true) == true
        : true;

    await _firestore
        .collection('users')
        .doc(carreraPath)
        .collection('students')
        .doc(studentId)
        .update({
      'sessionActive': true,
      'sessionToken': token,
      'lastLogin': FieldValue.serverTimestamp(),
      'primeraVez': false, // Ya no es primera vez
    });

    // Guardar token y flag de primera vez localmente
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySessionToken, token);
    await prefs.setBool('es_primera_vez_advertencia', esPrimeraVez);

    print('✅ Sesión estudiante activada. Primera vez: $esPrimeraVez');
    return true;
  } catch (e) {
    print('❌ Error activando sesión estudiante: $e');
    return false;
  }
}
/// Se consume una sola vez (se borra tras leerlo).
static Future<bool> debemostrarAdvertenciaPrimeraVez() async {
  final prefs = await SharedPreferences.getInstance();
  final valor = prefs.getBool('es_primera_vez_advertencia') ?? false;
  // Limpiar para no volver a mostrarlo
  await prefs.remove('es_primera_vez_advertencia');
  return valor;
}
static Future<void> cerrarSesionEstudiante() async {
  try {
    final userIdPath = await getCurrentUserId();
    if (userIdPath == null || !userIdPath.contains('/')) return;

    final parts = userIdPath.split('/');
    final carreraPath = parts[0];
    final studentId = parts[1];

    await _firestore
        .collection('users')
        .doc(carreraPath)
        .collection('students')
        .doc(studentId)
        .update({
      'sessionActive': true,
      'sessionToken': null,
    });

    print('✅ Sesión estudiante cerrada en Firestore');
  } catch (e) {
    print('❌ Error cerrando sesión estudiante en Firestore: $e');
  }
}
  // ✅ NUEVO: Verificar si la sesión del admin sigue siendo válida
  static Future<bool> isSessionValid() async {
    try {
      final userType = await getUserType();

      // Solo verificar para admin y asistente
      if (userType != userTypeAdmin && userType != userTypeAsistente) {
        return true;
      }

      final prefs = await SharedPreferences.getInstance();
      final localToken = prefs.getString(_keySessionToken);
      final userId = await getCurrentUserId();

      if (localToken == null || userId == null) return false;

      // Consultar contraseña actual en Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final currentPassword = userDoc.data()?['password'];

      // Si el token local no coincide con la contraseña en Firestore → sesión inválida
      final isValid = localToken == currentPassword;

      if (!isValid) {
        print(
          '🔒 Sesión invalidada: la contraseña fue cambiada en otro dispositivo',
        );
      }

      return isValid;
    } catch (e) {
      print('Error validando sesión: $e');
      return false;
    }
  }

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserType, userTypeAdminCarrera);
    await prefs.setString(_keyUserName, userName);
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyAdminCarreraFilial, filial);
    await prefs.setString(_keyAdminCarreraFilialNombre, filialNombre);
    await prefs.setString(_keyAdminCarreraFacultad, facultad);
    await prefs.setString(_keyAdminCarreraCarrera, carrera);
    await prefs.setString(_keyAdminCarreraCarreraId, carreraId);
    await prefs.setString(_keyAdminCarreraPermisos, permisos.join(','));
    await prefs.setBool(_keyIsLoggedIn, true);
    print('✅ Datos de admin carrera guardados en sesión');
  }

  static Future<String?> getAdminCarreraFilial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAdminCarreraFilial);
  }

  static Future<String?> getAdminCarreraFilialNombre() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAdminCarreraFilialNombre);
  }

  static Future<String?> getAdminCarreraFacultad() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAdminCarreraFacultad);
  }

  static Future<String?> getAdminCarreraCarrera() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAdminCarreraCarrera);
  }

  static Future<String?> getAdminCarreraCarreraId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAdminCarreraCarreraId);
  }

  static Future<List<String>> getAdminCarreraPermisos() async {
    final prefs = await SharedPreferences.getInstance();
    final permisosString = prefs.getString(_keyAdminCarreraPermisos);
    if (permisosString == null || permisosString.isEmpty) return [];
    return permisosString.split(',');
  }

  static Future<bool> isAdminCarrera() async {
    final userType = await getUserType();
    return userType == userTypeAdminCarrera;
  }

  static Future<Map<String, dynamic>?> getAdminCarreraData() async {
    final isAdmin = await isAdminCarrera();
    if (!isAdmin) return null;

    return {
      'userId': await getCurrentUserId(),
      'userName': await getUserName(),
      'filial': await getAdminCarreraFilial(),
      'filialNombre': await getAdminCarreraFilialNombre(),
      'facultad': await getAdminCarreraFacultad(),
      'carrera': await getAdminCarreraCarrera(),
      'carreraId': await getAdminCarreraCarreraId(),
      'permisos': await getAdminCarreraPermisos(),
    };
  }

  static Future<bool> tienePermiso(String permiso) async {
    final permisos = await getAdminCarreraPermisos();
    return permisos.contains(permiso);
  }

  static Future<void> saveUserData({
    required String userType,
    required String userName,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserType, userType);
    await prefs.setString(_keyUserName, userName);
    await prefs.setString(_keyUserId, userId);
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<String?> getUserType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserType);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  static Future<bool> loginAdmin(String email, String password) async {
    try {
      // ═══════════════════════════════════════════════════════════
      // 🔐 LOGIN ADMIN
      // ═══════════════════════════════════════════════════════════
      if (email.trim() == adminEmail) {
        print('🔍 Buscando admin en Firestore...');

        final adminQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: adminEmail)
            .where('userType', isEqualTo: userTypeAdmin)
            .limit(1)
            .get();

        String adminId;

        if (adminQuery.docs.isEmpty) {
          print('📝 Admin no existe, creando en Firestore...');
          final adminDoc = await _firestore.collection('users').add({
            'email': adminEmail,
            'password': password,
            'userType': userTypeAdmin,
            'name': 'Administrador',
            'createdAt': FieldValue.serverTimestamp(),
          });
          adminId = adminDoc.id;
          print('✅ Admin creado con contraseña: $password');

          await saveUserData(
            userType: userTypeAdmin,
            userName: 'Administrador',
            userId: adminId,
          );
          // ✅ Guardar token de sesión
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keySessionToken, password);
          return true;
        } else {
          adminId = adminQuery.docs.first.id;
          final adminData = adminQuery.docs.first.data();
          final firestorePassword = adminData['password'];

          print('🔍 Admin encontrado en Firestore');

          if (password == firestorePassword) {
            print('✅ Contraseña correcta (validada desde Firestore)');

            await saveUserData(
              userType: userTypeAdmin,
              userName: 'Administrador',
              userId: adminId,
            );
            // ✅ Guardar token de sesión con la contraseña actual
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_keySessionToken, firestorePassword);
            return true;
          } else {
            print('❌ Contraseña incorrecta');
            return false;
          }
        }
      }
      // ═══════════════════════════════════════════════════════════
      // 🔐 LOGIN ASISTENTE
      // ═══════════════════════════════════════════════════════════
      else if (email.trim() == asistenteEmail) {
        print('🔍 Buscando asistente en Firestore...');

        final asistenteQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: asistenteEmail)
            .where('userType', isEqualTo: userTypeAsistente)
            .limit(1)
            .get();

        String asistenteId;

        if (asistenteQuery.docs.isEmpty) {
          print('📝 Asistente no existe, creando en Firestore...');
          final asistenteDoc = await _firestore.collection('users').add({
            'email': asistenteEmail,
            'password': password,
            'userType': userTypeAsistente,
            'name': 'Asistente',
            'createdAt': FieldValue.serverTimestamp(),
          });
          asistenteId = asistenteDoc.id;
          print('✅ Asistente creado con contraseña: $password');

          await saveUserData(
            userType: userTypeAsistente,
            userName: 'Asistente',
            userId: asistenteId,
          );
          // ✅ Guardar token de sesión
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keySessionToken, password);
          return true;
        } else {
          asistenteId = asistenteQuery.docs.first.id;
          final asistenteData = asistenteQuery.docs.first.data();
          final firestorePassword = asistenteData['password'];

          print('🔍 Asistente encontrado en Firestore');

          if (password == firestorePassword) {
            print('✅ Contraseña correcta (validada desde Firestore)');

            await saveUserData(
              userType: userTypeAsistente,
              userName: 'Asistente',
              userId: asistenteId,
            );
            // ✅ Guardar token de sesión con la contraseña actual
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_keySessionToken, firestorePassword);
            return true;
          } else {
            print('❌ Contraseña incorrecta');
            return false;
          }
        }
      }

      print('❌ Usuario no reconocido: $email');
      return false;
    } catch (e) {
      print('❌ Error en login admin/asistente: $e');
      return false;
    }
  }

  static String generateUsername(String fullName) {
    final nameParts = fullName.trim().toLowerCase().split(' ');

    if (nameParts.length >= 3) {
      return '${nameParts[0]}.${nameParts[2]}';
    } else if (nameParts.length == 2) {
      return '${nameParts[0]}.${nameParts[1]}';
    } else if (nameParts.length == 1) {
      return nameParts[0];
    }

    return fullName.toLowerCase().replaceAll(' ', '.');
  }

  static Future<bool> loginStudent(String username, String password) async {
    try {
      print('🔐 Intentando login de estudiante...');
      print('   Usuario: $username');

      final indexQuery = await _firestore
          .collection('student_index')
          .where('username', isEqualTo: username.trim().toLowerCase())
          .limit(1)
          .get();

      if (indexQuery.docs.isNotEmpty) {
        final indexData = indexQuery.docs.first.data();
        final carreraPath = indexData['carreraPath'];
        final studentId = indexData['studentId'];

        print('✅ Usuario encontrado en índice');

        final studentDoc = await _firestore
            .collection('users')
            .doc(carreraPath)
            .collection('students')
            .doc(studentId)
            .get();

        if (!studentDoc.exists) {
          print('⚠️ Índice corrupto detectado, limpiando...');
          await _firestore
              .collection('student_index')
              .doc(username.trim().toLowerCase())
              .delete();

          print('🔄 Reintentando búsqueda manual...');
          return await _loginStudentFallback(username, password);
        }

        final studentData = studentDoc.data()!;
        final storedPassword = studentData['dni'] ?? studentData['documento'];

        if (storedPassword == password) {
          print('✅ Contraseña correcta');

          await saveUserData(
            userType: userTypeStudent,
            userName: studentData['name'] ?? 'Estudiante',
            userId: '$carreraPath/$studentId',
          );

          _userCache[studentId] = studentData;
          _cacheTimestamp = DateTime.now();

          return true;
        } else {
          print('❌ Contraseña incorrecta');
          return false;
        }
      }

      print('⚠️ Usuario no encontrado en índice, buscando manualmente...');
      return await _loginStudentFallback(username, password);
    } catch (e) {
      print('❌ Error en login estudiante: $e');
      return false;
    }
  }

  static Future<bool> _loginStudentFallback(
    String username,
    String password,
  ) async {
    try {
      final carrerasSnapshot = await _firestore.collection('users').get();

      for (var carreraDoc in carrerasSnapshot.docs) {
        final carreraName = carreraDoc.id;

        if (carreraName == 'admin' ||
            carreraName == 'asistente' ||
            carreraName == 'jurado') {
          continue;
        }

        try {
          final studentQuery = await _firestore
              .collection('users')
              .doc(carreraName)
              .collection('students')
              .where('username', isEqualTo: username.trim().toLowerCase())
              .limit(1)
              .get();

          if (studentQuery.docs.isNotEmpty) {
            final studentDoc = studentQuery.docs.first;
            final studentData = studentDoc.data();
            final storedPassword =
                studentData['dni'] ?? studentData['documento'];

            if (storedPassword == password) {
              await saveUserData(
                userType: userTypeStudent,
                userName: studentData['name'] ?? 'Estudiante',
                userId: '$carreraName/${studentDoc.id}',
              );

              await _createStudentIndex(
                username: username.trim().toLowerCase(),
                carreraPath: carreraName,
                studentId: studentDoc.id,
              );

              return true;
            }
          }
        } catch (e) {
          print('⚠️ Error buscando en $carreraName: $e');
          continue;
        }
      }

      return false;
    } catch (e) {
      print('❌ Error en fallback login: $e');
      return false;
    }
  }

  static Future<void> _createStudentIndex({
    required String username,
    required String carreraPath,
    required String studentId,
  }) async {
    try {
      await _firestore.collection('student_index').doc(username).set({
        'username': username,
        'carreraPath': carreraPath,
        'studentId': studentId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ Índice creado para $username');
    } catch (e) {
      print('⚠️ Error creando índice: $e');
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
    String? modoContrato,
    String? modalidadEstudio,
    String? sede,
    String? ciclo,
    String? grupo,
    String? correoInstitucional,
    String? celular,
  }) async {
    try {
      print('🔍 Creando estudiante en: $carrera');

      final indexExists = await _firestore
          .collection('student_index')
          .doc(username.toLowerCase().trim())
          .get();

      if (indexExists.exists) {
        print('❌ Username ya existe en índice');
        return false;
      }

      final studentsRef = _firestore
          .collection('users')
          .doc(carrera)
          .collection('students');

      final existingUsername = await studentsRef
          .where('username', isEqualTo: username.trim().toLowerCase())
          .limit(1)
          .get();

      if (existingUsername.docs.isNotEmpty) {
        print('❌ Username ya existe en esta carrera');
        return false;
      }

      if (email.trim().isNotEmpty) {
        final existingEmail = await studentsRef
            .where('email', isEqualTo: email.trim())
            .limit(1)
            .get();

        if (existingEmail.docs.isNotEmpty) {
          print('❌ Email ya existe en esta carrera');
          return false;
        }
      }

      if (codigoUniversitario.trim().isNotEmpty) {
        final existingCode = await studentsRef
            .where('codigoUniversitario', isEqualTo: codigoUniversitario.trim())
            .limit(1)
            .get();

        if (existingCode.docs.isNotEmpty) {
          print('❌ Código universitario ya existe en esta carrera');
          return false;
        }
      }

      final existingDni = await studentsRef
          .where('dni', isEqualTo: dni.trim())
          .limit(1)
          .get();

      if (existingDni.docs.isNotEmpty) {
        print('❌ DNI ya existe en esta carrera');
        return false;
      }

      final carreraRef = _firestore.collection('users').doc(carrera);

      final studentData = {
        'email': email.trim(),
        'name': name.trim(),
        'username': username.toLowerCase().trim(),
        'codigoUniversitario': codigoUniversitario.trim(),
        'dni': dni.trim(),
        'documento': dni.trim(),
        'facultad': facultad,
        'carrera': carrera,
        'userType': userTypeStudent,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (modoContrato != null && modoContrato.isNotEmpty) {
        studentData['modoContrato'] = modoContrato;
      }
      if (modalidadEstudio != null && modalidadEstudio.isNotEmpty) {
        studentData['modalidadEstudio'] = modalidadEstudio;
      }
      if (sede != null && sede.isNotEmpty) {
        studentData['sede'] = sede;
      }
      if (ciclo != null && ciclo.isNotEmpty) {
        studentData['ciclo'] = ciclo;
      }
      if (grupo != null && grupo.isNotEmpty) {
        studentData['grupo'] = grupo;
      }
      if (correoInstitucional != null && correoInstitucional.isNotEmpty) {
        studentData['correoInstitucional'] = correoInstitucional.trim();
      }
      if (celular != null && celular.isNotEmpty) {
        studentData['celular'] = celular.trim();
      }

      final studentDoc = await studentsRef.add(studentData);

      await _createStudentIndex(
        username: username.toLowerCase().trim(),
        carreraPath: carrera,
        studentId: studentDoc.id,
      );

      await carreraRef.set({
        'name': carrera,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Estudiante creado: ${studentDoc.id}');

      clearStudentsCache();
      return true;
    } catch (e) {
      print('❌ Error creando estudiante: $e');
      return false;
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
            print('✅ Datos obtenidos del caché');
            return _userCache[studentId];
          }
        }
      }

      if (userIdPath.contains('/')) {
        final parts = userIdPath.split('/');
        if (parts.length != 2) return null;

        final carreraPath = parts[0];
        final studentId = parts[1];

        final userDoc = await _firestore
            .collection('users')
            .doc(carreraPath)
            .collection('students')
            .doc(studentId)
            .get();

        if (!userDoc.exists) return null;

        final userData = userDoc.data()!;
        userData['id'] = userDoc.id;
        userData['carreraPath'] = carreraPath;

        _userCache[studentId] = userData;
        _cacheTimestamp = DateTime.now();

        return userData;
      } else {
        final userDoc = await _firestore
            .collection('users')
            .doc(userIdPath)
            .get();

        if (!userDoc.exists) return null;

        final userData = userDoc.data()!;
        userData['id'] = userDoc.id;
        return userData;
      }
    } catch (e) {
      print('Error obteniendo datos del usuario: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getStudentsByCarrera(
    String carrera,
  ) async {
    try {
      final studentsQuery = await _firestore
          .collection('users')
          .doc(carrera)
          .collection('students')
          .orderBy('createdAt', descending: true)
          .get();

      return studentsQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['carreraPath'] = carrera;
        return data;
      }).toList();
    } catch (e) {
      print('Error obteniendo estudiantes de $carrera: $e');
      return [];
    }
  }

  static Future<List<String>> getCarreras() async {
    try {
      final carrerasSnapshot = await _firestore.collection('users').get();
      return carrerasSnapshot.docs
          .map((doc) => doc.id)
          .where((id) => id != 'admin' && id != 'asistente' && id != 'jurado')
          .toList();
    } catch (e) {
      print('Error obteniendo carreras: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getStudents() async {
    try {
      if (_studentsCache != null &&
          _studentsCacheTimestamp != null &&
          DateTime.now().difference(_studentsCacheTimestamp!) <
              _studentsCacheDuration) {
        print('✅ Estudiantes obtenidos del caché');
        return _studentsCache!;
      }

      List<Map<String, dynamic>> allStudents = [];
      final carrerasSnapshot = await _firestore.collection('users').get();

      for (var carreraDoc in carrerasSnapshot.docs) {
        if (carreraDoc.id == 'admin' ||
            carreraDoc.id == 'asistente' ||
            carreraDoc.id == 'jurado') {
          continue;
        }

        final studentsQuery = await _firestore
            .collection('users')
            .doc(carreraDoc.id)
            .collection('students')
            .orderBy('createdAt', descending: true)
            .get();

        for (var studentDoc in studentsQuery.docs) {
          final data = studentDoc.data();
          data['id'] = studentDoc.id;
          data['carreraPath'] = carreraDoc.id;
          allStudents.add(data);
        }
      }

      _studentsCache = allStudents;
      _studentsCacheTimestamp = DateTime.now();

      return allStudents;
    } catch (e) {
      print('Error obteniendo estudiantes: $e');
      return [];
    }
  }

  static Future<bool> deleteStudent(
    String carreraPath,
    String studentId,
  ) async {
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
          await _firestore.collection('student_index').doc(username).delete();
        }
      }

      await _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .doc(studentId)
          .delete();

      _userCache.remove(studentId);

      print('Estudiante eliminado exitosamente de $carreraPath');
      clearStudentsCache();
      return true;
    } catch (e) {
      print('Error eliminando estudiante: $e');
      return false;
    }
  }

  static Future<Map<String, int>> deleteMultipleStudents(
    List<Map<String, String>> students,
  ) async {
    int successCount = 0;
    int errorCount = 0;

    try {
      const batchSize = 450;

      for (int i = 0; i < students.length; i += batchSize) {
        final batch = _firestore.batch();
        final endIndex = (i + batchSize < students.length)
            ? i + batchSize
            : students.length;

        final currentBatch = students.sublist(i, endIndex);

        for (var student in currentBatch) {
          try {
            final studentRef = _firestore
                .collection('users')
                .doc(student['carreraPath'])
                .collection('students')
                .doc(student['studentId']);

            final studentData = _userCache[student['studentId']];

            if (studentData != null) {
              final username = studentData['username'];
              if (username != null) {
                final indexRef = _firestore
                    .collection('student_index')
                    .doc(username);
                batch.delete(indexRef);
              }
            }

            batch.delete(studentRef);
            successCount++;
          } catch (e) {
            print(
              '❌ Error preparando eliminación de ${student['studentId']}: $e',
            );
            errorCount++;
          }
        }

        try {
          await batch.commit();
        } catch (e) {
          print('❌ Error ejecutando batch: $e');
          errorCount += currentBatch.length - successCount;
        }
      }

      _userCache.clear();
      _cacheTimestamp = null;

      clearStudentsCache();
      return {'success': successCount, 'errors': errorCount};
    } catch (e) {
      print('❌ Error general en eliminación masiva: $e');
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
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name.trim();
      if (email != null) updateData['email'] = email.trim();
      if (codigoUniversitario != null) {
        updateData['codigoUniversitario'] = codigoUniversitario.trim();
      }
      if (dni != null) {
        updateData['dni'] = dni.trim();
        updateData['documento'] = dni.trim();
      }
      if (facultad != null) updateData['facultad'] = facultad;
      if (carrera != null) updateData['carrera'] = carrera;
      if (modoContrato != null) updateData['modoContrato'] = modoContrato;
      if (modalidadEstudio != null) {
        updateData['modalidadEstudio'] = modalidadEstudio;
      }
      if (sede != null) updateData['sede'] = sede;
      if (ciclo != null) updateData['ciclo'] = ciclo;
      if (grupo != null) updateData['grupo'] = grupo;
      if (correoInstitucional != null) {
        updateData['correoInstitucional'] = correoInstitucional.trim();
      }
      if (celular != null) updateData['celular'] = celular.trim();

      await _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .doc(studentId)
          .update(updateData);

      _userCache.remove(studentId);

      print('Estudiante actualizado exitosamente');
      clearStudentsCache();
      return true;
    } catch (e) {
      print('Error actualizando estudiante: $e');
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
      final studentId = parts[1];

      final userDoc = await _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .doc(studentId)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final storedPassword = userData['dni'] ?? userData['documento'];

      if (storedPassword != currentPassword) {
        print('Contraseña actual incorrecta');
        return false;
      }

      await _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .doc(studentId)
          .update({
            'dni': newPassword,
            'documento': newPassword,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      _userCache.remove(studentId);

      print('Contraseña actualizada exitosamente');
      return true;
    } catch (e) {
      print('Error cambiando contraseña: $e');
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

        if (ciclo != null && ciclo.isNotEmpty) {
          query = query.where('ciclo', isEqualTo: ciclo);
        }
        if (grupo != null && grupo.isNotEmpty) {
          query = query.where('grupo', isEqualTo: grupo);
        }
        if (sede != null && sede.isNotEmpty) {
          query = query.where('sede', isEqualTo: sede);
        }

        final results = await query.get();
        allStudents = results.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          data['carreraPath'] = carrera;
          return data;
        }).toList();
      } else {
        final carrerasSnapshot = await _firestore.collection('users').get();

        for (var carreraDoc in carrerasSnapshot.docs) {
          if (carreraDoc.id == 'admin' ||
              carreraDoc.id == 'asistente' ||
              carreraDoc.id == 'jurado') {
            continue;
          }

          Query query = _firestore
              .collection('users')
              .doc(carreraDoc.id)
              .collection('students');

          if (ciclo != null && ciclo.isNotEmpty) {
            query = query.where('ciclo', isEqualTo: ciclo);
          }
          if (grupo != null && grupo.isNotEmpty) {
            query = query.where('grupo', isEqualTo: grupo);
          }
          if (sede != null && sede.isNotEmpty) {
            query = query.where('sede', isEqualTo: sede);
          }

          final results = await query.get();
          for (var doc in results.docs) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            data['carreraPath'] = carreraDoc.id;
            allStudents.add(data);
          }
        }
      }

      if (facultad != null && facultad.isNotEmpty) {
        allStudents = allStudents
            .where((s) => s['facultad'] == facultad)
            .toList();
      }

      if (searchTerm != null && searchTerm.isNotEmpty) {
        final searchLower = searchTerm.toLowerCase();
        allStudents = allStudents.where((student) {
          final name = (student['name'] ?? '').toString().toLowerCase();
          final username = (student['username'] ?? '').toString().toLowerCase();
          final codigo = (student['codigoUniversitario'] ?? '')
              .toString()
              .toLowerCase();
          final dni = (student['dni'] ?? '').toString().toLowerCase();

          return name.contains(searchLower) ||
              username.contains(searchLower) ||
              codigo.contains(searchLower) ||
              dni.contains(searchLower);
        }).toList();
      }

      return allStudents;
    } catch (e) {
      print('Error buscando estudiantes: $e');
      return [];
    }
  }

  static Future<Map<String, int>> deleteAllStudents() async {
    try {
      int successCount = 0;
      int errorCount = 0;

      final carrerasSnapshot = await _firestore.collection('users').get();

      for (var carreraDoc in carrerasSnapshot.docs) {
        if (carreraDoc.id == 'admin' ||
            carreraDoc.id == 'asistente' ||
            carreraDoc.id == 'jurado') {
          continue;
        }

        final studentsQuery = await _firestore
            .collection('users')
            .doc(carreraDoc.id)
            .collection('students')
            .get();

        for (var studentDoc in studentsQuery.docs) {
          try {
            final username = studentDoc.data()['username'];
            if (username != null) {
              await _firestore
                  .collection('student_index')
                  .doc(username)
                  .delete();
            }

            await studentDoc.reference.delete();
            successCount++;
          } catch (e) {
            print('Error eliminando estudiante ${studentDoc.id}: $e');
            errorCount++;
          }
        }
      }

      _userCache.clear();
      _cacheTimestamp = null;

      return {'success': successCount, 'errors': errorCount};
    } catch (e) {
      print('Error eliminando todos los estudiantes: $e');
      return {'success': 0, 'errors': -1};
    }
  }

  static Future<bool> createJuradoAccount({
    required String nombre,
    required String usuario,
    required String password,
    required String facultad,
    required String carrera,
    required String categoria,
  }) async {
    try {
      final existingJurado = await _firestore
          .collection('users')
          .where('usuario', isEqualTo: usuario.trim().toLowerCase())
          .where('userType', isEqualTo: userTypeJurado)
          .limit(1)
          .get();

      if (existingJurado.docs.isNotEmpty) {
        print('Ya existe un jurado con ese nombre de usuario');
        return false;
      }

      await _firestore.collection('users').add({
        'usuario': usuario.trim().toLowerCase(),
        'password': password,
        'userType': userTypeJurado,
        'name': nombre.trim(),
        'facultad': facultad,
        'carrera': carrera,
        'categoria': categoria,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Jurado creado exitosamente: $nombre');
      return true;
    } catch (e) {
      print('Error creando cuenta de jurado: $e');
      return false;
    }
  }

  static Future<bool> loginJurado(String usuario, String password) async {
    try {
      print('🔍 Intentando login jurado con usuario: $usuario');

      if (usuario.trim().toLowerCase() == juradoEmail &&
          password == juradoPassword) {
        final juradoQuery = await _firestore
            .collection('users')
            .where('usuario', isEqualTo: juradoEmail)
            .where('userType', isEqualTo: userTypeJurado)
            .limit(1)
            .get();

        String juradoId;
        if (juradoQuery.docs.isEmpty) {
          final juradoDoc = await _firestore.collection('users').add({
            'usuario': juradoEmail,
            'password': juradoPassword,
            'userType': userTypeJurado,
            'name': 'Jurado',
            'createdAt': FieldValue.serverTimestamp(),
          });
          juradoId = juradoDoc.id;
        } else {
          juradoId = juradoQuery.docs.first.id;
        }

        await saveUserData(
          userType: userTypeJurado,
          userName: 'Jurado',
          userId: juradoId,
        );

        return true;
      }

      final juradoQuery = await _firestore
          .collection('users')
          .where('usuario', isEqualTo: usuario.trim().toLowerCase())
          .where('userType', isEqualTo: userTypeJurado)
          .limit(1)
          .get();

      if (juradoQuery.docs.isNotEmpty) {
        final juradoDoc = juradoQuery.docs.first;
        final juradoData = juradoDoc.data();

        if (juradoData['password'] == password) {
          await saveUserData(
            userType: userTypeJurado,
            userName: juradoData['name'] ?? 'Jurado',
            userId: juradoDoc.id,
          );
          return true;
        }
      }

      return false;
    } catch (e) {
      print('❌ Error en login de jurado: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getJurados() async {
    try {
      final juradosQuery = await _firestore
          .collection('users')
          .where('userType', isEqualTo: userTypeJurado)
          .orderBy('createdAt', descending: true)
          .get();

      return juradosQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error obteniendo jurados: $e');
      return [];
    }
  }

  static Future<bool> deleteJurado(String juradoId) async {
    try {
      await _firestore.collection('users').doc(juradoId).delete();
      print('Jurado eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error eliminando jurado: $e');
      return false;
    }
  }

  static Future<bool> updateJurado({
    required String juradoId,
    String? nombre,
    String? usuario,
    String? password,
    String? facultad,
    String? carrera,
    String? categoria,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (nombre != null && nombre.isNotEmpty)
        updateData['name'] = nombre.trim();
      if (usuario != null && usuario.isNotEmpty) {
        updateData['usuario'] = usuario.trim().toLowerCase();
      }
      if (password != null && password.isNotEmpty)
        updateData['password'] = password;
      if (facultad != null && facultad.isNotEmpty)
        updateData['facultad'] = facultad;
      if (carrera != null && carrera.isNotEmpty)
        updateData['carrera'] = carrera;
      if (categoria != null && categoria.isNotEmpty)
        updateData['categoria'] = categoria;

      await _firestore.collection('users').doc(juradoId).update(updateData);
      print('Jurado actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error actualizando jurado: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> searchJurados({
    String? facultad,
    String? carrera,
    String? categoria,
    String? searchTerm,
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .where('userType', isEqualTo: userTypeJurado);

      if (facultad != null && facultad.isNotEmpty) {
        query = query.where('facultad', isEqualTo: facultad);
      }
      if (carrera != null && carrera.isNotEmpty) {
        query = query.where('carrera', isEqualTo: carrera);
      }
      if (categoria != null && categoria.isNotEmpty) {
        query = query.where('categoria', isEqualTo: categoria);
      }

      final results = await query.get();
      List<Map<String, dynamic>> jurados = results.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      if (searchTerm != null && searchTerm.isNotEmpty) {
        final searchLower = searchTerm.toLowerCase();
        jurados = jurados.where((jurado) {
          final name = (jurado['name'] ?? '').toString().toLowerCase();
          final usuario = (jurado['usuario'] ?? '').toString().toLowerCase();
          return name.contains(searchLower) || usuario.contains(searchLower);
        }).toList();
      }

      return jurados;
    } catch (e) {
      print('Error buscando jurados: $e');
      return [];
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserType);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keySessionToken); // ✅ Limpiar token de sesión
    await prefs.setBool(_keyIsLoggedIn, false);

    await prefs.remove(_keyAdminCarreraFilial);
    await prefs.remove(_keyAdminCarreraFilialNombre);
    await prefs.remove(_keyAdminCarreraFacultad);
    await prefs.remove(_keyAdminCarreraCarrera);
    await prefs.remove(_keyAdminCarreraCarreraId);
    await prefs.remove(_keyAdminCarreraPermisos);

    clearStudentsCache();
    _userCache.clear();
    _cacheTimestamp = null;

    FilialesService.clearCache();

    print('✅ Sesión cerrada y caché limpiado');
  }
}
