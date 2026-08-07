import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/logica/gestion_criterios.dart';

class EvaluacionCargada {
  final bool evaluada;
  final bool bloqueada;
  final Map<String, double> notas;

  const EvaluacionCargada({
    required this.evaluada,
    required this.bloqueada,
    required this.notas,
  });
}

class EvaluacionService {
  final _firestore = FirebaseFirestore.instance;

  DocumentReference _evalRef({
    required String eventId,
    required String proyectoId,
    required String juradoId,
  }) =>
      _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .doc(proyectoId)
          .collection('evaluaciones')
          .doc(juradoId);

  Future<EvaluacionCargada?> cargarNotas({
    required String eventId,
    required String proyectoId,
    required String juradoId,
  }) async {
    final doc = await _evalRef(
      eventId: eventId,
      proyectoId: proyectoId,
      juradoId: juradoId,
    ).get();

    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;

    final evaluada = data['evaluada'] as bool? ?? false;
    final bloqueada = data['bloqueada'] as bool? ?? false;
    final Map<String, double> notas = {};

    if (data.containsKey('notas')) {
      final notasRaw = data['notas'] as Map<String, dynamic>;
      for (final e in notasRaw.entries) {
        notas[e.key] = (e.value as num).toDouble();
      }
    }

    return EvaluacionCargada(
      evaluada: evaluada,
      bloqueada: bloqueada,
      notas: notas,
    );
  }

  Future<bool> estaEvaluadaOBloqueada({
    required String eventId,
    required String proyectoId,
    required String juradoId,
  }) async {
    try {
      final doc = await _evalRef(
        eventId: eventId,
        proyectoId: proyectoId,
        juradoId: juradoId,
      ).get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>?;
      return data != null &&
          (data['bloqueada'] == true || data['evaluada'] == true);
    } catch (_) {
      return false;
    }
  }

  Future<void> guardarNotas({
    required String eventId,
    required String proyectoId,
    required String juradoId,
    required Map<String, double?> notasSeleccionadas,
    required Rubrica rubrica,
  }) async {
    double notaTotal = 0;
    final Map<String, dynamic> notas = {};

    for (final seccion in rubrica.secciones) {
      for (final criterio in seccion.criterios) {
        final nota =
            (notasSeleccionadas[criterio.id]!).clamp(0.0, criterio.peso);
        notas[criterio.id] = nota;
        notaTotal += nota;
      }
    }

    notaTotal = notaTotal.clamp(0.0, rubrica.puntajeMaximo);

    await _evalRef(
      eventId: eventId,
      proyectoId: proyectoId,
      juradoId: juradoId,
    ).update({
      'notas': notas,
      'notaTotal': notaTotal,
      'puntajeMaximo': rubrica.puntajeMaximo,
      'rubricaId': rubrica.id,
      'evaluada': true,
      'bloqueada': true,
      'fechaEvaluacion': FieldValue.serverTimestamp(),
    });
  }
}
