import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class QRProyectoGenerado {
  final String qrData;
  final String qrId;

  const QRProyectoGenerado({required this.qrData, required this.qrId});
}

class ProyectosCategoriaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> cargarProyectos({
    required String eventId,
    required String categoria,
  }) async {
    final querySnapshot = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('proyectos')
        .where('Clasificación', isEqualTo: categoria)
        .orderBy('Código')
        .get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['docId'] = doc.id;
      return data;
    }).toList();
  }

  Future<QRProyectoGenerado> generarQRParaProyecto({
    required String eventId,
    required String eventName,
    required String facultad,
    required String carrera,
    required String categoria,
    required Map<String, dynamic> proyecto,
  }) async {
    final qrDocRef = _firestore
        .collection('events')
        .doc(eventId)
        .collection('qr_codes')
        .doc();

    final qrId = qrDocRef.id;

    final qrInfo = {
      'eventId': eventId,
      'eventName': eventName,
      'facultad': facultad,
      'carrera': carrera,
      'categoria': categoria,
      'codigoProyecto': proyecto['Código'] ?? 'Sin código',
      'tituloProyecto': proyecto['Título'] ?? 'Sin título',
      'grupo': proyecto['Sala'],
      'qrId': qrId,
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'asistencia_categoria',
      'activo': true,
    };

    final qrJson = jsonEncode(qrInfo);

    await qrDocRef.set({
      'eventId': eventId,
      'codigoProyecto': proyecto['Código'] ?? 'Sin código',
      'tituloProyecto': proyecto['Título'] ?? 'Sin título',
      'categoria': categoria,
      'grupo': proyecto['Sala'],
      'activo': true,
      'createdAt': FieldValue.serverTimestamp(),
      'finalizadoAt': null,
    });

    return QRProyectoGenerado(qrData: qrJson, qrId: qrId);
  }

  Future<void> finalizarQR({
    required String eventId,
    required String qrId,
  }) async {
    await _firestore
        .collection('events')
        .doc(eventId)
        .collection('qr_codes')
        .doc(qrId)
        .update({
      'activo': false,
      'finalizadoAt': FieldValue.serverTimestamp(),
    });
  }
}
