import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

















class CodigoAsistenciaService {
  CodigoAsistenciaService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Random _random = Random.secure();







  static Future<String> generarYRegistrar({
    required String eventId,
    required String qrId,
    required String type,
    required String qrData,
    String? asistenciaId,
  }) async {
    const maxIntentos = 10;

    for (var intento = 0; intento < maxIntentos; intento++) {

      final codigo = (100000 + _random.nextInt(900000)).toString();
      final ref = _firestore.collection('codigos').doc(codigo);

      try {
        final asignado = await _firestore.runTransaction<bool>((tx) async {
          final snap = await tx.get(ref);
          if (snap.exists) return false;
          tx.set(ref, {
            'codigo': codigo,
            'eventId': eventId,
            'qrId': qrId,
            'type': type,
            'asistenciaId': asistenciaId,
            'qrData': qrData,
            'createdAt': FieldValue.serverTimestamp(),
          });
          return true;
        });

        if (asignado) return codigo;
      } catch (_) {

      }
    }

    throw Exception('No se pudo generar un código único. Intenta de nuevo.');
  }








  static Future<String?> buscarQrData(String codigo) async {
    final c = codigo.trim();
    if (c.isEmpty) return null;

    final snap = await _firestore.collection('codigos').doc(c).get();
    if (!snap.exists) return null;

    return snap.data()?['qrData'] as String?;
  }



  static Future<void> eliminar(String codigo) async {
    final c = codigo.trim();
    if (c.isEmpty) return;
    try {
      await _firestore.collection('codigos').doc(c).delete();
    } catch (_) {

    }
  }
}