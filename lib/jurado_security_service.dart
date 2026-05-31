import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '/prefs_helper.dart';

class JuradoSecurityService {
  static final _functions = FirebaseFunctions.instance;

 static Future<void> encryptAndSavePassword({
  required String juradoId,
  required String password,
}) async {
  try {
    final adminId = await PrefsHelper.getCurrentUserId() ?? '';
    final callable = _functions.httpsCallable('encryptJuradoPassword');
    await callable.call({
      'juradoId': juradoId,
      'password': password,
      'adminId':  adminId, // ✅ doc ID real del admin
    });
  } on FirebaseFunctionsException catch (e) {
    debugPrint('❌ Error cifrando: ${e.code} - ${e.message}');
  }
}

static Future<String> decryptPassword({
  required String juradoId,
}) async {
  try {
    final adminId = await PrefsHelper.getCurrentUserId() ?? '';
    final callable = _functions.httpsCallable('decryptJuradoPassword');
    final result = await callable.call({
      'juradoId': juradoId,
      'adminId':  adminId, // ✅ doc ID real del admin
    });
    return result.data['password'] as String? ?? '';
  } on FirebaseFunctionsException catch (e) {
    debugPrint('❌ Error descifrando: ${e.code} - ${e.message}');
    return '';
  }
}
}