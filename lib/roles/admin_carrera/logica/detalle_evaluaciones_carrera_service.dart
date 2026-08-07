import 'package:cloud_firestore/cloud_firestore.dart';

class DetalleEvaluacionesCarreraService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> toggleBloqueo({
    required String eventoId,
    required String proyectoId,
    required String juradoId,
    required bool nuevoEstado,
  }) {
    return _firestore
        .collection('events')
        .doc(eventoId)
        .collection('proyectos')
        .doc(proyectoId)
        .collection('evaluaciones')
        .doc(juradoId)
        .update({
      'bloqueada': nuevoEstado,
      if (!nuevoEstado) 'evaluada': false,
    });
  }

  Future<void> guardarNotas({
    required String eventoId,
    required String proyectoId,
    required String juradoId,
    required Map<String, dynamic> notas,
    required double notaTotal,
  }) {
    return _firestore
        .collection('events')
        .doc(eventoId)
        .collection('proyectos')
        .doc(proyectoId)
        .collection('evaluaciones')
        .doc(juradoId)
        .update({
      'notas': notas,
      'notaTotal': notaTotal,
      'editadoPorAdmin': true,
      'fechaEdicionAdmin': FieldValue.serverTimestamp(),
    });
  }
}
