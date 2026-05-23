import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as enc;

class EncryptionHelper {
  // 32 caracteres exactos, sin caracteres especiales
  static const String _aesKey = 'EvSc2024SecureKeyUPEUDNI32CharsX';
  static const String _aesIV  = 'InitVector161616'; // 16 caracteres exactos

  static final _key = enc.Key.fromUtf8(_aesKey);
  static final _iv  = enc.IV.fromUtf8(_aesIV);

  static int get keyLength => _aesKey.length;

  static String encryptDni(String plainDni) {
    try {
      if (plainDni.trim().isEmpty) {
        debugPrint('⚠️ encryptDni recibió cadena vacía');
        return '';
      }
      final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(plainDni.trim(), iv: _iv);
      debugPrint('✅ encryptDni OK: ${encrypted.base64}');
      return encrypted.base64;
    } catch (e) {
      debugPrint('❌ Error en encryptDni: $e');
      return '';
    }
  }

  static String decryptDni(String encryptedBase64) {
    try {
      if (encryptedBase64.trim().isEmpty) return 'Sin DNI';
      final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
      final encrypted = enc.Encrypted.fromBase64(encryptedBase64);
      return encrypter.decrypt(encrypted, iv: _iv);
    } catch (e) {
      debugPrint('❌ Error en decryptDni: $e');
      return '(error)';
    }
  }
}