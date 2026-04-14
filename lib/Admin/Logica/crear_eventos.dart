  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'filiales_service.dart';

  class EventosService {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final FilialesService _filialesService = FilialesService();

    // ✅ Obtener filiales disponibles
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

    // ✅ Obtener facultades por filial
    Future<List<String>> getFacultadesByFilial(String filialId) async {
      return await _filialesService.getFacultadesByFilial(filialId);
    }

    // ✅ Obtener carreras por facultad
    Future<List<Map<String, dynamic>>> getCarrerasByFacultad(
      String filialId,
      String facultadNombre,
    ) async {
      return await _filialesService.getCarrerasByFacultad(
        filialId,
        facultadNombre,
      );
    }

    // ✅ Verificar si requiere facultad
    bool requiereFacultad(String? filialId) {
      // Siempre requiere facultad
      return filialId != null;
    }

    // ✅ Verificar si requiere carrera
    bool requiereCarrera(String? facultadNombre) {
      // Siempre requiere carrera si hay facultad
      return facultadNombre != null;
    }

    // Crear nuevo evento
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

    // Editar evento
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

    // Eliminar evento
    Future<void> deleteEvent(String eventId) async {
      await _firestore.collection('events').doc(eventId).delete();
    }

    // Obtener stream de eventos
    Stream<QuerySnapshot> getEventsStream() {
      return _firestore
          .collection('events')
          .orderBy('createdAt', descending: true)
          .snapshots();
    }

    // Obtener conteo de eventos
    Stream<QuerySnapshot> getEventsCountStream() {
      return _firestore.collection('events').snapshots();
    }

    // Validar nombre del evento
    String? validateEventName(String name) {
      if (name.trim().isEmpty) {
        return 'Por favor ingresa el nombre del evento';
      }
      return null;
    }

    // Validar filial
    String? validateFilial(String? filialId) {
      if (filialId == null) {
        return 'Por favor selecciona una filial';
      }
      return null;
    }

    // Validar facultad
    String? validateFacultad(String? facultad) {
      if (facultad == null) {
        return 'Por favor selecciona una facultad';
      }
      return null;
    }

    // Validar carrera
    String? validateCarrera(String? carreraId) {
      if (carreraId == null) {
        return 'Por favor selecciona una carrera';
      }
      return null;
    }

    // Validar período
    String? validatePeriodo(String? periodoId) {
      if (periodoId == null) {
        return 'Por favor selecciona un período';
      }
      return null;
    }

    // Formatear fecha
    String formatDate(DateTime date) {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }

    // Filtrar eventos por filial
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

    // Filtrar eventos por facultad
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

    // Filtrar eventos por carrera
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

    // Filtrar eventos por período
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
