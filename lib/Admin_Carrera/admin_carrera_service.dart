import 'package:cloud_firestore/cloud_firestore.dart';

class AdminCarreraService {
  static final AdminCarreraService _instance = AdminCarreraService._internal();
  factory AdminCarreraService() => _instance;
  AdminCarreraService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════
  // ✅ CREAR ADMIN DE CARRERA
  // ═══════════════════════════════════════════════════════════════
  Future<bool> crearAdminCarrera({
    required String nombre,
    required String usuario,
    required String password,
    required String email,
    required String filial,
    required String filialNombre,
    required String facultad,
    required String carrera,
    required String carreraId,
    List<String>? permisos,
  }) async {
    try {
      // Verificar si ya existe un admin con ese usuario
      final existingAdmin = await _firestore
          .collection('admins_carrera')
          .where('usuario', isEqualTo: usuario.trim().toLowerCase())
          .limit(1)
          .get();

      if (existingAdmin.docs.isNotEmpty) {
        print('❌ Ya existe un admin con ese usuario');
        return false;
      }

      // Permisos por defecto
      final permisosFinales =
          permisos ??
          ['estudiantes', 'grupos', 'proyectos', 'evaluaciones', 'reportes'];

      // Crear el admin
      await _firestore.collection('admins_carrera').add({
        'nombre': nombre.trim(),
        'usuario': usuario.trim().toLowerCase(),
        'password': password,
        'email': email.trim(),
        'filial': filial,
        'filialNombre': filialNombre,
        'facultad': facultad,
        'carrera': carrera,
        'carreraId': carreraId,
        'permisos': permisosFinales,
        'activo': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Admin de carrera creado: $nombre');
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

      print('✅ Login exitoso para admin de carrera: ${adminData['nombre']}');

      return {
        'id': adminDoc.id,
        'nombre': adminData['nombre'],
        'usuario': adminData['usuario'],
        'email': adminData['email'],
        'filial': adminData['filial'],
        'filialNombre': adminData['filialNombre'],
        'facultad': adminData['facultad'],
        'carrera': adminData['carrera'],
        'carreraId': adminData['carreraId'],
        'permisos': List<String>.from(adminData['permisos'] ?? []),
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
    String? nombre,
    String? usuario,
    String? password,
    String? email,
    List<String>? permisos,
    bool? activo,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (nombre != null) updateData['nombre'] = nombre.trim();
      if (usuario != null) {
        // Verificar que no exista otro admin con ese usuario
        final existing = await _firestore
            .collection('admins_carrera')
            .where('usuario', isEqualTo: usuario.trim().toLowerCase())
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty && existing.docs.first.id != adminId) {
          print('❌ Ya existe otro admin con ese usuario');
          return false;
        }

        updateData['usuario'] = usuario.trim().toLowerCase();
      }
      if (password != null) updateData['password'] = password;
      if (email != null) updateData['email'] = email.trim();
      if (permisos != null) updateData['permisos'] = permisos;
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
      await _firestore.collection('admins_carrera').doc(adminId).delete();
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

      // Filtrar por término de búsqueda
      if (searchTerm != null && searchTerm.isNotEmpty) {
        final searchLower = searchTerm.toLowerCase();
        admins = admins.where((admin) {
          final nombre = (admin['nombre'] ?? '').toString().toLowerCase();
          final usuario = (admin['usuario'] ?? '').toString().toLowerCase();
          final email = (admin['email'] ?? '').toString().toLowerCase();

          return nombre.contains(searchLower) ||
              usuario.contains(searchLower) ||
              email.contains(searchLower);
        }).toList();
      }

      return admins;
    } catch (e) {
      print('❌ Error buscando admins: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ VERIFICAR SI TIENE PERMISO
  // ═══════════════════════════════════════════════════════════════
  bool tienePermiso(List<String> permisos, String permiso) {
    return permisos.contains(permiso);
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ OBTENER ADMINS POR CARRERA
  // ═══════════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getAdminsPorCarrera(String carrera) async {
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
}
