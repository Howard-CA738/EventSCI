import 'dart:typed_data';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '/prefs_helper.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '/admin_Carrera/certificado_builder.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO LOCAL
// ─────────────────────────────────────────────────────────────────────────────
class CertificadoItem {
  final String id;
  final DatosCertificado datos;
  final DateTime? creadoEn;
  final String nombreEstudiante;

  const CertificadoItem({
    required this.id,
    required this.datos,
    this.creadoEn,
    this.nombreEstudiante = '',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTROLADOR — lógica pura, sin widgets
// ─────────────────────────────────────────────────────────────────────────────
class VerCertificadosController with ChangeNotifier {
  bool isLoading = true;
  List<CertificadoItem> certificados = [];
  String? error;

  String nombreEstudiante = '';

  /// Flags para evitar doble tap en Ver / Descargar.
  final Set<String> procesando = {};

  // ─────────────────────────────────────────────────────────────────────────
  // CARGA
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> cargarCertificados() async {
    isLoading = true;
    error     = null;
    notifyListeners();

    try {
      final userData = await PrefsHelper.getCurrentUserData();
      if (userData == null) {
        _setError('No se pudo obtener los datos del usuario.');
        return;
      }

      nombreEstudiante = userData['name']?.toString() ?? '';

      final ids = await resolverIds(userData);
      if (ids == null) {
        _setError('No se encontró la información académica del estudiante.');
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(ids.$1)
          .collection('students')
          .doc(ids.$2)
          .collection('certificados')
          .orderBy('creadoEn', descending: true)
          .get();

      certificados = snap.docs.map((doc) {
        final d = doc.data();
        return CertificadoItem(
          id:       doc.id,
          datos:    DatosCertificado.fromMap(d),
          creadoEn: (d['creadoEn'] as Timestamp?)?.toDate(),
          nombreEstudiante: d['nombreEstudiante'] as String? ?? '',
        );
      }).toList();

      isLoading = false;
      notifyListeners();
    } catch (e) {
      _setError('Error al cargar certificados: $e');
    }
  }

  /// Resuelve (carreraPath, studentId) desde los datos del usuario.
  /// Retorna null si no se pueden determinar ambos valores.
  Future<(String, String)?> resolverIds(Map<String, dynamic> userData) async {
    String carreraPath = userData['carreraPath']?.toString() ?? '';
    String studentId   = userData['id']?.toString()          ?? '';

    if (carreraPath.isEmpty || studentId.isEmpty) {
      final filial  = userData['filial']?.toString().trim()  ?? '';
      final carrera = userData['carrera']?.toString().trim() ?? '';
      if (filial.isNotEmpty && carrera.isNotEmpty) {
        carreraPath = '${filial}_$carrera';
      }
      studentId = userData['uid']?.toString() ??
          userData['docId']?.toString() ?? '';
    }

    if (carreraPath.isEmpty || studentId.isEmpty) return null;
    return (carreraPath, studentId);
  }

  void _setError(String msg) {
    error     = msg;
    isLoading = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GENERACIÓN DE PDF (on-demand, sin guardar en Firestore)
  // ─────────────────────────────────────────────────────────────────────────
  Future<Uint8List?> generarPdf(
    CertificadoItem cert, {
    required void Function(String) onError,
  }) async {
    try {
      final bytes1 = await _descargarPorUrl(cert.datos.urlFirma1);
      final bytes2 = await _descargarPorUrl(cert.datos.urlFirma2);
      final bytes3 = await _descargarPorUrl(cert.datos.urlFirma3);

      final datosConFirmas = DatosCertificado(
        evento:    cert.datos.evento,
        rol:       cert.datos.rol,
        fecha:     cert.datos.fecha,
        horas:     cert.datos.horas,
        carrera:   cert.datos.carrera,
        facultad:  cert.datos.facultad,
        campus:    cert.datos.campus,
        motivo:    cert.datos.motivo,
        director1: cert.datos.director1, cargo1: cert.datos.cargo1,
        director2: cert.datos.director2, cargo2: cert.datos.cargo2,
        director3: cert.datos.director3, cargo3: cert.datos.cargo3,
        urlFirma1: cert.datos.urlFirma1,
        urlFirma2: cert.datos.urlFirma2,
        urlFirma3: cert.datos.urlFirma3,
        bytesFirma1: bytes1,
        bytesFirma2: bytes2,
        bytesFirma3: bytes3,
        codigoCertificado: cert.datos.codigoCertificado, // ← imprime el código
      );

      // Usa el nombre guardado en Firestore, con fallback a PrefsHelper.
      final nombre = cert.nombreEstudiante.isNotEmpty
          ? cert.nombreEstudiante
          : nombreEstudiante;

      if (nombre.isEmpty) {
        onError('No se pudo determinar el nombre del estudiante.');
        return null;
      }

      final builder = CertificadoBuilder(datosConFirmas);
      final estudianteTemp = Estudiante(
        id: '', nombre: nombre, dni: '', codigo: '',
      );
      return await builder.buildPdf([estudianteTemp]);
    } catch (e) {
      onError('Error al generar el certificado: $e');
      return null;
    }
  }

  // Descarga directa por URL (sin necesitar permisos de Storage SDK)
  Future<Uint8List?> _descargarPorUrl(String? url) async {
    if (url == null || url.isEmpty) return null;

    try {
      // Intento 1: refrescar URL desde Storage SDK (más confiable)
      final storagePath = _extraerStoragePath(url);
      if (storagePath != null) {
        final freshUrl = await FirebaseStorage.instance
            .ref(storagePath)
            .getDownloadURL();
        final response = await http
            .get(Uri.parse(freshUrl))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) return response.bodyBytes;
      }

      // Intento 2: usar la URL directamente como fallback
      if (url.startsWith('https://')) {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) return response.bodyBytes;
      }

      debugPrint('⚠️ No se pudo descargar firma desde: $url');
      return null;
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase Storage error: ${e.code} — $e');
      return null;
    } on TimeoutException {
      debugPrint('❌ Timeout descargando firma');
      return null;
    } catch (e) {
      debugPrint('❌ Error inesperado descargando firma: $e');
      return null;
    }
  }

  String? _extraerStoragePath(String url) {
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

  Future<void> abrirCertificado(
    CertificadoItem cert, {
    required void Function(String) onSnack,
  }) async {
    if (procesando.contains(cert.id)) return;
    procesando.add(cert.id);
    notifyListeners();
    onSnack('Generando certificado...');

    try {
      final bytes = await generarPdf(cert, onError: onSnack);
      if (bytes == null) return;
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } finally {
      procesando.remove(cert.id);
      notifyListeners();
    }
  }

  Future<void> descargarCertificado(
    CertificadoItem cert, {
    required void Function(String) onSnack,
  }) async {
    if (procesando.contains(cert.id)) return;
    procesando.add(cert.id);
    notifyListeners();
    onSnack('Preparando descarga...');

    try {
      final bytes = await generarPdf(cert, onError: onSnack);
      if (bytes == null) return;
      final nombre =
          'certificado_${cert.datos.rol.toLowerCase()}_'
          '${cert.datos.evento.replaceAll(' ', '_').toLowerCase()}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: nombre);
    } finally {
      procesando.remove(cert.id);
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS PUROS
  // ─────────────────────────────────────────────────────────────────────────
  Color colorPorRol(String rol) {
    switch (rol) {
      case 'PONENTE':     return const Color(0xFF7C3AED);
      case 'JURADO':      return const Color(0xFF0F6E56);
      case 'ORGANIZADOR': return const Color(0xFFB45309);
      default:            return const Color(0xFF1E3A5F);
    }
  }

  IconData iconPorRol(String rol) {
    switch (rol) {
      case 'PONENTE':     return Icons.mic_rounded;
      case 'JURADO':      return Icons.gavel_rounded;
      case 'ORGANIZADOR': return Icons.manage_accounts_rounded;
      default:            return Icons.workspace_premium;
    }
  }

  String formatFecha(DateTime dt) {
    const meses = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${dt.day} ${meses[dt.month]} ${dt.year}';
  }

  /// Devuelve un mapa rol → cantidad para el widget de resumen.
  Map<String, int> contarPorRol() {
    final roles = <String, int>{};
    for (final c in certificados) {
      roles[c.datos.rol] = (roles[c.datos.rol] ?? 0) + 1;
    }
    return roles;
  }
}