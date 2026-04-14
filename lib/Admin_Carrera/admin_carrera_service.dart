import 'package:cloud_firestore/cloud_firestore.dart';

class AdminCarreraService {
  static final AdminCarreraService _instance = AdminCarreraService._internal();
  factory AdminCarreraService() => _instance;
  AdminCarreraService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const List<String> _permisosCompletos = [
    'estudiantes',
    'grupos',
    'proyectos',
    'evaluaciones',
    'reportes',
    'eventos',
  ];

  // ═══════════════════════════════════════════════════════════════
  // ✅ CREAR ADMIN DE CARRERA
  // ═══════════════════════════════════════════════════════════════
  Future<bool> crearAdminCarrera({
    required String usuario,
    required String password,
    required String filial,
    required String filialNombre,
    required String facultad,
    required String carrera,
    required String carreraId,
    List<String>? permisos,
  }) async {
    try {
      final existingAdmin = await _firestore
          .collection('admins_carrera')
          .where('usuario', isEqualTo: usuario.trim().toLowerCase())
          .limit(1)
          .get();

      if (existingAdmin.docs.isNotEmpty) {
        print('❌ Ya existe un admin con ese usuario');
        return false;
      }

      await _firestore.collection('admins_carrera').add({
        'usuario': usuario.trim().toLowerCase(),
        'password': password,
        'filial': filial,
        'filialNombre': filialNombre,
        'facultad': facultad,
        'carrera': carrera,
        'carreraId': carreraId,
        'permisos': _permisosCompletos,
        'activo': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Admin de carrera creado: $usuario');
      return true;
    } catch (e) {
      print('❌ Error creando admin de carrera: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ LOGIN ADMIN CARRERA
  // ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>?> loginAdminCarrera({
    required String usuario,
    required String password,
  }) async {
    try {
      print('🔍 Buscando admin de carrera: $usuario');

      final adminQuery = await _firestore
          .collection('admins_carrera')
          .where('usuario', isEqualTo: usuario.trim().toLowerCase())
          .where('activo', isEqualTo: true)
          .limit(1)
          .get();

      if (adminQuery.docs.isEmpty) {
        print('❌ Admin de carrera no encontrado');
        return null;
      }

      final adminDoc = adminQuery.docs.first;
      final adminData = adminDoc.data();

      if (adminData['password'] != password) {
        print('❌ Contraseña incorrecta');
        return null;
      }

      final permisosBD = List<String>.from(adminData['permisos'] ?? []);
      final tienePermisosFaltantes =
          _permisosCompletos.any((p) => !permisosBD.contains(p));

      if (tienePermisosFaltantes) {
        await _firestore
            .collection('admins_carrera')
            .doc(adminDoc.id)
            .update({'permisos': _permisosCompletos});
        print('🔄 Permisos migrados para: ${adminData['usuario']}');
      }

      print('✅ Login exitoso: ${adminData['usuario']}');

      return {
        'id': adminDoc.id,
        'usuario': adminData['usuario'],
        'filial': adminData['filial'],
        'filialNombre': adminData['filialNombre'],
        'facultad': adminData['facultad'],
        'carrera': adminData['carrera'],
        'carreraId': adminData['carreraId'],
        'permisos': _permisosCompletos,
      };
    } catch (e) {
      print('❌ Error en login de admin carrera: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ OBTENER TODOS LOS ADMINS DE CARRERA
  // ═══════════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getAdminsCarrera() async {
    try {
      final adminsQuery = await _firestore
          .collection('admins_carrera')
          .orderBy('createdAt', descending: true)
          .get();

      return adminsQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Error obteniendo admins de carrera: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ OBTENER ADMIN POR ID
  // ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>?> getAdminById(String adminId) async {
    try {
      final adminDoc = await _firestore
          .collection('admins_carrera')
          .doc(adminId)
          .get();

      if (!adminDoc.exists) return null;

      final data = adminDoc.data()!;
      data['id'] = adminDoc.id;
      return data;
    } catch (e) {
      print('❌ Error obteniendo admin: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ ACTUALIZAR ADMIN DE CARRERA
  // ═══════════════════════════════════════════════════════════════
  Future<bool> actualizarAdminCarrera({
    required String adminId,
    String? usuario,
    String? password,
    String? filial,
    String? filialNombre,
    String? facultad,
    String? carrera,
    String? carreraId,
    List<String>? permisos,
    bool? activo,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (usuario != null) {
        final existing = await _firestore
            .collection('admins_carrera')
            .where('usuario', isEqualTo: usuario.trim().toLowerCase())
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty &&
            existing.docs.first.id != adminId) {
          print('❌ Ya existe otro admin con ese usuario');
          return false;
        }
        updateData['usuario'] = usuario.trim().toLowerCase();
      }

      if (password != null) updateData['password'] = password;
      if (filial != null) updateData['filial'] = filial;
      if (filialNombre != null) updateData['filialNombre'] = filialNombre;
      if (facultad != null) updateData['facultad'] = facultad;
      if (carrera != null) updateData['carrera'] = carrera;
      if (carreraId != null) updateData['carreraId'] = carreraId;
      if (activo != null) updateData['activo'] = activo;

      await _firestore
          .collection('admins_carrera')
          .doc(adminId)
          .update(updateData);

      print('✅ Admin de carrera actualizado');
      return true;
    } catch (e) {
      print('❌ Error actualizando admin de carrera: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ ELIMINAR ADMIN DE CARRERA
  // ═══════════════════════════════════════════════════════════════
  Future<bool> eliminarAdminCarrera(String adminId) async {
    try {
      await _firestore
          .collection('admins_carrera')
          .doc(adminId)
          .delete();
      print('✅ Admin de carrera eliminado');
      return true;
    } catch (e) {
      print('❌ Error eliminando admin de carrera: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ BUSCAR ADMINS CON FILTROS
  // ═══════════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> buscarAdmins({
    String? filial,
    String? facultad,
    String? carrera,
    String? searchTerm,
  }) async {
    try {
      Query query = _firestore.collection('admins_carrera');

      if (filial != null && filial.isNotEmpty) {
        query = query.where('filial', isEqualTo: filial);
      }
      if (facultad != null && facultad.isNotEmpty) {
        query = query.where('facultad', isEqualTo: facultad);
      }
      if (carrera != null && carrera.isNotEmpty) {
        query = query.where('carrera', isEqualTo: carrera);
      }

      final results = await query.get();
      List<Map<String, dynamic>> admins = results.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      if (searchTerm != null && searchTerm.isNotEmpty) {
        final searchLower = searchTerm.toLowerCase();
        admins = admins.where((admin) {
          final usuario = (admin['usuario'] ?? '').toString().toLowerCase();
          return usuario.contains(searchLower);
        }).toList();
      }

      return admins;
    } catch (e) {
      print('❌ Error buscando admins: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ OBTENER ADMINS POR CARRERA
  // ═══════════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getAdminsPorCarrera(
      String carrera) async {
    try {
      final adminsQuery = await _firestore
          .collection('admins_carrera')
          .where('carrera', isEqualTo: carrera)
          .where('activo', isEqualTo: true)
          .get();

      return adminsQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Error obteniendo admins por carrera: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ VERIFICAR SI TIENE PERMISO
  // ═══════════════════════════════════════════════════════════════
  bool tienePermiso(List<String> permisos, String permiso) {
    return permisos.contains(permiso);
  }
}