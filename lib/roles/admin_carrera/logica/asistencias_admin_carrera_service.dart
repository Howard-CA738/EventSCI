import 'package:cloud_firestore/cloud_firestore.dart';

class AsistenciasAdminCarreraService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> cargarEventos({
    required String filialId,
    required String filialNombre,
    required String facultad,
    required String carrera,
  }) async {
    final snap = await _firestore
        .collection('events')
        .orderBy('createdAt', descending: true)
        .get();

    final todos = snap.docs.map((doc) {
      final d = doc.data();
      return {
        'id': doc.id,
        'name': d['name'] ?? 'Sin nombre',
        'filialId': d['filialId'] ?? '',
        'filialNombre': d['filialNombre'] ?? d['sede'] ?? '',
        'sede': d['sede'] ?? d['filialNombre'] ?? '',
        'facultad': d['facultad'] ?? '',
        'carreraNombre': d['carreraNombre'] ?? d['carrera'] ?? '',
        'carrera': d['carrera'] ?? '',
        'carreraId': d['carreraId'] ?? '',
      };
    }).toList();

    return todos.where((e) {
      final filialMatch = e['filialId'] == filialId ||
          e['filialNombre'] == filialNombre ||
          e['sede'] == filialNombre;
      if (!filialMatch) return false;

      final facultadMatch = e['facultad'] == facultad;
      if (!facultadMatch) return false;

      final carreraMatch =
          e['carreraNombre'] == carrera || e['carrera'] == carrera;
      return carreraMatch;
    }).toList();
  }

}
