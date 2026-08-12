import 'package:cloud_firestore/cloud_firestore.dart';

class GestionSesionesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> localizarCarreraPath({
    required String filialNombre,
    required String carrera,
  }) async {
    final snap = await _firestore
        .collection('users')
        .where('filial', isEqualTo: filialNombre)
        .where('carrera', isEqualTo: carrera)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  Future<List<Map<String, dynamic>>> obtenerEstudiantes(
      String carreraPath) async {
    final snap = await _firestore
        .collection('users')
        .doc(carreraPath)
        .collection('students')
        .get();

    final lista = snap.docs.map((doc) {
      final data = doc.data();
      return {
        'docId': doc.id,
        'nombre':
            data['name'] ?? data['nombre'] ?? data['usuario'] ?? 'Sin nombre',
        'usuario': data['username'] ?? data['usuario'] ?? '',
        'sessionActive': data['sessionActive'] ?? false,
        'sessionToken': data['sessionToken'] ?? '',
        'lastLogin': data['lastLogin'],
        'primeraVez': data['primeraVez'] ?? true,
        'deviceId': data['deviceId'] ?? '',
        'bloqueadoPermanente': data['bloqueadoPermanente'] ?? false,
        'bloqueadoEn': data['bloqueadoEn'],
      };
    }).toList();

    lista.sort(
        (a, b) => a['nombre'].toString().compareTo(b['nombre'].toString()));
    return lista;
  }

  Future<void> desbloquearEstudiantes({
    required String carreraPath,
    required List<Map<String, dynamic>> estudiantes,
  }) async {
    final studentsRef =
        _firestore.collection('users').doc(carreraPath).collection('students');

    WriteBatch batch = _firestore.batch();
    int ops = 0;

    for (final e in estudiantes) {
      batch.update(studentsRef.doc(e['docId']), {
        'sessionActive': false,
        'sessionToken': null,
        'primeraVez': true,
        'bloqueadoPermanente': false,
        'deviceId': null,
        'bloqueadoEn': null,
        'sessionResetAt': FieldValue.serverTimestamp(),
      });
      ops++;

      final deviceId = e['deviceId'] as String?;
      if (deviceId != null && deviceId.isNotEmpty) {
        batch.delete(_firestore.collection('blocked_devices').doc(deviceId));
        ops++;
      }

      if (ops >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        ops = 0;
      }
    }

    if (ops > 0) {
      await batch.commit();
    }
  }

  Future<void> resetearSesion({
    required String carreraPath,
    required Map<String, dynamic> estudiante,
  }) async {
    await _firestore
        .collection('users')
        .doc(carreraPath)
        .collection('students')
        .doc(estudiante['docId'])
        .update({
      'sessionActive': false,
      'sessionToken': null,
      'primeraVez': true,
      'bloqueadoPermanente': false,
      'deviceId': null,
      'bloqueadoEn': null,
      'sessionResetAt': FieldValue.serverTimestamp(),
    });

    final deviceId = estudiante['deviceId'] as String?;
    if (deviceId != null && deviceId.isNotEmpty) {
      await _firestore.collection('blocked_devices').doc(deviceId).delete();
    }
  }

  Future<void> bloquearSesion({
    required String carreraPath,
    required String studentId,
  }) {
    return _firestore
        .collection('users')
        .doc(carreraPath)
        .collection('students')
        .doc(studentId)
        .update({
      'sessionActive': false,
      'sessionToken': null,
      'bloqueadoPermanente': true,
      'bloqueadoEn': FieldValue.serverTimestamp(),
    });
  }
}
