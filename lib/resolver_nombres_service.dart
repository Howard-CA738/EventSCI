import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Singleton que resuelve códigos universitarios → nombres de estudiantes.
/// Usa cache para no repetir consultas en la misma sesión.
class ResolverNombresService {
  static final ResolverNombresService _instance =
      ResolverNombresService._internal();
  factory ResolverNombresService() => _instance;
  ResolverNombresService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _cache = {}; // codigo → nombre

  /// Carga todos los estudiantes de una carrera en el cache.
  /// Llamar una vez al iniciar la pantalla.
  Future<void> cargarEstudiantes({
  required String filialNombre,
  required String carrera,
}) async {
  try {
    final docKey = '${filialNombre}_$carrera';
    debugPrint('🔑 ResolverNombres docKey: $docKey');
    
    final snap = await _firestore
        .collection('users')
        .doc(docKey)
        .collection('students')
        .get();

    debugPrint('👥 Estudiantes encontrados: ${snap.docs.length}');

    for (final doc in snap.docs) {
      final d = doc.data();
      final codigo = (d['codigoUniversitario'] ?? '').toString().trim();
      final nombre = (d['name'] ?? '').toString().trim();
      if (codigo.isNotEmpty && nombre.isNotEmpty) {
        _cache[codigo] = nombre;
        debugPrint('   ✅ $codigo → $nombre');
      }
    }
    debugPrint('📦 Cache total: ${_cache.length}');
  } catch (e) {
    debugPrint('❌ ResolverNombres error: $e');
  }
}

  /// Resuelve un string de integrantes (códigos separados por coma)
  /// y devuelve los nombres separados por coma.
  /// Si no encuentra el nombre, deja el código original.
  String resolver(dynamic integrantes) {
  if (integrantes == null) return '';
  
  List<String> codigos;
  
  // Manejar List directamente
  if (integrantes is List) {
    codigos = integrantes
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  } else {
    final texto = integrantes.toString().trim();
    if (texto.isEmpty) return '';
    codigos = texto
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  return codigos
      .map((c) => _cache[c] ?? c)
      .join(', ');
}

  /// Versión que devuelve lista en vez de string.
  List<String> resolverLista(dynamic integrantes) {
  if (integrantes == null) return [];
  
  List<String> codigos;
  
  if (integrantes is List) {
    codigos = integrantes
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  } else {
    final texto = integrantes.toString().trim();
    if (texto.isEmpty) return [];
    codigos = texto
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  return codigos
      .map((c) => _cache[c] ?? c)
      .toList();
}

  void limpiarCache() => _cache.clear();
}