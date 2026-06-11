import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  EXTRACCIÓN DE FIRMA — universal y de alta calidad
//
//  Funciona con cualquier firma sin importar el fondo:
//   • Fondo blanco con tinta negra o azul.
//   • Fondo negro con tinta azul o trazo gris débil.
//   • Sellos circulares (se conservan).
//
//  Claves de calidad:
//   1) Detecta el color de fondo real muestreando los bordes de la imagen.
//   2) Alpha GRADUAL según la distancia de color al fondo → bordes suaves
//      (antialiasing), no "recortados" ni opacos.
//   3) Conserva el color de la tinta (azul sigue azul, negro sigue negro);
//      solo profundiza un poco para que no quede lavada sobre el blanco.
//   4) Umbral adaptativo: refuerza automáticamente las firmas muy débiles.
//   5) Nunca lanza excepción: si algo falla, devuelve null y el certificado
//      se genera igual (con el respaldo de texto del firmante).
// ─────────────────────────────────────────────────────────────────────────────
Future<Uint8List?> _procesarFirma(Uint8List? srcBytes) async {
  if (srcBytes == null) return null;
  try {
    return await _extraerFirma(srcBytes);
  } catch (e) {
    // Una firma defectuosa JAMÁS debe tumbar el certificado completo.
    debugPrint('Firma omitida (no se pudo procesar): $e');
    return null;
  }
}

Future<Uint8List> _extraerFirma(Uint8List srcBytes) async {
  // 1) Decodificar. Si la imagen es enorme, la reducimos a un lado máximo
  //    de 1600 px: procesa mucho más rápido y la firma en el PDF (~250 pt)
  //    no pierde nitidez.
  const maxSide = 1600;
  var codec = await ui.instantiateImageCodec(srcBytes);
  var frame = await codec.getNextFrame();
  ui.Image img = frame.image;

  final longSide = img.width > img.height ? img.width : img.height;
  if (longSide > maxSide) {
    final scale = maxSide / longSide;
    codec = await ui.instantiateImageCodec(
      srcBytes,
      targetWidth:  (img.width  * scale).round(),
      targetHeight: (img.height * scale).round(),
    );
    img = (await codec.getNextFrame()).image;
  }

  final w  = img.width;
  final h  = img.height;
  final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final px = bd!.buffer.asUint8List();
  final out = Uint8List.fromList(px);

  // 2) Color de fondo: promedio de una banda de 2 px en los 4 bordes.
  int sr = 0, sg = 0, sb = 0, n = 0;
  void sample(int x, int y) {
    final i = (y * w + x) * 4;
    sr += px[i]; sg += px[i + 1]; sb += px[i + 2]; n++;
  }
  const band = 2;
  for (int y = 0; y < h; y++) {
    for (int b = 0; b < band && b < w; b++) {
      sample(b, y); sample(w - 1 - b, y);
    }
  }
  for (int x = 0; x < w; x++) {
    for (int b = 0; b < band && b < h; b++) {
      sample(x, b); sample(x, h - 1 - b);
    }
  }
  if (n == 0) n = 1;
  final bgR = sr / n, bgG = sg / n, bgB = sb / n;

  // 3) Histograma de distancias al fondo (1 pasada) → umbral adaptativo.
  final hist = List<int>.filled(444, 0);
  for (int i = 0; i < px.length; i += 4) {
    final dr = px[i] - bgR, dg = px[i + 1] - bgG, db = px[i + 2] - bgB;
    var d = math.sqrt(dr * dr + dg * dg + db * db).round();
    if (d > 443) d = 443;
    hist[d]++;
  }
  final total = w * h;
  final cut   = (total * 0.995).floor();   // percentil 99.5
  int acc = 0;
  double maxd = 1;
  for (int d = 0; d < hist.length; d++) {
    acc += hist[d];
    if (acc >= cut) { maxd = d.toDouble(); break; }
  }
  if (maxd < 1) maxd = 1;

  final lo    = math.max(18.0, maxd * 0.12);  // por debajo = fondo (alpha 0)
  final hi    = math.max(45.0, maxd * 0.55);  // por encima = tinta sólida
  final gamma = maxd < 150 ? 0.55 : 0.8;      // firmas débiles → más sólidas
  final rango = (hi - lo) <= 0 ? 1.0 : (hi - lo);

  // 4) Componer salida: alpha gradual + color de tinta conservado.
  for (int i = 0; i < out.length; i += 4) {
    final r = px[i], g = px[i + 1], b = px[i + 2];
    final dr = r - bgR, dg = g - bgG, db = b - bgB;
    final d  = math.sqrt(dr * dr + dg * dg + db * db);

    var a = ((d - lo) / rango).clamp(0.0, 1.0);
    if (a <= 0) { out[i + 3] = 0; continue; }
    a = math.pow(a, gamma).toDouble();

    final maxc   = math.max(r, math.max(g, b));
    final minc   = math.min(r, math.min(g, b));
    final chroma = maxc - minc;

    if (chroma < 28) {
      // Tinta gris / negra → negro de tinta legible.
      out[i] = 20; out[i + 1] = 20; out[i + 2] = 20;
    } else {
      // Tinta de color → conserva el tono, profundiza un poco.
      out[i]     = (r * 0.78).round().clamp(0, 255);
      out[i + 1] = (g * 0.78).round().clamp(0, 255);
      out[i + 2] = (b * 0.78).round().clamp(0, 255);
    }
    out[i + 3] = (a * 255).round().clamp(0, 255);
  }

  // 5) Re-codificar a PNG con transparencia.
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(out, w, h, ui.PixelFormat.rgba8888,
      (im) => completer.complete(im));
  final newImg = await completer.future;
  final png    = await newImg.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO ESTUDIANTE — incluye codigoCertificado
// ─────────────────────────────────────────────────────────────────────────────
class Estudiante {
  final String id, nombre, dni, codigo, email;
  final String codigoCertificado; // ← campo para mostrar en el PDF
  final bool   pagado;
  bool         seleccionado;

  Estudiante({
    required this.id,
    required this.nombre,
    required this.dni,
    required this.codigo,
    this.email               = '',
    this.codigoCertificado   = '',
    this.pagado              = false,
    this.seleccionado        = false,
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
// DATOS DEL CERTIFICADO — incluye codigoCertificado
// ─────────────────────────────────────────────────────────────────────────────
class DatosCertificado {
  final String evento, rol, fecha, horas, carrera, facultad, campus, motivo;
  final String director1, cargo1;
  final String director2, cargo2;
  final String director3, cargo3;
  final String urlFirma1, urlFirma2, urlFirma3;
  final String codigoCertificado; // ← campo para mostrar en el PDF

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
    this.urlFirma1          = '',
    this.urlFirma2          = '',
    this.urlFirma3          = '',
    this.codigoCertificado  = '',
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
    'codigoCertificado': codigoCertificado,
    // bytesFirma no se guardan — son solo para memoria
  };

  factory DatosCertificado.fromMap(Map<String, dynamic> d) =>
      DatosCertificado(
        evento:    d['evento']    ?? '', rol:    d['rol']    ?? 'ASISTENTE',
        fecha:     d['fecha']     ?? '', horas:  d['horas']  ?? '',
        carrera:   d['carrera']   ?? '', facultad: d['facultad'] ?? '',
        campus:    d['campus']    ?? '', motivo: d['motivo']  ?? '',
        director1: d['director1'] ?? '', cargo1: d['cargo1'] ?? '',
        director2: d['director2'] ?? '', cargo2: d['cargo2'] ?? '',
        director3: d['director3'] ?? '', cargo3: d['cargo3'] ?? '',
        urlFirma1: d['urlFirma1'] ?? '',
        urlFirma2: d['urlFirma2'] ?? '',
        urlFirma3: d['urlFirma3'] ?? '',
        codigoCertificado: d['codigoCertificado'] as String? ?? '',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILDER DEL PDF
// ─────────────────────────────────────────────────────────────────────────────
class CertificadoBuilder {
  final DatosCertificado datos;
  CertificadoBuilder(this.datos);

  Future<Uint8List> buildPdf(List<Estudiante> estudiantes) async {
    await _AssetCache.loadAssets();

    pw.MemoryImage? f1Image, f2Image, f3Image;

    final results = await Future.wait([
      _procesarFirma(datos.bytesFirma1),
      _procesarFirma(datos.bytesFirma2),
      _procesarFirma(datos.bytesFirma3),
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
      final codigoFinal = est.codigoCertificado.isNotEmpty
          ? est.codigoCertificado
          : datos.codigoCertificado;

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

           if (codigoFinal.isNotEmpty)
  pw.Positioned(
    right:  W * 0.040,
    bottom: H * 0.030,
    child: pw.Text(
      codigoFinal,
      style: pw.TextStyle(
        font:          bold,
        fontSize:      8,
        color:         const PdfColor(1, 1, 1, 1.0),
        letterSpacing: 1.5,
      ),
    ),
  ),

          ]),
        ),
      ));
    }

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS DE FIRMA
  // ─────────────────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS DE TEXTO
  // ─────────────────────────────────────────────────────────────────────────
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