import 'package:cloud_firestore/cloud_firestore.dart';

class ConfiguracionAsistenciaPersonalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<Map<String, dynamic>> watchAsistencia({
    required String eventId,
    required String docId,
  }) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('asistencias_personales')
        .doc(docId)
        .snapshots()
        .where((snap) => snap.exists)
        .map((snap) => snap.data()!);
  }

  Future<void> guardarConfiguracion({
    required String eventId,
    required String docId,
    required String qrId,
    required Map<String, dynamic> updates,
  }) async {
    await _firestore
        .collection('events')
        .doc(eventId)
        .collection('asistencias_personales')
        .doc(docId)
        .update(updates);

    await _firestore
        .collection('events')
        .doc(eventId)
        .collection('qr_codes')
        .doc(qrId)
        .update(updates);
  }
}
