import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '/prefs_helper.dart';

class StudentProfileData {
  final String name;
  final String? filial;
  final String? facultad;
  final String? carrera;

  const StudentProfileData({
    required this.name,
    this.filial,
    this.facultad,
    this.carrera,
  });
}

class EstudianteService {
  Future<StudentProfileData> cargarPerfil() async {
    final name = await PrefsHelper.getUserName();
    final userData = await PrefsHelper.getCurrentUserData(forceRefresh: true);

    if (userData == null) {
      return StudentProfileData(name: name ?? 'Estudiante');
    }

    String filial = userData['filial']?.toString().trim() ?? '';
    String facultad = userData['facultad']?.toString().trim() ?? '';
    String carrera = userData['carrera']?.toString().trim() ?? '';

    final bool needsParentDoc =
        filial.isEmpty || facultad.isEmpty || carrera.isEmpty;

    if (needsParentDoc) {
      final carreraPath = userData['carreraPath']?.toString() ?? '';
      if (carreraPath.isNotEmpty) {
        try {
          final parentDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(carreraPath)
              .get();
          if (parentDoc.exists) {
            final parentData = parentDoc.data() ?? {};
            if (filial.isEmpty) {
              filial = parentData['filial']?.toString().trim() ?? '';
            }
            if (facultad.isEmpty) {
              facultad = parentData['facultad']?.toString().trim() ?? '';
            }
            if (carrera.isEmpty) {
              carrera = parentData['carrera']?.toString().trim() ?? '';
            }
          }
        } catch (e) {
          debugPrint('Error leyendo doc padre: $e');
        }
      }
      if (carreraPath.contains('_')) {
        final parts = carreraPath.split('_');
        if (filial.isEmpty) filial = parts.first.trim();
        if (carrera.isEmpty) carrera = parts.skip(1).join('_').trim();
      }
    }

    return StudentProfileData(
      name: name ?? 'Estudiante',
      filial: filial.isNotEmpty ? filial : null,
      facultad: facultad.isNotEmpty ? facultad : null,
      carrera: carrera.isNotEmpty ? carrera : null,
    );
  }

  Stream<DocumentSnapshot> buildStudentStream() {
    return PrefsHelper.getCurrentUserData(forceRefresh: false)
        .asStream()
        .asyncExpand((userData) {
      if (userData == null) return const Stream.empty();

      final carreraPath = userData['carreraPath']?.toString() ?? '';
      final docId = userData['docId']?.toString() ??
          userData['id']?.toString() ??
          '';

      if (carreraPath.isEmpty || docId.isEmpty) return const Stream.empty();

      return FirebaseFirestore.instance
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .doc(docId)
          .snapshots();
    });
  }
}
