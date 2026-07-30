import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class GenerarQRController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


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




  bool requiereCarrera(String? facultad) {
    if (facultad == null) return true;
    return facultad != 'Universidad Peruana Unión';
  }






  Future<List<QueryDocumentSnapshot>> buscarEventos({
    required String facultad,
    String? carrera,
    String? sede,
  }) async {
    Query query = _firestore
        .collection('events')
        .where('facultad', isEqualTo: facultad);

    if (carrera != null && carrera.isNotEmpty) {
      query = query.where('carrera', isEqualTo: carrera);
    } else if (facultad == 'Universidad Peruana Unión') {
      query = query.where('carrera', isEqualTo: 'General');
    }


    if (sede != null && sede.isNotEmpty) {
      query = query.where('sede', isEqualTo: sede);
    }

    final QuerySnapshot snapshot = await query
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs;
  }




  Future<List<String>> cargarCategorias(String eventId) async {
    final QuerySnapshot proyectosSnapshot = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('proyectos')
        .get();

    final Set<String> categoriasSet = {};
    for (final doc in proyectosSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final clasificacion = data['Clasificación']?.toString().trim();
      if (clasificacion != null && clasificacion.isNotEmpty) {
        categoriasSet.add(clasificacion);
      }
    }
    return categoriasSet.toList()..sort();
  }




  Future<Map<String, String>> generarQRParaTodasLasCategorias({
    required String eventId,
    required String eventName,
    required String facultad,
    required String carrera,
    required List<String> categorias,
    String? sede,
  }) async {
    final Map<String, String> qrData = {};

    for (final categoria in categorias) {
      final proyectos = await _obtenerProyectosPorCategoria(
        eventId: eventId,
        categoria: categoria,
      );
      final primerProyecto = proyectos.isNotEmpty ? proyectos.first : null;

      final qrInfo = _crearQRInfo(
        eventId: eventId,
        eventName: eventName,
        facultad: facultad,
        carrera: carrera,
        categoria: categoria,
        codigoProyecto: primerProyecto?['Código']?.toString(),
        tituloProyecto: primerProyecto?['Título']?.toString(),
        grupo: primerProyecto?['Sala']?.toString(),
        sede: sede,
      );
      qrData[categoria] = jsonEncode(qrInfo);
    }
    return qrData;
  }

  Future<String> generarQRParaProyecto({
    required String eventId,
    required String eventName,
    required String facultad,
    required String carrera,
    required String categoria,
    required String codigoProyecto,
    required String tituloProyecto,
    String? grupo,
    String? sede,
  }) async {
    final qrInfo = _crearQRInfo(
      eventId: eventId,
      eventName: eventName,
      facultad: facultad,
      carrera: carrera,
      categoria: categoria,
      codigoProyecto: codigoProyecto,
      tituloProyecto: tituloProyecto,
      grupo: grupo,
      sede: sede,
    );

    debugPrint('🔧 QR generado para proyecto:');
    debugPrint('   Código: $codigoProyecto | Sede: $sede');

    return jsonEncode(qrInfo);
  }

  String generarQRParaCategoria({
    required String eventId,
    required String eventName,
    required String facultad,
    required String carrera,
    required String categoria,
    String? codigoProyecto,
    String? tituloProyecto,
    String? grupo,
    String? sede,
  }) {
    final qrInfo = _crearQRInfo(
      eventId: eventId,
      eventName: eventName,
      facultad: facultad,
      carrera: carrera,
      categoria: categoria,
      codigoProyecto: codigoProyecto,
      tituloProyecto: tituloProyecto,
      grupo: grupo,
      sede: sede,
    );
    return jsonEncode(qrInfo);
  }




  Map<String, dynamic> _crearQRInfo({
    required String eventId,
    required String eventName,
    required String facultad,
    required String carrera,
    required String categoria,
    String? codigoProyecto,
    String? tituloProyecto,
    String? grupo,
    String? sede,
  }) {
    final grupoValido =
        grupo != null &&
        grupo.trim().isNotEmpty &&
        grupo.toLowerCase() != 'sin grupo' &&
        grupo.toLowerCase() != 'null';

    final sedeValida = sede != null && sede.trim().isNotEmpty;

    final qrData = <String, dynamic>{
      'eventId': eventId,
      'eventName': eventName,
      'facultad': facultad,
      'carrera': carrera,
      'categoria': categoria,
      'codigoProyecto': codigoProyecto ?? 'Sin código',
      'tituloProyecto': tituloProyecto ?? 'Sin título',
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'asistencia_categoria',
    };


    if (sedeValida) {
      qrData['sede'] = sede.trim();
      debugPrint('✅ Sede incluida en QR: $sede');
    }

    if (grupoValido) {
      qrData['grupo'] = grupo;
    }

    return qrData;
  }




  Future<List<Map<String, dynamic>>> _obtenerProyectosPorCategoria({
    required String eventId,
    required String categoria,
  }) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .where('Clasificación', isEqualTo: categoria)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('❌ Error obteniendo proyectos: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> obtenerProyectosDeCategoria({
    required String eventId,
    required String categoria,
  }) async {
    return await _obtenerProyectosPorCategoria(
      eventId: eventId,
      categoria: categoria,
    );
  }

  Future<Map<String, String>> generarQRsPorProyecto({
    required String eventId,
    required String eventName,
    required String facultad,
    required String carrera,
    required String categoria,
    String? sede,
  }) async {
    final Map<String, String> qrsPorProyecto = {};
    final proyectos = await obtenerProyectosDeCategoria(
      eventId: eventId,
      categoria: categoria,
    );

    for (final proyecto in proyectos) {
      final codigo = proyecto['Código']?.toString() ?? 'Sin código';
      final titulo = proyecto['Título']?.toString() ?? 'Sin título';
      final sala = proyecto['Sala']?.toString();

      final qrData = await generarQRParaProyecto(
        eventId: eventId,
        eventName: eventName,
        facultad: facultad,
        carrera: carrera,
        categoria: categoria,
        codigoProyecto: codigo,
        tituloProyecto: titulo,
        grupo: sala,
        sede: sede,
      );
      qrsPorProyecto[codigo] = qrData;
    }

    debugPrint('✅ Generados ${qrsPorProyecto.length} QRs para: $categoria');
    return qrsPorProyecto;
  }

  List<String> obtenerCarrerasPorFacultad(String facultad) {
    return facultadesCarreras[facultad] ?? [];
  }
}
