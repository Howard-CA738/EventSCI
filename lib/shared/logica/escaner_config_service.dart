import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';



class EscanerConfigService {
  static final _firestore = FirebaseFirestore.instance;
  static const _prefsKey = 'cooldown_segundos_cache';


  static const int defaultCooldown = 600;

  static DocumentReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('config').doc('escaner_bloqueo');



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

    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsKey) ?? defaultCooldown;
  }


  static Stream<int> watchCooldownSegundos() {
    return _ref.snapshots().map((doc) {
      if (doc.exists) {
        final valor = (doc.data()?['cooldownSegundos'] as num?)?.toInt();
        if (valor != null && valor >= 0) return valor;
      }
      return defaultCooldown;
    });
  }



  static Future<void> setCooldownSegundos(int segundos) async {
    await _ref.set({
      'cooldownSegundos': segundos,
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}