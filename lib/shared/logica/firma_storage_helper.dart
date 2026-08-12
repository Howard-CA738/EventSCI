import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

// Descarga la imagen de una firma. Si la URL directa falla (token vencido),
// reintenta resolviendo una URL fresca desde Firebase Storage.
Future<Uint8List?> descargarFirma(String url) async {
  if (url.isEmpty) return null;
  try {
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (response.statusCode == 200) return response.bodyBytes;
  } catch (e) {
    debugPrint('Error HTTP directo: $e — intentando refrescar...');
  }
  try {
    final uri = Uri.parse(url);
    final segments = uri.path.split('/o/');
    if (segments.length < 2) return null;
    final fullPath = Uri.decodeComponent(segments.last.split('?').first);
    final newUrl =
        await FirebaseStorage.instance.ref(fullPath).getDownloadURL();
    final response = await http
        .get(Uri.parse(newUrl))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 200) return response.bodyBytes;
  } catch (e) {
    debugPrint('Error refrescando URL: $e');
  }
  return null;
}
