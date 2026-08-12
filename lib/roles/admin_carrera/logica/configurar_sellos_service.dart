import 'package:cloud_firestore/cloud_firestore.dart';

class ConfigurarSellosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String docId({
    required String? filialId,
    required String? facultad,
    required String? carreraId,
    required String eventoId,
  }) =>
      '${filialId}_${facultad}_${carreraId}_$eventoId'
          .replaceAll(' ', '_')
          .replaceAll('/', '_')
          .replaceAll('.', '_');

  Future<List<Map<String, dynamic>>> cargarEventos({
    required String? filialId,
    required String? facultad,
    required String? carreraId,
  }) async {
    final snap = await _firestore
        .collection('events')
        .where('filialId', isEqualTo: filialId)
        .where('facultad', isEqualTo: facultad)
        .where('carreraId', isEqualTo: carreraId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'] ?? 'Sin nombre',
        'date': data['fecha'],
      };
    }).toList();
  }

  Future<int?> cargarConfigEvento({
    required String? filialId,
    required String? facultad,
    required String? carreraId,
    required String eventoId,
  }) async {
    final doc = await _firestore
        .collection('sellos_asistencia')
        .doc(docId(
            filialId: filialId,
            facultad: facultad,
            carreraId: carreraId,
            eventoId: eventoId))
        .get();

    if (!doc.exists) return null;
    final meta = doc.data()!['meta'];
    return (meta is int && meta > 0) ? meta : null;
  }

  Future<void> guardarMeta({
    required String? filialId,
    required String? facultad,
    required String? carreraId,
    required String? carreraNombre,
    required String eventoId,
    required String? eventoNombre,
    required int meta,
  }) {
    return _firestore
        .collection('sellos_asistencia')
        .doc(docId(
            filialId: filialId,
            facultad: facultad,
            carreraId: carreraId,
            eventoId: eventoId))
        .set({
      'filialId': filialId,
      'facultad': facultad,
      'carreraId': carreraId,
      'carreraNombre': carreraNombre,
      'eventoId': eventoId,
      'eventoNombre': eventoNombre,
      'meta': meta,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
