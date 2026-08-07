import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import '/shared/certificado_builder.dart';
import '/roles/jurados/datos/cert_item.dart';

class JuradoCertificadosService {
  final String juradoId;
  final String juradoNombre;

  JuradoCertificadosService({
    required this.juradoId,
    required this.juradoNombre,
  });

  Future<List<CertItem>> cargar() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(juradoId)
        .collection('certificados')
        .orderBy('creadoEn', descending: true)
        .get();

    return snap.docs.map((doc) {
      final d = doc.data();
      return CertItem(
        id: doc.id,
        datos: DatosCertificado.fromMap(d),
        creadoEn: (d['creadoEn'] as Timestamp?)?.toDate(),
        nombreJurado: d['nombreEstudiante'] as String? ?? juradoNombre,
      );
    }).toList();
  }

  Future<Uint8List?> generarPdf(CertItem cert) async {
    try {
      final bytes1 = await descargarPorUrl(cert.datos.urlFirma1);
      final bytes2 = await descargarPorUrl(cert.datos.urlFirma2);
      final bytes3 = await descargarPorUrl(cert.datos.urlFirma3);

      final datosConFirmas = DatosCertificado(
        evento: cert.datos.evento,
        rol: cert.datos.rol,
        fecha: cert.datos.fecha,
        horas: cert.datos.horas,
        carrera: cert.datos.carrera,
        facultad: cert.datos.facultad,
        campus: cert.datos.campus,
        motivo: cert.datos.motivo,
        director1: cert.datos.director1, cargo1: cert.datos.cargo1,
        director2: cert.datos.director2, cargo2: cert.datos.cargo2,
        director3: cert.datos.director3, cargo3: cert.datos.cargo3,
        urlFirma1: cert.datos.urlFirma1,
        urlFirma2: cert.datos.urlFirma2,
        urlFirma3: cert.datos.urlFirma3,
        bytesFirma1: bytes1,
        bytesFirma2: bytes2,
        bytesFirma3: bytes3,
        codigoCertificado: cert.datos.codigoCertificado,
      );

      final nombre =
          cert.nombreJurado.isNotEmpty ? cert.nombreJurado : juradoNombre;
      if (nombre.isEmpty) return null;

      final builder = CertificadoBuilder(datosConFirmas);
      final persona = Estudiante(
        id: juradoId,
        nombre: nombre,
        dni: '',
        codigo: '',
      );
      return await builder.buildPdf([persona]);
    } catch (e) {
      debugPrint('Error generando PDF certificado jurado: $e');
      return null;
    }
  }

  Future<Uint8List?> descargarPorUrl(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final storagePath = extraerStoragePath(url);
      if (storagePath != null) {
        final freshUrl = await FirebaseStorage.instance
            .ref(storagePath)
            .getDownloadURL();
        final r = await http
            .get(Uri.parse(freshUrl))
            .timeout(const Duration(seconds: 30));
        if (r.statusCode == 200) return r.bodyBytes;
      }

      if (url.startsWith('https://')) {
        final r = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30));
        if (r.statusCode == 200) return r.bodyBytes;
      }
      return null;
    } on FirebaseException catch (e) {
      debugPrint('Firebase Storage error: ${e.code}');
      return null;
    } on TimeoutException {
      debugPrint('Timeout descargando firma');
      return null;
    } catch (e) {
      debugPrint('Error descargando firma: $e');
      return null;
    }
  }

  String? extraerStoragePath(String url) {
    try {
      final uri = Uri.parse(url);
      final oIndex = uri.path.indexOf('/o/');
      if (oIndex == -1) return null;
      final encoded = uri.path.substring(oIndex + 3).split('?').first;
      return Uri.decodeComponent(encoded);
    } catch (_) {
      return null;
    }
  }
}
