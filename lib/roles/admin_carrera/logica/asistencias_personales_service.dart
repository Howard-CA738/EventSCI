import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'codigo_asistencia_service.dart';

String construirQrPayload(Map<String, dynamic> a) {
  final guardado = a['qrData'] as String?;
  if (guardado != null && guardado.isNotEmpty) return guardado;

  final payload = {
    'filialId': a['filialId'],
    'filialNombre': a['filialNombre'],
    'facultad': a['facultad'],
    'carreraId': a['carreraId'],
    'carrera': a['carrera'],
    'eventId': a['eventId'],
    'eventName': a['eventName'],
    'asistenciaId': a['docId'],
    'nombre': a['nombre'],
    'descripcion': a['descripcion'],
    'qrId': a['qrId'],
    'timestamp': DateTime.now().toIso8601String(),
    'type': 'asistencia_personal',
  };
  return jsonEncode(payload);
}

class AsistenciasPersonalesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> cargarEventos({
    String? filialNombre,
    String? facultad,
    String? carreraNombre,
  }) async {
    final snap = await _firestore
        .collection('events')
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.where((doc) {
      final data = doc.data();

      if (filialNombre != null && filialNombre.isNotEmpty) {
        final eventoFilial = data['filialNombre']?.toString() ??
            data['filialId']?.toString() ??
            '';
        if (eventoFilial != filialNombre) return false;
      }

      if (facultad != null && facultad.isNotEmpty) {
        if (data['facultad'] != facultad) return false;
      }

      if (carreraNombre != null && carreraNombre.isNotEmpty) {
        if (data['carreraNombre'] != carreraNombre) return false;
      }

      return true;
    }).map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> cargarMisAsistencias({
    required List<Map<String, dynamic>> eventos,
    String? filtroEventoId,
  }) async {
    final List<Map<String, dynamic>> todas = [];

    final eventosAConsultar = filtroEventoId != null
        ? eventos.where((e) => e['id'] == filtroEventoId).toList()
        : eventos;

    for (final evento in eventosAConsultar) {
      final snap = await _firestore
          .collection('events')
          .doc(evento['id'] as String)
          .collection('asistencias_personales')
          .orderBy('createdAt', descending: true)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        data['docId'] = doc.id;
        data['eventId'] = evento['id'];
        data['eventName'] = evento['name'] ?? evento['nombre'] ?? 'Evento';
        todas.add(data);
      }
    }

    return todas;
  }

  Future<void> eliminarAsistencia({
    required String docId,
    required String eventId,
    required String qrId,
    required String codigo,
  }) async {
    await _firestore
        .collection('events')
        .doc(eventId)
        .collection('asistencias_personales')
        .doc(docId)
        .delete();

    if (qrId.isNotEmpty) {
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('qr_codes')
          .doc(qrId)
          .delete();
    }

    if (codigo.isNotEmpty) {
      await CodigoAsistenciaService.eliminar(codigo);
    }
  }

  Future<Map<String, dynamic>> crearAsistenciaYQR({
    required String eventId,
    required String eventName,
    required String? filialId,
    required String? filialNombre,
    required String? facultad,
    required String? carreraId,
    required String? carreraNombre,
    required String nombre,
    required String descripcion,
  }) async {
    final asistenciaRef = _firestore
        .collection('events')
        .doc(eventId)
        .collection('asistencias_personales')
        .doc();
    final asistenciaId = asistenciaRef.id;

    final qrRef = _firestore
        .collection('events')
        .doc(eventId)
        .collection('qr_codes')
        .doc();
    final qrId = qrRef.id;

    final ahora = DateTime.now();

    final payload = {
      'filialId': filialId,
      'filialNombre': filialNombre,
      'facultad': facultad,
      'carreraId': carreraId,
      'carrera': carreraNombre,
      'eventId': eventId,
      'eventName': eventName,
      'asistenciaId': asistenciaId,
      'nombre': nombre,
      'descripcion': descripcion,
      'qrId': qrId,
      'timestamp': ahora.toIso8601String(),
      'type': 'asistencia_personal',
    };

    final qrDataJson = jsonEncode(payload);

    final codigo = await CodigoAsistenciaService.generarYRegistrar(
      eventId: eventId,
      qrId: qrId,
      type: 'asistencia_personal',
      asistenciaId: asistenciaId,
      qrData: qrDataJson,
    );

    await asistenciaRef.set({
      'filialId': filialId,
      'filialNombre': filialNombre,
      'facultad': facultad,
      'carreraId': carreraId,
      'carrera': carreraNombre,
      'eventId': eventId,
      'eventName': eventName,
      'nombre': nombre,
      'descripcion': descripcion,
      'qrId': qrId,
      'qrData': qrDataJson,
      'codigo': codigo,
      'createdAt': FieldValue.serverTimestamp(),
      'generadoPor': 'admin_carrera',
      'activo': true,
      'activadoEn': FieldValue.serverTimestamp(),
      'finalizadoAt': null,
      'tiempoLimiteActivo': false,
      'tiempoLimiteMinutos': 30,
      'ventanaHorariaActiva': false,
      'ventanaInicio': null,
      'ventanaFin': null,
    });

    await qrRef.set({
      'filialId': filialId,
      'filialNombre': filialNombre,
      'facultad': facultad,
      'carreraId': carreraId,
      'carrera': carreraNombre,
      'eventId': eventId,
      'eventName': eventName,
      'nombre': nombre,
      'descripcion': descripcion,
      'asistenciaId': asistenciaId,
      'codigo': codigo,
      'activo': true,
      'type': 'asistencia_personal',
      'createdAt': FieldValue.serverTimestamp(),
      'finalizadoAt': null,
      'generadoPor': 'admin_carrera',
      'tiempoLimiteActivo': false,
      'tiempoLimiteMinutos': 30,
      'ventanaHorariaActiva': false,
      'ventanaInicio': null,
      'ventanaFin': null,
    });

    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'eventName': eventName,
      'eventId': eventId,
      'asistenciaId': asistenciaId,
      'qrId': qrId,
      'codigo': codigo,
      'qrData': qrDataJson,
    };
  }
}
