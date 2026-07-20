import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────
// MODELOS DEL RESUMEN  (Filial → Facultad → Carrera → Evento)
// ─────────────────────────────────────────────────────────────────────────
class EventoResumen {
  final String eventId;
  final String eventName;
  final String periodoNombre;
  final DateTime? fecha;
  final String carreraPath;

  final int matriculados; // todos los estudiantes de la carrera
  final int pagaron;      // inscritos al evento (pagos.{eventId} == true)
  final int asistieron;   // estudiantes únicos con ≥1 asistencia al evento

  const EventoResumen({
    required this.eventId,
    required this.eventName,
    required this.periodoNombre,
    required this.fecha,
    required this.carreraPath,
    required this.matriculados,
    required this.pagaron,
    required this.asistieron,
  });

  // % de inscritos que efectivamente asistieron
  double get pctAsistioVsPago =>
      pagaron == 0 ? 0 : (asistieron / pagaron) * 100;

  // % de matriculados que se inscribieron (pagaron)
  double get pctPagoVsMatricula =>
      matriculados == 0 ? 0 : (pagaron / matriculados) * 100;
}

class CarreraResumen {
  final String carreraPath;
  final String filialId;
  final String facultad;
  final String carrera;
  final int matriculados;
  final List<EventoResumen> eventos;

  const CarreraResumen({
    required this.carreraPath,
    required this.filialId,
    required this.facultad,
    required this.carrera,
    required this.matriculados,
    required this.eventos,
  });

  int get totalAsistieron => eventos.fold(0, (s, e) => s + e.asistieron);
  int get totalPagaron => eventos.fold(0, (s, e) => s + e.pagaron);
}

class FacultadResumen {
  final String nombre;
  final List<CarreraResumen> carreras;
  const FacultadResumen(this.nombre, this.carreras);

  int get totalEventos => carreras.fold(0, (s, c) => s + c.eventos.length);
  int get totalMatriculados =>
      carreras.fold(0, (s, c) => s + c.matriculados);
}

class FilialResumen {
  final String filialId;
  final String filialNombre;
  final List<FacultadResumen> facultades;
  const FilialResumen(this.filialId, this.filialNombre, this.facultades);

  int get totalEventos =>
      facultades.fold(0, (s, f) => s + f.totalEventos);
  int get totalMatriculados =>
      facultades.fold(0, (s, f) => s + f.totalMatriculados);
}

// ─────────────────────────────────────────────────────────────────────────
// SERVICIO
// ─────────────────────────────────────────────────────────────────────────
class ReporteUsuariosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _filialesOrden = ['lima', 'juliaca', 'tarapoto'];

  // ── Caché (evita relecturas durante 10 min) ──────────────────────────────
  List<FilialResumen>? _resumenCache;
  DateTime? _resumenTs;
  final Map<String, int> _matriculadosCache = {};
  final Map<String, int> _asistieronCache = {};
  static const Duration _ttl = Duration(minutes: 10);

  void invalidarCache() {
    _resumenCache = null;
    _resumenTs = null;
    _matriculadosCache.clear();
    _asistieronCache.clear();
  }

  bool get _resumenFresco =>
      _resumenCache != null &&
      _resumenTs != null &&
      DateTime.now().difference(_resumenTs!) < _ttl;

  // carreraPath de los estudiantes = "{filialNombre}_{carreraNombre}"
  String _buildCarreraPath(String filialNombre, String carreraNombre) =>
      '${filialNombre}_$carreraNombre';

  // ───────────────────────────────────────────────────────────────────────
  // RESUMEN COMPLETO
  // 1 lectura de 'events' + count() por carrera (matriculados) +
  // count() por evento (pagaron) + conteo de asistencias por evento.
  // ───────────────────────────────────────────────────────────────────────
  Future<List<FilialResumen>> getResumen({bool forceRefresh = false}) async {
    if (!forceRefresh && _resumenFresco) return _resumenCache!;

    final eventsSnap = await _firestore.collection('events').get();

    // ── Normalizar metadatos de cada evento ────────────────────────────────
    final eventosRaw = eventsSnap.docs.map((doc) {
      final d = doc.data();
      final filialId = (d['filialId'] ?? 'otros').toString();
      final filialNombre =
          (d['filialNombre'] ?? d['filialId'] ?? 'Sin filial').toString();
      final facultad = (d['facultad'] ?? 'Sin facultad').toString();
      final carreraNombre =
          (d['carreraNombre'] ?? d['carreraId'] ?? 'Sin carrera').toString();
      final name = (d['name'] ?? 'Sin nombre').toString();
      final periodo = (d['periodoNombre'] ?? '').toString();
      DateTime? fecha;
      if (d['fecha'] is Timestamp) fecha = (d['fecha'] as Timestamp).toDate();

      return _EventoTmp(
        eventId: doc.id,
        eventName: name,
        periodoNombre: periodo,
        fecha: fecha,
        filialId: filialId,
        filialNombre: filialNombre,
        facultad: facultad,
        carreraNombre: carreraNombre,
        carreraPath: _buildCarreraPath(filialNombre, carreraNombre),
      );
    }).toList();

    // ── Matriculados: un count() por carreraPath único ─────────────────────
    final carreraPaths = eventosRaw.map((e) => e.carreraPath).toSet().toList();
    await Future.wait(
      carreraPaths.map((p) async {
        _matriculadosCache[p] = await _contarMatriculados(p);
      }),
    );

    // ── Pagaron + Asistieron por evento (en lotes para no saturar) ──────────
    final List<EventoResumen> eventos = [];
    const lote = 6;
    for (var i = 0; i < eventosRaw.length; i += lote) {
      final slice = eventosRaw.skip(i).take(lote).toList();
      final res = await Future.wait(slice.map((e) async {
        final pagaron = await _contarPagaron(e.carreraPath, e.eventId);
        final asistieron = await _contarAsistieron(e.eventId);
        return EventoResumen(
          eventId: e.eventId,
          eventName: e.eventName,
          periodoNombre: e.periodoNombre,
          fecha: e.fecha,
          carreraPath: e.carreraPath,
          matriculados: _matriculadosCache[e.carreraPath] ?? 0,
          pagaron: pagaron,
          asistieron: asistieron,
        );
      }));
      eventos.addAll(res);
    }

    // ── Agrupar: filial → facultad → carrera → eventos ─────────────────────
    // Indexamos los eventos junto a sus metadatos de origen.
    final mapaEventos = <String, _EventoTmp>{
      for (final e in eventosRaw) e.eventId: e,
    };

    final agrupado =
        <String, Map<String, Map<String, List<EventoResumen>>>>{};
    final nombreFilial = <String, String>{};

    for (final ev in eventos) {
      final src = mapaEventos[ev.eventId]!;
      nombreFilial[src.filialId] = src.filialNombre;
      agrupado
          .putIfAbsent(src.filialId, () => {})
          .putIfAbsent(src.facultad, () => {})
          .putIfAbsent(src.carreraNombre, () => [])
          .add(ev);
    }

    // ── Ordenar filiales según _filialesOrden, el resto alfabético ─────────
    final filialesOrdenadas = agrupado.keys.toList()
      ..sort((a, b) {
        final ia = _filialesOrden.indexOf(a);
        final ib = _filialesOrden.indexOf(b);
        if (ia == -1 && ib == -1) return a.compareTo(b);
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia.compareTo(ib);
      });

    final List<FilialResumen> resultado = [];
    for (final fid in filialesOrdenadas) {
      final facsMap = agrupado[fid]!;
      final facultades = facsMap.entries.map((facEntry) {
        final carrerasMap = facEntry.value;
        final carreras = carrerasMap.entries.map((carEntry) {
          final lista = carEntry.value
            ..sort((a, b) => a.eventName
                .toLowerCase()
                .compareTo(b.eventName.toLowerCase()));
          final src = mapaEventos[lista.first.eventId]!;
          return CarreraResumen(
            carreraPath: lista.first.carreraPath,
            filialId: fid,
            facultad: facEntry.key,
            carrera: carEntry.key,
            matriculados: lista.first.matriculados,
            eventos: lista,
          );
        }).toList()
          ..sort((a, b) => a.carrera.compareTo(b.carrera));
        return FacultadResumen(facEntry.key, carreras);
      }).toList()
        ..sort((a, b) => a.nombre.compareTo(b.nombre));

      resultado.add(
        FilialResumen(fid, nombreFilial[fid] ?? fid, facultades),
      );
    }

    _resumenCache = resultado;
    _resumenTs = DateTime.now();
    return resultado;
  }

  // ───────────────────────────────────────────────────────────────────────
  // CONTEOS INDIVIDUALES
  // ───────────────────────────────────────────────────────────────────────

  // Matriculados: todos los estudiantes de la carrera (sin filtrar por login).
  Future<int> _contarMatriculados(String carreraPath) async {
    if (_matriculadosCache.containsKey(carreraPath)) {
      return _matriculadosCache[carreraPath]!;
    }
    try {
      final agg = await _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .count()
          .get();
      return agg.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ matriculados count() falló en $carreraPath: $e');
      return 0;
    }
  }

  // Inscritos = pagaron para ese evento (pagos.{eventId} == true).
  Future<int> _contarPagaron(String carreraPath, String eventId) async {
    try {
      final agg = await _firestore
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .where('pagos.$eventId', isEqualTo: true)
          .count()
          .get();
      return agg.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ pagaron count() falló en $carreraPath/$eventId: $e');
      return 0;
    }
  }

  // Asistieron = estudiantes ÚNICOS con ≥1 asistencia (QR de proyecto y/o
  // asistencia personal). Si un alumno hizo ambas, cuenta una sola vez.
  Future<int> _contarAsistieron(String eventId) async {
    if (_asistieronCache.containsKey(eventId)) {
      return _asistieronCache[eventId]!;
    }
    try {
      // ¿Existen asistencias personales para este evento?
      final personalDefs = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias_personales')
          .get();

      int total;
      if (personalDefs.docs.isEmpty) {
        // Caso común: solo QR de proyecto. 'asistencias' tiene 1 doc por
        // estudiante (doc.id == studentId), así que count() ya es único.
        final agg = await _firestore
            .collection('events')
            .doc(eventId)
            .collection('asistencias')
            .count()
            .get();
        total = agg.count ?? 0;
      } else {
        // Hay personal: unimos IDs de ambas fuentes para no contar doble.
        final ids = <String>{};

        final asisSnap = await _firestore
            .collection('events')
            .doc(eventId)
            .collection('asistencias')
            .get();
        for (final d in asisSnap.docs) {
          ids.add(d.id); // doc.id == studentId
        }

        for (final ap in personalDefs.docs) {
          final regs = await ap.reference.collection('registros').get();
          for (final r in regs.docs) {
            ids.add(r.id); // doc.id == studentId
          }
        }
        total = ids.length;
      }

      _asistieronCache[eventId] = total;
      return total;
    } catch (e) {
      debugPrint('⚠️ asistieron count falló en $eventId: $e');
      return 0;
    }
  }
}

// Estructura interna temporal para arrastrar metadatos del evento.
class _EventoTmp {
  final String eventId;
  final String eventName;
  final String periodoNombre;
  final DateTime? fecha;
  final String filialId;
  final String filialNombre;
  final String facultad;
  final String carreraNombre;
  final String carreraPath;

  const _EventoTmp({
    required this.eventId,
    required this.eventName,
    required this.periodoNombre,
    required this.fecha,
    required this.filialId,
    required this.filialNombre,
    required this.facultad,
    required this.carreraNombre,
    required this.carreraPath,
  });
}