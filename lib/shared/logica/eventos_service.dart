import 'package:cloud_firestore/cloud_firestore.dart';
import '/shared/logica/filiales_service.dart';

class EventosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FilialesService _filialesService = FilialesService();

  Future<List<Map<String, String>>> getFiliales() async {
    final filiales = await _filialesService.getFiliales();
    return filiales.map((id) {
      return {
        'id': id,
        'nombre': _filialesService.getNombreFilial(id),
        'ubicacion': _filialesService.getUbicacionFilial(id),
      };
    }).toList();
  }

  Future<List<String>> getFacultadesByFilial(String filialId) async {
    return await _filialesService.getFacultadesByFilial(filialId);
  }

  Future<List<Map<String, dynamic>>> getCarrerasByFacultad(
    String filialId,
    String facultadNombre,
  ) async {
    return await _filialesService.getCarrerasByFacultad(
      filialId,
      facultadNombre,
    );
  }

  bool requiereFacultad(String? filialId) {
    return filialId != null;
  }

  bool requiereCarrera(String? facultadNombre) {
    return facultadNombre != null;
  }

  Future<void> createEvent({
    required String name,
    required String filialId,
    required String filialNombre,
    required String facultad,
    required String carreraId,
    required String carreraNombre,
    required String periodoId,
    required String periodoNombre,
  }) async {
    final eventData = {
      'name': name,
      'filialId': filialId,
      'filialNombre': filialNombre,
      'facultad': facultad,
      'carreraId': carreraId,
      'carreraNombre': carreraNombre,
      'periodoId': periodoId,
      'periodoNombre': periodoNombre,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'fecha': null,
      'hora': null,
      'lugar': '',
      'ponentes': [],
    };

    await _firestore.collection('events').add(eventData);
  }

  Future<void> updateEvent({
    required String eventId,
    required String name,
    required String filialId,
    required String filialNombre,
    required String facultad,
    required String carreraId,
    required String carreraNombre,
    String? periodoId,
    String? periodoNombre,
  }) async {
    final updateData = {
      'name': name,
      'filialId': filialId,
      'filialNombre': filialNombre,
      'facultad': facultad,
      'carreraId': carreraId,
      'carreraNombre': carreraNombre,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (periodoId != null) {
      updateData['periodoId'] = periodoId;
    }
    if (periodoNombre != null) {
      updateData['periodoNombre'] = periodoNombre;
    }

    await _firestore.collection('events').doc(eventId).update(updateData);
  }

  Future<void> actualizarNombreYPeriodo({
    required String eventId,
    required String name,
    String? periodoId,
    String? periodoNombre,
  }) async {
    final updateData = <String, dynamic>{
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (periodoId != null) {
      updateData['periodoId'] = periodoId;
      updateData['periodoNombre'] = periodoNombre;
    }

    await _firestore.collection('events').doc(eventId).update(updateData);
  }

  Future<void> deleteEvent(String eventId) async {
    await _firestore.collection('events').doc(eventId).delete();
  }

  Stream<QuerySnapshot> getEventsStream() {
    return _firestore
        .collection('events')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getEventsCountStream() {
    return _firestore.collection('events').snapshots();
  }

  String? validateEventName(String name) {
    if (name.trim().isEmpty) {
      return 'Por favor ingresa el nombre del evento';
    }
    return null;
  }

  String? validateFilial(String? filialId) {
    if (filialId == null) {
      return 'Por favor selecciona una filial';
    }
    return null;
  }

  String? validateFacultad(String? facultad) {
    if (facultad == null) {
      return 'Por favor selecciona una facultad';
    }
    return null;
  }

  String? validateCarrera(String? carreraId) {
    if (carreraId == null) {
      return 'Por favor selecciona una carrera';
    }
    return null;
  }

  String? validatePeriodo(String? periodoId) {
    if (periodoId == null) {
      return 'Por favor selecciona un período';
    }
    return null;
  }

  String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  List<QueryDocumentSnapshot> filterByFilial(
    List<QueryDocumentSnapshot> events,
    String? filtroFilial,
  ) {
    if (filtroFilial == null) return events;
    return events.where((event) {
      final data = event.data() as Map<String, dynamic>;
      return data['filialId'] == filtroFilial;
    }).toList();
  }

  List<QueryDocumentSnapshot> filterByFacultad(
    List<QueryDocumentSnapshot> events,
    String? filtroFacultad,
  ) {
    if (filtroFacultad == null) return events;
    return events.where((event) {
      final data = event.data() as Map<String, dynamic>;
      return data['facultad'] == filtroFacultad;
    }).toList();
  }

  List<QueryDocumentSnapshot> filterByCarrera(
    List<QueryDocumentSnapshot> events,
    String? filtroCarreraId,
  ) {
    if (filtroCarreraId == null) return events;
    return events.where((event) {
      final data = event.data() as Map<String, dynamic>;
      return data['carreraId'] == filtroCarreraId;
    }).toList();
  }

  List<QueryDocumentSnapshot> filterByPeriodo(
    List<QueryDocumentSnapshot> events,
    String? filtroPeriodo,
  ) {
    if (filtroPeriodo == null) return events;
    return events.where((event) {
      final data = event.data() as Map<String, dynamic>;
      return data['periodoId'] == filtroPeriodo;
    }).toList();
  }
}
