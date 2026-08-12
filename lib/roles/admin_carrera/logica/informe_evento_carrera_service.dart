import 'package:cloud_firestore/cloud_firestore.dart';

class InformeEventoCarreraService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> cargarEventos({
    required String? filialId,
    required String? facultad,
    required String? carrera,
  }) async {
    final snapshot = await _firestore
        .collection('events')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.where((doc) {
      final data = doc.data();

      if (filialId != null && filialId.isNotEmpty) {
        final eventoFilial = data['filialId']?.toString() ?? '';
        if (eventoFilial != filialId) return false;
      }

      if (facultad != null && facultad.isNotEmpty) {
        if (data['facultad'] != facultad) return false;
      }

      if (carrera != null && carrera.isNotEmpty) {
        final eventoCarrera = data['carreraNombre']?.toString() ??
            data['carrera']?.toString() ??
            '';
        if (eventoCarrera != carrera) return false;
      }

      return true;
    }).map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'] ?? 'Sin nombre',
        'facultad': data['facultad'] ?? '',
        'carrera': data['carreraNombre'] ?? data['carrera'] ?? '',
        'fecha': data['fecha'] ?? '',
        'createdAt': data['createdAt'],
      };
    }).toList();
  }
}
