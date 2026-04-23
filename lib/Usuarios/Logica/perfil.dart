import 'package:flutter/material.dart';
import '/prefs_helper.dart';

class PerfilController with ChangeNotifier {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? errorMessage;

  // 🔥 INYECCIÓN PARA TESTING (NUEVO)
  final Future<Map<String, dynamic>?> Function()? fetchUserData;

  PerfilController({this.fetchUserData});

  Future<void> loadUserData() async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      // 👇 USA MOCK EN TEST O PREFS EN PRODUCCIÓN
      final data = fetchUserData != null
          ? await fetchUserData!()
          : await PrefsHelper.getCurrentUserData();

      if (data != null) {
        userData = data;
      } else {
        errorMessage = 'No se pudo cargar la información del usuario';
      }
    } catch (e) {
      errorMessage = 'Error cargando datos: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Devuelve el nombre de la filial/sede del estudiante.
  String? getSede() {
    final sede   = userData?['sede']?.toString()   ?? '';
    final filial = userData?['filial']?.toString() ?? '';
    if (sede.isNotEmpty)   return sede;
    if (filial.isNotEmpty) return filial;
    return null;
  }

  /// Retorna el valor de un campo si no está vacío.
  String? getCampo(String key) {
    final valor = (userData?[key] ?? '').toString();
    return valor.isNotEmpty ? valor : null;
  }
}