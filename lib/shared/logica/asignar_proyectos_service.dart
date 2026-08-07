import 'package:cloud_firestore/cloud_firestore.dart';
import '/shared/logica/gestion_criterios.dart';

class ProyectosCargados {
  final bool sinCategorias;
  final List<Map<String, dynamic>> proyectos;
  final Map<String, List<Map<String, dynamic>>> proyectosPorCategoria;
  final List<String> categoriasJurado;
  final int totalProyectosEnEvento;

  ProyectosCargados({
    required this.sinCategorias,
    required this.proyectos,
    required this.proyectosPorCategoria,
    required this.categoriasJurado,
    required this.totalProyectosEnEvento,
  });
}

class AsignacionResultado {
  final int asignados;
  final int actualizados;
  final int eliminados;

  AsignacionResultado({
    required this.asignados,
    required this.actualizados,
    required this.eliminados,
  });
}

class AsignarProyectosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<ProyectosCargados> cargarProyectosPorRubrica({
    required String eventoId,
    required String juradoId,
    required Rubrica rubrica,
    String ordenarPor = 'titulo',
  }) async {
    final resultados = await Future.wait([
      _firestore.collection('users').doc(juradoId).get(),
      _firestore
          .collection('events')
          .doc(eventoId)
          .collection('proyectos')
          .get(),
      _firestore
          .collectionGroup('evaluaciones')
          .where('juradoId', isEqualTo: juradoId)
          .where('rubricaId', isEqualTo: rubrica.id)
          .get(),
    ]);

    final juradoDoc = resultados[0] as DocumentSnapshot;
    final proyectosSnap = resultados[1] as QuerySnapshot;
    final evaluacionesSnap = resultados[2] as QuerySnapshot;

    List<String> categoriasJurado = [];
    if (juradoDoc.exists) {
      final rawData = juradoDoc.data();
      if (rawData != null) {
        final d = rawData as Map<String, dynamic>;
        if (d.containsKey('categorias')) {
          categoriasJurado =
              List<String>.from(d['categorias'] as List? ?? []);
        }
      }
    }

    if (categoriasJurado.isEmpty) {
      return ProyectosCargados(
        sinCategorias: true,
        proyectos: [],
        proyectosPorCategoria: {},
        categoriasJurado: [],
        totalProyectosEnEvento: proyectosSnap.docs.length,
      );
    }

    final proyectosAsignados = <String>{};

    for (final doc in evaluacionesSnap.docs) {
      final parts = doc.reference.path.split('/');
      if (parts.length >= 4) proyectosAsignados.add(parts[3]);
    }

    final Map<String, Map<String, dynamic>> proyectosMap = {};

    for (final doc in proyectosSnap.docs) {
      final rawDoc = doc.data();
      if (rawDoc == null) continue;
      final d = rawDoc as Map<String, dynamic>;

      final codigo = (d['Código'] as String?) ?? '';
      final clasificacion =
          (d['Clasificación'] as String?) ?? 'Sin categoría';

      if (!categoriasJurado.contains(clasificacion)) continue;

      proyectosMap[doc.id] = {
        'id': doc.id,
        'eventId': eventoId,
        'codigo': codigo.isEmpty ? '(sin código)' : codigo,
        'titulo': (d['Título'] as String?) ?? '',
        'integrantes': (d['Integrantes'] as String?) ?? '',
        'sala': (d['Sala'] as String?) ?? '',
        'clasificacion': clasificacion,
        'yaAsignado': proyectosAsignados.contains(doc.id),
      };
    }

    final proyectosList = proyectosMap.values.toList()
      ..sort((a, b) =>
          (a[ordenarPor] as String).compareTo(b[ordenarPor] as String));

    final Map<String, List<Map<String, dynamic>>> grupos = {};

    for (final p in proyectosList) {
      final cat = p['clasificacion'] as String;
      grupos.putIfAbsent(cat, () => []).add(p);
    }

    return ProyectosCargados(
      sinCategorias: false,
      proyectos: proyectosList,
      proyectosPorCategoria: grupos,
      categoriasJurado: categoriasJurado,
      totalProyectosEnEvento: proyectosSnap.docs.length,
    );
  }

  Future<AsignacionResultado> asignarProyectosPorBatch({
    required List<Map<String, dynamic>> proyectosDisponibles,
    required Set<String> proyectosSeleccionados,
    required String juradoId,
    required Map<String, dynamic> juradoData,
    required Rubrica rubrica,
  }) async {
    final batch = _firestore.batch();
    int asignados = 0, actualizados = 0, eliminados = 0;

    for (final p in proyectosDisponibles) {
      final id = p['id'] as String;
      final yaAsignado = p['yaAsignado'] as bool;
      final seleccionado = proyectosSeleccionados.contains(id);

      final docRef = _firestore
          .collection('events')
          .doc(p['eventId'] as String?)
          .collection('proyectos')
          .doc(p['id'] as String?)
          .collection('evaluaciones')
          .doc(juradoId);

      if (yaAsignado && !seleccionado) {
        batch.delete(docRef);
        eliminados++;
      } else if (yaAsignado && seleccionado) {
        batch.update(docRef, {
          'rubricaId': rubrica.id,
          'rubricaNombre': rubrica.nombre,
          'fechaActualizacion': FieldValue.serverTimestamp(),
        });
        actualizados++;
      } else if (!yaAsignado && seleccionado) {
        batch.set(docRef, {
          'juradoId': juradoId,
          'juradoNombre': juradoData['nombre'],
          'rubricaId': rubrica.id,
          'rubricaNombre': rubrica.nombre,
          'filialId': rubrica.filial,
          'facultad': rubrica.facultad,
          'carreraNombre': rubrica.carrera,
          'evaluada': false,
          'bloqueada': false,
          'notaTotal': 0.0,
          'fechaAsignacion': FieldValue.serverTimestamp(),
        });
        asignados++;
      }
    }

    await batch.commit();

    return AsignacionResultado(
      asignados: asignados,
      actualizados: actualizados,
      eliminados: eliminados,
    );
  }
}
