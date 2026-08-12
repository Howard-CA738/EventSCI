import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '/resolver_nombres_service.dart';
import '../datos/categoria_data.dart';
import 'nota_docente_service.dart';
import 'participantes_ranking_calculator.dart';

class ParticipantesCompletoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotaDocenteService notaDocenteService;
  final ResolverNombresService resolverNombres;

  ParticipantesCompletoService({
    NotaDocenteService? notaDocenteService,
    ResolverNombresService? resolverNombres,
  })  : notaDocenteService = notaDocenteService ?? NotaDocenteService(),
        resolverNombres = resolverNombres ?? ResolverNombresService();

  Future<void> cargarEstudiantesParaResolucion({
    required String filialNombre,
    required String carrera,
  }) {
    return resolverNombres.cargarEstudiantes(
      filialNombre: filialNombre,
      carrera: carrera,
    );
  }

  Future<List<Map<String, dynamic>>> cargarEventos({
    required String? filialId,
    required String? facultad,
    required String? carreraId,
  }) async {
    final snap = await _firestore
        .collection('events')
        .where('filialId', isEqualTo: filialId)
        .where('facultad', isEqualTo: facultad)
        .where('carreraId', isEqualTo: carreraId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs
        .map((doc) => {
              'id': doc.id,
              'name': formatearTexto(doc.data()['name'], 'Sin nombre'),
            })
        .toList();
  }

  Future<Map<String, double>> obtenerNotasDocente(String eventoId) {
    return notaDocenteService.obtenerNotasDocente(eventoId);
  }

  Future<NotaDocenteImportResult?> importarNotasDocenteDesdeExcel(
    String eventId, {
    String? filialNombre,
    String? filialId,
    String? carreraNombre,
    String? carreraId,
  }) {
    return notaDocenteService.importarDesdeExcel(
      eventId,
      filialNombre: filialNombre,
      filialId: filialId,
      carreraNombre: carreraNombre,
      carreraId: carreraId,
    );
  }

  Future<void> eliminarNotasDocente(String eventId) {
    return notaDocenteService.eliminarNotasDocente(eventId);
  }

  Future<List<CategoriaData>> cargarParticipantes(
      String eventoId, Map<String, double> notasDocente) async {
    try {
      final proyectosSnap = await _firestore
          .collection('events')
          .doc(eventoId)
          .collection('proyectos')
          .get();

      if (proyectosSnap.docs.isEmpty) return [];

      const batchSize = 10;
      final docs = proyectosSnap.docs;
      final results = <Map<String, dynamic>>[];

      for (int i = 0; i < docs.length; i += batchSize) {
        final batch = docs.sublist(i, (i + batchSize).clamp(0, docs.length));
        final batchResults = await Future.wait(
          batch.map((doc) => _procesarProyecto(eventoId, doc, notasDocente)),
        );
        results.addAll(batchResults);
      }

      final Map<String, List<Map<String, dynamic>>> porCategoria = {};
      for (final p in results) {
        final codigo = (p['codigo'] as String).toUpperCase().trim();
        final String modalidad;
        if (codigo.startsWith('ORAL')) {
          modalidad = 'ORAL';
        } else if (codigo.startsWith('BANNER')) {
          modalidad = 'BANNER';
        } else {
          modalidad = 'OTROS';
        }
        final clasif = p['clasificacion'] as String;
        final cat = '$modalidad · $clasif';
        porCategoria.putIfAbsent(cat, () => []).add(p);
      }

      for (final lista in porCategoria.values) {
        lista.sort((a, b) =>
            (b['promedio'] as double).compareTo(a['promedio'] as double));
      }

      final entradas = porCategoria.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      return entradas
          .map((e) => CategoriaData(nombre: e.key, proyectos: e.value))
          .toList();
    } catch (e, stack) {
      debugPrint('❌ Error en cargarParticipantes: $e');
      debugPrint('$stack');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _procesarProyecto(
      String eventoId, QueryDocumentSnapshot doc,
      Map<String, double> notasDocente) async {
    try {
      final d = doc.data() as Map<String, dynamic>;

      final evalSnap = await _firestore
          .collection('events')
          .doc(eventoId)
          .collection('proyectos')
          .doc(doc.id)
          .collection('evaluaciones')
          .where('evaluada', isEqualTo: true)
          .get();

      final evaluaciones = evalSnap.docs.map((e) => e.data()).toList();
      final codigos = extraerCodigosIntegrantes(d['Integrantes']);
      final ranking = calcularRanking(
        evaluaciones: evaluaciones,
        codigosIntegrantes: codigos,
        notasDocente: notasDocente,
      );

      return {
        'proyectoId': doc.id,
        'codigo': formatearTexto(d['Código'], 'Sin código'),
        'titulo': formatearTexto(d['Título'], 'Sin título'),
        'integrantes': resolverNombres.resolver(d['Integrantes']),
        'sala': formatearTexto(d['Sala'], ''),
        'clasificacion': formatearTexto(d['Clasificación'], 'Sin categoría'),
        'asesor': formatearTexto(d['Asesor'], ''),
        'descripcion': formatearTexto(d['Descripción'], ''),
        'promedio': ranking.promedio,
        'promedioJurados': ranking.promedioJurados,
        'promedioRaw': ranking.promedioRaw,
        'notaDocente': ranking.notaDocente,
        'notaMax': ranking.notaMax,
        'notaMin': ranking.notaMin,
        'cantidadJurados': ranking.cantidadJurados,
        'nombresJurados': ranking.nombresJurados,
        'notas': ranking.notas,
        'notasRaw': ranking.notasRaw,
        'escalaBase': escalaBaseParticipantes,
        'tieneEvaluaciones': ranking.tieneEvaluaciones,
        'tieneNotaDocente': ranking.tieneNotaDocente,
      };
    } catch (e, stack) {
      debugPrint('❌ Error en proyecto ${doc.id}: $e');
      debugPrint('$stack');
      return {
        'proyectoId': doc.id,
        'codigo': 'Error',
        'titulo': 'Error al procesar',
        'integrantes': '',
        'sala': '',
        'clasificacion': 'Sin categoría',
        'asesor': '',
        'descripcion': '',
        'promedio': 0.0,
        'promedioJurados': 0.0,
        'promedioRaw': 0.0,
        'notaDocente': null,
        'notaMax': 0.0,
        'notaMin': 0.0,
        'cantidadJurados': 0,
        'nombresJurados': '',
        'notas': <double>[],
        'notasRaw': <double>[],
        'escalaBase': escalaBaseParticipantes,
        'tieneEvaluaciones': false,
        'tieneNotaDocente': false,
      };
    }
  }
}
