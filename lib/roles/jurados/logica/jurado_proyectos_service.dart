import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/logica/gestion_criterios.dart';
import '/resolver_nombres_service.dart';

class JuradoProyectosResult {
  final Map<String, List<Map<String, dynamic>>> proyectosPorRubrica;
  final Map<String, Rubrica> rubricasMap;

  const JuradoProyectosResult({
    required this.proyectosPorRubrica,
    required this.rubricasMap,
  });
}

class JuradoProyectosService {
  final String userId;
  final String filial;
  final String facultad;

  final _resolverNombres = ResolverNombresService();
  final _rubricasService = RubricasService();

  JuradoProyectosService({
    required this.userId,
    required this.filial,
    required this.facultad,
  });

  String resolverCampoString(dynamic valor) {
    if (valor == null) return '';
    if (valor is List) return valor.map((e) => e.toString()).join(', ');
    return valor.toString();
  }

  Future<void> cargarCacheNombres() async {
    try {
      if (filial.isEmpty) return;
      final juradoDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!juradoDoc.exists) return;

      final data = juradoDoc.data();
      final filialNombre = data?['filialNombre'] as String? ?? filial;
      final carrera = data?['carrera'] as String? ?? '';

      if (carrera.isNotEmpty) {
        await _resolverNombres.cargarEstudiantes(
          filialNombre: filialNombre,
          carrera: carrera,
        );
      }
    } catch (e) {
      debugPrint('Error cargando cache nombres jurado: $e');
    }
  }

  Future<JuradoProyectosResult> cargarProyectosAsignados() async {
    Query evaluacionesQuery = FirebaseFirestore.instance
        .collectionGroup('evaluaciones')
        .where('juradoId', isEqualTo: userId);

    if (filial.isNotEmpty) {
      evaluacionesQuery =
          evaluacionesQuery.where('filialId', isEqualTo: filial);
    }
    if (facultad.isNotEmpty) {
      evaluacionesQuery =
          evaluacionesQuery.where('facultad', isEqualTo: facultad);
    }

    final resultados = await Future.wait([
      _rubricasService.obtenerRubricas(),
      evaluacionesQuery.get(),
    ]);

    final todasRubricas = resultados[0] as List<Rubrica>;
    final evaluacionesSnapshot = resultados[1] as QuerySnapshot;

    final rubricasAsignadas = todasRubricas
        .where((r) => r.juradosAsignados.contains(userId))
        .toList();

    final Map<String, List<Map<String, dynamic>>> proyectosPorRubrica = {};
    final Map<String, Rubrica> rubricasMapFinal = {};

    for (final rubrica in rubricasAsignadas) {
      proyectosPorRubrica[rubrica.id] = [];
      rubricasMapFinal[rubrica.id] = rubrica;
    }

    final List<Future<void>> tareas = [];

    for (final evalDoc in evaluacionesSnapshot.docs) {
      tareas.add(_procesarEvaluacion(
        evalDoc: evalDoc,
        rubricasMapFinal: rubricasMapFinal,
        proyectosPorRubrica: proyectosPorRubrica,
      ));
    }

    await Future.wait(tareas);

    proyectosPorRubrica.removeWhere((k, v) => v.isEmpty);
    rubricasMapFinal
        .removeWhere((k, _) => !proyectosPorRubrica.containsKey(k));

    return JuradoProyectosResult(
      proyectosPorRubrica: proyectosPorRubrica,
      rubricasMap: rubricasMapFinal,
    );
  }

  Future<void> _procesarEvaluacion({
    required QueryDocumentSnapshot evalDoc,
    required Map<String, Rubrica> rubricasMapFinal,
    required Map<String, List<Map<String, dynamic>>> proyectosPorRubrica,
  }) async {
    try {
      final evalData = evalDoc.data() as Map<String, dynamic>;
      final rubricaId = evalData['rubricaId'] as String?;

      if (rubricaId == null || !rubricasMapFinal.containsKey(rubricaId)) {
        Rubrica? rubricaEncontrada;
        for (final r in rubricasMapFinal.values) {
          if (r.juradosAsignados.contains(userId)) {
            rubricaEncontrada = r;
            break;
          }
        }
        if (rubricaEncontrada == null) return;
      }

      final rubricaFinal =
          rubricaId != null && rubricasMapFinal.containsKey(rubricaId)
              ? rubricasMapFinal[rubricaId]!
              : rubricasMapFinal.values.first;

      final proyectoRef = evalDoc.reference.parent.parent;
      if (proyectoRef == null) return;

      final proyectoSnap = await proyectoRef.get();
      if (!proyectoSnap.exists) return;

      final proyectoData = proyectoSnap.data() as Map<String, dynamic>;
      final eventoId = proyectoRef.parent.parent?.id ?? '';

      final integrantesRaw =
          proyectoData['integrantes'] ?? proyectoData['Integrantes'];
      final integrantes = _resolverNombres.resolver(integrantesRaw);

      final salaRaw = proyectoData['Sala'] ?? proyectoData['sala'] ?? '';
      final titulo = proyectoData['Título'] ?? proyectoData['titulo'] ?? '';
      final codigo = proyectoData['Código'] ?? proyectoData['codigo'] ?? '';

      final entrada = {
        'proyectoId': proyectoRef.id,
        'eventId': eventoId,
        'codigo': resolverCampoString(codigo),
        'titulo': resolverCampoString(titulo),
        'integrantes': integrantes,
        'sala': resolverCampoString(salaRaw),
        'eventoNombre': resolverCampoString(
            evalData['eventoNombre'] ?? proyectoData['eventoNombre'] ?? ''),
        'evaluada': evalData['evaluada'] ?? false,
        'bloqueada': evalData['bloqueada'] ?? false,
        'notaTotal': (evalData['notaTotal'] ?? 0.0).toDouble(),
        'rubrica': rubricaFinal,
      };

      proyectosPorRubrica[rubricaFinal.id]?.add(entrada);
    } catch (e) {
      debugPrint('Error procesando evaluación ${evalDoc.id}: $e');
    }
  }
}
