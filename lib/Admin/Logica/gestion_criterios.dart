// gestion_criterios.dart
// Modelos de datos actualizados para usar sistema de filiales

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

/// Modelo principal para una rúbrica completa - ACTUALIZADO CON FILIAL
class Rubrica {
  String id;
  String nombre;
  String descripcion;
  List<SeccionRubrica> secciones;
  List<String> juradosAsignados;
  DateTime fechaCreacion;
  double puntajeMaximo;
  // ✅ NUEVO: Sistema de filiales
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

/// Servicio actualizado para usar FilialesService
class RubricasService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FilialesService _filialesService = FilialesService();
  final String _collection = 'rubricas';

  // ✅ Cache para estructura de filiales
  Map<String, dynamic>? _estructuraCache;

  // ✅ Obtener estructura completa de filiales
  Future<Map<String, dynamic>> getEstructuraCompleta() async {
    if (_estructuraCache != null) {
      return _estructuraCache!;
    }

    _estructuraCache = await _filialesService.getEstructuraCompleta();
    return _estructuraCache!;
  }

  // ✅ Obtener lista de filiales
  Future<List<String>> getFiliales() async {
    final estructura = await getEstructuraCompleta();
    return estructura.keys.toList();
  }

  // ✅ Obtener nombre de filial
  Future<String> getNombreFilial(String filialId) async {
    final estructura = await getEstructuraCompleta();
    return estructura[filialId]?['nombre'] ?? filialId;
  }

  // ✅ Obtener facultades de una filial
  Future<List<String>> getFacultadesByFilial(String filialId) async {
    final estructura = await getEstructuraCompleta();
    final filial = estructura[filialId];
    if (filial == null) return [];

    final facultades = filial['facultades'] as Map<String, dynamic>;
    return facultades.keys.toList();
  }

  // ✅ Obtener carreras de una facultad
  Future<List<Map<String, dynamic>>> getCarrerasByFacultad(
    String filialId,
    String facultadNombre,
  ) async {
    return await _filialesService.getCarrerasByFacultad(
      filialId,
      facultadNombre,
    );
  }

  // Obtener todas las rúbricas
  Future<List<Rubrica>> obtenerRubricas() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      return snapshot.docs.map((doc) => Rubrica.fromMap(doc.data())).toList()
        ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
    } catch (e) {
      print('Error al obtener rúbricas: $e');
      return [];
    }
  }

  // ✅ Obtener rúbricas por filial
  Future<List<Rubrica>> obtenerRubricasPorFilial(String filial) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('filial', isEqualTo: filial)
          .get();
      return snapshot.docs.map((doc) => Rubrica.fromMap(doc.data())).toList()
        ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
    } catch (e) {
      print('Error al obtener rúbricas por filial: $e');
      return [];
    }
  }

  // ✅ Obtener rúbricas por filial y facultad
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
      print('Error al obtener rúbricas: $e');
      return [];
    }
  }

  // Obtener una rúbrica por ID
  Future<Rubrica?> obtenerRubricaPorId(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return Rubrica.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error al obtener rúbrica: $e');
      return null;
    }
  }

  // Crear una nueva rúbrica
  Future<bool> crearRubrica(Rubrica rubrica) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(rubrica.id)
          .set(rubrica.toMap());
      return true;
    } catch (e) {
      print('Error al crear rúbrica: $e');
      return false;
    }
  }

  // Actualizar una rúbrica existente
  Future<bool> actualizarRubrica(Rubrica rubrica) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(rubrica.id)
          .update(rubrica.toMap());
      return true;
    } catch (e) {
      print('Error al actualizar rúbrica: $e');
      return false;
    }
  }

  // Eliminar una rúbrica
  Future<bool> eliminarRubrica(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
      return true;
    } catch (e) {
      print('Error al eliminar rúbrica: $e');
      return false;
    }
  }

  // ✅ Obtener jurados filtrados por filial, facultad y carrera
  Future<List<Map<String, dynamic>>> obtenerJurados({
    String? filial,
    String? facultad,
    String? carrera,
  }) async {
    try {
      print('🔍 Buscando jurados...');
      print('   Filial: $filial');
      print('   Facultad: $facultad');
      print('   Carrera: $carrera');

      Query query = _firestore
          .collection('users')
          .where('userType', isEqualTo: 'jurado');

      // Aplicar filtros
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
      print('✅ ${snapshot.docs.length} jurados encontrados');

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
        };
      }).toList();
    } catch (e) {
      print('❌ Error al obtener jurados: $e');
      return [];
    }
  }

  // Eliminar evaluaciones cuando se remueven jurados
  Future<void> eliminarEvaluacionesDeJurados({
    required String rubricaId,
    required List<String> juradosIds,
  }) async {
    try {
      print('🗑️ Eliminando evaluaciones de jurados removidos...');

      final eventosSnapshot = await _firestore.collection('events').get();
      int evaluacionesEliminadas = 0;

      for (var eventoDoc in eventosSnapshot.docs) {
        final proyectosSnapshot = await _firestore
            .collection('events')
            .doc(eventoDoc.id)
            .collection('proyectos')
            .get();

        for (var proyectoDoc in proyectosSnapshot.docs) {
          for (var juradoId in juradosIds) {
            final evaluacionDoc = await _firestore
                .collection('events')
                .doc(eventoDoc.id)
                .collection('proyectos')
                .doc(proyectoDoc.id)
                .collection('evaluaciones')
                .doc(juradoId)
                .get();

            if (evaluacionDoc.exists) {
              final data = evaluacionDoc.data();
              if (data != null && data['rubricaId'] == rubricaId) {
                await evaluacionDoc.reference.delete();
                evaluacionesEliminadas++;
              }
            }
          }
        }
      }

      print('✅ $evaluacionesEliminadas evaluaciones eliminadas');
    } catch (e) {
      print('❌ Error al eliminar evaluaciones: $e');
      rethrow;
    }
  }

  // ✅ Filtrar rúbricas en memoria
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

  // ✅ Limpiar cache
  void clearCache() {
    _estructuraCache = null;
    FilialesService.clearCache();
  }
}
