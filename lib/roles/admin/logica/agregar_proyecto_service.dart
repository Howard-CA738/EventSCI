import 'package:cloud_firestore/cloud_firestore.dart';

class AgregarProyectoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> cargarEstudiantes({
    required String filialNombre,
    required String carrera,
  }) async {
    final docKey = '${filialNombre}_$carrera';
    final snap = await _firestore
        .collection('users')
        .doc(docKey)
        .collection('students')
        .orderBy('name')
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();
  }
}
