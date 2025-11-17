// gestion_criterios.dart
// Este archivo contiene todos los modelos de datos para las rúbricas

import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Crear una copia del criterio
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

/// Modelo para una sección de la rúbrica (agrupa varios criterios)
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

  // Calcular el total de pesos de los criterios
  double get totalPesosCriterios {
    return criterios.fold(0.0, (sum, criterio) => sum + criterio.peso);
  }

  // Verificar si los pesos están balanceados
  bool get pesosBalanceados {
    return (totalPesosCriterios - pesoTotal).abs() < 0.01;
  }

  // Crear una copia de la sección
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
  // ✅ NUEVO: Agregar facultad y carrera
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
    required this.facultad,
    this.carrera,
  });

  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'secciones': secciones.map((s) => s.toMap()).toList(),
      'juradosAsignados': juradosAsignados,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'puntajeMaximo': puntajeMaximo,
      'facultad': facultad,
    };

    // Solo agregar carrera si existe
    if (carrera != null && carrera!.isNotEmpty) {
      map['carrera'] = carrera!;
    } else if (facultad == 'Universidad Peruana Unión') {
      map['carrera'] = 'General';
    }

    return map;
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
      facultad: map['facultad'] ?? 'Universidad Peruana Unión',
      carrera: map['carrera'],
    );
  }

  // Obtener el total de criterios en toda la rúbrica
  int get totalCriterios {
    return secciones.fold<int>(
      0,
      (sum, seccion) => sum + seccion.criterios.length,
    );
  }

  // Obtener el total de secciones
  int get totalSecciones {
    return secciones.length;
  }

  // Verificar si la rúbrica está completa
  bool get estaCompleta {
    if (nombre.isEmpty) return false;
    if (secciones.isEmpty) return false;
    for (var seccion in secciones) {
      if (seccion.criterios.isEmpty) return false;
    }
    return true;
  }

  // Crear una copia de la rúbrica
  Rubrica copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    List<SeccionRubrica>? secciones,
    List<String>? juradosAsignados,
    DateTime? fechaCreacion,
    double? puntajeMaximo,
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
      facultad: facultad ?? this.facultad,
      carrera: carrera ?? this.carrera,
    );
  }
}

/// Servicio para manejar las operaciones de Firestore
class RubricasService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'rubricas';

  // ✅ NUEVO: Estructura de facultades y carreras (igual que EventosService)
  final Map<String, List<String>> facultadesCarreras = {
    'Universidad Peruana Unión': [],
    'Facultad de Ciencias Empresariales': [
      'Administración',
      'Contabilidad',
      'Gestión Tributaria y Aduanera',
    ],
    'Facultad de Ciencias Humanas y Educación': [
      'Educación, Especialidad Inicial y Puericultura',
      'Educación, Especialidad Primaria y Pedagogía Terapéutica',
      'Educación, Especialidad Inglés y Español',
    ],
    'Facultad de Ciencias de la Salud': [
      'Enfermería',
      'Nutrición Humana',
      'Psicología',
    ],
    'Facultad de Ingeniería y Arquitectura': [
      'Ingeniería Civil',
      'Arquitectura y Urbanismo',
      'Ingeniería Ambiental',
      'Ingeniería de Industrias Alimentarias',
      'Ingeniería de Sistemas',
    ],
  };

  // ✅ NUEVO: Verificar si la facultad requiere carrera
  bool requiereCarrera(String? facultad) {
    if (facultad == null) return true;
    return facultad != 'Universidad Peruana Unión';
  }

  // ✅ NUEVO: Validar facultad
  String? validateFacultad(String? facultad) {
    if (facultad == null) {
      return 'Por favor selecciona una facultad';
    }
    return null;
  }

  // ✅ NUEVO: Validar carrera
  String? validateCarrera(String? carrera, String? facultad) {
    if (facultad == 'Universidad Peruana Unión') {
      return null;
    }
    if (carrera == null) {
      return 'Por favor selecciona una carrera';
    }
    return null;
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

  // ✅ NUEVO: Obtener rúbricas filtradas por facultad
  Future<List<Rubrica>> obtenerRubricasPorFacultad(String facultad) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('facultad', isEqualTo: facultad)
          .get();
      return snapshot.docs.map((doc) => Rubrica.fromMap(doc.data())).toList()
        ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
    } catch (e) {
      print('Error al obtener rúbricas por facultad: $e');
      return [];
    }
  }

  // ✅ NUEVO: Obtener rúbricas filtradas por facultad y carrera
  Future<List<Rubrica>> obtenerRubricasPorFacultadYCarrera(
    String facultad,
    String carrera,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('facultad', isEqualTo: facultad)
          .where('carrera', isEqualTo: carrera)
          .get();
      return snapshot.docs.map((doc) => Rubrica.fromMap(doc.data())).toList()
        ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
    } catch (e) {
      print('Error al obtener rúbricas por facultad y carrera: $e');
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

  // ✅ MODIFICADO: Obtener jurados filtrados por facultad y carrera
  Future<List<Map<String, dynamic>>> obtenerJurados({
    String? facultad,
    String? carrera,
  }) async {
    try {
      print('Intentando obtener jurados de Firestore...');
      print('Filtros - Facultad: $facultad, Carrera: $carrera');

      Query query = _firestore
          .collection('users')
          .where('userType', isEqualTo: 'jurado');

      // Aplicar filtro por facultad si se proporciona
      if (facultad != null && facultad.isNotEmpty) {
        query = query.where('facultad', isEqualTo: facultad);
      }

      // Aplicar filtro por carrera si se proporciona y no es UPeU
      if (carrera != null &&
          carrera.isNotEmpty &&
          facultad != 'Universidad Peruana Unión') {
        query = query.where('carrera', isEqualTo: carrera);
      }

      final snapshot = await query.get();

      print('Documentos encontrados: ${snapshot.docs.length}');

      final jurados = snapshot.docs.map((doc) {
        print('Jurado ID: ${doc.id}, Data: ${doc.data()}');
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'nombre': data['name'] ?? data['nombre'] ?? '',
          'usuario': data['usuario'] ?? '',
          'facultad': data['facultad'] ?? '',
          'carrera': data['carrera'] ?? '',
          'categoria': data['categoria'] ?? '',
        };
      }).toList();

      print('Total de jurados procesados: ${jurados.length}');
      return jurados;
    } catch (e) {
      print('Error al obtener jurados: $e');
      return [];
    }
  }

  // ✅ NUEVO: Eliminar evaluaciones cuando se remueven jurados de una rúbrica
  Future<void> eliminarEvaluacionesDeJurados({
    required String rubricaId,
    required List<String> juradosIds,
  }) async {
    try {
      print('🗑️ Iniciando eliminación de evaluaciones...');
      print('   Rúbrica ID: $rubricaId');
      print('   Jurados a remover: ${juradosIds.length}');

      // Buscar todos los proyectos que usan esta rúbrica
      final eventosSnapshot = await _firestore.collection('events').get();

      int evaluacionesEliminadas = 0;

      for (var eventoDoc in eventosSnapshot.docs) {
        final proyectosSnapshot = await _firestore
            .collection('events')
            .doc(eventoDoc.id)
            .collection('proyectos')
            .get();

        for (var proyectoDoc in proyectosSnapshot.docs) {
          // Para cada jurado removido, eliminar su evaluación si existe
          for (var juradoId in juradosIds) {
            final evaluacionDoc = await _firestore
                .collection('events')
                .doc(eventoDoc.id)
                .collection('proyectos')
                .doc(proyectoDoc.id)
                .collection('evaluaciones')
                .doc(juradoId)
                .get();

            // Solo eliminar si la evaluación usa esta rúbrica
            if (evaluacionDoc.exists) {
              final data = evaluacionDoc.data();
              if (data != null && data['rubricaId'] == rubricaId) {
                await evaluacionDoc.reference.delete();
                evaluacionesEliminadas++;
                print(
                  '   ✅ Evaluación eliminada: ${eventoDoc.id}/${proyectoDoc.id}/$juradoId',
                );
              }
            }
          }
        }
      }

      print('✅ Total de evaluaciones eliminadas: $evaluacionesEliminadas');
    } catch (e) {
      print('❌ Error al eliminar evaluaciones de jurados: $e');
      rethrow;
    }
  }

  // ✅ NUEVO: Filtrar rúbricas en memoria (para uso local)
  List<Rubrica> filtrarRubricas(
    List<Rubrica> rubricas, {
    String? facultad,
    String? carrera,
  }) {
    var resultado = rubricas;

    if (facultad != null && facultad.isNotEmpty) {
      resultado = resultado.where((r) => r.facultad == facultad).toList();
    }

    if (carrera != null && carrera.isNotEmpty) {
      if (carrera == 'General') {
        resultado = resultado
            .where(
              (r) =>
                  r.carrera == 'General' &&
                  r.facultad == 'Universidad Peruana Unión',
            )
            .toList();
      } else {
        resultado = resultado.where((r) => r.carrera == carrera).toList();
      }
    }

    return resultado;
  }
}
