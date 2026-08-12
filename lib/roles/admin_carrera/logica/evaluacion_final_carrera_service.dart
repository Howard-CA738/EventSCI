import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../datos/eval_final_config.dart';
import '../datos/integrante_ref.dart';
import '../datos/nota_final_item.dart';
import 'evaluacion_final_calculo.dart';

class EvaluacionFinalCarreraService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String docIdConfig({
    required String? filialId,
    required String? facultad,
    required String? carreraId,
    required String eventoId,
  }) =>
      '${filialId}_${facultad}_${carreraId}_$eventoId'.replaceAll(' ', '_');

  String docIdSellos({
    required String? filialId,
    required String? facultad,
    required String? carreraId,
    required String eventoId,
  }) =>
      '${filialId}_${facultad}_${carreraId}_$eventoId'
          .replaceAll(' ', '_')
          .replaceAll('/', '_')
          .replaceAll('.', '_');

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
        .map((d) => {
              'id': d.id,
              'name': d.data()['name'] ?? 'Sin nombre',
            })
        .toList();
  }

  Future<EvalFinalConfig> cargarConfig(String docId) async {
    try {
      final doc =
          await _firestore.collection('evaluacion_final_config').doc(docId).get();
      return doc.exists ? EvalFinalConfig.fromMap(doc.data()!) : EvalFinalConfig();
    } catch (e) {
      return EvalFinalConfig();
    }
  }

  Future<void> guardarConfig({
    required String docId,
    required EvalFinalConfig config,
  }) {
    return _firestore
        .collection('evaluacion_final_config')
        .doc(docId)
        .set(config.toMap(), SetOptions(merge: true));
  }

  Future<List<NotaFinalItem>> calcularNotas({
    required String eventoId,
    required String filialNombreWidget,
    required String carreraWidget,
    required String? filialId,
    required String? carreraId,
    required String docIdSellos,
    required EvalFinalConfig config,
  }) async {
    final candidatos = [
      '${filialNombreWidget}_$carreraWidget',
      '${filialNombreWidget}_$carreraId',
      '${filialId}_$carreraWidget',
      '${filialId}_$carreraId',
    ];

    List<QueryDocumentSnapshot<Map<String, dynamic>>> estudianteDocs = [];
    for (final path in candidatos) {
      final snap = await _firestore
          .collection('users')
          .doc(path)
          .collection('students')
          .get();
      debugPrint('🔍 Ruta probada: "$path" → ${snap.docs.length} students');
      if (snap.docs.isNotEmpty) {
        estudianteDocs = snap.docs;
        break;
      }
    }
    debugPrint('✅ Total estudiantes cargados: ${estudianteDocs.length}');

    if (estudianteDocs.isEmpty) {
      throw Exception('No se encontraron estudiantes para esta carrera');
    }

    final List<IntegranteRef> integrantesProyecto = [];

    final proyectosSnap = await _firestore
        .collection('events')
        .doc(eventoId)
        .collection('proyectos')
        .get();

    for (final pDoc in proyectosSnap.docs) {
      final pData = pDoc.data();
      final codProyecto = pData['Código']?.toString() ?? '';
      final integrantesRaw = pData['Integrantes'] ?? pData['integrantes'];
      List<String> integrantes = [];
      if (integrantesRaw is List) {
        for (final e in integrantesRaw) {
          integrantes.addAll(
            e
                .toString()
                .split(RegExp(r'[,\n]'))
                .map((x) => x.trim())
                .where((x) => x.isNotEmpty),
          );
        }
      } else if (integrantesRaw is String && integrantesRaw.isNotEmpty) {
        integrantes = integrantesRaw
            .split(RegExp(r'[,\n]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      for (final cod in integrantes) {
        final codNorm = cod.trim();
        if (codNorm.isEmpty) continue;
        integrantesProyecto.add(IntegranteRef(
          codigo: codNorm,
          proyectoCodigo: codProyecto,
          proyectoDocId: pDoc.id,
        ));
      }
    }

    debugPrint('📦 Proyectos encontrados: ${proyectosSnap.docs.length}');
    debugPrint(
        '👥 Total integrantes acumulados: ${integrantesProyecto.length}');
    for (final ref in integrantesProyecto.take(10)) {
      debugPrint(
          '   → proyecto ${ref.proyectoCodigo} | integrante "${ref.codigo}"');
    }

    final Map<String, IntegranteRef> integrantesPorNombre = {};
    for (final ref in integrantesProyecto) {
      integrantesPorNombre[normalizarNombre(ref.codigo)] = ref;
    }

    final Map<String, double> promedioJuradoPorProyecto = {};

    final proyectoIdsUnicos =
        integrantesProyecto.map((e) => e.proyectoDocId).toSet();

    try {
      final Map<String, double> sumNormPorProyecto = {};
      final Map<String, int> countPorProyecto = {};

      final evalGroupSnap = await _firestore
          .collectionGroup('evaluaciones')
          .where('evaluada', isEqualTo: true)
          .get();

      for (final eDoc in evalGroupSnap.docs) {
        final proyectoRef = eDoc.reference.parent.parent;
        if (proyectoRef == null) continue;

        final evtId = proyectoRef.parent.parent?.id;
        if (evtId != eventoId) continue;

        final pDocId = proyectoRef.id;

        if (!proyectoIdsUnicos.contains(pDocId)) continue;

        final eData = eDoc.data();
        final notaTotal = ((eData['notaTotal'] ?? 0) as num).toDouble();
        final puntajeMaximo =
            ((eData['puntajeMaximo'] ?? 20) as num).toDouble();
        final base = puntajeMaximo > 0 ? puntajeMaximo : 20;
        final norm = (notaTotal / base * 20).clamp(0.0, 20.0);

        sumNormPorProyecto[pDocId] = (sumNormPorProyecto[pDocId] ?? 0) + norm;
        countPorProyecto[pDocId] = (countPorProyecto[pDocId] ?? 0) + 1;
      }

      for (final pDocId in proyectoIdsUnicos) {
        final c = countPorProyecto[pDocId] ?? 0;
        promedioJuradoPorProyecto[pDocId] =
            c > 0 ? (sumNormPorProyecto[pDocId]! / c) : 0.0;
      }

      debugPrint('⚖️ Jurado (collectionGroup): '
          '${countPorProyecto.length} proyectos con notas de ${proyectoIdsUnicos.length}');
    } catch (e) {
      debugPrint('❌ Error leyendo evaluaciones (collectionGroup): $e');
    }

    int metaSellos = 0;
    try {
      final configSellos = await _firestore
          .collection('sellos_asistencia')
          .doc(docIdSellos)
          .get();
      if (configSellos.exists) {
        final meta = configSellos.data()!['meta'];
        if (meta is int) metaSellos = meta;
        if (meta is double) metaSellos = meta.toInt();
      }
    } catch (_) {}

    final Map<String, double> notaDocentePorCodigo = {};
    try {
      final docentesSnap = await _firestore
          .collection('events')
          .doc(eventoId)
          .collection('notas_docente')
          .get();
      for (final d in docentesSnap.docs) {
        final n = ((d.data()['nota'] ?? 0) as num).toDouble();
        notaDocentePorCodigo[d.id.trim()] = n.clamp(0.0, 20.0);
      }
    } catch (_) {}

    final Map<String, int> sellosPersonalesPorStudent = {};
    if (metaSellos > 0) {
      try {
        final asistPersonalesSnap = await _firestore
            .collection('events')
            .doc(eventoId)
            .collection('asistencias_personales')
            .get();

        final registrosSnaps = await Future.wait(
          asistPersonalesSnap.docs.map((d) => _firestore
              .collection('events')
              .doc(eventoId)
              .collection('asistencias_personales')
              .doc(d.id)
              .collection('registros')
              .get()),
        );

        for (final rs in registrosSnaps) {
          for (final reg in rs.docs) {
            sellosPersonalesPorStudent[reg.id] =
                (sellosPersonalesPorStudent[reg.id] ?? 0) + 1;
          }
        }
      } catch (_) {}
    }

    final List<Future<NotaFinalItem>> futuros = estudianteDocs.map((sDoc) async {
      final sData = sDoc.data();
      final codigoUniv = sData['codigoUniversitario']?.toString() ?? '';

      double notaAsist = 0;
      if (metaSellos > 0) {
        try {
          final scansCount = await _firestore
              .collection('events')
              .doc(eventoId)
              .collection('asistencias')
              .doc(sDoc.id)
              .collection('scans')
              .count()
              .get();
          final sellosProyectos = scansCount.count ?? 0;

          final sellosPersonales = sellosPersonalesPorStudent[sDoc.id] ?? 0;

          final totalSellos = sellosProyectos + sellosPersonales;
          notaAsist = (totalSellos / metaSellos * 20).clamp(0.0, 20.0);
        } catch (_) {}
      }

      final codAlumno = codigoUniv.trim();
      final nombreNorm = normalizarNombre(sData['name']?.toString() ?? '');
      String proyectoDocId = '';
      String proyectoCodigo = '';

      if (codAlumno.isNotEmpty) {
        for (final ref in integrantesProyecto) {
          if (ref.codigo == codAlumno) {
            proyectoDocId = ref.proyectoDocId;
            proyectoCodigo = ref.proyectoCodigo;
            break;
          }
        }
      }

      if (proyectoDocId.isEmpty && nombreNorm.isNotEmpty) {
        final ref = integrantesPorNombre[nombreNorm];
        if (ref != null) {
          proyectoDocId = ref.proyectoDocId;
          proyectoCodigo = ref.proyectoCodigo;
        }
      }

      final seleccionado = proyectoDocId.isNotEmpty;

      final notaJurado =
          seleccionado ? (promedioJuradoPorProyecto[proyectoDocId] ?? 0) : 0.0;

      final notaDocente = notaDocentePorCodigo[codigoUniv.trim()] ?? 0.0;

      final notaFinal = calcularNotaFinal(
        seleccionado: seleccionado,
        notaAsist: notaAsist,
        notaJurado: notaJurado,
        notaDocente: notaDocente,
        config: config,
      );

      return NotaFinalItem(
        studentId: sDoc.id,
        nombre: sData['name']?.toString() ?? 'Sin nombre',
        codigo: codigoUniv,
        ciclo: sData['ciclo']?.toString() ?? '',
        grupo: sData['grupo']?.toString() ?? '',
        seleccionado: seleccionado,
        proyectoCodigo: proyectoCodigo,
        notaAsist: notaAsist,
        notaJurado: notaJurado,
        notaDocente: notaDocente,
        notaFinal: notaFinal,
      );
    }).toList();

    final resultados = await Future.wait(futuros);
    resultados.sort((a, b) => b.notaFinal.compareTo(a.notaFinal));
    return resultados;
  }
}
