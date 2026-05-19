import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// Archivo: lib/admin/interfaz/informe_word.dart

class InformeWordGenerator {
  static Future<void> generarYCompartir({
    required Map<String, dynamic> evento,
    required Map<String, dynamic> adminData,
  }) async {
    final Uint8List bytes =
        await _obtenerBytes(evento: evento, adminData: adminData);

    final dir = await getTemporaryDirectory();
    final nombreEvento = (evento['name'] as String)
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');
    final archivo = File('${dir.path}/Informe_$nombreEvento.docx');
    await archivo.writeAsBytes(bytes);

    await Share.shareXFiles(
      [
        XFile(
          archivo.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        ),
      ],
      subject: 'Informe - ${evento['name']}',
    );
  }

  // ─── OBTENER CATEGORÍAS DESDE FIRESTORE ──────────────────────────────────

  static Future<List<String>> _obtenerCategorias(String eventId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .get();

      final Set<String> categorias = {};
      for (final doc in snapshot.docs) {
        final clasificacion = doc.data()['Clasificación'] as String?;
        if (clasificacion != null && clasificacion.isNotEmpty) {
          categorias.add(clasificacion);
        }
      }

      return categorias.toList()..sort();
    } catch (e) {
      debugPrint('Error al obtener categorías: $e');
      return [];
    }
  }

  // ─── OBTENER FILAS DE RESULTADO PARA LA TABLA DE RESULTADOS ──────────────

  static Future<List<_FilaResultado>> _obtenerFilasResultado(
      String eventId) async {
    final List<_FilaResultado> filas = [];

    try {
      final proyectosSnap = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .get();

      final Map<String, int> conteoPorCategoria = {};
      for (final doc in proyectosSnap.docs) {
        final clasificacion =
            (doc.data()['Clasificación'] as String?)?.trim() ?? '';
        if (clasificacion.isNotEmpty) {
          conteoPorCategoria[clasificacion] =
              (conteoPorCategoria[clasificacion] ?? 0) + 1;
        }
      }

      if (conteoPorCategoria.isEmpty) return [];

      final categorias = conteoPorCategoria.keys.toList()..sort();

      final Map<String, Set<String>> asistentesUnicos = {
        for (final cat in categorias) cat: <String>{},
      };

      bool fallbackNecesario = false;

      final lotes = <List<String>>[];
      for (int i = 0; i < categorias.length; i += 10) {
        lotes.add(categorias.skip(i).take(10).toList());
      }

      for (final lote in lotes) {
        try {
          final scansSnap = await FirebaseFirestore.instance
              .collectionGroup('scans')
              .where('categoria', whereIn: lote)
              .get();

          for (final scanDoc in scansSnap.docs) {
            final segments = scanDoc.reference.path.split('/');
            if (segments.length < 6) continue;
            if (segments[0] != 'events') continue;
            if (segments[1] != eventId) continue;
            if (segments[2] != 'asistencias') continue;

            final categoria =
                scanDoc.data()['categoria']?.toString() ?? '';
            if (!asistentesUnicos.containsKey(categoria)) continue;

            final studentId = segments[3];
            asistentesUnicos[categoria]!.add(studentId);
          }
        } catch (e) {
          debugPrint('collectionGroup falló para lote $lote: $e');
          fallbackNecesario = true;
          break;
        }
      }

      if (fallbackNecesario) {
        debugPrint('Activando fallback por alumno para eventId=$eventId');

        for (final cat in categorias) {
          asistentesUnicos[cat]!.clear();
        }

        try {
          final alumnosSnap = await FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .collection('asistencias')
              .get();

          for (final alumnoDoc in alumnosSnap.docs) {
            final studentId = alumnoDoc.id;

            final scansAlumno =
                await alumnoDoc.reference.collection('scans').get();

            for (final scanDoc in scansAlumno.docs) {
              final categoria =
                  scanDoc.data()['categoria']?.toString() ?? '';
              if (asistentesUnicos.containsKey(categoria)) {
                asistentesUnicos[categoria]!.add(studentId);
              }
            }
          }
        } catch (e2) {
          debugPrint('Error en fallback de asistencias: $e2');
        }
      }

      for (final categoria in categorias) {
        filas.add(_FilaResultado(
          categoria: categoria,
          trabajosAceptados: conteoPorCategoria[categoria]!,
          estudiantesAsistentes: asistentesUnicos[categoria]?.length ?? 0,
        ));
      }
    } catch (e) {
      debugPrint('Error general en _obtenerFilasResultado: $e');
    }

    return filas;
  }

  // ─── OBTENER TOP 2 GANADORES POR CATEGORÍA DESDE FIRESTORE ───────────────

  static Future<List<_FilaGanador>> _obtenerGanadores(String eventId) async {
    final List<_FilaGanador> filas = [];
    try {
      final proyectosSnap = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .get();

      if (proyectosSnap.docs.isEmpty) return [];

      final results = await Future.wait(
        proyectosSnap.docs.map((proyectoDoc) async {
          final evalSnap = await FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .collection('proyectos')
              .doc(proyectoDoc.id)
              .collection('evaluaciones')
              .where('evaluada', isEqualTo: true)
              .get();

          if (evalSnap.docs.isEmpty) return null;

          final pData = proyectoDoc.data();
          final notas = evalSnap.docs
              .map((e) => (e.data()['notaTotal'] ?? 0.0) as num)
              .toList();
          final promedio = notas.reduce((a, b) => a + b) / notas.length;

          return {
            'codigo':        pData['Código']       ?? '',
            'titulo':        pData['Título']        ?? '',
            'integrantes':   pData['Integrantes']   ?? '',
            'clasificacion': pData['Clasificación'] ?? 'Sin categoría',
            'promedio':      promedio.toDouble(),
          };
        }),
      );

      final validos = results.whereType<Map<String, dynamic>>().toList();
      if (validos.isEmpty) return [];

      final Map<String, List<Map<String, dynamic>>> porCategoria = {};
      for (final p in validos) {
        final cat = p['clasificacion'] as String;
        porCategoria.putIfAbsent(cat, () => []).add(p);
      }

      porCategoria.forEach((categoria, lista) {
        lista.sort((a, b) =>
            (b['promedio'] as double).compareTo(a['promedio'] as double));
        for (final p in lista.take(2)) {
          filas.add(_FilaGanador(
            categoria:   categoria,
            codigo:      p['codigo']      as String,
            titulo:      p['titulo']      as String,
            integrantes: p['integrantes'] as String,
            promedio:    p['promedio']    as double,
          ));
        }
      });

      filas.sort((a, b) {
        final c = a.categoria.compareTo(b.categoria);
        return c != 0 ? c : b.promedio.compareTo(a.promedio);
      });
    } catch (e) {
      debugPrint('Error en _obtenerGanadores: $e');
    }
    return filas;
  }

  // ─── XML: PIE DE TABLA (párrafo "Descripción" centrado) ──────────────────

  static String _buildPieTabla(String texto) {
    final t = texto
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return '<w:p>'
        '<w:pPr><w:pStyle w:val="Descripcin"/><w:jc w:val="center"/></w:pPr>'
        '<w:r><w:t xml:space="preserve"> $t</w:t></w:r>'
        '</w:p>';
  }

  // ─── XML: TABLA DE CATEGORÍAS (2 columnas: N° + CATEGORÍA) ──────────────

  static String _buildTablaCategorias(List<String> categorias) {
    const String abrirTabla = '''
<w:tbl>
  <w:tblPr>
    <w:tblStyle w:val="TableGrid"/>
    <w:tblW w:w="9360" w:type="dxa"/>
    <w:tblBorders>
      <w:top    w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
      <w:left   w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
      <w:bottom w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
      <w:right  w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
      <w:insideH w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
      <w:insideV w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
    </w:tblBorders>
    <w:tblLook w:val="04A0"/>
  </w:tblPr>
  <w:tblGrid>
    <w:gridCol w:w="936"/>
    <w:gridCol w:w="8424"/>
  </w:tblGrid>''';

    const String filaEncabezado = '''
  <w:tr>
    <w:trPr><w:trHeight w:val="400"/></w:trPr>
    <w:tc>
      <w:tcPr>
        <w:tcW w:w="936" w:type="dxa"/>
        <w:shd w:val="clear" w:color="auto" w:fill="1E3A5F"/>
      </w:tcPr>
      <w:p>
        <w:pPr><w:jc w:val="center"/></w:pPr>
        <w:r>
          <w:rPr><w:b/><w:color w:val="FFFFFF"/><w:sz w:val="20"/></w:rPr>
          <w:t>N°</w:t>
        </w:r>
      </w:p>
    </w:tc>
    <w:tc>
      <w:tcPr>
        <w:tcW w:w="8424" w:type="dxa"/>
        <w:shd w:val="clear" w:color="auto" w:fill="1E3A5F"/>
      </w:tcPr>
      <w:p>
        <w:pPr><w:jc w:val="center"/></w:pPr>
        <w:r>
          <w:rPr><w:b/><w:color w:val="FFFFFF"/><w:sz w:val="20"/></w:rPr>
          <w:t>CATEGORÍA</w:t>
        </w:r>
      </w:p>
    </w:tc>
  </w:tr>''';

    final StringBuffer filas = StringBuffer();
    for (int i = 0; i < categorias.length; i++) {
      final numero = (i + 1).toString();
      final cat = categorias[i]
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');
      final fill = (i % 2 == 0) ? 'FFFFFF' : 'EEF2F7';

      filas.write('''
  <w:tr>
    <w:trPr><w:trHeight w:val="360"/></w:trPr>
    <w:tc>
      <w:tcPr>
        <w:tcW w:w="936" w:type="dxa"/>
        <w:shd w:val="clear" w:color="auto" w:fill="$fill"/>
      </w:tcPr>
      <w:p>
        <w:pPr><w:jc w:val="center"/></w:pPr>
        <w:r>
          <w:rPr><w:sz w:val="20"/></w:rPr>
          <w:t>$numero</w:t>
        </w:r>
      </w:p>
    </w:tc>
    <w:tc>
      <w:tcPr>
        <w:tcW w:w="8424" w:type="dxa"/>
        <w:shd w:val="clear" w:color="auto" w:fill="$fill"/>
      </w:tcPr>
      <w:p>
        <w:pPr><w:jc w:val="left"/></w:pPr>
        <w:r>
          <w:rPr><w:sz w:val="20"/></w:rPr>
          <w:t xml:space="preserve"> $cat</w:t>
        </w:r>
      </w:p>
    </w:tc>
  </w:tr>''');
    }

    return '$abrirTabla$filaEncabezado${filas.toString()}\n</w:tbl>';
  }

  // ─── XML: TABLA DE RESULTADOS (4 columnas) ───────────────────────────────

  static String _buildTablaResultados(List<_FilaResultado> filas) {
    const int col1 = 2340;
    const int col2 = 2340;
    const int col3 = 2340;
    const int col4 = 2340;
    const int totalAncho = col1 + col2 + col3 + col4;

    final String abrirTabla = '''
<w:tbl>
  <w:tblPr>
    <w:tblStyle w:val="TableGrid"/>
    <w:tblW w:w="$totalAncho" w:type="dxa"/>
    <w:tblBorders>
      <w:top    w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
      <w:left   w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
      <w:bottom w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
      <w:right  w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
      <w:insideH w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
      <w:insideV w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
    </w:tblBorders>
    <w:tblLook w:val="04A0"/>
  </w:tblPr>
  <w:tblGrid>
    <w:gridCol w:w="$col1"/>
    <w:gridCol w:w="$col2"/>
    <w:gridCol w:w="$col3"/>
    <w:gridCol w:w="$col4"/>
  </w:tblGrid>''';

    final String filaEncabezado = '''
  <w:tr>
    <w:trPr><w:trHeight w:val="560"/></w:trPr>
    ${_celdaEncabezado('CATEGORÍA', col1)}
    ${_celdaEncabezado('TRABAJOS DE INVESTIGACIÓN SOMETIDOS', col2)}
    ${_celdaEncabezado('TRABAJOS DE INVESTIGACIÓN ACEPTADOS', col3)}
    ${_celdaEncabezado('ESTUDIANTES ASISTENTES', col4)}
  </w:tr>''';

    final StringBuffer filasDatos = StringBuffer();
    int totalAceptados = 0;
    int totalAsistentes = 0;

    for (int i = 0; i < filas.length; i++) {
      final fila = filas[i];
      totalAceptados += fila.trabajosAceptados;
      totalAsistentes += fila.estudiantesAsistentes;

      final fill = (i % 2 == 0) ? 'FFFFFF' : 'EEF2F7';
      final catEsc = fila.categoria
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');

      filasDatos.write('''
  <w:tr>
    <w:trPr><w:trHeight w:val="400"/></w:trPr>
    ${_celdaDato(catEsc, col1, fill, centrado: false)}
    ${_celdaDato('', col2, fill)}
    ${_celdaDato(fila.trabajosAceptados.toString(), col3, fill)}
    ${_celdaDato(fila.estudiantesAsistentes.toString(), col4, fill)}
  </w:tr>''');
    }

    final String filaTotales = '''
  <w:tr>
    <w:trPr><w:trHeight w:val="440"/></w:trPr>
    ${_celdaTotal('TOTAL', col1)}
    ${_celdaTotal('', col2)}
    ${_celdaTotal(totalAceptados.toString(), col3)}
    ${_celdaTotal(totalAsistentes.toString(), col4)}
  </w:tr>''';

    return '$abrirTabla$filaEncabezado${filasDatos.toString()}$filaTotales\n</w:tbl>';
  }

  // ─── XML: TABLA DE GANADORES (5 columnas, top 2 por categoría) ───────────

  static String _buildTablaGanadores(
      String nombreEvento, List<_FilaGanador> filas) {
    const int colCat  = 1440;
    const int colCod  = 900;
    const int colInv  = 2880;
    const int colInt  = 3240;
    const int colProm = 900;
    const int totalAncho = colCat + colCod + colInv + colInt + colProm;

    final String tituloEsc = nombreEvento
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .toUpperCase();

    final StringBuffer sb = StringBuffer();

    sb.write('''
<w:tbl>
  <w:tblPr>
    <w:tblStyle w:val="TableGrid"/>
    <w:tblW w:w="$totalAncho" w:type="dxa"/>
    <w:tblBorders>
      <w:top    w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
      <w:left   w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
      <w:bottom w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
      <w:right  w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
      <w:insideH w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
      <w:insideV w:val="single" w:sz="4" w:space="0" w:color="1E3A5F"/>
    </w:tblBorders>
    <w:tblLook w:val="04A0"/>
  </w:tblPr>
  <w:tblGrid>
    <w:gridCol w:w="$colCat"/>
    <w:gridCol w:w="$colCod"/>
    <w:gridCol w:w="$colInv"/>
    <w:gridCol w:w="$colInt"/>
    <w:gridCol w:w="$colProm"/>
  </w:tblGrid>''');

    sb.write('''
  <w:tr>
    <w:trPr><w:trHeight w:val="480"/></w:trPr>
    <w:tc>
      <w:tcPr>
        <w:tcW w:w="$totalAncho" w:type="dxa"/>
        <w:gridSpan w:val="5"/>
        <w:shd w:val="clear" w:color="auto" w:fill="1E3A5F"/>
      </w:tcPr>
      <w:p>
        <w:pPr><w:jc w:val="center"/></w:pPr>
        <w:r>
          <w:rPr><w:b/><w:color w:val="FFFFFF"/><w:sz w:val="20"/></w:rPr>
          <w:t xml:space="preserve">GANADORES $tituloEsc</w:t>
        </w:r>
      </w:p>
    </w:tc>
  </w:tr>''');

    sb.write('''
  <w:tr>
    <w:trPr><w:trHeight w:val="560"/></w:trPr>
    ${_celdaEncabezado('CATEGORÍA',     colCat)}
    ${_celdaEncabezado('CÓDIGO',        colCod)}
    ${_celdaEncabezado('INVESTIGACIÓN', colInv)}
    ${_celdaEncabezado('INTEGRANTES',   colInt)}
    ${_celdaEncabezado('PROMEDIO',      colProm)}
  </w:tr>''');

    final Map<String, List<_FilaGanador>> porCategoria = {};
    for (final f in filas) {
      porCategoria.putIfAbsent(f.categoria, () => []).add(f);
    }

    int globalIdx = 0;

    porCategoria.forEach((categoria, lista) {
      final catEsc = categoria
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');

      for (int i = 0; i < lista.length; i++) {
        final f = lista[i];
        final fill = (globalIdx % 2 == 0) ? 'FFFFFF' : 'EEF2F7';

        final codEsc = f.codigo
            .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
        final titEsc = f.titulo
            .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
        final intEsc = f.integrantes
            .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
        final promStr = f.promedio.toStringAsFixed(2);

        final String celdaCat = (i == 0)
            ? '''
    <w:tc>
      <w:tcPr>
        <w:tcW w:w="$colCat" w:type="dxa"/>
        <w:vMerge w:val="restart"/>
        <w:shd w:val="clear" w:color="auto" w:fill="1E3A5F"/>
        <w:vAlign w:val="center"/>
      </w:tcPr>
      <w:p>
        <w:pPr><w:jc w:val="center"/></w:pPr>
        <w:r>
          <w:rPr><w:b/><w:color w:val="FFFFFF"/><w:sz w:val="18"/></w:rPr>
          <w:t xml:space="preserve">$catEsc</w:t>
        </w:r>
      </w:p>
    </w:tc>'''
            : '''
    <w:tc>
      <w:tcPr>
        <w:tcW w:w="$colCat" w:type="dxa"/>
        <w:vMerge/>
        <w:shd w:val="clear" w:color="auto" w:fill="1E3A5F"/>
      </w:tcPr>
      <w:p><w:r><w:t/></w:r></w:p>
    </w:tc>''';

        sb.write('''
  <w:tr>
    <w:trPr><w:trHeight w:val="440"/></w:trPr>
    $celdaCat
    ${_celdaDato(codEsc, colCod, fill)}
    ${_celdaDato(titEsc, colInv, fill, centrado: false)}
    ${_celdaDato(intEsc, colInt, fill, centrado: false)}
    ${_celdaDato(promStr, colProm, fill)}
  </w:tr>''');

        globalIdx++;
      }
    });

    sb.write('\n</w:tbl>');
    return sb.toString();
  }

  // ── Helpers celdas XML ────────────────────────────────────────────────────

  static String _celdaEncabezado(String texto, int ancho) {
    final t = texto
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return '''
    <w:tc>
      <w:tcPr>
        <w:tcW w:w="$ancho" w:type="dxa"/>
        <w:shd w:val="clear" w:color="auto" w:fill="1E3A5F"/>
      </w:tcPr>
      <w:p>
        <w:pPr><w:jc w:val="center"/></w:pPr>
        <w:r>
          <w:rPr><w:b/><w:color w:val="FFFFFF"/><w:sz w:val="18"/></w:rPr>
          <w:t xml:space="preserve">$t</w:t>
        </w:r>
      </w:p>
    </w:tc>''';
  }

  static String _celdaDato(String texto, int ancho, String fill,
      {bool centrado = true}) {
    final t = texto
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    final jc = centrado ? 'center' : 'left';
    return '''
    <w:tc>
      <w:tcPr>
        <w:tcW w:w="$ancho" w:type="dxa"/>
        <w:shd w:val="clear" w:color="auto" w:fill="$fill"/>
      </w:tcPr>
      <w:p>
        <w:pPr><w:jc w:val="$jc"/></w:pPr>
        <w:r>
          <w:rPr><w:sz w:val="20"/></w:rPr>
          <w:t xml:space="preserve"> $t</w:t>
        </w:r>
      </w:p>
    </w:tc>''';
  }

  static String _celdaTotal(String texto, int ancho) {
    final t = texto
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return '''
    <w:tc>
      <w:tcPr>
        <w:tcW w:w="$ancho" w:type="dxa"/>
        <w:shd w:val="clear" w:color="auto" w:fill="D6E4F0"/>
      </w:tcPr>
      <w:p>
        <w:pPr><w:jc w:val="center"/></w:pPr>
        <w:r>
          <w:rPr><w:b/><w:color w:val="1E3A5F"/><w:sz w:val="20"/></w:rPr>
          <w:t xml:space="preserve"> $t</w:t>
        </w:r>
      </w:p>
    </w:tc>''';
  }

  // ─── OBTENER BYTES DEL DOCX MODIFICADO ───────────────────────────────────

  static Future<Uint8List> _obtenerBytes({
    required Map<String, dynamic> evento,
    required Map<String, dynamic> adminData,
  }) async {
    final String facultadRaw  = adminData['facultad']     as String? ?? '';
    final String carrera      = adminData['carrera']      as String? ?? '';
    final String filialRaw    = adminData['filialNombre'] as String? ?? '';
    final String nombreEvento = evento['name']            as String? ?? '';
    final String eventId      = evento['id']              as String? ?? '';

    final List<String> categorias       = await _obtenerCategorias(eventId);
    final List<_FilaResultado> filasResultado =
        await _obtenerFilasResultado(eventId);
    final List<_FilaGanador> filasGanadores =
        await _obtenerGanadores(eventId);

    final DateTime hoy = DateTime.now();
    final String anio = hoy.year.toString();
    final List<String> meses = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final String fechaEvento = '${hoy.day} de ${meses[hoy.month]}';

    final String facultadCorta = facultadRaw
        .replaceAll(RegExp(r'^facultad\s+de\s+', caseSensitive: false), '')
        .trim();
    final String facultadMayus  = 'FACULTAD DE ${facultadCorta.toUpperCase()}';
    final String facultadTitulo = 'Facultad de $facultadCorta';

    final String filialCorta = filialRaw
        .replaceAll(
            RegExp(r'^UPeU\s*[–-]\s*Campus\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'^Campus\s+', caseSensitive: false), '')
        .trim();
    final String filialCampus     = 'Campus $filialCorta';
    final String filialConPrefijo = 'UPeU – Campus $filialCorta';

    final List<MapEntry<String, String>> reemplazos = [
      MapEntry('FACULTAD DE INGENIERÍA Y ARQUITECTURA', facultadMayus),
      MapEntry('Escuela Profesional de Ingeniería de Sistemas',
          'Escuela Profesional de $carrera'),
      MapEntry('PLAN COLOQUIOS Y JORNADAS DE INVESTIGACIÓN 2025', nombreEvento),
      MapEntry('EP. Ingeniería de Sistemas', 'EP. $carrera'),
      MapEntry('UPeU – Campus Juliaca', filialConPrefijo),
      MapEntry(
          '"XXII Jornada Científica de Investigación e Innovación de Ingeniería de Sistemas"',
          '"$nombreEvento"'),
      MapEntry(
          'XXII Jornada Científica de Investigación e Innovación de Ingeniería de Sistemas',
          nombreEvento),
      MapEntry('Facultad de Ingeniería y Arquitectura', facultadTitulo),
      MapEntry('Ingeniería de Sistemas', carrera),
      MapEntry('Campus Juliaca', filialCampus),
      MapEntry('19 de noviembre', fechaEvento),
      MapEntry('2025', anio),
    ];

    final ByteData templateData =
        await rootBundle.load('assets/plantilla_informe.docx');
    final Uint8List templateBytes = templateData.buffer.asUint8List();

    final Archive archive = ZipDecoder().decodeBytes(templateBytes);
    final Archive archivoModificado = Archive();

    for (final ArchiveFile file in archive) {
      if (!file.isFile) continue;

      final String nombre = file.name;
      final bool esXml = nombre.endsWith('.xml');

      if (esXml) {
        String contenido = utf8.decode(file.content as List<int>);

        contenido = _fusionarRunsFragmentados(contenido);

        for (final entry in reemplazos) {
          if (entry.key.isNotEmpty && entry.value.isNotEmpty) {
            contenido = contenido.replaceAll(entry.key, entry.value);
          }
        }

        if (nombre == 'word/document.xml') {
          if (categorias.isNotEmpty) {
            contenido = _reemplazarTablaCategorias(contenido, categorias);
          }
          contenido = _reemplazarTablaResultadosYGanadores(
              contenido, filasResultado, nombreEvento, filasGanadores);

          // ── FIX 2: Insertar salto de página antes de "INTRODUCCIÓN" ──────
          contenido = _insertarSaltoAntesDeIntroduccion(contenido);
        }

        final List<int> newBytes = utf8.encode(contenido);
        archivoModificado.addFile(
            ArchiveFile(nombre, newBytes.length, newBytes));
      } else {
        archivoModificado.addFile(file);
      }
    }

    return Uint8List.fromList(ZipEncoder().encode(archivoModificado)!);
  }

  // ─── FIX 2: SALTO DE PÁGINA ANTES DE INTRODUCCIÓN ────────────────────────
  //
  // Busca el primer párrafo que contenga "INTRODUCCIÓN" o "INTRODUCCION"
  // y le antepone un párrafo de salto de página explícito, de modo que
  // el punto 1 quede siempre en la segunda hoja.

  static String _insertarSaltoAntesDeIntroduccion(String xml) {
    final RegExp introRe = RegExp(
      r'(<w:p\b(?:(?!<w:p\b).)*?INTRODUCCI[ÓO]N(?:(?!</w:p>).)*?</w:p>)',
      dotAll: true,
    );
    const String pageBreak =
        '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';
    bool insertado = false;
    return xml.replaceFirstMapped(introRe, (m) {
      if (insertado) return m.group(0)!;
      insertado = true;
      return '$pageBreak${m.group(0)!}';
    });
  }

  // ─── REEMPLAZAR TABLA DE CATEGORÍAS EN EL XML (punto 4) ──────────────────

  static String _reemplazarTablaCategorias(
      String xml, List<String> categorias) {
    final RegExp tablaRe = RegExp(r'<w:tbl\b.*?</w:tbl>', dotAll: true);
    bool reemplazado = false;
    return xml.replaceAllMapped(tablaRe, (match) {
      if (reemplazado) return match.group(0)!;
      final tablaXml = match.group(0)!;
      if ((tablaXml.contains('CATEGORÍA') ||
              tablaXml.contains('CATEGORIA')) &&
          !tablaXml.contains('SOMETIDOS') &&
          !tablaXml.contains('ACEPTADOS') &&
          !tablaXml.contains('ASISTENTES')) {
        reemplazado = true;
        return _buildTablaCategorias(categorias);
      }
      return tablaXml;
    });
  }

  // ─── REEMPLAZAR TABLA DE RESULTADOS + GANADORES EN EL XML (punto 5) ──────
  //
  // FIX 1: Después de reemplazar cada tabla, se salta el párrafo "pie"
  // que ya existía en la plantilla (detectado por contener "Tabla 0"),
  // evitando así que aparezca duplicado junto al pie que genera el código.

  static String _reemplazarTablaResultadosYGanadores(
    String xml,
    List<_FilaResultado> filasResultado,
    String nombreEvento,
    List<_FilaGanador> filasGanadores,
  ) {
    final RegExp tablaRe = RegExp(r'<w:tbl\b.*?</w:tbl>', dotAll: true);
    final RegExp parrafoRe = RegExp(r'<w:p\b.*?</w:p>', dotAll: true);

    final List<Match> matches = tablaRe.allMatches(xml).toList();

    int idxResultados = -1;
    int idxGanadores  = -1;
    int idxDuplicada  = -1;

    for (int i = 0; i < matches.length; i++) {
      final t = matches[i].group(0)!;
      if (idxResultados == -1 &&
          (t.contains('SOMETIDOS') ||
              t.contains('ACEPTADOS') ||
              t.contains('ASISTENTES'))) {
        idxResultados = i;
      } else if (idxGanadores == -1 && t.contains('GANADORES')) {
        idxGanadores = i;
      } else if (idxDuplicada == -1 &&
          idxResultados != -1 &&
          (t.contains('CATEGORÍA') || t.contains('CATEGORIA')) &&
          !t.contains('SOMETIDOS') &&
          !t.contains('ACEPTADOS') &&
          !t.contains('GANADORES')) {
        idxDuplicada = i;
      }
    }

    if (idxResultados == -1) return xml;

    final StringBuffer sb = StringBuffer();
    int cursor = 0;

    for (int i = 0; i < matches.length; i++) {
      final m = matches[i];

      if (i == idxResultados) {
        // ── Texto previo + tabla de resultados actualizada ──────────────────
        sb.write(xml.substring(cursor, m.start));
        sb.write(_buildTablaResultados(filasResultado));
        cursor = m.end;

        // FIX 1: saltar el pie antiguo de la plantilla si existe
        final afterResultados = xml.substring(cursor);
        final pieMatch = parrafoRe.firstMatch(afterResultados);
        if (pieMatch != null && pieMatch.group(0)!.contains('Tabla 0')) {
          cursor += pieMatch.end;
        }

        // Insertar pie nuevo
        sb.write('\n');
        sb.write(_buildPieTabla('Tabla 02. Resumen de trabajos sometidos'));

      } else if (i == idxDuplicada) {
        // ── Eliminar tabla duplicada de categorías ──────────────────────────
        sb.write(xml.substring(cursor, m.start));
        cursor = m.end;

      } else if (i == idxGanadores) {
        // ── Tabla de ganadores actualizada ──────────────────────────────────
        sb.write(xml.substring(cursor, m.start));
        if (filasGanadores.isNotEmpty) {
          sb.write(_buildTablaGanadores(nombreEvento, filasGanadores));
        } else {
          sb.write(m.group(0)!);
        }
        cursor = m.end;

        // FIX 1: saltar el pie antiguo de la plantilla si existe
        final afterGanadores = xml.substring(cursor);
        final pieMatchG = parrafoRe.firstMatch(afterGanadores);
        if (pieMatchG != null && pieMatchG.group(0)!.contains('Tabla 0')) {
          cursor += pieMatchG.end;
        }

        // Insertar pie nuevo
        sb.write('\n');
        sb.write(_buildPieTabla('Tabla 03. Resumen de ganadores de la Jornada'));
      }
    }

    sb.write(xml.substring(cursor));
    return sb.toString();
  }

  // ─── FUSIONAR RUNS FRAGMENTADOS ──────────────────────────────────────────

  static String _fusionarRunsFragmentados(String xml) {
    final StringBuffer resultado = StringBuffer();
    int pos = 0;
    final RegExp parrafoRe = RegExp(r'<w:p[ >].*?</w:p>', dotAll: true);
    for (final Match m in parrafoRe.allMatches(xml)) {
      resultado.write(xml.substring(pos, m.start));
      pos = m.end;
      resultado.write(_fusionarRunsEnParrafo(m.group(0)!));
    }
    resultado.write(xml.substring(pos));
    return resultado.toString();
  }

  static String _fusionarRunsEnParrafo(String parrafo) {
    final RegExp runRe = RegExp(
      r'(<w:r(?:\s[^>]*)?>)((?:<w:rPr>.*?</w:rPr>)?)(.*?)(</w:r>)',
      dotAll: true,
    );

    final List<_Run> runs = [];
    final List<int> runStarts = [];
    final List<int> runEnds = [];

    for (final Match m in runRe.allMatches(parrafo)) {
      runStarts.add(m.start);
      runEnds.add(m.end);
      runs.add(_Run(
        apertura: m.group(1)!,
        rPr: m.group(2)!,
        contenido: m.group(3)!,
        cierre: m.group(4)!,
      ));
    }

    if (runs.isEmpty) return parrafo;

    final StringBuffer sb = StringBuffer();
    int posParrafo = 0;
    int i = 0;

    while (i < runs.length) {
      sb.write(parrafo.substring(posParrafo, runStarts[i]));
      final _Run runBase = runs[i];
      final StringBuffer textoFusionado = StringBuffer();
      textoFusionado.write(_extraerTextoDeRun(runBase.contenido));

      int j = i + 1;
      while (j < runs.length &&
          runEnds[j - 1] == runStarts[j] &&
          runs[j].rPr == runBase.rPr) {
        textoFusionado.write(_extraerTextoDeRun(runs[j].contenido));
        j++;
      }

      if (j > i + 1) {
        final String texto = textoFusionado.toString();
        final String espacio =
            (texto.startsWith(' ') || texto.endsWith(' '))
                ? ' xml:space="preserve"'
                : '';
        sb.write(runBase.apertura);
        sb.write(runBase.rPr);
        sb.write('<w:t$espacio>$texto</w:t>');
        sb.write(runBase.cierre);
        posParrafo = runEnds[j - 1];
        i = j;
      } else {
        sb.write(parrafo.substring(runStarts[i], runEnds[i]));
        posParrafo = runEnds[i];
        i++;
      }
    }

    sb.write(parrafo.substring(posParrafo));
    return sb.toString();
  }

  static String _extraerTextoDeRun(String contenidoRun) {
    final RegExp wtRe = RegExp(r'<w:t(?:[^>]*)>(.*?)</w:t>', dotAll: true);
    final StringBuffer sb = StringBuffer();
    for (final Match m in wtRe.allMatches(contenidoRun)) {
      sb.write(m.group(1));
    }
    return sb.toString();
  }
}

// ─── MODELOS INTERNOS ─────────────────────────────────────────────────────────

class _FilaResultado {
  final String categoria;
  final int trabajosAceptados;
  final int estudiantesAsistentes;

  const _FilaResultado({
    required this.categoria,
    required this.trabajosAceptados,
    required this.estudiantesAsistentes,
  });
}

class _FilaGanador {
  final String categoria;
  final String codigo;
  final String titulo;
  final String integrantes;
  final double promedio;

  const _FilaGanador({
    required this.categoria,
    required this.codigo,
    required this.titulo,
    required this.integrantes,
    required this.promedio,
  });
}

class _Run {
  final String apertura;
  final String rPr;
  final String contenido;
  final String cierre;

  const _Run({
    required this.apertura,
    required this.rPr,
    required this.contenido,
    required this.cierre,
  });
}