import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'reporte_usuarios_service.dart';


class EventoFinalRow {
  final int nro;
  final String filial;
  final String facultadCorta;
  final String epNombreCorto;
  final String escuelaProfesional;
  final String nombreEvento;
  final String fechaEvento;
  final int matriculados;
  final int inscritos;
  final int juradosEvaluadores;
  final int ponenciasOrales;
  final int ponenciasPoster;

  const EventoFinalRow({
    required this.nro,
    required this.filial,
    required this.facultadCorta,
    required this.epNombreCorto,
    required this.escuelaProfesional,
    required this.nombreEvento,
    required this.fechaEvento,
    required this.matriculados,
    required this.inscritos,
    required this.juradosEvaluadores,
    required this.ponenciasOrales,
    required this.ponenciasPoster,
  });
}

class _Mapeo {
  final String facultadCorta;
  final String nombreCorto;
  const _Mapeo(this.facultadCorta, this.nombreCorto);
}

class ReporteFinalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  static const int _umbralEstudiantes = 20;





  static final Map<String, _Mapeo> _overrides = {
    'ep contabilidad - presencial': _Mapeo('FCE', 'CONTABILIDAD'),
    'ep administracion - presencial': _Mapeo('FCE', 'ADMINISTRACIÓN'),
    'ep contabilidad - semipresencial': _Mapeo('SEMI', 'CONTA SEMI'),
    'ep administracion - semipresencial': _Mapeo('SEMI', 'ADMIN SEMI'),
    'ep marketing y negocios internacionales': _Mapeo('FCE', 'MARKETING'),
    'ep administracion - ead': _Mapeo('FCE', 'ADMINISTRACIÓN'),
    'ep contabilidad - ead': _Mapeo('FCE', 'CONTABILIDAD'),
    'ep educacion - ead': _Mapeo('FACIHED', 'EDUCACIÓN'),
    'ep educacion': _Mapeo('FACIHED', 'EDUCACION'),
    'ep derecho': _Mapeo('FACIHED', 'DERECHO'),
    'ep comunicaciones': _Mapeo('FACIHED', 'COMUNICACIONES'),
    'ep enfermeria': _Mapeo('FCS', 'ENFERMERÍA'),
    'ep medicina': _Mapeo('MED', 'MEDICINA'),
    'ep nutricion humana': _Mapeo('FCS', 'NUTRICION'),
    'ep psicologia': _Mapeo('FCS', 'PSICOLOGIA'),
    'ep ingenieria de sistemas': _Mapeo('FIA', 'SISTEMAS'),
    'ep ingenieria industrias alimentarias': _Mapeo('FIA', 'INDALI'),
    'ep arquitectura': _Mapeo('FIA', 'ARQUITECTURA'),
    'ep ingenieria ambiental': _Mapeo('FIA', 'AMBIENTAL'),
    'ep ingenieria civil': _Mapeo('FIA', 'CIVIL'),
    'ep ingenieria industrial': _Mapeo('FIA', 'INDUSTRIAL'),
    'ep teologia': _Mapeo('TEO', 'TEOLOGIA'),
    'ep tecnologia medica': _Mapeo('FCS', 'TEC MEDICA'),
  };


  Future<List<EventoFinalRow>> getReporteFinal({
    required List<FilialResumen> resumen,
  }) async {

    final eventIds = <String>[];
    for (final f in resumen) {
      for (final fa in f.facultades) {
        for (final c in fa.carreras) {
          for (final e in c.eventos) {
            eventIds.add(e.eventId);
          }
        }
      }
    }


    final juradosPorEvento = await _contarJuradosPorEvento();


    final fechaPorEvento = <String, String>{};
    const lote = 6;
    for (var i = 0; i < eventIds.length; i += lote) {
      final slice = eventIds.skip(i).take(lote).toList();
      final res = await Future.wait(
        slice.map((id) async => MapEntry(id, await _fechaMayorAsistencia(id))),
      );
      fechaPorEvento.addEntries(res);
    }

    final ponenciasPorEvento = <String, ({int orales, int poster})>{};
    for (var i = 0; i < eventIds.length; i += lote) {
      final slice = eventIds.skip(i).take(lote).toList();
      final res = await Future.wait(
        slice.map((id) async => MapEntry(id, await _contarPonencias(id))),
      );
      ponenciasPorEvento.addEntries(res);
    }

    final filas = <EventoFinalRow>[];
    int nro = 1;
    for (final f in resumen) {
      for (final fa in f.facultades) {
        for (final c in fa.carreras) {
          for (final e in c.eventos) {
            final m = _mapear(c.facultad, c.carrera);
            final pon = ponenciasPorEvento[e.eventId] ??
                (orales: 0, poster: 0);
            filas.add(EventoFinalRow(
              nro: nro++,
              filial: f.filialNombre,
              facultadCorta: m.facultadCorta,
              epNombreCorto: m.nombreCorto,
              escuelaProfesional: c.carrera,
              nombreEvento: e.eventName,
              fechaEvento: fechaPorEvento[e.eventId] ?? '',
              matriculados: c.matriculados,
              inscritos: e.pagaron,
              juradosEvaluadores: juradosPorEvento[e.eventId] ?? 0,
              ponenciasOrales: pon.orales,
              ponenciasPoster: pon.poster,
            ));
          }
        }
      }
    }
    return filas;
  }


  Future<Map<String, int>> _contarJuradosPorEvento() async {
    final map = <String, int>{};
    try {
      final snap = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'jurado')
          .get();
      for (final d in snap.docs) {
        final eid = (d.data()['eventoId'] ?? '').toString();
        if (eid.isEmpty) continue;
        map[eid] = (map[eid] ?? 0) + 1;
      }
    } catch (e) {
      debugPrint('⚠️ Error contando jurados por evento: $e');
    }
    return map;
  }



  Future<({int orales, int poster})> _contarPonencias(String eventId) async {
    int orales = 0;
    int poster = 0;
    try {
      final snap = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .get();
      for (final doc in snap.docs) {
        final codigo = (doc.data()['Código'] as String?)?.trim() ?? '';
        if (codigo.isEmpty) continue;
        final low = codigo.toLowerCase();
        final esPoster = low.contains('banner') || low.contains('baner');
        if (esPoster) {
          poster++;
        } else {
          orales++;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error contando ponencias en $eventId: $e');
    }
    return (orales: orales, poster: poster);
  }


  Future<String> _fechaMayorAsistencia(String eventId) async {
    try {
      final porDia = <DateTime, Set<String>>{};
      DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);


      final asisSnap = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias')
          .get();
      for (final d in asisSnap.docs) {
        final ts = d.data()['lastScan'];
        if (ts is Timestamp) {
          (porDia[soloFecha(ts.toDate())] ??= <String>{}).add(d.id);
        }
      }


      final personalDefs = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias_personales')
          .get();
      for (final ap in personalDefs.docs) {
        final regs = await ap.reference.collection('registros').get();
        for (final r in regs.docs) {
          final ts = r.data()['timestamp'];
          if (ts is Timestamp) {
            (porDia[soloFecha(ts.toDate())] ??= <String>{}).add(r.id);
          }
        }
      }

      if (porDia.isEmpty) return '';


      final superan = porDia.entries
          .where((e) => e.value.length > _umbralEstudiantes)
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      final DateTime elegido;
      if (superan.isNotEmpty) {
        elegido = superan.first.key;
      } else {
        final lista = porDia.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));
        elegido = lista.first.key;
      }
      return DateFormat('dd/MM/yyyy').format(elegido);
    } catch (e) {
      debugPrint('⚠️ Error calculando fecha (>20) en $eventId: $e');
      return '';
    }
  }


  _Mapeo _mapear(String facultad, String carrera) {
    final clave = _normalizar(carrera);
    final ov = _overrides[clave];
    if (ov != null) return ov;
    return _Mapeo(_facultadCortaHeuristica(facultad, carrera),
        _nombreCortoHeuristico(carrera));
  }

  String _facultadCortaHeuristica(String facultad, String carrera) {
    final c = _normalizar(carrera);
    if (c.contains('semipresencial')) return 'SEMI';
    if (c.contains('medicina')) return 'MED';

    final f = _normalizar(facultad);
    if (f.contains('empresariales')) return 'FCE';
    if (f.contains('medicina')) return 'MED';
    if (f.contains('salud')) return 'FCS';
    if (f.contains('ingenieria') || f.contains('arquitectura')) return 'FIA';
    if (f.contains('teologia')) return 'TEO';
    if (f.contains('humanidades') ||
        f.contains('educacion') ||
        f.contains('derecho') ||
        f.contains('comunica')) return 'FACIHED';


    final palabras = f
        .replaceAll('facultad de ', '')
        .split(' ')
        .where((p) => p.length > 2)
        .toList();
    if (palabras.isEmpty) return '—';
    return palabras.map((p) => p[0].toUpperCase()).join();
  }

  String _nombreCortoHeuristico(String carrera) {
    var s = _normalizar(carrera).replaceFirst(RegExp(r'^ep\s+'), '');
    final dash = s.indexOf(' - ');
    if (dash != -1) s = s.substring(0, dash);
    s = s
        .replaceAll('ingenieria de ', '')
        .replaceAll('ingenieria ', '')
        .trim();
    return s.toUpperCase();
  }

  String _normalizar(String valor) {
    var s = valor.trim().toLowerCase();
    const acentos = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n', 'ç': 'c',
    };
    acentos.forEach((a, r) => s = s.replaceAll(a, r));
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}