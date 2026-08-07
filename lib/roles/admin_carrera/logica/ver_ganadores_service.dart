import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/resolver_nombres_service.dart';

class VerGanadoresService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> cargarEventos({
    required String? filialId,
    required String? facultad,
    required String? carreraId,
  }) async {
    final snap = await _firestore
        .collection('events')
        .where('filialId', isEqualTo: filialId)
        .where('facultad', isEqualTo: facultad)
        .where('carreraId', isEqualTo: carreraId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs
        .map((doc) => {
              'id': doc.id,
              'name': _s(doc.data()['name'], 'Sin nombre'),
            })
        .toList();
  }

  List<String> _extraerCodigos(dynamic integrantes) {
    if (integrantes == null) return [];
    if (integrantes is List) {
      return integrantes.map((e) => e.toString().trim()).toList();
    }
    if (integrantes is String) {
      return integrantes
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  Future<Map<String, List<Map<String, dynamic>>>> calcularGanadores(
    String eventoId,
    Map<String, double> notasDocente, {
    required ResolverNombresService resolverNombres,
  }) async {
    const double escalaBase = 20.0;

    final proyectosSnap = await _firestore
        .collection('events')
        .doc(eventoId)
        .collection('proyectos')
        .get();

    if (proyectosSnap.docs.isEmpty) return {};

    final results = await Future.wait(
      proyectosSnap.docs.map((doc) async {
        try {
          final evalSnap = await _firestore
              .collection('events')
              .doc(eventoId)
              .collection('proyectos')
              .doc(doc.id)
              .collection('evaluaciones')
              .where('evaluada', isEqualTo: true)
              .get();

          if (evalSnap.docs.isEmpty) return null;

          final d = doc.data();

          final notasNormalizadas = <double>[];
          for (final e in evalSnap.docs) {
            final data = e.data();
            final notaTotal = ((data['notaTotal'] ?? 0.0) as num).toDouble();

            if (!data.containsKey('puntajeMaximo')) continue;

            final puntajeMax = (data['puntajeMaximo'] as num).toDouble();
            final maxSeguro = puntajeMax > 0 ? puntajeMax : escalaBase;
            final normalizada =
                ((notaTotal / maxSeguro) * escalaBase).clamp(0.0, escalaBase);

            notasNormalizadas.add(double.parse(normalizada.toStringAsFixed(2)));
          }

          if (notasNormalizadas.isEmpty) return null;

          final promedioJurados = notasNormalizadas.reduce((a, b) => a + b) /
              notasNormalizadas.length;

          double? notaDoc;
          if (notasDocente.isNotEmpty) {
            final integrantesRaw = d['Integrantes'] ?? d['integrantes'];
            final codigos = _extraerCodigos(integrantesRaw);
            for (final cod in codigos) {
              if (notasDocente.containsKey(cod)) {
                notaDoc = notasDocente[cod];
                break;
              }
            }
          }

          final notaFinal =
              notaDoc != null ? (promedioJurados + notaDoc) / 2.0 : promedioJurados;

          final notaMax = notasNormalizadas.reduce((a, b) => a > b ? a : b);
          final notaMin = notasNormalizadas.reduce((a, b) => a < b ? a : b);

          return {
            'proyectoId': doc.id,
            'codigo': _s(d['Código'], 'Sin código'),
            'titulo': _s(d['Título'], 'Sin título'),
            'integrantes': resolverNombres.resolver(d['Integrantes']),
            'sala': _s(d['Sala'], ''),
            'clasificacion': _s(d['Clasificación'], 'Sin categoría'),
            'asesor': _s(d['Asesor'], ''),
            'descripcion': _s(d['Descripción'], ''),
            'promedio': double.parse(notaFinal.toStringAsFixed(2)),
            'promedioJurados': double.parse(promedioJurados.toStringAsFixed(2)),
            'notaDocente': notaDoc,
            'notaMax': notaMax,
            'notaMin': notaMin,
            'cantidadJurados': notasNormalizadas.length,
            'notas': notasNormalizadas,
            'escalaBase': escalaBase,
            'tieneNotaDocente': notaDoc != null,
          };
        } catch (e) {
          debugPrint('❌ [Ganadores] Error en proyecto ${doc.id}: $e');
          return null;
        }
      }),
    );

    final validos = results.whereType<Map<String, dynamic>>().toList();
    if (validos.isEmpty) return {};

    final Map<String, List<Map<String, dynamic>>> porCategoria = {};
    for (final p in validos) {
      final cat = p['clasificacion'] as String;
      porCategoria.putIfAbsent(cat, () => []).add(p);
    }

    return {
      for (final entry in porCategoria.entries)
        entry.key: (entry.value
              ..sort((a, b) =>
                  (b['promedio'] as double).compareTo(a['promedio'] as double)))
            .take(4)
            .toList(),
    };
  }

  String _s(dynamic v, [String fb = '—']) {
    if (v == null) return fb;
    final s = v.toString().trim();
    return s.isEmpty ? fb : s;
  }
}
