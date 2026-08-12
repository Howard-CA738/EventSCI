import 'package:cloud_firestore/cloud_firestore.dart';

class AsistenciasService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> cargarResumen(String eventoId) async {
    final results = await Future.wait([
      _firestore
          .collection('events')
          .doc(eventoId)
          .collection('asistencias')
          .get(),
      _firestore
          .collection('events')
          .doc(eventoId)
          .collection('asistencias_personales')
          .get(),
      _firestore
          .collectionGroup('registros')
          .where('eventId', isEqualTo: eventoId)
          .where('type', isEqualTo: 'asistencia_personal')
          .get(),
    ]);

    final snapProyectos = results[0];
    final snapPersonales = results[1];
    final snapHuerfanos = results[2];

    final Set<String> asistenciasExistentes =
        snapPersonales.docs.map((d) => d.id).toSet();

    final List<Future<QuerySnapshot>> registrosFutures = snapPersonales.docs
        .map((asistDoc) => _firestore
            .collection('events')
            .doc(eventoId)
            .collection('asistencias_personales')
            .doc(asistDoc.id)
            .collection('registros')
            .get())
        .toList();

    final registrosSnaps = await Future.wait(registrosFutures);

    final Map<String, String> nombrePorAsistenciaId = {};
    for (final regDoc in snapHuerfanos.docs) {
      final rd = regDoc.data();
      final asistId = rd['asistenciaId']?.toString() ?? '';
      final nombre =
          rd['asistenciaNombre']?.toString() ?? 'Asistencia personal';
      if (asistId.isNotEmpty) {
        nombrePorAsistenciaId.putIfAbsent(asistId, () => nombre);
      }
    }

    final huerfanosReales = snapHuerfanos.docs.where((regDoc) {
      final rd = regDoc.data();
      final asistId = rd['asistenciaId']?.toString() ?? '';
      return !asistenciasExistentes.contains(asistId);
    }).toList();

    final Map<String, int> sellosPersonalesPorEstudiante = {};

    for (final regSnap in registrosSnaps) {
      for (final regDoc in regSnap.docs) {
        final sid = regDoc.id;
        sellosPersonalesPorEstudiante[sid] =
            (sellosPersonalesPorEstudiante[sid] ?? 0) + 1;
      }
    }

    for (final regDoc in huerfanosReales) {
      final sid = regDoc.id;
      sellosPersonalesPorEstudiante[sid] =
          (sellosPersonalesPorEstudiante[sid] ?? 0) + 1;
    }

    final Map<String, DocumentSnapshot?> porStudentId = {};

    for (final doc in snapProyectos.docs) {
      porStudentId.putIfAbsent(doc.id, () => doc);
    }
    for (final regSnap in registrosSnaps) {
      for (final regDoc in regSnap.docs) {
        porStudentId.putIfAbsent(regDoc.id, () => null);
        if (porStudentId[regDoc.id] == null) {
          porStudentId[regDoc.id] = regDoc;
        }
      }
    }

    for (final regDoc in huerfanosReales) {
      porStudentId.putIfAbsent(regDoc.id, () => regDoc);
    }

    final futures = porStudentId.entries.map((entry) async {
      final studentId = entry.key;
      final sourceDoc = entry.value;
      final data = (sourceDoc?.data() ?? {}) as Map<String, dynamic>;

      QuerySnapshot? scansSnap;
      try {
        scansSnap = await _firestore
            .collection('events')
            .doc(eventoId)
            .collection('asistencias')
            .doc(studentId)
            .collection('scans')
            .get();
      } catch (_) {}

      final sellosProyectos = scansSnap?.docs.length ?? 0;
      final sellosPersonales = sellosPersonalesPorEstudiante[studentId] ?? 0;

      String? ciclo = data['ciclo']?.toString();
      String? grupo = data['grupo']?.toString();

      if (ciclo == null || grupo == null) {
        try {
          final carreraPath = data['carrera'];
          final username = data['studentUsername'] ?? data['username'];
          if (carreraPath != null &&
              username != null &&
              (username as String).isNotEmpty) {
            final q = await _firestore
                .collection('users')
                .doc(carreraPath as String)
                .collection('students')
                .where('username', isEqualTo: username)
                .limit(1)
                .get();
            if (q.docs.isNotEmpty) {
              final sd = q.docs.first.data();
              ciclo ??= sd['ciclo']?.toString();
              grupo ??= sd['grupo']?.toString();
            }
          }
        } catch (_) {}
      }

      final scans = (scansSnap?.docs ?? []).map((s) {
        final sd = s.data() as Map<String, dynamic>;
        return {
          'id': s.id,
          'codigoProyecto': sd['codigoProyecto'] ?? 'Sin código',
          'tituloProyecto': sd['tituloProyecto'] ?? 'Sin título',
          'categoria': sd['categoria'] ?? 'Sin categoría',
          'grupo': sd['grupo'],
          'timestamp': sd['timestamp'],
        };
      }).toList();

      scans.sort((a, b) {
        final tA = (a['timestamp'] as Timestamp?)?.toDate();
        final tB = (b['timestamp'] as Timestamp?)?.toDate();
        if (tA == null || tB == null) return 0;
        return tB.compareTo(tA);
      });

      final List<Map<String, dynamic>> personales = [];

      for (int idx = 0; idx < snapPersonales.docs.length; idx++) {
        final asistDoc = snapPersonales.docs[idx];
        final asistData = asistDoc.data();
        final regSnap = registrosSnaps[idx];
        for (final regDoc in regSnap.docs) {
          if (regDoc.id != studentId) continue;
          final rd = regDoc.data() as Map<String, dynamic>;
          personales.add({
            'id': regDoc.id,
            'asistenciaId': asistDoc.id,
            'asistenciaNombre': rd['asistenciaNombre'] ??
                asistData['nombre'] ??
                'Asistencia personal',
            'asistenciaTipo': rd['asistenciaTipo'] ??
                asistData['tipo'] ??
                'Asistencia Personal',
            'timestamp': rd['timestamp'],
          });
        }
      }

      for (final regDoc in huerfanosReales) {
        if (regDoc.id != studentId) continue;
        final rd = regDoc.data();
        final asistId = rd['asistenciaId']?.toString() ?? '';
        personales.add({
          'id': regDoc.id,
          'asistenciaId': asistId,
          'asistenciaNombre': rd['asistenciaNombre'] ??
              nombrePorAsistenciaId[asistId] ??
              'Asistencia personal',
          'asistenciaTipo': rd['asistenciaTipo'] ?? 'Asistencia Personal',
          'timestamp': rd['timestamp'],
        });
      }

      personales.sort((a, b) {
        final tA = (a['timestamp'] as Timestamp?)?.toDate();
        final tB = (b['timestamp'] as Timestamp?)?.toDate();
        if (tA == null || tB == null) return 0;
        return tB.compareTo(tA);
      });

      dynamic lastScan = data['lastScan'];

      return {
        'id': studentId,
        'nombre': data['studentName'] ?? data['nombre'] ?? 'Sin nombre',
        'username': data['studentUsername'] ?? data['username'] ?? '',
        'dni': data['studentDNI'] ?? data['dni'] ?? '',
        'codigo': data['studentCodigo'] ?? data['codigoUniversitario'] ?? '',
        'facultad': data['facultad'] ?? '',
        'carrera': data['carrera'] ?? '',
        'ciclo': ciclo ?? 'N/A',
        'grupo': grupo ?? 'N/A',
        'totalScans': sellosProyectos + sellosPersonales,
        'lastScan': lastScan,
        'scans': scans,
        'personales': personales,
      };
    }).toList();

    final lista = await Future.wait(futures);

    lista.sort((a, b) {
      final cA = _parseCiclo(a['ciclo']);
      final cB = _parseCiclo(b['ciclo']);
      if (cA != cB) return cA.compareTo(cB);
      final gA = _parseGrupo(a['grupo']);
      final gB = _parseGrupo(b['grupo']);
      if (gA != gB) return gA.compareTo(gB);
      return (a['nombre'] as String).compareTo(b['nombre'] as String);
    });

    return lista;
  }

  int _parseCiclo(String? ciclo) {
    if (ciclo == null || ciclo.isEmpty || ciclo == 'N/A') return 999;
    try {
      final m = RegExp(r'\d+').firstMatch(ciclo);
      if (m != null) return int.parse(m.group(0)!);
    } catch (_) {}
    return 999;
  }

  int _parseGrupo(String? grupo) {
    if (grupo == null || grupo.isEmpty || grupo == 'N/A') return 999;
    final g = grupo.toLowerCase();
    if (g.contains('único') || g.contains('unico')) return 0;
    try {
      final m = RegExp(r'\d+').firstMatch(grupo);
      if (m != null) return int.parse(m.group(0)!);
    } catch (_) {}
    return 999;
  }
}
