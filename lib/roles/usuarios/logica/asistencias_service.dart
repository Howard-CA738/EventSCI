import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '/prefs_helper.dart';

class StudentInfo {
  final String userId;
  final String? userName;
  final String? filial;
  final String? facultad;
  final String? carrera;
  final String? ciclo;
  final String? grupo;

  const StudentInfo({
    required this.userId,
    this.userName,
    this.filial,
    this.facultad,
    this.carrera,
    this.ciclo,
    this.grupo,
  });
}

class EventoSeleccionado {
  final String eventoId;
  final String nombre;
  final List<Map<String, dynamic>> scans;
  final List<Map<String, dynamic>> personales;
  final int meta;
  final int tabInicial;

  const EventoSeleccionado({
    required this.eventoId,
    required this.nombre,
    required this.scans,
    required this.personales,
    required this.meta,
    required this.tabInicial,
  });
}

class AsistenciasService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<StudentInfo?> cargarEstudiante() async {
    final userId = await PrefsHelper.getCurrentUserId();
    final userName = await PrefsHelper.getUserName();
    final userData = await PrefsHelper.getCurrentUserData();

    if (userId == null) return null;

    return StudentInfo(
      userId: userId,
      userName: userName,
      filial: userData?['filial']?.toString(),
      facultad: userData?['facultad']?.toString(),
      carrera: userData?['carrera']?.toString(),
      ciclo: userData?['ciclo']?.toString(),
      grupo: userData?['grupo']?.toString(),
    );
  }

  Future<List<Map<String, dynamic>>> cargarEventosConAsistencias(
      StudentInfo info) async {
    final parts = info.userId.split('/');
    if (parts.length != 2) throw Exception('ID de usuario inválido');
    final studentId = parts[1];

    Query query = _firestore
        .collection('events')
        .orderBy('createdAt', descending: true);

    if (info.facultad != null && info.facultad!.isNotEmpty) {
      query = query.where('facultad', isEqualTo: info.facultad);
    }
    if (info.carrera != null && info.carrera!.isNotEmpty) {
      query = query.where('carreraNombre', isEqualTo: info.carrera);
    }
    if (info.filial != null && info.filial!.isNotEmpty) {
      query = query.where('filialNombre', isEqualTo: info.filial);
    }

    final eventosSnap = await query.get();
    if (eventosSnap.docs.isEmpty) return [];

    final todos = eventosSnap.docs.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      return {
        'eventId': doc.id,
        'eventName': d['name'] ?? 'Sin nombre',
        'eventDescription': d['description'] ?? '',
        'eventDate': d['fecha'],
        'eventFacultad': d['facultad'] ?? '',
        'eventCarrera': d['carreraNombre'] ?? d['carrera'] ?? '',
        'eventFilial': d['filialNombre'] ?? '',
        'asistencias': <Map<String, dynamic>>[],
        'asistenciasPersonales': <Map<String, dynamic>>[],
        'tieneAsistencias': false,
      };
    }).toList();

    await Future.wait(
      todos.map((evento) => _cargarAsistenciasDeEvento(evento, studentId)),
    );

    return todos.where((e) => e['tieneAsistencias'] == true).toList();
  }

  Future<void> _cargarAsistenciasDeEvento(
      Map<String, dynamic> evento, String studentId) async {
    final eventId = evento['eventId'] as String;

    try {
      final resumenDoc = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias')
          .doc(studentId)
          .get();

      List<Map<String, dynamic>> scans = [];
      if (resumenDoc.exists) {
        final scansSnap = await _firestore
            .collection('events')
            .doc(eventId)
            .collection('asistencias')
            .doc(studentId)
            .collection('scans')
            .orderBy('timestamp', descending: true)
            .get();

        scans = scansSnap.docs
            .map((s) {
              final d = s.data();
              if (d['timestamp'] == null) return null;
              return {
                'id': s.id,
                'timestamp': d['timestamp'],
                'categoria': d['categoria'] ?? 'Sin categoría',
                'tipoInvestigacion': d['categoria'] ?? 'Sin categoría',
                'codigoProyecto': d['codigoProyecto'] ?? 'Sin código',
                'tituloProyecto': d['tituloProyecto'] ?? 'Sin título',
                'grupo': d['grupo'],
                'qrId': d['qrId'],
                'registrationMethod': d['registrationMethod'] ?? 'qr_scan',
                'tipo': 'proyecto',
              };
            })
            .whereType<Map<String, dynamic>>()
            .toList();
      }

      List<Map<String, dynamic>> personales = [];
      final asistPersonalesSnap = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias_personales')
          .get();

      final registros = await Future.wait(
        asistPersonalesSnap.docs.map((asistDoc) async {
          final registroDoc = await _firestore
              .collection('events')
              .doc(eventId)
              .collection('asistencias_personales')
              .doc(asistDoc.id)
              .collection('registros')
              .doc(studentId)
              .get();

          if (!registroDoc.exists) return null;

          final rd = registroDoc.data()!;
          final ad = asistDoc.data();
          return {
            'id': registroDoc.id,
            'asistenciaId': asistDoc.id,
            'asistenciaNombre':
                rd['asistenciaNombre'] ?? ad['nombre'] ?? 'Asistencia personal',
            'asistenciaTipo':
                rd['asistenciaTipo'] ?? ad['tipo'] ?? 'Asistencia Personal',
            'timestamp': rd['timestamp'],
            'eventId': eventId,
            'eventName': evento['eventName'],
            'type': 'asistencia_personal',
            'qrId': rd['qrId'],
            'tipo': 'personal',
          };
        }),
      );

      personales.addAll(registros.whereType<Map<String, dynamic>>());

      evento['asistencias'] = scans;
      evento['asistenciasPersonales'] = personales;
      evento['tieneAsistencias'] = scans.isNotEmpty || personales.isNotEmpty;
    } catch (e) {
      debugPrint('Error cargando asistencias del evento $eventId: $e');
    }
  }

  Future<EventoSeleccionado> seleccionarEvento(
      Map<String, dynamic> eventoData, String currentUserId) async {
    final eventoId = eventoData['eventId'] as String;
    final nombre = eventoData['eventName'] as String;
    final scans =
        List<Map<String, dynamic>>.from(eventoData['asistencias'] as List);
    final personales = List<Map<String, dynamic>>.from(
        (eventoData['asistenciasPersonales'] as List?) ?? []);

    int meta = -1;

    try {
      final eventDoc =
          await _firestore.collection('events').doc(eventoId).get();
      if (eventDoc.exists) {
        final ed = eventDoc.data()!;
        final filialId = ed['filialId']?.toString();
        final facultad = ed['facultad']?.toString();
        final carreraId = ed['carreraId']?.toString();

        if (filialId != null && facultad != null && carreraId != null) {
          final docId =
              '${filialId}_${facultad}_${carreraId}_$eventoId'.replaceAll(' ', '_');
          final configDoc = await _firestore
              .collection('sellos_asistencia')
              .doc(docId)
              .get();

          if (configDoc.exists) {
            final m = configDoc.data()!['meta'];
            if (m is int && m > 0) {
              meta = m;
            } else if (m is double && m > 0) {
              meta = m.toInt();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error cargando meta de sellos: $e');
    }

    scans.sort((a, b) {
      final tA = (a['timestamp'] as Timestamp?)?.toDate();
      final tB = (b['timestamp'] as Timestamp?)?.toDate();
      if (tA == null || tB == null) return 0;
      return tB.compareTo(tA);
    });
    personales.sort((a, b) {
      final tA = (a['timestamp'] as Timestamp?)?.toDate();
      final tB = (b['timestamp'] as Timestamp?)?.toDate();
      if (tA == null || tB == null) return 0;
      return tB.compareTo(tA);
    });

    return EventoSeleccionado(
      eventoId: eventoId,
      nombre: nombre,
      scans: scans,
      personales: personales,
      meta: meta,
      tabInicial: scans.isEmpty && personales.isNotEmpty ? 1 : 0,
    );
  }
}
