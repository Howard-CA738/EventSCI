import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ProyectosCache {
  static final Map<String, List<Map<String, dynamic>>> _proyectosPorEvento = {};
  static List<Map<String, dynamic>>? _eventosCache;
  static DateTime? _eventosCacheTime;

  static const _eventosMaxAge = Duration(minutes: 10);
  static const _proyectosMaxAge = Duration(minutes: 15);
  static final Map<String, DateTime> _proyectosCacheTime = {};

  static bool get eventosVigentes {
    if (_eventosCache == null || _eventosCacheTime == null) return false;
    return DateTime.now().difference(_eventosCacheTime!) < _eventosMaxAge;
  }

  static List<Map<String, dynamic>>? get eventos => _eventosCache;

  static void setEventos(List<Map<String, dynamic>> eventos) {
    _eventosCache = eventos;
    _eventosCacheTime = DateTime.now();
  }

  static bool proyectosVigentes(String eventoId) {
    if (!_proyectosPorEvento.containsKey(eventoId)) return false;
    final t = _proyectosCacheTime[eventoId];
    if (t == null) return false;
    return DateTime.now().difference(t) < _proyectosMaxAge;
  }

  static List<Map<String, dynamic>>? proyectos(String eventoId) =>
      _proyectosPorEvento[eventoId];

  static void setProyectos(
      String eventoId, List<Map<String, dynamic>> proyectos) {
    _proyectosPorEvento[eventoId] = proyectos;
    _proyectosCacheTime[eventoId] = DateTime.now();
  }

  static void invalidarEventos() {
    _eventosCache = null;
    _eventosCacheTime = null;
  }

  static void invalidarProyectos(String eventoId) {
    _proyectosPorEvento.remove(eventoId);
    _proyectosCacheTime.remove(eventoId);
  }
}

class VerProyectosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? filial;
  String? facultad;
  String? carrera;

  VerProyectosService({this.filial, this.facultad, this.carrera});

  Future<List<Map<String, dynamic>>> cargarEventos(
      {bool forceRefresh = false}) async {
    if (!forceRefresh && ProyectosCache.eventosVigentes) {
      return List.from(ProyectosCache.eventos!);
    }

    try {
      Query query = _firestore
          .collection('events')
          .orderBy('createdAt', descending: true);
      if (facultad != null && facultad!.isNotEmpty) {
        query = query.where('facultad', isEqualTo: facultad);
      }
      if (carrera != null && carrera!.isNotEmpty) {
        query = query.where('carreraNombre', isEqualTo: carrera);
      }
      if (filial != null && filial!.isNotEmpty) {
        query = query.where('filialNombre', isEqualTo: filial);
      }

      QuerySnapshot snap;
      try {
        snap = await query.get(const GetOptions(source: Source.cache));
        debugPrint('Eventos cargados desde caché Firestore offline');
      } catch (_) {
        snap = await query.get(const GetOptions(source: Source.server));
        debugPrint('Eventos cargados desde servidor Firestore');
      }

      final eventos = snap.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        d['id'] = doc.id;
        return d;
      }).toList();

      ProyectosCache.setEventos(eventos);
      return eventos;
    } catch (e) {
      debugPrint('Error cargando eventos: $e');
      final cached = ProyectosCache.eventos;
      if (cached != null) return List.from(cached);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> cargarProyectos(String eventoId,
      {bool forceRefresh = false}) async {
    if (!forceRefresh && ProyectosCache.proyectosVigentes(eventoId)) {
      final cached = ProyectosCache.proyectos(eventoId)!;
      debugPrint('Proyectos cargados desde caché: ${cached.length} docs');
      return List.from(cached);
    }

    final snap = await _firestore
        .collection('events')
        .doc(eventoId)
        .collection('proyectos')
        .get(const GetOptions(source: Source.server));

    final lista = snap.docs.map((doc) {
      final d = doc.data();
      d['docId'] = doc.id;
      return d;
    }).toList();

    lista.sort((a, b) {
      final tA = a['importedAt'];
      final tB = b['importedAt'];
      if (tA == null && tB == null) return 0;
      if (tA == null) return 1;
      if (tB == null) return -1;
      if (tA is Timestamp && tB is Timestamp) {
        return tA.compareTo(tB);
      }
      return 0;
    });

    ProyectosCache.setProyectos(eventoId, lista);
    return lista;
  }

  Map<String, List<Map<String, dynamic>>> agruparPorCategoria(
      List<Map<String, dynamic>> proyectos) {
    final Map<String, List<Map<String, dynamic>>> grupos = {};
    for (final p in proyectos) {
      final cat = p['Clasificación']?.toString().trim();
      final key = (cat != null && cat.isNotEmpty) ? cat : 'Sin categoría';
      grupos.putIfAbsent(key, () => []).add(p);
    }
    return grupos;
  }

  void invalidarEventos() => ProyectosCache.invalidarEventos();
  void invalidarProyectos(String eventoId) =>
      ProyectosCache.invalidarProyectos(eventoId);
}
