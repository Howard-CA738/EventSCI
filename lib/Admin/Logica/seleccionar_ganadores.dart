import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SeleccionarGanadoresLogic {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Estructura de facultades y carreras
  final Map<String, List<String>> facultadesCarreras = {
    'Facultad de Ciencias Empresariales': [
      'Administración',
      'Contabilidad',
      'Gestión Tributaria y Aduanera',
    ],
    'Facultad de Ciencias Humanas y Educación': [
      'Educación, Especialidad Inicial y Puericultura',
      'Educación, Especialidad Primaria y Pedagogía Terapéutica',
      'Educación, Especialidad Inglés y Español',
    ],
    'Facultad de Ciencias de la Salud': [
      'Enfermería',
      'Nutrición Humana',
      'Psicología',
    ],
    'Facultad de Ingeniería y Arquitectura': [
      'Ingeniería Civil',
      'Arquitectura y Urbanismo',
      'Ingeniería Ambiental',
      'Ingeniería de Industrias Alimentarias',
      'Ingeniería de Sistemas',
    ],
  };

  Stream<QuerySnapshot> getEventsStream(String facultad, String carrera) {
    return _firestore
        .collection('events')
        .where('facultad', isEqualTo: facultad)
        .where('carrera', isEqualTo: carrera)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> loadGrupos(String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .get();

      final grupos = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;

        return {
          'id': doc.id,
          'projectName': data['Título'] ?? 'Proyecto sin nombre',
          'integrantes': _parseIntegrantes(data['Integrantes']),
          'eventId': eventId,
          'clasificacion': data['Clasificación'],
          'codigo': data['Código'],
          'sala': data['Sala'],
          'isWinner': data['isWinner'] ?? false,
          'winnerDate': data['winnerDate'],
          'importedAt': data['importedAt'],
        };
      }).toList();

      return grupos;
    } catch (e) {
      debugPrint('Error detallado al cargar grupos: $e');
      rethrow;
    }
  }

  Future<void> toggleWinner(
    String eventId,
    String grupoId,
    bool isWinner,
  ) async {
    try {
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .doc(grupoId)
          .update({
            'isWinner': isWinner,
            'winnerDate': isWinner ? Timestamp.now() : null,
          });
    } catch (e) {
      debugPrint('Error detallado al actualizar ganador: $e');
      rethrow;
    }
  }

  List<String> _parseIntegrantes(dynamic integrantesData) {
    if (integrantesData == null) return [];

    String integrantesStr = integrantesData.toString();

    if (integrantesStr.contains(',')) {
      return integrantesStr
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return integrantesStr.isNotEmpty ? [integrantesStr.trim()] : [];
  }
}
