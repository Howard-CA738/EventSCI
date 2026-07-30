import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '/prefs_helper.dart';
import '/encryption_helper.dart';

class StudentSecurityService {
  static final _functions = FirebaseFunctions.instance;

  static Future<void> encryptAndSaveDni({
    required String carreraPath,
    required String studentId,
    required String dni,
  }) async {
    try {
      final adminId = await PrefsHelper.getCurrentUserId() ?? '';
      final callable = _functions.httpsCallable('encryptStudentDni');
      await callable.call({
        'carreraPath': carreraPath,
        'studentId':   studentId,
        'dni':         dni,
        'adminId':     adminId,
      });
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Error cifrando DNI: ${e.code} - ${e.message}');
    }
  }

  static Future<String> decryptDni({
    required String carreraPath,
    required String studentId,

    Map<String, dynamic>? studentData,
  }) async {

    final encryptedLocal = studentData?['dniEncrypted'] as String? ?? '';
    if (encryptedLocal.isNotEmpty) {
      final dni = EncryptionHelper.decryptDni(encryptedLocal);
      if (dni.isNotEmpty && dni != '(error)') return dni;
    }


    try {
      final adminId  = await PrefsHelper.getCurrentUserId() ?? '';
      final callable = _functions.httpsCallable('decryptStudentDni');
      final result   = await callable.call({
        'carreraPath': carreraPath,
        'studentId':   studentId,
        'adminId':     adminId,
      });
      return result.data['dni'] as String? ?? '';
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Error descifrando DNI: ${e.code} - ${e.message}');
      return '';
    }
  }
}