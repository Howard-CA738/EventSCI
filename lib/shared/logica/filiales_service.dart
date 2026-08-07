import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FilialesService {
  static final FilialesService _instance = FilialesService._internal();
  factory FilialesService() => _instance;
  FilialesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Map<String, dynamic>? _estructuraCache;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(hours: 24);
  static bool _isInitialized = false;

  static const Map<String, Map<String, dynamic>> estructuraBase = {
    'lima': {
      'nombre': 'Campus Lima',
      'ubicacion': 'Ñaña, Chosica',
      'facultades': {
        'Facultad de Ciencias Empresariales': [
          'Administración',
          'Contabilidad, gestión tributaria y aduanera',
          'Marketing y negocios internacionales',
        ],
        'Facultad de Ciencias Humanas y Educación': [
          'Comunicación Audiovisual y Medios Interactivos',
          'Comunicación Organizacional',
          'Comunicación y Periodismo',
          'Comunicación y Publicidad',
          'Educación, Especialidad Ciencias Naturales y Tecnología',
          'Educación, Especialidad Ciencias: Matemática, Análisis de Datos y Computación',
          'Derecho',
          'Educación, Especialidad Primaria y Pedagogía Terapéutica',
          'Educación, Especialidad Inglés y Español',
          'Educación, Especialidad Música y Artes Visuales',
        ],
        'Facultad de Ciencias de la Salud': [
          'Enfermería',
          'Nutrición Humana',
          'Psicología',
          'Medicina',
          'Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',
          'Tecnología Médica en Terapia Física y Rehabilitación',
        ],
        'Facultad de Ingeniería y Arquitectura': [
          'Ingeniería de Industrias Alimentarias',
          'Ingeniería de Sistemas',
          'Ingeniería Ambiental',
          'Arquitectura',
          'Ingeniería Civil',
          'Ingeniería Industrial',
          'Ingeniería de Ciberseguridad',
          'Ingeniería de Software',
          'Ingeniería de Ciencia de Datos e Inteligencia Artificial',
        ],
        'Facultad de Teología': ['Teología'],
      },
    },
    'juliaca': {
      'nombre': 'Campus Juliaca',
      'ubicacion': 'Juliaca, Puno',
      'facultades': {
        'Facultad de Ciencias Empresariales': [
          'Administración',
          'Contabilidad, Gestión Tributaria y Aduanera',
        ],
        'Facultad de Ciencias Humanas y Educación': [
          'Educación Inicial y Puericultura',
          'Educación Primaria y Pedagogía Terapéutica',
          'Educación, Especialidad Inglés y Español',
        ],
        'Facultad de Ciencias de la Salud': [
          'Enfermería',
          'Nutrición Humana',
          'Psicología',
        ],
        'Facultad de Ingeniería y Arquitectura': [
          'Ingeniería de Industrias Alimentarias',
          'Ingeniería de Sistemas',
          'Arquitectura',
          'Ingeniería Ambiental',
          'Ingeniería Civil',
        ],
      },
    },
    'tarapoto': {
      'nombre': 'Campus Tarapoto',
      'ubicacion': 'Tarapoto, San Martín',
      'facultades': {
        'Facultad de Ciencias Empresariales': [
          'Administración',
          'Contabilidad, Gestión Tributaria y Aduanera',
          'Marketing y Negocios Internacionales',
        ],
        'Facultad de Ciencias de la Salud': ['Enfermería', 'Psicología'],
        'Facultad de Ingeniería y Arquitectura': [
          'Ingeniería de Sistemas',
          'Arquitectura',
          'Ingeniería Ambiental',
          'Ingeniería Civil',
        ],
      },
    },
  };

  Future<bool> inicializarSiEsNecesario() async {
    if (_isInitialized) {
      return true;
    }

    try {
      final filialesSnapshot = await _firestore
          .collection('filiales')
          .limit(1)
          .get();

      if (filialesSnapshot.docs.isNotEmpty) {
        _isInitialized = true;
        return true;
      }

      final batch = _firestore.batch();
      int operaciones = 0;

      for (var filialEntry in estructuraBase.entries) {
        final filialId = filialEntry.key;
        final filialData = filialEntry.value;

        final filialRef = _firestore.collection('filiales').doc(filialId);
        batch.set(filialRef, {
          'nombre': filialData['nombre'],
          'ubicacion': filialData['ubicacion'],
          'createdAt': FieldValue.serverTimestamp(),
        });
        operaciones++;

        final facultades = filialData['facultades'] as Map<String, dynamic>;

        for (var facultadEntry in facultades.entries) {
          final facultadNombre = facultadEntry.key;
          final carreras = facultadEntry.value as List<dynamic>;

          final facultadId = _generarId(facultadNombre);
          final facultadRef = filialRef
              .collection('facultades')
              .doc(facultadId);

          batch.set(facultadRef, {
            'nombre': facultadNombre,
            'createdAt': FieldValue.serverTimestamp(),
          });
          operaciones++;

          for (var carrera in carreras) {
            final carreraRef = facultadRef.collection('carreras').doc();
            batch.set(carreraRef, {
              'nombre': carrera,
              'createdAt': FieldValue.serverTimestamp(),
            });
            operaciones++;

            if (operaciones >= 450) {
              await batch.commit();
              operaciones = 0;
            }
          }
        }
      }

      if (operaciones > 0) {
        await batch.commit();
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error inicializando estructura: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getEstructuraCompleta({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _estructuraCache != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return Map<String, dynamic>.from(_estructuraCache!);
    }

    try {
      final Map<String, dynamic> estructura = {};

      final filialesSnapshot = await _firestore.collection('filiales').get();

      for (var filialDoc in filialesSnapshot.docs) {
        final filialId = filialDoc.id;
        final filialData = Map<String, dynamic>.from(filialDoc.data());

        estructura[filialId] = {
          'nombre': filialData['nombre'] ?? '',
          'ubicacion': filialData['ubicacion'] ?? '',
          'facultades': <String, dynamic>{},
        };

        final facultadesSnapshot = await _firestore
            .collection('filiales')
            .doc(filialId)
            .collection('facultades')
            .get();

        for (var facultadDoc in facultadesSnapshot.docs) {
          final facultadData = Map<String, dynamic>.from(facultadDoc.data());
          final facultadNombre = facultadData['nombre'] ?? '';

          final carrerasSnapshot = await _firestore
              .collection('filiales')
              .doc(filialId)
              .collection('facultades')
              .doc(facultadDoc.id)
              .collection('carreras')
              .orderBy('nombre')
              .get();

          final carreras = carrerasSnapshot.docs
              .map(
                (doc) => {'id': doc.id, 'nombre': doc.data()['nombre'] ?? ''},
              )
              .toList();

          (estructura[filialId]!['facultades']
              as Map<String, dynamic>)[facultadNombre] = {
            'id': facultadDoc.id,
            'carreras': carreras,
          };
        }
      }

      _estructuraCache = estructura;
      _cacheTimestamp = DateTime.now();

      return estructura;
    } catch (e) {
      debugPrint('Error obteniendo estructura: $e');
      return {};
    }
  }

  Future<bool> agregarFacultad({
    required String filialId,
    required String nombreFacultad,
  }) async {
    try {
      if (nombreFacultad.trim().isEmpty) {
        return false;
      }

      final facultadId = _generarId(nombreFacultad.trim());

      final facultadDoc = await _firestore
          .collection('filiales')
          .doc(filialId)
          .collection('facultades')
          .doc(facultadId)
          .get();

      if (facultadDoc.exists) {
        return false;
      }

      await _firestore
          .collection('filiales')
          .doc(filialId)
          .collection('facultades')
          .doc(facultadId)
          .set({
            'nombre': nombreFacultad.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });

      _invalidateCache();
      return true;
    } catch (e) {
      debugPrint('Error agregando facultad: $e');
      return false;
    }
  }

  Future<bool> agregarCarrera({
    required String filialId,
    required String facultadId,
    required String nombreCarrera,
  }) async {
    try {
      if (nombreCarrera.trim().isEmpty) {
        return false;
      }

      final carrerasSnapshot = await _firestore
          .collection('filiales')
          .doc(filialId)
          .collection('facultades')
          .doc(facultadId)
          .collection('carreras')
          .where('nombre', isEqualTo: nombreCarrera.trim())
          .limit(1)
          .get();

      if (carrerasSnapshot.docs.isNotEmpty) {
        return false;
      }

      await _firestore
          .collection('filiales')
          .doc(filialId)
          .collection('facultades')
          .doc(facultadId)
          .collection('carreras')
          .add({
            'nombre': nombreCarrera.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });

      _invalidateCache();
      return true;
    } catch (e) {
      debugPrint('Error agregando carrera: $e');
      return false;
    }
  }

  Future<bool> eliminarCarrera({
    required String filialId,
    required String facultadId,
    required String carreraId,
  }) async {
    try {
      await _firestore
          .collection('filiales')
          .doc(filialId)
          .collection('facultades')
          .doc(facultadId)
          .collection('carreras')
          .doc(carreraId)
          .delete();

      _invalidateCache();
      return true;
    } catch (e) {
      debugPrint('Error eliminando carrera: $e');
      return false;
    }
  }

  Future<bool> editarFilial({
    required String filialId,
    required String nuevoNombre,
    required String nuevaUbicacion,
  }) async {
    try {
      if (nuevoNombre.trim().isEmpty || nuevaUbicacion.trim().isEmpty) {
        return false;
      }

      await _firestore.collection('filiales').doc(filialId).update({
        'nombre': nuevoNombre.trim(),
        'ubicacion': nuevaUbicacion.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _invalidateCache();
      return true;
    } catch (e) {
      debugPrint('Error editando filial: $e');
      return false;
    }
  }

  Future<bool> editarFacultad({
    required String filialId,
    required String facultadId,
    required String nuevoNombre,
  }) async {
    try {
      if (nuevoNombre.trim().isEmpty) {
        return false;
      }

      final nuevoId = _generarId(nuevoNombre.trim());

      if (nuevoId != facultadId) {
        final existente = await _firestore
            .collection('filiales')
            .doc(filialId)
            .collection('facultades')
            .doc(nuevoId)
            .get();

        if (existente.exists) {
          return false;
        }
      }

      await _firestore
          .collection('filiales')
          .doc(filialId)
          .collection('facultades')
          .doc(facultadId)
          .update({
            'nombre': nuevoNombre.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      _invalidateCache();
      return true;
    } catch (e) {
      debugPrint('Error editando facultad: $e');
      return false;
    }
  }

  Future<bool> editarCarrera({
    required String filialId,
    required String facultadId,
    required String carreraId,
    required String nuevoNombre,
  }) async {
    try {
      if (nuevoNombre.trim().isEmpty) {
        return false;
      }

      final duplicado = await _firestore
          .collection('filiales')
          .doc(filialId)
          .collection('facultades')
          .doc(facultadId)
          .collection('carreras')
          .where('nombre', isEqualTo: nuevoNombre.trim())
          .limit(1)
          .get();

      if (duplicado.docs.isNotEmpty && duplicado.docs.first.id != carreraId) {
        return false;
      }

      await _firestore
          .collection('filiales')
          .doc(filialId)
          .collection('facultades')
          .doc(facultadId)
          .collection('carreras')
          .doc(carreraId)
          .update({
            'nombre': nuevoNombre.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      _invalidateCache();
      return true;
    } catch (e) {
      debugPrint('Error editando carrera: $e');
      return false;
    }
  }

  Future<List<String>> getFiliales() async {
    final estructura = await getEstructuraCompleta();
    return estructura.keys.map((e) => e.toString()).toList();
  }

  Future<Map<String, dynamic>?> getFilial(String filialId) async {
    final estructura = await getEstructuraCompleta();
    return estructura[filialId];
  }

  Future<List<String>> getFacultadesByFilial(String filialId) async {
    final estructura = await getEstructuraCompleta();
    final filial = estructura[filialId];
    if (filial == null) return [];
    return (filial['facultades'] as Map).keys.map((e) => e.toString()).toList();
  }

  Future<List<Map<String, dynamic>>> getCarrerasByFacultad(
    String filialId,
    String facultadNombre,
  ) async {
    final estructura = await getEstructuraCompleta();
    final filial = estructura[filialId];
    if (filial == null) return [];

    final facultades = filial['facultades'] as Map;
    final facultad = facultades[facultadNombre];
    if (facultad == null) return [];

    return List<Map<String, dynamic>>.from(facultad['carreras'] ?? []);
  }

  Future<List<Map<String, dynamic>>> getAllCarrerasByFilial(
    String filialId,
  ) async {
    final estructura = await getEstructuraCompleta();
    final filial = estructura[filialId];
    if (filial == null) return [];

    final List<Map<String, dynamic>> todasCarreras = [];
    final facultades = filial['facultades'] as Map;

    for (var facultad in facultades.values) {
      final carreras = List<Map<String, dynamic>>.from(
        facultad['carreras'] ?? [],
      );
      todasCarreras.addAll(carreras);
    }

    return todasCarreras;
  }

  static void clearCache() {
    _estructuraCache = null;
    _cacheTimestamp = null;
  }

  void _invalidateCache() {
    _cacheTimestamp = null;
  }

  String _generarId(String texto) {
    return texto
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  String getNombreFilial(String filialId) {
    return estructuraBase[filialId]?['nombre'] ?? '';
  }

  String getUbicacionFilial(String filialId) {
    return estructuraBase[filialId]?['ubicacion'] ?? '';
  }
}