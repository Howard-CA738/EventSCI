import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─────────────────────────────────────────────────────────────────────────────
// MODELO ESTUDIANTE
// ─────────────────────────────────────────────────────────────────────────────
class Estudiante {
  final String id;
  final String nombre;
  final String dni;
  final String codigo;
  final String email;
  final bool pagado;
  bool seleccionado;

  Estudiante({
    required this.id,
    required this.nombre,
    required this.dni,
    required this.codigo,
    this.email = '',
    this.pagado = false,
    this.seleccionado = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CACHE DE ASSETS — se carga UNA sola vez para todos los PDFs
// ─────────────────────────────────────────────────────────────────────────────
class _AssetCache {
  static pw.MemoryImage? templateImage;
  static pw.Font? ttfRegular;
  static pw.Font? ttfBold;
  static pw.Font? ttfItalic;
  static pw.Font? ttfNombre;

  static bool get isLoaded =>
      templateImage != null &&
      ttfRegular != null &&
      ttfBold != null &&
      ttfItalic != null &&
      ttfNombre != null;

  static Future<void> load() async {
    if (isLoaded) return;
    final results = await Future.wait([
      rootBundle.load('assets/certificado.jpg'),
      rootBundle.load('assets/fonts/Montserrat-Regular.ttf'),
      rootBundle.load('assets/fonts/Montserrat-Bold.ttf'),
      rootBundle.load('assets/fonts/Montserrat-Italic.ttf'),
      rootBundle.load('assets/fonts/Cinzel-Regular.ttf'),
    ]);
    templateImage = pw.MemoryImage(results[0].buffer.asUint8List());
    ttfRegular    = pw.Font.ttf(results[1]);
    ttfBold       = pw.Font.ttf(results[2]);
    ttfItalic     = pw.Font.ttf(results[3]);
    ttfNombre     = pw.Font.ttf(results[4]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATOS DE CERTIFICADO — lo que se guarda en Firestore (sin PDF)
// ─────────────────────────────────────────────────────────────────────────────
class DatosCertificado {
  final String evento;
  final String rol;
  final String fecha;
  final String horas;
  final String carrera;
  final String facultad;
  final String campus;
  final String motivo;
  final String director1;
  final String cargo1;
  final String director2;
  final String cargo2;

  const DatosCertificado({
    required this.evento,
    required this.rol,
    required this.fecha,
    required this.horas,
    required this.carrera,
    required this.facultad,
    required this.campus,
    required this.motivo,
    required this.director1,
    required this.cargo1,
    required this.director2,
    required this.cargo2,
  });

  Map<String, dynamic> toMap() => {
        'evento':    evento,
        'rol':       rol,
        'fecha':     fecha,
        'horas':     horas,
        'carrera':   carrera,
        'facultad':  facultad,
        'campus':    campus,
        'motivo':    motivo,
        'director1': director1,
        'cargo1':    cargo1,
        'director2': director2,
        'cargo2':    cargo2,
      };

  factory DatosCertificado.fromMap(Map<String, dynamic> d) => DatosCertificado(
        evento:    d['evento']    ?? '',
        rol:       d['rol']       ?? 'ASISTENTE',
        fecha:     d['fecha']     ?? '',
        horas:     d['horas']     ?? '',
        carrera:   d['carrera']   ?? '',
        facultad:  d['facultad']  ?? '',
        campus:    d['campus']    ?? '',
        motivo:    d['motivo']    ?? '',
        director1: d['director1'] ?? '',
        cargo1:    d['cargo1']    ?? '',
        director2: d['director2'] ?? '',
        cargo2:    d['cargo2']    ?? '',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILDER — genera el PDF en el momento que se necesita
// ─────────────────────────────────────────────────────────────────────────────
class CertificadoBuilder {
  final DatosCertificado datos;

  CertificadoBuilder(this.datos);

  factory CertificadoBuilder.fromParams({
    required String facultad,
    required String carrera,
    required String campus,
    required String motivo,
    required String fecha,
    required String horas,
    required String evento,
    required String rolParticipante,
    required String director1,
    required String cargo1,
    required String director2,
    required String cargo2,
  }) =>
      CertificadoBuilder(DatosCertificado(
        facultad:  facultad,
        carrera:   carrera,
        campus:    campus,
        motivo:    motivo,
        fecha:     fecha,
        horas:     horas,
        evento:    evento,
        rol:       rolParticipante,
        director1: director1,
        cargo1:    cargo1,
        director2: director2,
        cargo2:    cargo2,
      ));

  Future<Uint8List> buildPdf(List<Estudiante> estudiantes) async {
    await _AssetCache.load();

    final templateImage = _AssetCache.templateImage!;
    final ttfRegular    = _AssetCache.ttfRegular!;
    final ttfBold       = _AssetCache.ttfBold!;
    final ttfItalic     = _AssetCache.ttfItalic!;
    final ttfNombre     = _AssetCache.ttfNombre!;

    const colorAzulOscuro = PdfColor.fromInt(0xFF1B2A4A);
    const colorDorado     = PdfColor.fromInt(0xFFB8952A);
    const colorGrisTexto  = PdfColor.fromInt(0xFF2B2B2B);

    final a4l        = PdfPageFormat.a4.landscape;
    final pageFormat = PdfPageFormat(a4l.width, a4l.height, marginAll: 0);
    final W = pageFormat.width;
    final H = pageFormat.height;

    final pageTheme = pw.PageTheme(
      pageFormat: pageFormat,
      margin: pw.EdgeInsets.zero,
      buildBackground: (ctx) => pw.Container(
        width: pageFormat.width,
        height: pageFormat.height,
        child: pw.Image(templateImage, fit: pw.BoxFit.cover),
      ),
    );

    final campusNormalizado = datos.campus.toUpperCase().startsWith('CAMPUS ')
        ? datos.campus.toUpperCase()
        : 'CAMPUS ${datos.campus.toUpperCase()}';

    final facultadTexto =
        'FACULTAD DE ${datos.facultad.toUpperCase().replaceFirst(RegExp(r'^FACULTAD\s+DE\s+', caseSensitive: false), '')}';

    final pdf = pw.Document();

    for (final est in estudiantes) {
      pdf.addPage(
        pw.Page(
          pageTheme: pageTheme,
          build: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Stack(
              children: [
                // Campus
                pw.Positioned(
                  left: 0, right: 0, top: H * 0.235,
                  child: pw.Center(
                    child: pw.Text(
                      campusNormalizado,
                      style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 16,
                          color: colorAzulOscuro,
                          letterSpacing: 1.0),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ),
                // Facultad
                pw.Positioned(
                  left: 0, right: 0, top: H * 0.280,
                  child: pw.Center(
                    child: pw.RichText(
                      textAlign: pw.TextAlign.center,
                      text: pw.TextSpan(
                        text: facultadTexto,
                        style: pw.TextStyle(
                            font: ttfBold, fontSize: 18, color: colorDorado),
                      ),
                    ),
                  ),
                ),
                // Nombre del estudiante
                pw.Positioned(
                  left: W * 0.10, right: W * 0.10, top: H * 0.420,
                  child: pw.Center(
                    child: pw.Text(
                      est.nombre,
                      style: pw.TextStyle(
                          font: ttfNombre,
                          fontSize: 26,
                          color: colorGrisTexto,
                          letterSpacing: 1.2),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ),
                // Motivo
                pw.Positioned(
                  left: W * 0.18, right: W * 0.18, top: H * 0.490,
                  child: pw.RichText(
                    textAlign: pw.TextAlign.center,
                    text: _buildMotivoSpan(
                        datos.motivo.trim(), ttfRegular, ttfBold, colorGrisTexto),
                  ),
                ),
                // Fecha
                pw.Positioned(
                  left: 0, right: W * 0.12, top: H * 0.630,
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      datos.fecha,
                      style: pw.TextStyle(
                          font: ttfItalic, fontSize: 9, color: colorGrisTexto),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return pdf.save();
  }

  pw.InlineSpan _buildMotivoSpan(
      String texto, pw.Font regular, pw.Font bold, PdfColor color) {
    final boldPhrases = [
      datos.rol,
      datos.evento,
      '${datos.horas} horas académicas',
      datos.carrera,
    ].where((s) => s.isNotEmpty).toList();

    // ✅ OPT: pre-calcular lowercase de frases una sola vez
    final boldPhrasesLower = boldPhrases.map((s) => s.toLowerCase()).toList();

    final baseStyle = pw.TextStyle(fontSize: 9.5, color: color, lineSpacing: 2.5);
    final spans     = <pw.InlineSpan>[];
    String remaining      = texto;
    String remainingLower = texto.toLowerCase();

    while (remaining.isNotEmpty) {
      int nearestIdx    = -1;
      int nearestPhraseI = -1;

      for (int i = 0; i < boldPhrasesLower.length; i++) {
        final idx = remainingLower.indexOf(boldPhrasesLower[i]);
        if (idx != -1 && (nearestIdx == -1 || idx < nearestIdx)) {
          nearestIdx    = idx;
          nearestPhraseI = i;
        }
      }

      if (nearestIdx == -1) {
        spans.add(pw.TextSpan(
            text: remaining, style: baseStyle.copyWith(font: regular)));
        break;
      }

      final phraseLen = boldPhrases[nearestPhraseI].length;

      if (nearestIdx > 0) {
        spans.add(pw.TextSpan(
            text: remaining.substring(0, nearestIdx),
            style: baseStyle.copyWith(font: regular)));
      }

      spans.add(pw.TextSpan(
        text: remaining.substring(nearestIdx, nearestIdx + phraseLen),
        style: baseStyle.copyWith(font: bold),
      ));

      remaining      = remaining.substring(nearestIdx + phraseLen);
      remainingLower = remainingLower.substring(nearestIdx + phraseLen);
    }

    return pw.TextSpan(children: spans);
  }
}