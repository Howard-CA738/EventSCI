import 'package:cloud_firestore/cloud_firestore.dart';
import '/password_helper.dart';
import '/jurado_security_service.dart';

class JuradosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> obtenerJurados({
    required String filialId,
    required String facultad,
    required String carreraNombre,
  }) async {
    final snap = await _firestore
        .collection('users')
        .where('userType', isEqualTo: 'jurado')
        .where('filial', isEqualTo: filialId)
        .where('facultad', isEqualTo: facultad)
        .where('carrera', isEqualTo: carreraNombre)
        .get();

    return snap.docs.map((doc) {
      final d = doc.data();
      List<String> categorias = [];
      if (d['categorias'] != null) {
        categorias = List<String>.from(d['categorias']);
      } else if (d['categoria'] != null) {
        categorias = [d['categoria']];
      }
      return {
        'id': doc.id,
        'nombre': d['name'] ?? '',
        'usuario': d['usuario'] ?? '',
        'categorias': categorias,
        'eventoId': d['eventoId'] ?? '',
        'eventoNombre': d['eventoNombre'] ?? '',
      };
    }).toList();
  }

  Future<List<String>> obtenerCategoriasPorEvento(String eventoId) async {
    final proySnap = await _firestore
        .collection('events')
        .doc(eventoId)
        .collection('proyectos')
        .get();
    final Set<String> cats = {};
    for (final p in proySnap.docs) {
      final clasificacion = p.data()['Clasificación'] as String?;
      if (clasificacion != null && clasificacion.isNotEmpty) {
        cats.add(clasificacion);
      }
    }
    return cats.toList()..sort();
  }

  Future<List<Map<String, dynamic>>> obtenerEventos({
    required String? filialId,
    required String? facultad,
    String? carreraId,
    String? carreraNombre,
  }) async {
    if (filialId == null || facultad == null) return [];

    final snap = await _firestore
        .collection('events')
        .where('filialId', isEqualTo: filialId)
        .where('facultad', isEqualTo: facultad)
        .get();

    final docs = snap.docs.where((doc) {
      final data = doc.data();
      if (carreraId != null && carreraId.isNotEmpty) {
        return data['carreraId'] == carreraId;
      }
      return data['carreraNombre'] == carreraNombre ||
          data['carrera'] == carreraNombre;
    }).toList();

    return docs
        .map((doc) => {
              'id': doc.id,
              'name': doc.data()['name'] ?? 'Sin nombre',
            })
        .toList();
  }

  Future<String> crearJurado({
    required String nombre,
    required String usuario,
    required String password,
    required List<String> categorias,
    required String eventoId,
    required String eventoNombre,
    required String? filialId,
    required String? filialNombre,
    required String? facultad,
    required String? carreraNombre,
    required String? carreraId,
  }) async {
    if (usuario.contains(' ')) {
      throw Exception('El usuario no puede contener espacios');
    }
    final usuarioRegex = RegExp(r'^[a-zA-Z0-9._\-]+$');
    if (!usuarioRegex.hasMatch(usuario)) {
      throw Exception(
          'El usuario solo puede contener letras, números, puntos, guiones y guiones bajos');
    }

    final existing = await _firestore
        .collection('users')
        .where('usuario', isEqualTo: usuario.trim())
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('El usuario "$usuario" ya está registrado');
    }

    final passwordHash = PasswordHelper.hashPassword(password);
    final docRef = await _firestore.collection('users').add({
      'name': nombre.trim(),
      'usuario': usuario.trim(),
      'password': passwordHash,
      'filial': filialId,
      'filialNombre': filialNombre,
      'facultad': facultad,
      'carrera': carreraNombre,
      'carreraId': carreraId,
      'categorias': categorias,
      'eventoId': eventoId,
      'eventoNombre': eventoNombre,
      'userType': 'jurado',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await JuradoSecurityService.encryptAndSavePassword(
      juradoId: docRef.id,
      password: password,
    );

    return docRef.id;
  }

  bool _isSha256(String value) {
    return value.length == 64 && RegExp(r'^[a-f0-9]+$').hasMatch(value);
  }

  Future<bool> actualizarJurado({
    required String id,
    required String nombre,
    required String usuario,
    required String password,
    required List<String> categorias,
    required String eventoId,
    required String eventoNombre,
  }) async {
    final Map<String, dynamic> updateData = {
      'name': nombre.trim(),
      'usuario': usuario.trim(),
      'categorias': categorias,
      'eventoId': eventoId,
      'eventoNombre': eventoNombre,
    };

    final passwordCambiada = password.isNotEmpty && !_isSha256(password);
    if (passwordCambiada) {
      updateData['password'] = PasswordHelper.hashPassword(password);
    }

    await _firestore.collection('users').doc(id).update(updateData);

    if (passwordCambiada) {
      await JuradoSecurityService.encryptAndSavePassword(
        juradoId: id,
        password: password,
      );
    }

    return passwordCambiada;
  }

  Future<void> eliminarJurado(String id) {
    return _firestore.collection('users').doc(id).delete();
  }
}
