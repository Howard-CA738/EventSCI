import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class DeviceHelper {
  static const String _keyDeviceId = 'app_unique_device_id';

  static Future<String> getDeviceId() async {
    final prefs   = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_keyDeviceId);
    if (savedId != null && savedId.isNotEmpty) return savedId;

    final newId = kIsWeb ? 'web_${const Uuid().v4()}' : const Uuid().v4();
    await prefs.setString(_keyDeviceId, newId);
    debugPrint('✅ Nuevo device ID generado: $newId');
    return newId;
  }
}