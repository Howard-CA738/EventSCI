import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '/shared/certificado_builder.dart';
import '../datos/persona.dart';
import '../datos/certificado_enviado.dart';

class GenerarCertificadosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Persona>> cargarEstudiantes({
    required String docKeyEstudiantes,
  }) async {
    final snap = await _firestore
        .collection('users')
        .doc(docKeyEstudiantes)
        .collection('students')
        .orderBy('name')
        .get();
    return snap.docs.map((doc) {
      final d = doc.data();
      return Persona(
        id: doc.id,
        nombre: d['name'] as String? ?? 'Sin nombre',
        dni: d['dni'] as String? ?? '',
        codigo: d['codigoUniversitario'] as String? ?? '',
      );
    }).toList();
  }

  Future<List<Persona>> cargarJurados({
    required String filialId,
    required String facultad,
    required String carrera,
  }) async {
    final snap = await _firestore
        .collection('users')
        .where('userType', isEqualTo: 'jurado')
        .where('filial', isEqualTo: filialId)
        .where('facultad', isEqualTo: facultad)
        .where('carrera', isEqualTo: carrera)
        .get();
    final lista = snap.docs.map((doc) {
      final d = doc.data();
      return Persona(
        id: doc.id,
        nombre: d['name'] as String? ?? 'Sin nombre',
        dni: d['dni'] as String? ?? '',
        codigo: d['usuario'] as String? ?? '',
        esJurado: true,
      );
    }).toList();
    lista.sort((a, b) => a.nombre.compareTo(b.nombre));
    return lista;
  }

  Future<List<CertificadoEnviado>> certificadosDe({
    required Persona p,
    required String rol,
    required String docKeyEstudiantes,
  }) async {
    final ref = p.esJurado
        ? _firestore.collection('users').doc(p.id).collection('certificados')
        : _firestore
            .collection('users')
            .doc(docKeyEstudiantes)
            .collection('students')
            .doc(p.id)
            .collection('certificados');

    final snap = await ref.where('rol', isEqualTo: rol).get();
    final lista = snap.docs.map(CertificadoEnviado.fromDoc).toList();
    lista.sort((a, b) {
      final ta = a.creadoEn?.millisecondsSinceEpoch ?? 0;
      final tb = b.creadoEn?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });
    return lista;
  }

  Future<Uint8List?> descargarFirma(String url) async {
    if (url.isEmpty) return null;
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (e) {
      debugPrint('Error HTTP directo: $e — intentando refrescar...');
    }
    try {
      final uri = Uri.parse(url);
      final segments = uri.path.split('/o/');
      if (segments.length < 2) return null;
      final fullPath = Uri.decodeComponent(segments.last.split('?').first);
      final newUrl =
          await FirebaseStorage.instance.ref(fullPath).getDownloadURL();
      final response = await http
          .get(Uri.parse(newUrl))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (e) {
      debugPrint('Error refrescando URL: $e');
    }
    return null;
  }

  Future<Uint8List> generarPdfCertificado(
      Persona p, CertificadoEnviado c) async {
    final datosBase = DatosCertificado.fromMap(c.raw);
    final resultados = await Future.wait([
      descargarFirma(datosBase.urlFirma1),
      descargarFirma(datosBase.urlFirma2),
      descargarFirma(datosBase.urlFirma3),
    ]);
    final datos = DatosCertificado(
      facultad: datosBase.facultad,
      carrera: datosBase.carrera,
      campus: datosBase.campus,
      motivo: datosBase.motivo,
      fecha: datosBase.fecha,
      horas: datosBase.horas,
      evento: datosBase.evento,
      rol: datosBase.rol,
      director1: datosBase.director1,
      cargo1: datosBase.cargo1,
      director2: datosBase.director2,
      cargo2: datosBase.cargo2,
      director3: datosBase.director3,
      cargo3: datosBase.cargo3,
      codigoCertificado: c.codigoCertificado,
      bytesFirma1: resultados[0],
      bytesFirma2: resultados[1],
      bytesFirma3: resultados[2],
    );
    final estudiante = Estudiante(
      id: p.id,
      nombre: (c.raw['nombreEstudiante'] as String? ?? '').isNotEmpty
          ? c.raw['nombreEstudiante'] as String
          : p.nombre,
      dni: p.dni,
      codigo: p.codigo,
      codigoCertificado: c.codigoCertificado,
    );
    final builder = CertificadoBuilder(datos);
    return await builder.buildPdf([estudiante]);
  }
}
