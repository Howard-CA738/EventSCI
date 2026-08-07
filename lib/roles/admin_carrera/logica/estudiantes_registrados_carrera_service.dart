import '/prefs_helper.dart';
import '/student_security_service.dart';

class EstudiantesRegistradosCarreraService {
  Future<Map<String, dynamic>?> obtenerDatosAdminCarrera() {
    return PrefsHelper.getAdminCarreraData();
  }

  Future<List<Map<String, dynamic>>> obtenerEstudiantes(String carreraPath) {
    return PrefsHelper.getStudentsByCarrera(carreraPath);
  }

  Future<String> descifrarDni({
    required String carreraPath,
    required String studentId,
    required Map<String, dynamic> studentData,
  }) async {
    final dni = await StudentSecurityService.decryptDni(
      carreraPath: carreraPath,
      studentId: studentId,
      studentData: studentData,
    );
    return dni.isNotEmpty ? dni : 'Sin DNI';
  }

  Future<bool> actualizarEstudiante({
    required String carreraPath,
    required String studentId,
    String? name,
    String? email,
    String? codigoUniversitario,
    String? dni,
    String? celular,
    String? correoInstitucional,
    String? ciclo,
    String? grupo,
  }) async {
    final success = await PrefsHelper.updateStudent(
      carreraPath: carreraPath,
      studentId: studentId,
      name: name?.isNotEmpty == true ? name : null,
      email: email?.isNotEmpty == true ? email : null,
      codigoUniversitario:
          codigoUniversitario?.isNotEmpty == true ? codigoUniversitario : null,
      dni: dni?.isNotEmpty == true ? dni : null,
      celular: celular?.isNotEmpty == true ? celular : null,
      correoInstitucional: correoInstitucional?.isNotEmpty == true
          ? correoInstitucional
          : null,
      ciclo: ciclo,
      grupo: grupo,
    );

    if (success && dni != null && dni.isNotEmpty) {
      await StudentSecurityService.encryptAndSaveDni(
        carreraPath: carreraPath,
        studentId: studentId,
        dni: dni,
      );
    }

    return success;
  }

  Future<bool> eliminarEstudiante({
    required String carreraPath,
    required String studentId,
  }) {
    return PrefsHelper.deleteStudent(carreraPath, studentId);
  }

  Future<Map<String, int>> eliminarEstudiantes(
    List<Map<String, String>> estudiantes,
  ) async {
    final result = await PrefsHelper.deleteMultipleStudents(estudiantes);
    return {
      'success': result['success'] ?? 0,
      'errors': result['errors'] ?? 0,
    };
  }
}
