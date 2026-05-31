import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class DeviceHelper {
  static const String _keyDeviceId = 'app_unique_device_id';

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    // Si ya tiene UUID guardado, siempre usar ese
    final savedId = prefs.getString(_keyDeviceId);
    if (savedId != null && savedId.isNotEmpty) {
      return savedId;
    }

    // Primera vez → generar UUID completamente único
    final newId = const Uuid().v4();
    await prefs.setString(_keyDeviceId, newId);

    debugPrint('✅ Nuevo UUID de dispositivo generado: $newId');
    return newId;
  }
}