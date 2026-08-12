import 'package:cloud_firestore/cloud_firestore.dart';

class GestionRolesService {
  static const String rolEstudiante = 'estudiante';
  static const String rolAsistente = 'asistente_qr';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> localizarCarreraPath({
    required String filialNombre,
    required String carrera,
  }) async {
    final snap = await _firestore
        .collection('users')
        .where('filial', isEqualTo: filialNombre)
        .where('carrera', isEqualTo: carrera)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  Future<List<Map<String, dynamic>>> obtenerEstudiantes(
      String carreraPath) async {
    final snap = await _firestore
        .collection('users')
        .doc(carreraPath)
        .collection('students')
        .orderBy('name')
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      final bool esAsiste = data['esAsisteQR'] == true;
      data['rol'] = esAsiste ? rolAsistente : rolEstudiante;
      data['esAsisteQR'] = esAsiste;
      return data;
    }).toList();
  }

  Future<void> cambiarRol({
    required String carreraPath,
    required String studentId,
    required bool asignarAsistente,
  }) {
    return _firestore
        .collection('users')
        .doc(carreraPath)
        .collection('students')
        .doc(studentId)
        .update({
      'rol': rolEstudiante,
      'esAsisteQR': asignarAsistente,
    });
  }
}
