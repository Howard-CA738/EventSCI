import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Elimina fondo blanco — firma01 y firma03
// ─────────────────────────────────────────────────────────────────────────────
Future<Uint8List> _removeWhiteBackground(
  Uint8List srcBytes, {
  int threshold = 60,
}) async {
  final codec    = await ui.instantiateImageCodec(srcBytes);
  final frame    = await codec.getNextFrame();
  final uiImage  = frame.image;
  final w        = uiImage.width;
  final h        = uiImage.height;
  final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
  final pixels   = byteData!.buffer.asUint8List();
  final out      = Uint8List.fromList(pixels);

  for (int i = 0; i < out.length; i += 4) {
    final brightness = (out[i] + out[i + 1] + out[i + 2]) ~/ 3;
    out[i + 3] = brightness > (255 - threshold) ? 0 : 255;
  }

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(out, w, h, ui.PixelFormat.rgba8888,
      (img) => completer.complete(img));
  final newImg = await completer.future;
  final png    = await newImg.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

// ─────────────────────────────────────────────────────────────────────────────
// Elimina fondo negro — firma02
// ─────────────────────────────────────────────────────────────────────────────
Future<Uint8List> _processF2BlackBackground(Uint8List srcBytes) async {
  final codec    = await ui.instantiateImageCodec(srcBytes);
  final frame    = await codec.getNextFrame();
  final uiImage  = frame.image;
  final w        = uiImage.width;
  final h        = uiImage.height;
  final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
  final pixels   = byteData!.buffer.asUint8List();
  final out      = Uint8List.fromList(pixels);

  const bgThresh = 4;
  final visited  = List<bool>.filled(w * h, false);
  final queue    = Queue<int>();

  bool isBg(int idx) =>
      out[idx] < bgThresh &&
      out[idx + 1] < bgThresh &&
      out[idx + 2] < bgThresh;

  void enqueue(int x, int y) {
    if (x < 0 || x >= w || y < 0 || y >= h) return;
    final p = y * w + x;
    if (visited[p]) return;
    if (!isBg(p * 4)) return;
    visited[p] = true;
    queue.add(p);
  }

  for (int x = 0; x < w; x++) { enqueue(x, 0); enqueue(x, h - 1); }
  for (int y = 0; y < h; y++) { enqueue(0, y); enqueue(w - 1, y); }

  while (queue.isNotEmpty) {
    final p = queue.removeFirst();
    out[p * 4 + 3] = 0;
    final x = p % w;
    final y = p ~/ w;
    enqueue(x + 1, y);
    enqueue(x - 1, y);
    enqueue(x, y + 1);
    enqueue(x, y - 1);
  }

  for (int i = 0; i < out.length; i += 4) {
    if (out[i + 3] == 0) continue;
    final r = out[i], g = out[i + 1], b = out[i + 2];
    final isBlue = b > r + 15 && b > g + 8;
    if (isBlue) {
      out[i]     = (27 * (1.0 - (b / 128.0) * 0.5)).clamp(0, 255).toInt();
      out[i + 1] = (42 * (1.0 - (b / 128.0) * 0.5)).clamp(0, 255).toInt();
      out[i + 2] = (b * 1.5).clamp(100, 255).toInt();
      out[i + 3] = (100 + b * 1.5).clamp(0, 255).toInt();
    }
  }

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(out, w, h, ui.PixelFormat.rgba8888,
      (img) => completer.complete(img));
  final newImg = await completer.future;
  final png    = await newImg.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

// ─────────────────────────────────────────────────────────────────────────────
class Estudiante {
  final String id, nombre, dni, codigo, email;
  final bool   pagado;
  bool         seleccionado;

  Estudiante({
    required this.id,
    required this.nombre,
    required this.dni,
    required this.codigo,
    this.email        = '',
    this.pagado       = false,
    this.seleccionado = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Cache solo para assets estáticos
// ─────────────────────────────────────────────────────────────────────────────
class _AssetCache {
  static pw.MemoryImage? templateImage;
  static pw.Font?        ttfRegular;
  static pw.Font?        ttfBold;
  static pw.Font?        ttfItalic;
  static pw.Font?        ttfNombre;

  static bool get isLoaded =>
      templateImage != null && ttfRegular != null &&
      ttfBold != null && ttfItalic != null && ttfNombre != null;

  static Future<void> loadAssets() async {
    if (isLoaded) return;
    final r = await Future.wait([
      rootBundle.load('assets/plantilla_certificado.png'),
      rootBundle.load('assets/fonts/Montserrat-Regular.ttf'),
      rootBundle.load('assets/fonts/Montserrat-Bold.ttf'),
      rootBundle.load('assets/fonts/Montserrat-Italic.ttf'),
      rootBundle.load('assets/fonts/Cinzel-Regular.ttf'),
    ]);
    templateImage = pw.MemoryImage(r[0].buffer.asUint8List());
    ttfRegular    = pw.Font.ttf(r[1]);
    ttfBold       = pw.Font.ttf(r[2]);
    ttfItalic     = pw.Font.ttf(r[3]);
    ttfNombre     = pw.Font.ttf(r[4]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class DatosCertificado {
  final String evento, rol, fecha, horas, carrera, facultad, campus, motivo;
  final String director1, cargo1;
  final String director2, cargo2;
  final String director3, cargo3;
  final String urlFirma1, urlFirma2, urlFirma3;

  // Bytes procesados (en memoria, no se guardan en Firestore)
  final Uint8List? bytesFirma1;
  final Uint8List? bytesFirma2;
  final Uint8List? bytesFirma3;

  const DatosCertificado({
    required this.evento,    required this.rol,      required this.fecha,
    required this.horas,     required this.carrera,  required this.facultad,
    required this.campus,    required this.motivo,
    required this.director1, required this.cargo1,
    required this.director2, required this.cargo2,
    required this.director3, required this.cargo3,
    this.urlFirma1 = '',
    this.urlFirma2 = '',
    this.urlFirma3 = '',
    this.bytesFirma1,
    this.bytesFirma2,
    this.bytesFirma3,
  });

  Map<String, dynamic> toMap() => {
    'evento': evento, 'rol': rol, 'fecha': fecha, 'horas': horas,
    'carrera': carrera, 'facultad': facultad, 'campus': campus, 'motivo': motivo,
    'director1': director1, 'cargo1': cargo1,
    'director2': director2, 'cargo2': cargo2,
    'director3': director3, 'cargo3': cargo3,
    'urlFirma1': urlFirma1,
    'urlFirma2': urlFirma2,
    'urlFirma3': urlFirma3,
    // bytesFirma no se guardan — son solo para memoria
  };

  factory DatosCertificado.fromMap(Map<String, dynamic> d) =>
      DatosCertificado(
        evento: d['evento'] ?? '', rol: d['rol'] ?? 'ASISTENTE',
        fecha: d['fecha'] ?? '', horas: d['horas'] ?? '',
        carrera: d['carrera'] ?? '', facultad: d['facultad'] ?? '',
        campus: d['campus'] ?? '', motivo: d['motivo'] ?? '',
        director1: d['director1'] ?? '', cargo1: d['cargo1'] ?? '',
        director2: d['director2'] ?? '', cargo2: d['cargo2'] ?? '',
        director3: d['director3'] ?? '', cargo3: d['cargo3'] ?? '',
        urlFirma1: d['urlFirma1'] ?? '',
        urlFirma2: d['urlFirma2'] ?? '',
        urlFirma3: d['urlFirma3'] ?? '',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
class CertificadoBuilder {
  final DatosCertificado datos;
  CertificadoBuilder(this.datos);

  Future<Uint8List> buildPdf(List<Estudiante> estudiantes) async {
    // 1. Assets estáticos
    await _AssetCache.loadAssets();

    // 2. Procesar bytes de firmas (ya descargados desde la pantalla)
    pw.MemoryImage? f1Image, f2Image, f3Image;

    final results = await Future.wait([
      datos.bytesFirma1 != null
          ? _removeWhiteBackground(datos.bytesFirma1!)
          : Future.value(null),
      datos.bytesFirma2 != null
          ? _processF2BlackBackground(datos.bytesFirma2!)
          : Future.value(null),
      datos.bytesFirma3 != null
          ? _removeWhiteBackground(datos.bytesFirma3!)
          : Future.value(null),
    ]);

    if (results[0] != null) f1Image = pw.MemoryImage(results[0]!);
    if (results[1] != null) f2Image = pw.MemoryImage(results[1]!);
    if (results[2] != null) f3Image = pw.MemoryImage(results[2]!);

    final tpl    = _AssetCache.templateImage!;
    final reg    = _AssetCache.ttfRegular!;
    final bold   = _AssetCache.ttfBold!;
    final italic = _AssetCache.ttfItalic!;
    final nom    = _AssetCache.ttfNombre!;

    const cAzul   = PdfColor.fromInt(0xFF0D254A);
    const cTexto  = PdfColor.fromInt(0xFF2B2B2B);
    const cGris   = PdfColor.fromInt(0xFF94A3B8);
    const cCampus = PdfColor.fromInt(0xFF0D254A);

    final a4l        = PdfPageFormat.a4.landscape;
    final pageFormat = PdfPageFormat(a4l.width, a4l.height, marginAll: 0);
    final W          = pageFormat.width;
    final H          = pageFormat.height;

    final pageTheme = pw.PageTheme(
      pageFormat: pageFormat,
      margin:     pw.EdgeInsets.zero,
      buildBackground: (_) => pw.Container(
        width: W, height: H,
        child: pw.Image(tpl, fit: pw.BoxFit.fill),
      ),
    );

    final firmaAncho = W * 0.300;
    final firmaImgH  = 72.0;
    final firmaTop   = H * 0.640;

    final pdf = pw.Document();

    for (final est in estudiantes) {
      pdf.addPage(pw.Page(
        pageTheme: pageTheme,
        build: (_) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Stack(children: [

            pw.Positioned(
              left: 0, right: 0, top: H * 0.280,
              child: pw.Center(child: pw.Text(
                _facultadFmt(datos.facultad),
                style: pw.TextStyle(font: bold, fontSize: 21, color: cAzul),
                textAlign: pw.TextAlign.center,
              )),
            ),

            pw.Positioned(
              left: 0, right: 0, top: H * 0.330,
              child: pw.Center(child: pw.Text(
                _campusFmt(datos.campus),
                style: pw.TextStyle(font: reg, fontSize: 11,
                    color: cCampus, letterSpacing: 5.5),
                textAlign: pw.TextAlign.center,
              )),
            ),

            pw.Positioned(
              left: W * 0.07, right: W * 0.07, top: H * 0.410,
              child: pw.Center(child: pw.Text(
                est.nombre,
                style: pw.TextStyle(font: nom, fontSize: 22,
                    color: cTexto, letterSpacing: 1.5),
                textAlign: pw.TextAlign.center,
              )),
            ),

            pw.Positioned(
              left: W * 0.10, right: W * 0.10, top: H * 0.470,
              child: pw.RichText(
                textAlign: pw.TextAlign.center,
                text: _motivoSpan(datos.motivo.trim(), reg, bold, cTexto),
              ),
            ),

            pw.Positioned(
              right: W * 0.080, top: H * 0.600,
              child: pw.Text(
                '${_campusNombre(datos.campus)}, ${datos.fecha}',
                style: pw.TextStyle(font: italic, fontSize: 10, color: cTexto),
              ),
            ),

            if (f1Image != null)
              pw.Positioned(
                left: W * 0.190 - firmaAncho / 2, top: firmaTop,
                child: _firmaBloque(f1Image, datos.director1, datos.cargo1,
                    firmaAncho, firmaImgH, bold, reg, cAzul, cGris),
              ),
            if (f2Image != null)
              pw.Positioned(
                left: W * 0.500 - firmaAncho / 2, top: firmaTop,
                child: _firmaBloque(f2Image, datos.director2, datos.cargo2,
                    firmaAncho, firmaImgH, bold, reg, cAzul, cGris),
              ),
            if (f3Image != null)
              pw.Positioned(
                left: W * 0.810 - firmaAncho / 2, top: firmaTop,
                child: _firmaBloque(f3Image, datos.director3, datos.cargo3,
                    firmaAncho, firmaImgH, bold, reg, cAzul, cGris),
              ),

            if (f1Image == null && datos.director1.isNotEmpty)
              pw.Positioned(
                left: W * 0.190 - firmaAncho / 2,
                top:  firmaTop + firmaImgH + 5,
                child: _firmaBloqueTexto(datos.director1, datos.cargo1,
                    firmaAncho, bold, reg, cAzul, cGris),
              ),
            if (f2Image == null && datos.director2.isNotEmpty)
              pw.Positioned(
                left: W * 0.500 - firmaAncho / 2,
                top:  firmaTop + firmaImgH + 5,
                child: _firmaBloqueTexto(datos.director2, datos.cargo2,
                    firmaAncho, bold, reg, cAzul, cGris),
              ),
            if (f3Image == null && datos.director3.isNotEmpty)
              pw.Positioned(
                left: W * 0.810 - firmaAncho / 2,
                top:  firmaTop + firmaImgH + 5,
                child: _firmaBloqueTexto(datos.director3, datos.cargo3,
                    firmaAncho, bold, reg, cAzul, cGris),
              ),

            // ── CÓDIGO ELIMINADO DEL PDF ──
            // El código único ahora se guarda solo en Firestore (campo 'codigoCertificado')

          ]),
        ),
      ));
    }

    return pdf.save();
  }

  pw.Widget _firmaBloque(
    pw.MemoryImage img, String nombre, String cargo,
    double ancho, double imgH,
    pw.Font bold, pw.Font reg, PdfColor cAzul, PdfColor cGris,
  ) =>
      pw.SizedBox(
        width: ancho,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(width: ancho, height: imgH,
                child: pw.Image(img, fit: pw.BoxFit.contain)),
            pw.SizedBox(height: 2),
            pw.Container(height: 0.5, width: ancho * 0.75, color: cGris),
            pw.SizedBox(height: 4),
            pw.Text(nombre,
                style: pw.TextStyle(font: bold, fontSize: 7.5, color: cAzul),
                textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 2),
            pw.Container(
              width: ancho,
              child: pw.Text(
                _formatearCargo(cargo),
                style: pw.TextStyle(font: reg, fontSize: 6, color: cGris),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
      );

  pw.Widget _firmaBloqueTexto(
    String nombre, String cargo, double ancho,
    pw.Font bold, pw.Font reg, PdfColor cAzul, PdfColor cGris,
  ) =>
      pw.SizedBox(
        width: ancho,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(height: 0.5, width: ancho * 0.75, color: cGris),
            pw.SizedBox(height: 4),
            pw.Text(nombre,
                style: pw.TextStyle(font: bold, fontSize: 7.5, color: cAzul),
                textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 2),
            pw.Container(
              width: ancho,
              child: pw.Text(
                _formatearCargo(cargo),
                style: pw.TextStyle(font: reg, fontSize: 6, color: cGris),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
      );

  String _formatearCargo(String cargo) {
    if (cargo.length <= 28) return cargo;
    final mid = cargo.length ~/ 2;
    int izq = mid, der = mid;
    while (izq > 0 || der < cargo.length) {
      if (izq > 0 && cargo[izq] == ' ') {
        return '${cargo.substring(0, izq)}\n${cargo.substring(izq + 1)}';
      }
      if (der < cargo.length && cargo[der] == ' ') {
        return '${cargo.substring(0, der)}\n${cargo.substring(der + 1)}';
      }
      izq--;
      der++;
    }
    return cargo;
  }

  String _facultadFmt(String raw) {
    final sin = raw.replaceFirst(
        RegExp(r'^FACULTAD\s+DE\s+', caseSensitive: false), '');
    return 'Facultad de ${_tc(sin)}'.replaceAll(RegExp(r'\bY\b'), 'y');
  }

  String _campusFmt(String raw) {
    final u = raw.trim().toUpperCase();
    return u.startsWith('CAMPUS ') ? u : 'CAMPUS $u';
  }

  String _campusNombre(String raw) => _tc(
      raw.trim().replaceFirst(RegExp(r'^CAMPUS\s+', caseSensitive: false), ''));

  String _tc(String s) => s.toLowerCase().split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  pw.InlineSpan _motivoSpan(
      String texto, pw.Font reg, pw.Font bold, PdfColor color) {
    final phrases = [
      datos.rol, datos.evento,
      '${datos.horas} horas académicas', datos.carrera,
    ].where((s) => s.isNotEmpty).toList();

    final phrasesLow = phrases.map((s) => s.toLowerCase()).toList();
    final base       = pw.TextStyle(fontSize: 10, color: color, lineSpacing: 4.0);
    final spans      = <pw.InlineSpan>[];
    String rem       = texto;
    String remLow    = texto.toLowerCase();

    while (rem.isNotEmpty) {
      int ni = -1, np = -1;
      for (int i = 0; i < phrasesLow.length; i++) {
        final idx = remLow.indexOf(phrasesLow[i]);
        if (idx != -1 && (ni == -1 || idx < ni)) { ni = idx; np = i; }
      }
      if (ni == -1) {
        spans.add(pw.TextSpan(text: rem, style: base.copyWith(font: reg)));
        break;
      }
      final pl = phrases[np].length;
      if (ni > 0) {
        spans.add(pw.TextSpan(
            text: rem.substring(0, ni), style: base.copyWith(font: reg)));
      }
      spans.add(pw.TextSpan(
          text: rem.substring(ni, ni + pl), style: base.copyWith(font: bold)));
      rem    = rem.substring(ni + pl);
      remLow = remLow.substring(ni + pl);
    }
    return pw.TextSpan(children: spans);
  }
}