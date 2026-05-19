import 'dart:convert';
import 'package:crypto/crypto.dart';

class PasswordHelper {
  static const String _appSalt = 'eventsci_salt_2024_upeu';

  /// Retorna el hash SHA-256 de [password] + salt.
  /// Siempre retorna una cadena hexadecimal de 64 caracteres.
  static String hashPassword(String password) {
    final saltedInput = '$_appSalt:${password.trim()}';
    final bytes = utf8.encode(saltedInput);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Compara [plainPassword] con [storedHash].
  /// Retorna true si coinciden.
  static bool verifyPassword(String plainPassword, String storedHash) {
    if (plainPassword.isEmpty || storedHash.isEmpty) return false;
    if (!_isSha256Hash(storedHash)) {
      return plainPassword.trim() == storedHash;
    }

    return hashPassword(plainPassword) == storedHash;
  }

  static bool _isSha256Hash(String value) {
    return value.length == 64 &&
        RegExp(r'^[a-f0-9]+$').hasMatch(value);
  }
}