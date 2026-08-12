import 'package:cloud_firestore/cloud_firestore.dart';

double calcularNota(int totalSellos, int metaSellos) {
  if (metaSellos <= 0) return 0.0;
  return (totalSellos / metaSellos * 20).clamp(0.0, 20.0);
}

class NotasPorSellosResultado {
  final bool tieneConfig;
  final int metaSellos;
  final List<Map<String, dynamic>> notas;

  NotasPorSellosResultado({
    required this.tieneConfig,
    required this.metaSellos,
    required this.notas,
  });
}

class NotasPorSellosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _docIdConfig({
    required String? filialId,
    required String? facultad,
    required String? carreraId,
    required String eventoId,
  }) =>
      '${filialId}_${facultad}_${carreraId}_$eventoId'.replaceAll(' ', '_');

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

    return snap.docs.map((doc) {
      final d = doc.data();
      return {
        'id': doc.id,
        'name': d['name'] ?? 'Sin nombre',
        'date': d['fecha'],
      };
    }).toList();
  }

  Future<NotasPorSellosResultado> cargarNotasDeEvento({
    required String? filialId,
    required String? facultad,
    required String? carreraId,
    required String? carreraNombre,
    required String filialNombre,
    required String eventoId,
  }) async {
    final docIdConfig = _docIdConfig(
      filialId: filialId,
      facultad: facultad,
      carreraId: carreraId,
      eventoId: eventoId,
    );
    final configDoc = await _firestore
        .collection('sellos_asistencia')
        .doc(docIdConfig)
        .get();

    if (!configDoc.exists) {
      return NotasPorSellosResultado(
          tieneConfig: false, metaSellos: 0, notas: []);
    }

    final meta = configDoc.data()!['meta'];
    final int? metaInt;
    if (meta is int && meta > 0) {
      metaInt = meta;
    } else if (meta is double && meta > 0) {
      metaInt = meta.toInt();
    } else {
      metaInt = null;
    }

    if (metaInt == null) {
      return NotasPorSellosResultado(
          tieneConfig: false, metaSellos: 0, notas: []);
    }
    final int metaSellos = metaInt;

    final candidatos = [
      '${filialNombre}_$carreraNombre',
      '${filialNombre}_$carreraId',
      '${filialId}_$carreraNombre',
      '${filialId}_$carreraId',
    ];

    List<QueryDocumentSnapshot<Map<String, dynamic>>> estudiantesDocs = [];
    for (final path in candidatos) {
      final snap = await _firestore
          .collection('users')
          .doc(path)
          .collection('students')
          .get();
      if (snap.docs.isNotEmpty) {
        estudiantesDocs = snap.docs;
        break;
      }
    }

    if (estudiantesDocs.isEmpty) {
      return NotasPorSellosResultado(
          tieneConfig: true, metaSellos: metaSellos, notas: []);
    }

    final asistPersonalesSnap = await _firestore
        .collection('events')
        .doc(eventoId)
        .collection('asistencias_personales')
        .get();

    final List<Map<String, dynamic>> notas = [];

    await Future.wait(estudiantesDocs.map((studentDoc) async {
      final studentData = studentDoc.data();
      final studentId = studentDoc.id;

      int sellosProyectos = 0;
      try {
        final scansSnap = await _firestore
            .collection('events')
            .doc(eventoId)
            .collection('asistencias')
            .doc(studentId)
            .collection('scans')
            .get();
        sellosProyectos = scansSnap.docs.length;
      } catch (_) {}

      int sellosPersonales = 0;
      try {
        final resultados = await Future.wait(
          asistPersonalesSnap.docs.map((asistDoc) => _firestore
              .collection('events')
              .doc(eventoId)
              .collection('asistencias_personales')
              .doc(asistDoc.id)
              .collection('registros')
              .doc(studentId)
              .get()),
        );

        sellosPersonales = resultados.where((doc) => doc.exists).length;
      } catch (_) {}

      final totalSellos = sellosProyectos + sellosPersonales;
      final nota = calcularNota(totalSellos, metaSellos);

      notas.add({
        'studentId': studentId,
        'name': studentData['name'] ?? 'Sin nombre',
        'username': studentData['username'] ?? '',
        'codigo': studentData['codigoUniversitario'] ?? '',
        'ciclo': studentData['ciclo']?.toString() ?? '',
        'grupo': studentData['grupo']?.toString() ?? '',
        'totalSellos': totalSellos,
        'sellosProyectos': sellosProyectos,
        'sellosPersonales': sellosPersonales,
        'nota': nota,
      });
    }));

    notas.sort(
        (a, b) => (b['nota'] as double).compareTo(a['nota'] as double));

    return NotasPorSellosResultado(
        tieneConfig: true, metaSellos: metaSellos, notas: notas);
  }
}
