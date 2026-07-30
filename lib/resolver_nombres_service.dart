import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';



class ResolverNombresService {
  static final ResolverNombresService _instance =
      ResolverNombresService._internal();
  factory ResolverNombresService() => _instance;
  ResolverNombresService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _cache = {};



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




  String resolver(dynamic integrantes) {
  if (integrantes == null) return '';

  List<String> codigos;


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