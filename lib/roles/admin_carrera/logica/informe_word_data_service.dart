import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '/resolver_nombres_service.dart';
import '../datos/fila_ganador.dart';
import '../datos/fila_resultado.dart';

class InformeWordDataService {
  Future<List<String>> obtenerCategorias(String eventId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .get();

      final Set<String> categorias = {};
      for (final doc in snapshot.docs) {
        final clasificacion = doc.data()['Clasificación'] as String?;
        if (clasificacion != null && clasificacion.isNotEmpty) {
          categorias.add(clasificacion);
        }
      }

      return categorias.toList()..sort();
    } catch (e) {
      debugPrint('Error al obtener categorías: $e');
      return [];
    }
  }

  Future<List<FilaResultado>> obtenerFilasResultado(String eventId) async {
    final List<FilaResultado> filas = [];

    try {
      final proyectosSnap = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .get();

      final Map<String, int> conteoPorCategoria = {};

      final Map<String, int> bannerPorCategoria = {};
      final Map<String, int> oralPorCategoria = {};

      for (final doc in proyectosSnap.docs) {
        final data = doc.data();
        final clasificacion =
            (data['Clasificación'] as String?)?.trim() ?? '';
        if (clasificacion.isEmpty) continue;

        conteoPorCategoria[clasificacion] =
            (conteoPorCategoria[clasificacion] ?? 0) + 1;

        final codigo = (data['Código'] as String?)?.trim() ?? '';
        final codigoLower = codigo.toLowerCase();

        final esBanner = codigoLower.contains('banner') ||
            codigoLower.contains('baner');

        if (esBanner) {
          bannerPorCategoria[clasificacion] =
              (bannerPorCategoria[clasificacion] ?? 0) + 1;
        } else if (codigo.isNotEmpty) {
          oralPorCategoria[clasificacion] =
              (oralPorCategoria[clasificacion] ?? 0) + 1;
        }
      }

      if (conteoPorCategoria.isEmpty) return [];

      final categorias = conteoPorCategoria.keys.toList()..sort();

      final Map<String, int> presentadosPorCategoria = {
        for (final cat in categorias) cat: 0,
      };

      for (final proyectoDoc in proyectosSnap.docs) {
        final clasificacion =
            (proyectoDoc.data()['Clasificación'] as String?)?.trim() ?? '';
        if (clasificacion.isEmpty) continue;

        try {
          final evalSnap = await FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .collection('proyectos')
              .doc(proyectoDoc.id)
              .collection('evaluaciones')
              .where('evaluada', isEqualTo: true)
              .limit(1)
              .get();

          if (evalSnap.docs.isNotEmpty) {
            presentadosPorCategoria[clasificacion] =
                (presentadosPorCategoria[clasificacion] ?? 0) + 1;
          }
        } catch (e) {
          debugPrint(
              'Error al obtener evaluaciones del proyecto ${proyectoDoc.id}: $e');
        }
      }

      for (final categoria in categorias) {
        filas.add(FilaResultado(
          categoria: categoria,
          trabajosAceptados: conteoPorCategoria[categoria]!,
          trabajosPresentados: presentadosPorCategoria[categoria] ?? 0,
          exposicionBanner: bannerPorCategoria[categoria] ?? 0,
          exposicionOral: oralPorCategoria[categoria] ?? 0,
        ));
      }
    } catch (e) {
      debugPrint('Error general en _obtenerFilasResultado: $e');
    }

    return filas;
  }

  Future<Map<String, int>> obtenerIndicadores(String eventId) async {
    int matriculados = 0;
    int asistentes = 0;
    int inscritos = 0;
    int exponen = 0;

    try {
      final eventoDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();

      if (!eventoDoc.exists) {
        return {
          'matriculados': 0,
          'asistentes': 0,
          'inscritos': 0,
          'exponen': 0,
        };
      }

      final eventoData = eventoDoc.data()!;
      final String filialNombre =
          (eventoData['filialNombre'] as String?)?.trim() ?? '';
      final String carreraNombre =
          (eventoData['carreraNombre'] as String?)?.trim() ?? '';
      final String docKey = '${filialNombre}_$carreraNombre';

      debugPrint('📊 filialNombre: "$filialNombre"');
      debugPrint('📊 carreraNombre: "$carreraNombre"');
      debugPrint('📊 docKey: "$docKey"');

      if (filialNombre.isNotEmpty && carreraNombre.isNotEmpty) {
        debugPrint('📊 Buscando matriculados en: "$docKey"');
        try {
          final estudiantesSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(docKey)
              .collection('students')
              .count()
              .get();
          matriculados = estudiantesSnap.count ?? 0;
        } catch (e) {
          debugPrint('count() no soportado, usando fallback: $e');
          final estudiantesSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(docKey)
              .collection('students')
              .get();
          matriculados = estudiantesSnap.docs.length;
        }
        debugPrint('✅ Matriculados: $matriculados');
      }

      if (filialNombre.isNotEmpty && carreraNombre.isNotEmpty) {
        try {
          final inscritosSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(docKey)
              .collection('students')
              .where('pagos.$eventId', isEqualTo: true)
              .get();
          inscritos = inscritosSnap.docs.length;
          debugPrint('📊 Inscritos (pagaron): $inscritos');
        } catch (e) {
          debugPrint('Error al contar inscritos: $e');
        }
      }

      final proyectosSnap = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .get();

      final Set<String> estudiantesQueExponen = {};

      for (final doc in proyectosSnap.docs) {
        final evalSnap = await doc.reference
            .collection('evaluaciones')
            .where('evaluada', isEqualTo: true)
            .limit(1)
            .get();

        if (evalSnap.docs.isNotEmpty) {
          final data = doc.data();
          final integrantes = data['Integrantes'];

          List<String> lista = [];
          if (integrantes is List) {
            lista = integrantes.map((e) => e.toString().trim()).toList();
          } else if (integrantes is String && integrantes.isNotEmpty) {
            lista = integrantes
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }

          for (final codigo in lista) {
            if (codigo.isNotEmpty) {
              estudiantesQueExponen.add(codigo);
            }
          }
        }
      }

      exponen = estudiantesQueExponen.length;
      debugPrint('📊 Estudiantes que exponen: $exponen');

      final asistenciasSnap = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('asistencias')
          .get();

      final asistPersonalesSnap = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('asistencias_personales')
          .get();

      final Set<String> idsAsistentes = {
        ...asistenciasSnap.docs.map((d) => d.id),
      };

      for (final asistDoc in asistPersonalesSnap.docs) {
        final registrosSnap = await FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .collection('asistencias_personales')
            .doc(asistDoc.id)
            .collection('registros')
            .get();
        for (final reg in registrosSnap.docs) {
          idsAsistentes.add(reg.id);
        }
      }

      asistentes = idsAsistentes.length;
      debugPrint('✅ Asistentes únicos (ambas fuentes): $asistentes');
    } catch (e) {
      debugPrint('Error en _obtenerIndicadores: $e');
    }

    return {
      'matriculados': matriculados,
      'asistentes': asistentes,
      'inscritos': inscritos,
      'exponen': exponen,
    };
  }

  Future<List<FilaGanador>> obtenerGanadores(
    String eventId, {
    required String filialId,
    required String facultad,
    required ResolverNombresService resolver,
  }) async {
    final List<FilaGanador> filas = [];
    const double escalaBase = 20.0;

    try {
      final proyectosSnap = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .get();

      if (proyectosSnap.docs.isEmpty) return [];

      final results = await Future.wait(
        proyectosSnap.docs.map((proyectoDoc) async {
          Query evalQuery = FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .collection('proyectos')
              .doc(proyectoDoc.id)
              .collection('evaluaciones')
              .where('evaluada', isEqualTo: true);

          if (filialId.isNotEmpty) {
            evalQuery = evalQuery.where('filialId', isEqualTo: filialId);
          }
          if (facultad.isNotEmpty) {
            evalQuery = evalQuery.where('facultad', isEqualTo: facultad);
          }

          final evalSnap = await evalQuery.get();

          if (evalSnap.docs.isEmpty) return null;

          final pData = proyectoDoc.data();

          final notasNormalizadas = <double>[];
          for (final e in evalSnap.docs) {
            final data = e.data() as Map<String, dynamic>;
            final notaTotal = ((data['notaTotal'] ?? 0.0) as num).toDouble();

            if (!data.containsKey('puntajeMaximo')) {
              debugPrint(
                '⚠️ [InformeWord] Evaluación ${e.id} sin puntajeMaximo — omitida',
              );
              continue;
            }

            final puntajeMax = (data['puntajeMaximo'] as num).toDouble();
            final maxSeguro = puntajeMax > 0 ? puntajeMax : escalaBase;
            final normalizada =
                ((notaTotal / maxSeguro) * escalaBase).clamp(0.0, escalaBase);

            notasNormalizadas.add(double.parse(normalizada.toStringAsFixed(2)));
          }

          if (notasNormalizadas.isEmpty) return null;

          final promedio = notasNormalizadas.reduce((a, b) => a + b) /
              notasNormalizadas.length;

          return {
            'codigo': pData['Código'] ?? '',
            'titulo': pData['Título'] ?? '',
            'integrantes': resolver.resolver(pData['Integrantes']),
            'clasificacion': pData['Clasificación'] ?? 'Sin categoría',
            'promedio': double.parse(promedio.toStringAsFixed(2)),
          };
        }),
      );

      final validos = results.whereType<Map<String, dynamic>>().toList();
      if (validos.isEmpty) return [];

      final Map<String, List<Map<String, dynamic>>> porCategoria = {};
      for (final p in validos) {
        final cat = p['clasificacion'] as String;
        porCategoria.putIfAbsent(cat, () => []).add(p);
      }

      porCategoria.forEach((categoria, lista) {
        lista.sort((a, b) =>
            (b['promedio'] as double).compareTo(a['promedio'] as double));
        for (final p in lista.take(3)) {
          filas.add(FilaGanador(
            categoria: categoria,
            codigo: p['codigo'] as String,
            titulo: p['titulo'] as String,
            integrantes: p['integrantes'] as String,
            promedio: p['promedio'] as double,
          ));
        }
      });

      filas.sort((a, b) {
        final c = a.categoria.compareTo(b.categoria);
        return c != 0 ? c : b.promedio.compareTo(a.promedio);
      });
    } catch (e) {
      debugPrint('Error en _obtenerGanadores: $e');
    }
    return filas;
  }
}
