import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '/prefs_helper.dart';

class AsistenteDatos {
  final String nombre;
  final String? filialId;
  final String? filialNombre;
  final String? facultad;
  final String? carreraId;
  final String? carreraNombre;

  const AsistenteDatos({
    required this.nombre,
    this.filialId,
    this.filialNombre,
    this.facultad,
    this.carreraId,
    this.carreraNombre,
  });
}

class AsistenteService {
  Future<AsistenteDatos> cargarDatos() async {
    final name = await PrefsHelper.getUserName();
    final userIdPath = await PrefsHelper.getCurrentUserId();

    if (userIdPath == null || !userIdPath.contains('/')) {
      return AsistenteDatos(nombre: name ?? 'Asistente');
    }

    final parts = userIdPath.split('/');
    final carreraPath = parts[0];
    final studentId = parts[1];

    final studentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(carreraPath)
        .collection('students')
        .doc(studentId)
        .get();

    final carreraDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(carreraPath)
        .get();

    final sd = studentDoc.data() ?? {};
    final cd = carreraDoc.data() ?? {};

    final facultad = sd['facultad']?.toString().trim() ?? '';
    final carreraNombre = sd['carrera']?.toString().trim() ?? '';
    final filialId = cd['filial']?.toString().trim() ?? '';
    final filialNombre = cd['filialNombre']?.toString().trim() ??
        cd['filial']?.toString().trim() ??
        '';
    final carreraId = cd['carreraId']?.toString().trim() ?? carreraPath;

    debugPrint('🎓 Asistente QR:'
        '\n  filialId=$filialId'
        '\n  facultad=$facultad'
        '\n  carreraId=$carreraId'
        '\n  carreraNombre=$carreraNombre');

    return AsistenteDatos(
      nombre: name ?? 'Asistente',
      filialId: filialId.isNotEmpty ? filialId : null,
      filialNombre: filialNombre.isNotEmpty ? filialNombre : null,
      facultad: facultad.isNotEmpty ? facultad : null,
      carreraId: carreraId.isNotEmpty ? carreraId : null,
      carreraNombre: carreraNombre.isNotEmpty ? carreraNombre : null,
    );
  }

  Stream<List<QueryDocumentSnapshot>> getEventosStream({
    String? filialNombre,
    String? facultad,
    String? carreraNombre,
  }) {
    return FirebaseFirestore.instance
        .collection('events')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {
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
      }).toList();
    });
  }

  Future<List<String>> cargarCategorias(String eventId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('proyectos')
        .get();

    final Set<String> categoriasSet = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final clasificacion = data['Clasificación']?.toString().trim();
      if (clasificacion != null && clasificacion.isNotEmpty) {
        categoriasSet.add(clasificacion);
      }
    }

    return categoriasSet.toList()..sort();
  }
}
