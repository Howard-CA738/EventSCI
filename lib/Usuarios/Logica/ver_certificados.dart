import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '/prefs_helper.dart';
import '/admin_Carrera/certificado_builder.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO LOCAL
// ─────────────────────────────────────────────────────────────────────────────
class CertificadoItem {
  final String id;
  final DatosCertificado datos;
  final DateTime? creadoEn;

  const CertificadoItem({
    required this.id,
    required this.datos,
    this.creadoEn,
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
      final builder        = CertificadoBuilder(cert.datos);
      final estudianteTemp = Estudiante(
        id:     '',
        nombre: nombreEstudiante,
        dni:    '',
        codigo: '',
      );
      return await builder.buildPdf([estudianteTemp]);
    } catch (e) {
      onError('Error al generar el certificado: $e');
      return null;
    }
  }

  Future<void> abrirCertificado(
    CertificadoItem cert, {
    required void Function(String) onSnack,
  }) async {
    if (procesando.contains(cert.id)) return;
    procesando.add(cert.id);
    onSnack('Generando certificado...');

    final bytes = await generarPdf(cert, onError: onSnack);
    procesando.remove(cert.id);

    if (bytes == null) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> descargarCertificado(
    CertificadoItem cert, {
    required void Function(String) onSnack,
  }) async {
    if (procesando.contains(cert.id)) return;
    procesando.add(cert.id);
    onSnack('Preparando descarga...');

    final bytes = await generarPdf(cert, onError: onSnack);
    procesando.remove(cert.id);

    if (bytes == null) return;
    final nombre =
        'certificado_${cert.datos.rol.toLowerCase()}_'
        '${cert.datos.evento.replaceAll(' ', '_').toLowerCase()}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: nombre);
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