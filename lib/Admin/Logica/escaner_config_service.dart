import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Maneja el tiempo de bloqueo (cooldown) del escáner de forma GLOBAL.
/// El valor vive en Firestore: config/escaner_bloqueo { cooldownSegundos }.
class EscanerConfigService {
  static final _firestore = FirebaseFirestore.instance;
  static const _prefsKey = 'cooldown_segundos_cache';

  /// Valor por defecto si no hay conexión ni cache (10 min).
  static const int defaultCooldown = 600;

  static DocumentReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('config').doc('escaner_bloqueo');

  /// Lee el cooldown desde Firestore y lo cachea localmente.
  /// Si falla la red, usa el último valor cacheado; si no hay, el default.
  static Future<int> getCooldownSegundos() async {
    try {
      final doc = await _ref.get();
      if (doc.exists) {
        final valor = (doc.data()?['cooldownSegundos'] as num?)?.toInt();
        if (valor != null && valor >= 0) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_prefsKey, valor);
          return valor;
        }
      }
    } catch (_) {
      // Sin conexión o permisos → caemos al cache.
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsKey) ?? defaultCooldown;
  }

  /// Stream en vivo para la pantalla del super admin.
  static Stream<int> watchCooldownSegundos() {
    return _ref.snapshots().map((doc) {
      if (doc.exists) {
        final valor = (doc.data()?['cooldownSegundos'] as num?)?.toInt();
        if (valor != null && valor >= 0) return valor;
      }
      return defaultCooldown;
    });
  }

  /// Guarda el nuevo valor. Solo lo debe poder ejecutar el super admin
  /// (lo controlas con las reglas de Firestore, ver más abajo).
  static Future<void> setCooldownSegundos(int segundos) async {
    await _ref.set({
      'cooldownSegundos': segundos,
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}