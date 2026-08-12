import 'package:cloud_firestore/cloud_firestore.dart';

class EventosFiltradosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> eventosStream({
    required String? filialId,
    required String? facultad,
    required String? carreraId,
  }) {
    return _firestore
        .collection('events')
        .where('filialId', isEqualTo: filialId)
        .where('facultad', isEqualTo: facultad)
        .where('carreraId', isEqualTo: carreraId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
