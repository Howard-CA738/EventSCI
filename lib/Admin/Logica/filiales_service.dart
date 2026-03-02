import 'package:cloud_firestore/cloud_firestore.dart';

class FilialesService {
  static final FilialesService _instance = FilialesService._internal();
  factory FilialesService() => _instance;
  FilialesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════
  // ✅ CACHÉ EN MEMORIA (como PrefsHelper)
  // ═══════════════════════════════════════════════════════════════
  static Map<String, dynamic>? _estructuraCache;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(hours: 24);
  static bool _isInitialized = false;

  // ═══════════════════════════════════════════════════════════════
  // ✅ ESTRUCTURA PREDEFINIDA (solo se usa para inicialización)
  // ═══════════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════════
  // ✅ INICIALIZACIÓN (SOLO UNA VEZ EN TODA LA APP)
  // ═══════════════════════════════════════════════════════════════
  Future<bool> inicializarSiEsNecesario() async {
    if (_isInitialized) {
      print('✅ Estructura ya inicializada, omitiendo...');
      return true;
    }

    try {
      // Verificar si ya existe la estructura en Firebase
      final filialesSnapshot = await _firestore
          .collection('filiales')
          .limit(1)
          .get();

      if (filialesSnapshot.docs.isNotEmpty) {
        print('✅ Estructura ya existe en Firebase');
        _isInitialized = true;
        return true;
      }

      print('📝 Inicializando estructura por primera vez...');

      // Crear estructura completa
      final batch = _firestore.batch();
      int operaciones = 0;

      for (var filialEntry in estructuraBase.entries) {
        final filialId = filialEntry.key;
        final filialData = filialEntry.value;

        // Crear filial
        final filialRef = _firestore.collection('filiales').doc(filialId);
        batch.set(filialRef, {
          'nombre': filialData['nombre'],
          'ubicacion': filialData['ubicacion'],
          'createdAt': FieldValue.serverTimestamp(),
        });
        operaciones++;

        // Crear facultades y carreras
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

          // Crear carreras
          for (var carrera in carreras) {
            final carreraRef = facultadRef.collection('carreras').doc();
            batch.set(carreraRef, {
              'nombre': carrera,
              'createdAt': FieldValue.serverTimestamp(),
            });
            operaciones++;

            // Firebase batch limit es 500, dividir si es necesario
            if (operaciones >= 450) {
              await batch.commit();
              print('✅ Batch de $operaciones operaciones ejecutado');
              operaciones = 0;
            }
          }
        }
      }

      // Commit final
      if (operaciones > 0) {
        await batch.commit();
        print('✅ Batch final de $operaciones operaciones ejecutado');
      }

      _isInitialized = true;
      print('✅ Estructura completa inicializada exitosamente');
      return true;
    } catch (e) {
      print('❌ Error inicializando estructura: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ OBTENER ESTRUCTURA COMPLETA CON CACHÉ
  // ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> getEstructuraCompleta({
    bool forceRefresh = false,
  }) async {
    // Verificar caché
    if (!forceRefresh &&
        _estructuraCache != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      print('✅ Estructura obtenida del caché (válida por 24h)');
      return Map<String, dynamic>.from(_estructuraCache!);
    }

    print('⚠️ Caché expirado o no disponible, cargando desde Firestore...');

    try {
      final Map<String, dynamic> estructura = {};

      // Obtener todas las filiales (3 lecturas)
      final filialesSnapshot = await _firestore.collection('filiales').get();

      for (var filialDoc in filialesSnapshot.docs) {
        final filialId = filialDoc.id;
        final filialData = Map<String, dynamic>.from(filialDoc.data());

        estructura[filialId] = {
          'nombre': filialData['nombre'] ?? '',
          'ubicacion': filialData['ubicacion'] ?? '',
          'facultades': <String, dynamic>{},
        };

        // Obtener facultades de esta filial
        final facultadesSnapshot = await _firestore
            .collection('filiales')
            .doc(filialId)
            .collection('facultades')
            .get();

        for (var facultadDoc in facultadesSnapshot.docs) {
          final facultadData = Map<String, dynamic>.from(facultadDoc.data());
          final facultadNombre = facultadData['nombre'] ?? '';

          // Obtener carreras de esta facultad
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

      // Guardar en caché
      _estructuraCache = estructura;
      _cacheTimestamp = DateTime.now();

      print('✅ Estructura cargada y cacheada exitosamente');
      return estructura;
    } catch (e) {
      print('❌ Error obteniendo estructura: $e');
      return {};
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ AGREGAR NUEVA CARRERA
  // ═══════════════════════════════════════════════════════════════
  Future<bool> agregarCarrera({
    required String filialId,
    required String facultadId,
    required String nombreCarrera,
  }) async {
    try {
      // Validar que el nombre no esté vacío
      if (nombreCarrera.trim().isEmpty) {
        print('❌ El nombre de la carrera no puede estar vacío');
        return false;
      }

      // Verificar si la carrera ya existe
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
        print('⚠️ La carrera "$nombreCarrera" ya existe en esta facultad');
        return false;
      }

      // Agregar la nueva carrera
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

      print('✅ Carrera "$nombreCarrera" agregada exitosamente');

      // Invalidar caché para que se recargue
      _invalidateCache();

      return true;
    } catch (e) {
      print('❌ Error agregando carrera: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ ELIMINAR CARRERA
  // ═══════════════════════════════════════════════════════════════
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

      print('✅ Carrera eliminada exitosamente');

      // Invalidar caché para que se recargue
      _invalidateCache();

      return true;
    } catch (e) {
      print('❌ Error eliminando carrera: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ MÉTODOS RÁPIDOS (usan caché)
  // ═══════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════
  // ✅ LIMPIAR CACHÉ (llamar al cerrar sesión)
  // ═══════════════════════════════════════════════════════════════
  static void clearCache() {
    _estructuraCache = null;
    _cacheTimestamp = null;
    print('🗑️ Caché de filiales limpiado');
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ INVALIDAR CACHÉ (forzar recarga en próxima consulta)
  // ═══════════════════════════════════════════════════════════════
  void _invalidateCache() {
    _cacheTimestamp = null;
    print('🔄 Caché invalidado, se recargará en la próxima consulta');
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ UTILIDADES
  // ═══════════════════════════════════════════════════════════════
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
