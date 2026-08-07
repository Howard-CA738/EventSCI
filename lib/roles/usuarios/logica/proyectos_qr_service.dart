import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '/roles/admin_carrera/logica/codigo_asistencia_service.dart';

class QRGeneradoResult {
  final String qrData;
  final String codigo;
  final String qrId;

  const QRGeneradoResult({
    required this.qrData,
    required this.codigo,
    required this.qrId,
  });
}

class ProyectosQRService {
  final String eventId;
  final String eventName;
  final String filialId;
  final String filialNombre;
  final String facultad;
  final String carrera;
  final String categoria;

  const ProyectosQRService({
    required this.eventId,
    required this.eventName,
    required this.filialId,
    required this.filialNombre,
    required this.facultad,
    required this.carrera,
    required this.categoria,
  });

  Future<List<Map<String, dynamic>>> cargarProyectos() async {
    final querySnapshot = await FirebaseFirestore.instance
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

  Future<QRGeneradoResult> generarQR(Map<String, dynamic> proyecto) async {
    String safeString(dynamic value) {
      if (value == null) return '';
      if (value is List) return value.join(', ');
      return value.toString();
    }

    final codigoProyecto = safeString(proyecto['Código']).isEmpty
        ? 'Sin código'
        : safeString(proyecto['Código']);
    final tituloProyecto = safeString(proyecto['Título']).isEmpty
        ? 'Sin título'
        : safeString(proyecto['Título']);
    final grupo = safeString(proyecto['Sala']);

    final qrDocRef = FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('qr_codes')
        .doc();

    final qrId = qrDocRef.id;

    final qrPayload = {
      'filialId': filialId,
      'filialNombre': filialNombre,
      'facultad': facultad,
      'carrera': carrera,
      'eventId': eventId,
      'eventName': eventName,
      'categoria': categoria,
      'codigoProyecto': codigoProyecto,
      'tituloProyecto': tituloProyecto,
      'grupo': grupo,
      'qrId': qrId,
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'asistencia_categoria_asistente',
      'activo': true,
    };

    final qrJson = jsonEncode(qrPayload);

    final codigo = await CodigoAsistenciaService.generarYRegistrar(
      eventId: eventId,
      qrId: qrId,
      type: 'proyecto',
      qrData: qrJson,
    );

    await qrDocRef.set({
      'filialId': filialId,
      'filialNombre': filialNombre,
      'facultad': facultad,
      'carrera': carrera,
      'eventId': eventId,
      'eventName': eventName,
      'categoria': categoria,
      'codigoProyecto': codigoProyecto,
      'tituloProyecto': tituloProyecto,
      'grupo': grupo,
      'codigo': codigo,
      'activo': true,
      'createdAt': FieldValue.serverTimestamp(),
      'finalizadoAt': null,
      'generadoPor': 'asistente_qr',
    });

    return QRGeneradoResult(qrData: qrJson, codigo: codigo, qrId: qrId);
  }

  Future<void> finalizarQR(String qrId, String? codigo) async {
    await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('qr_codes')
        .doc(qrId)
        .update({
      'activo': false,
      'finalizadoAt': FieldValue.serverTimestamp(),
    });

    if (codigo != null) {
      await CodigoAsistenciaService.eliminar(codigo);
    }
  }

  Future<void> finalizarQRSiActivo(
      String? qrId, bool qrFinalizado, String? codigo) async {
    if (qrId == null || qrFinalizado) return;
    try {
      await finalizarQR(qrId, codigo);
    } catch (e) {
      debugPrint('Error al auto-finalizar QR: $e');
    }
  }
}
