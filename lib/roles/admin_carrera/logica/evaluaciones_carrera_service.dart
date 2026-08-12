import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/shared/logica/gestion_criterios.dart';
import '/resolver_nombres_service.dart';

class EvaluacionesCarreraService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RubricasService _rubricasService = RubricasService();
  final ResolverNombresService resolverNombres;

  EvaluacionesCarreraService({ResolverNombresService? resolverNombres})
      : resolverNombres = resolverNombres ?? ResolverNombresService();

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
    final snapshot = await _firestore
        .collection('events')
        .where('filialId', isEqualTo: filialId)
        .where('facultad', isEqualTo: facultad)
        .where('carreraId', isEqualTo: carreraId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'] ?? 'Sin nombre',
        'facultad': data['facultad'] ?? '',
        'carrera': data['carrera'] ?? '',
      };
    }).toList();
  }

  List<String> _extraerCodigosIntegrantes(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final texto = raw.toString().trim();
    if (texto.isEmpty) return [];
    return texto
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<List<Map<String, dynamic>>> cargarEvaluacionesDeEvento(
      String eventoId) async {
    final rubricasFuture = _rubricasService.obtenerRubricas();

    final proyectosSnapshot = await _firestore
        .collection('events')
        .doc(eventoId)
        .collection('proyectos')
        .get();

    if (proyectosSnapshot.docs.isEmpty) return [];

    final todasRubricas = await rubricasFuture;
    final rubricasCache = {for (var r in todasRubricas) r.id: r};

    final futures = proyectosSnapshot.docs.map((proyectoDoc) async {
      try {
        final proyectoData = proyectoDoc.data();
        final evalSnapshot = await _firestore
            .collection('events')
            .doc(eventoId)
            .collection('proyectos')
            .doc(proyectoDoc.id)
            .collection('evaluaciones')
            .get();

        return evalSnapshot.docs.map((evalDoc) {
          final evalData = evalDoc.data();
          final notasRaw = evalData['notas'];
          final Map<String, dynamic> notas = {};
          if (notasRaw != null && notasRaw is Map) {
            notasRaw.forEach((k, v) => notas[k.toString()] = v);
          }
          final rubricaId = evalData['rubricaId'] as String?;
          Rubrica? rubrica;
          if (rubricaId != null && rubricasCache.containsKey(rubricaId)) {
            rubrica = rubricasCache[rubricaId];
          }
          return {
            'proyectoId': proyectoDoc.id,
            'codigo': proyectoData['Código'] ?? 'Sin código',
            'titulo': proyectoData['Título'] ?? 'Sin título',
            'integrantes': proyectoData['Integrantes'] ?? '',
            'integrantesCodigos':
                _extraerCodigosIntegrantes(proyectoData['Integrantes'])
                    .join('\n'),
            'integrantesNombres': resolverNombres
                .resolverLista(proyectoData['Integrantes'])
                .join('\n'),
            'sala': proyectoData['Sala'] ?? '',
            'clasificacion': proyectoData['Clasificación'] ?? 'Sin categoría',
            'juradoId': evalDoc.id,
            'juradoNombre': evalData['juradoNombre'] ?? 'Jurado',
            'rubricaId': rubricaId,
            'rubricaNombre': evalData['rubricaNombre'] ?? 'Sin rúbrica',
            'rubrica': rubrica,
            'evaluada': evalData['evaluada'] ?? false,
            'bloqueada': evalData['bloqueada'] ?? false,
            'notaTotal': (evalData['notaTotal'] ?? 0.0).toDouble(),
            'notas': notas,
            'fechaAsignacion': evalData['fechaAsignacion'],
            'fechaEvaluacion': evalData['fechaEvaluacion'],
          };
        }).toList();
      } catch (e) {
        debugPrint('Error procesando proyecto ${proyectoDoc.id}: $e');
        return <Map<String, dynamic>>[];
      }
    }).toList();

    final resultados = await Future.wait(futures);
    final lista = <Map<String, dynamic>>[];
    for (var r in resultados) {
      lista.addAll(r);
    }
    lista.sort(
        (a, b) => (a['codigo'] as String).compareTo(b['codigo'] as String));
    return lista;
  }
}
