import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'filiales_service.dart';

/// Modelo para un criterio individual de evaluación
class Criterio {
  String id;
  String descripcion;
  double peso;
  double puntajeObtenido;

  Criterio({
    required this.id,
    required this.descripcion,
    required this.peso,
    this.puntajeObtenido = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descripcion': descripcion,
      'peso': peso,
      'puntajeObtenido': puntajeObtenido,
    };
  }

  factory Criterio.fromMap(Map<String, dynamic> map) {
    return Criterio(
      id: map['id'] ?? '',
      descripcion: map['descripcion'] ?? '',
      peso: (map['peso'] ?? 0).toDouble(),
      puntajeObtenido: (map['puntajeObtenido'] ?? 0).toDouble(),
    );
  }

  Criterio copyWith({
    String? id,
    String? descripcion,
    double? peso,
    double? puntajeObtenido,
  }) {
    return Criterio(
      id: id ?? this.id,
      descripcion: descripcion ?? this.descripcion,
      peso: peso ?? this.peso,
      puntajeObtenido: puntajeObtenido ?? this.puntajeObtenido,
    );
  }
}

/// Modelo para una sección de la rúbrica
class SeccionRubrica {
  String id;
  String nombre;
  List<Criterio> criterios;
  double pesoTotal;

  SeccionRubrica({
    required this.id,
    required this.nombre,
    required this.criterios,
    this.pesoTotal = 10,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'criterios': criterios.map((c) => c.toMap()).toList(),
      'pesoTotal': pesoTotal,
    };
  }

  factory SeccionRubrica.fromMap(Map<String, dynamic> map) {
    return SeccionRubrica(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      criterios:
          (map['criterios'] as List<dynamic>?)
              ?.map((c) => Criterio.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
      pesoTotal: (map['pesoTotal'] ?? 10).toDouble(),
    );
  }

  double get totalPesosCriterios {
    return criterios.fold(0.0, (sum, criterio) => sum + criterio.peso);
  }

  bool get pesosBalanceados {
    return (totalPesosCriterios - pesoTotal).abs() < 0.01;
  }

  SeccionRubrica copyWith({
    String? id,
    String? nombre,
    List<Criterio>? criterios,
    double? pesoTotal,
  }) {
    return SeccionRubrica(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      criterios: criterios ?? this.criterios.map((c) => c.copyWith()).toList(),
      pesoTotal: pesoTotal ?? this.pesoTotal,
    );
  }
}

/// Modelo principal para una rúbrica completa
class Rubrica {
  String id;
  String nombre;
  String descripcion;
  List<SeccionRubrica> secciones;
  List<String> juradosAsignados;
  DateTime fechaCreacion;
  double puntajeMaximo;
  String filial;
  String facultad;
  String? carrera;

  Rubrica({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.secciones,
    required this.juradosAsignados,
    required this.fechaCreacion,
    this.puntajeMaximo = 20,
    required this.filial,
    required this.facultad,
    this.carrera,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'secciones': secciones.map((s) => s.toMap()).toList(),
      'juradosAsignados': juradosAsignados,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'puntajeMaximo': puntajeMaximo,
      'filial': filial,
      'facultad': facultad,
      'carrera': carrera,
    };
  }

  factory Rubrica.fromMap(Map<String, dynamic> map) {
    return Rubrica(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      secciones:
          (map['secciones'] as List<dynamic>?)
              ?.map((s) => SeccionRubrica.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [],
      juradosAsignados: List<String>.from(map['juradosAsignados'] ?? []),
      fechaCreacion:
          (map['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      puntajeMaximo: (map['puntajeMaximo'] ?? 20).toDouble(),
      filial: map['filial'] ?? 'lima',
      facultad: map['facultad'] ?? '',
      carrera: map['carrera'],
    );
  }

  int get totalCriterios {
    return secciones.fold<int>(
      0,
      (sum, seccion) => sum + seccion.criterios.length,
    );
  }

  int get totalSecciones {
    return secciones.length;
  }

  bool get estaCompleta {
    if (nombre.isEmpty) return false;
    if (secciones.isEmpty) return false;
    for (var seccion in secciones) {
      if (seccion.criterios.isEmpty) return false;
    }
    return true;
  }

  Rubrica copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    List<SeccionRubrica>? secciones,
    List<String>? juradosAsignados,
    DateTime? fechaCreacion,
    double? puntajeMaximo,
    String? filial,
    String? facultad,
    String? carrera,
  }) {
    return Rubrica(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      secciones: secciones ?? this.secciones.map((s) => s.copyWith()).toList(),
      juradosAsignados: juradosAsignados ?? List.from(this.juradosAsignados),
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      puntajeMaximo: puntajeMaximo ?? this.puntajeMaximo,
      filial: filial ?? this.filial,
      facultad: facultad ?? this.facultad,
      carrera: carrera ?? this.carrera,
    );
  }
}

/// Servicio de rúbricas con todos los fixes aplicados
class RubricasService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FilialesService _filialesService = FilialesService();
  final String _collection = 'rubricas';

  Map<String, dynamic>? _estructuraCache;

  Future<Map<String, dynamic>> getEstructuraCompleta() async {
    if (_estructuraCache != null) {
      return _estructuraCache!;
    }
    _estructuraCache = await _filialesService.getEstructuraCompleta();
    return _estructuraCache!;
  }

  Future<List<String>> getFiliales() async {
    final estructura = await getEstructuraCompleta();
    return estructura.keys.toList();
  }

  Future<String> getNombreFilial(String filialId) async {
    final estructura = await getEstructuraCompleta();
    return estructura[filialId]?['nombre'] ?? filialId;
  }

  Future<List<String>> getFacultadesByFilial(String filialId) async {
    final estructura = await getEstructuraCompleta();
    final filial = estructura[filialId];
    if (filial == null) return [];
    final facultades = filial['facultades'] as Map<String, dynamic>;
    return facultades.keys.toList();
  }

  Future<List<Map<String, dynamic>>> getCarrerasByFacultad(
    String filialId,
    String facultadNombre,
  ) async {
    return await _filialesService.getCarrerasByFacultad(
      filialId,
      facultadNombre,
    );
  }

  // Obtener todas las rúbricas (sin filtro — para el panel del jurado)
  Future<List<Rubrica>> obtenerRubricas() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      return snapshot.docs.map((doc) => Rubrica.fromMap(doc.data())).toList()
        ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
    } catch (e) {
      debugPrint('Error al obtener rúbricas: $e');
      return [];
    }
  }

  Future<List<Rubrica>> obtenerRubricasPorFilial(String filial) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('filial', isEqualTo: filial)
          .get();
      return snapshot.docs.map((doc) => Rubrica.fromMap(doc.data())).toList()
        ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
    } catch (e) {
      debugPrint('Error al obtener rúbricas por filial: $e');
      return [];
    }
  }

  Future<List<Rubrica>> obtenerRubricasPorFilialYFacultad(
    String filial,
    String facultad,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('filial', isEqualTo: filial)
          .where('facultad', isEqualTo: facultad)
          .get();
      return snapshot.docs.map((doc) => Rubrica.fromMap(doc.data())).toList()
        ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
    } catch (e) {
      debugPrint('Error al obtener rúbricas: $e');
      return [];
    }
  }

  Future<Rubrica?> obtenerRubricaPorId(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return Rubrica.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error al obtener rúbrica: $e');
      return null;
    }
  }

  Future<bool> crearRubrica(Rubrica rubrica) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(rubrica.id)
          .set(rubrica.toMap());
      return true;
    } catch (e) {
      debugPrint('Error al crear rúbrica: $e');
      return false;
    }
  }

  Future<bool> actualizarRubrica(Rubrica rubrica) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(rubrica.id)
          .update(rubrica.toMap());
      return true;
    } catch (e) {
      debugPrint('Error al actualizar rúbrica: $e');
      return false;
    }
  }

  Future<bool> eliminarRubrica(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('Error al eliminar rúbrica: $e');
      return false;
    }
  }

  // FIX M3 (4.1): obtenerJurados ahora incluye eventoNombre y eventoId
  // en el mapa retornado, para que el selector de jurados en la rúbrica
  // pueda mostrar el evento asignado a cada jurado correctamente.
  Future<List<Map<String, dynamic>>> obtenerJurados({
    String? filial,
    String? facultad,
    String? carrera,
  }) async {
    try {
      debugPrint('🔍 Buscando jurados...');
      debugPrint('   Filial: $filial');
      debugPrint('   Facultad: $facultad');
      debugPrint('   Carrera: $carrera');

      Query query = _firestore
          .collection('users')
          .where('userType', isEqualTo: 'jurado');

      if (filial != null && filial.isNotEmpty) {
        query = query.where('filial', isEqualTo: filial);
      }
      if (facultad != null && facultad.isNotEmpty) {
        query = query.where('facultad', isEqualTo: facultad);
      }
      if (carrera != null && carrera.isNotEmpty) {
        query = query.where('carrera', isEqualTo: carrera);
      }

      final snapshot = await query.get();
      debugPrint('✅ ${snapshot.docs.length} jurados encontrados');

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'nombre': data['name'] ?? data['nombre'] ?? '',
          'usuario': data['usuario'] ?? '',
          'filial': data['filial'] ?? '',
          'facultad': data['facultad'] ?? '',
          'carrera': data['carrera'] ?? '',
          'categoria': data['categoria'] ?? '',
          // FIX M3/4.1: campos agregados para que el selector de rúbricas
          // muestre el evento asignado a cada jurado.
          'eventoNombre': data['eventoNombre'] ?? '',
          'eventoId': data['eventoId'] ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error al obtener jurados: $e');
      return [];
    }
  }

  // FIX C4 + 4.2: eliminarEvaluacionesDeJurados ahora maneja tanto
  // evaluaciones nuevas (con rubricaId) como legacy (sin rubricaId).
  // - Evaluaciones con rubricaId == este rubricaId → eliminar.
  // - Evaluaciones legacy sin rubricaId → eliminar también (el jurado
  //   fue removido de la rúbrica, así que su evaluación debe limpiarse).
  // - Evaluaciones con rubricaId de OTRA rúbrica → NO tocar.
  Future<void> eliminarEvaluacionesDeJurados({
    required String rubricaId,
    required List<String> juradosIds,
  }) async {
    try {
      debugPrint('🗑️ Eliminando evaluaciones de jurados removidos...');

      // 1. Traer todos los eventos
      final eventosSnapshot = await _firestore.collection('events').get();

      // 2. Obtener todos los proyectos de todos los eventos en paralelo
      final proyectosSnapshotList = await Future.wait(
        eventosSnapshot.docs.map((eventoDoc) => _firestore
            .collection('events')
            .doc(eventoDoc.id)
            .collection('proyectos')
            .get()),
      );

      // 3. Construir todas las rutas de evaluación a verificar
      final List<DocumentReference> refsAVerificar = [];

      for (int i = 0; i < eventosSnapshot.docs.length; i++) {
        final eventoId = eventosSnapshot.docs[i].id;
        final proyectos = proyectosSnapshotList[i].docs;

        for (var proyectoDoc in proyectos) {
          for (var juradoId in juradosIds) {
            refsAVerificar.add(_firestore
                .collection('events')
                .doc(eventoId)
                .collection('proyectos')
                .doc(proyectoDoc.id)
                .collection('evaluaciones')
                .doc(juradoId));
          }
        }
      }

      // 4. Leer todas las evaluaciones en paralelo
      final evaluacionesDocs = await Future.wait(
        refsAVerificar.map((ref) => ref.get()),
      );

      // 5. Eliminar en lotes según la lógica de rubricaId
      //    - rubricaId coincide → eliminar
      //    - rubricaId ausente (legacy) → eliminar (evaluación huérfana)
      //    - rubricaId de otra rúbrica → conservar
      final WriteBatch batch = _firestore.batch();
      int eliminadas = 0;

      for (var doc in evaluacionesDocs) {
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null) {
            final docRubricaId = data['rubricaId'] as String?;
            final debeEliminar =
                docRubricaId == rubricaId || docRubricaId == null;
            if (debeEliminar) {
              batch.delete(doc.reference);
              eliminadas++;
            }
          }
        }
      }

      if (eliminadas > 0) await batch.commit();
      debugPrint('✅ $eliminadas evaluaciones eliminadas');
    } catch (e) {
      debugPrint('❌ Error al eliminar evaluaciones: $e');
      rethrow;
    }
  }

  List<Rubrica> filtrarRubricas(
    List<Rubrica> rubricas, {
    String? filial,
    String? facultad,
    String? carrera,
  }) {
    var resultado = rubricas;

    if (filial != null && filial.isNotEmpty) {
      resultado = resultado.where((r) => r.filial == filial).toList();
    }
    if (facultad != null && facultad.isNotEmpty) {
      resultado = resultado.where((r) => r.facultad == facultad).toList();
    }
    if (carrera != null && carrera.isNotEmpty) {
      resultado = resultado.where((r) => r.carrera == carrera).toList();
    }

    return resultado;
  }

  void clearCache() {
    _estructuraCache = null;
    FilialesService.clearCache();
  }
}