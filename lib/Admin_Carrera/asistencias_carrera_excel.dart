import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class AsistenciasCarreraExcelService {

  // ── Paleta de colores ────────────────────────────────────────────────────────
  static const _navy        = '#0F2044';
  static const _blue        = '#2563EB';
  static const _blueSoft    = '#DBEAFE';
  static const _white       = '#FFFFFF';
  static const _gray900     = '#111827';
  static const _gray700     = '#374151';
  static const _gray100     = '#F3F4F6';
  static const _greenDark   = '#166534';
  static const _greenLight  = '#DCFCE7';
  static const _yellowDark  = '#854D0E';
  static const _yellowLight = '#FEF9C3';
  static const _redDark     = '#991B1B';
  static const _redLight    = '#FEE2E2';
  static const _purpleDark  = '#5B21B6';
  static const _purpleLight = '#EDE9FE';
  static const _orange      = '#EA580C';
  static const _orangeLight = '#FFF7ED';
  // ── Punto de entrada principal ───────────────────────────────────────────────
  Future<String?> generarReporteAsistencias({
    required List<Map<String, dynamic>> estudiantes,
    required String eventoNombre,
    required String eventoId,
    required String filialId,
    required String filialNombre,
    required String facultad,
    String? carreraId,
    String? carrera,
  }) async {
    try {
      final excel = Excel.createExcel();

      // ── 1. Deduplicar y ordenar estudiantes ──────────────────────────────────
      final Map<String, Map<String, dynamic>> vistos = {};

      for (final e in estudiantes) {
        final key = _idEstudiante(e);
        if (!vistos.containsKey(key)) {
          vistos[key] = Map<String, dynamic>.from(e);
          vistos[key]!['scans'] = List<Map<String, dynamic>>.from(
            (e['scans'] as List<dynamic>? ?? [])
                .map((s) => Map<String, dynamic>.from(s as Map)),
          );
          vistos[key]!['personales'] = List<Map<String, dynamic>>.from(
            (e['personales'] as List<dynamic>? ?? [])
                .map((s) => Map<String, dynamic>.from(s as Map)),
          );
        } else {
          // Mergear scans de proyectos
          final scansPrevios =
              vistos[key]!['scans'] as List<Map<String, dynamic>>;
          final scansNuevos =
              (e['scans'] as List<dynamic>? ?? [])
                  .map((s) => Map<String, dynamic>.from(s as Map))
                  .toList();
          final idsExistentes = scansPrevios.map((s) => s['id']).toSet();
          for (final scan in scansNuevos) {
            if (!idsExistentes.contains(scan['id'])) {
              scansPrevios.add(scan);
            }
          }

          // Mergear personales
          final personalesPrev =
              vistos[key]!['personales'] as List<Map<String, dynamic>>;
          final personalesNuevos =
              (e['personales'] as List<dynamic>? ?? [])
                  .map((s) => Map<String, dynamic>.from(s as Map))
                  .toList();
          final idsPersPrev = personalesPrev.map((s) => s['id']).toSet();
          for (final p in personalesNuevos) {
            if (!idsPersPrev.contains(p['id'])) {
              personalesPrev.add(p);
            }
          }

          final totalScans =
              scansPrevios.length + personalesPrev.length;
          vistos[key]!['totalScans'] = totalScans;

          // lastScan: el más reciente de los dos
          final lastA = vistos[key]!['lastScan'];
          final lastB = e['lastScan'];
          if (lastA == null) {
            vistos[key]!['lastScan'] = lastB;
          } else if (lastB != null &&
              (lastB as dynamic).compareTo(lastA) > 0) {
            vistos[key]!['lastScan'] = lastB;
          }
        }
      }

      // Recalcular totalScans después del merge
      for (final e in vistos.values) {
        final scans = (e['scans'] as List<dynamic>?) ?? [];
        final pers = (e['personales'] as List<dynamic>?) ?? [];
        e['totalScans'] = scans.length + pers.length;
      }

      final estudiantesLimpios = vistos.values.toList()
        ..sort((a, b) {
          final ca = _parseCiclo(a['ciclo']);
          final cb = _parseCiclo(b['ciclo']);
          if (ca != cb) return ca.compareTo(cb);
          final ga = _parseGrupo(a['grupo']);
          final gb = _parseGrupo(b['grupo']);
          if (ga != gb) return ga.compareTo(gb);
          return ((a['nombre'] as String?) ?? '')
              .compareTo((b['nombre'] as String?) ?? '');
        });

      debugPrint(
          '✅ Estudiantes únicos para Excel: ${estudiantesLimpios.length}');

      // ── 2. Consultar meta de sellos desde Firestore ──────────────────────────
      int metaSellos = 0;
      try {
        final docId =
            '${filialId}_${facultad}_${carreraId ?? ''}_$eventoId'
                .replaceAll(' ', '_')
                .replaceAll('/', '_')
                .replaceAll('.', '_');
        final configDoc = await FirebaseFirestore.instance
            .collection('sellos_asistencia')
            .doc(docId)
            .get();
        if (configDoc.exists) {
          final m = configDoc.data()!['meta'];
          if (m is int && m > 0) {
            metaSellos = m;
          } else if (m is double && m > 0) {
            metaSellos = m.toInt();
          }
        }
      } catch (e) {
        debugPrint('⚠️ No se pudo leer meta de sellos: $e');
      }

      // ── 3. Construir todas las filas de detalle (para hojas 2–5) ────────────
      //   Cada fila = un scan o una asistencia personal individual
      final List<Map<String, dynamic>> todasLasFilas = [];
      for (final est in estudiantesLimpios) {
        final nombre = (est['nombre'] as String?) ?? '';
        final codigo = (est['codigo'] as String?) ?? '';
        final ciclo  = (est['ciclo'] as String?) ?? 'N/A';
        final grupo  = (est['grupo'] as String?) ?? 'N/A';

        for (final scan
            in (est['scans'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>()) {
          todasLasFilas.add({
            'nombre':     nombre,
            'codigo':     codigo,
            'ciclo':      ciclo,
            'grupo':      grupo,
            'tipo':       'Proyecto',
            'detalle':    scan['codigoProyecto']?.toString() ?? 'Sin código',
            'subtitulo':  scan['tituloProyecto']?.toString() ?? '',
            'categoria':  scan['categoria']?.toString() ?? '',
            'timestamp':  scan['timestamp'],
          });
        }

        for (final p
            in (est['personales'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>()) {
          todasLasFilas.add({
            'nombre':     nombre,
            'codigo':     codigo,
            'ciclo':      ciclo,
            'grupo':      grupo,
            'tipo':       'Personal',
            'detalle':    p['asistenciaNombre']?.toString() ?? 'Asistencia personal',
            'subtitulo':  p['asistenciaTipo']?.toString() ?? '',
            'categoria':  '',
            'timestamp':  p['timestamp'],
          });
        }
      }

      // Ordenar todas las filas por timestamp ascendente
      todasLasFilas.sort((a, b) {
        final tA = (a['timestamp'] as Timestamp?)?.toDate();
        final tB = (b['timestamp'] as Timestamp?)?.toDate();
        if (tA == null && tB == null) return 0;
        if (tA == null) return 1;
        if (tB == null) return -1;
        return tA.compareTo(tB);
      });

      // Separar por turno
      final filasTurnoManana = todasLasFilas.where((f) {
        final ts = (f['timestamp'] as Timestamp?)?.toDate();
        if (ts == null) return false;
        return ts.hour < 12;
      }).toList();

      final filasTarde = todasLasFilas.where((f) {
        final ts = (f['timestamp'] as Timestamp?)?.toDate();
        if (ts == null) return false;
        return ts.hour >= 12;
      }).toList();

      // ── 4. Crear hojas ───────────────────────────────────────────────────────
      _crearHojaListaCompleta(
        excel: excel,
        estudiantes: estudiantesLimpios,
        eventoNombre: eventoNombre,
        filialNombre: filialNombre,
        facultad: facultad,
        carrera: carrera,
        metaSellos: metaSellos,
      );

      _crearHojaDetalle(
        excel: excel,
        nombreHoja: 'Proyectos',
        filas: todasLasFilas
            .where((f) => f['tipo'] == 'Proyecto')
            .toList(),
        eventoNombre: eventoNombre,
        filialNombre: filialNombre,
        facultad: facultad,
        carrera: carrera,
        colorFondo: _blue,
        colorBadge: '#1D4ED8',
        icono: '📋',
        etiquetaTipo: 'PROYECTO',
      );

      _crearHojaDetalle(
        excel: excel,
        nombreHoja: 'Personales',
        filas: todasLasFilas
            .where((f) => f['tipo'] == 'Personal')
            .toList(),
        eventoNombre: eventoNombre,
        filialNombre: filialNombre,
        facultad: facultad,
        carrera: carrera,
        colorFondo: _purpleDark,
        colorBadge: '#4C1D95',
        icono: '👤',
        etiquetaTipo: 'PERSONAL',
      );

      _crearHojaTurno(
        excel: excel,
        nombreHoja: 'Turno Mañana',
        filas: filasTurnoManana,
        eventoNombre: eventoNombre,
        filialNombre: filialNombre,
        facultad: facultad,
        carrera: carrera,
        colorFondo: '#D97706',
        etiquetaTurno: 'TURNO MAÑANA (antes de 12:00)',
        icono: '🌅',
      );

      _crearHojaTurno(
        excel: excel,
        nombreHoja: 'Turno Tarde',
        filas: filasTarde,
        eventoNombre: eventoNombre,
        filialNombre: filialNombre,
        facultad: facultad,
        carrera: carrera,
        colorFondo: _orange,
        etiquetaTurno: 'TURNO TARDE (12:00 en adelante)',
        icono: '🌇',
      );

      excel.delete('Sheet1');

      // ── 5. Guardar archivo ───────────────────────────────────────────────────
      final bytes = excel.encode();
      if (bytes == null) return null;

      final dir = await getTemporaryDirectory();
      final fecha = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final nombreArchivo =
          'Asistencias_${_sanitizar(eventoNombre)}_$fecha.xlsx';
      final file = File('${dir.path}/$nombreArchivo');
      await file.writeAsBytes(bytes);

      return file.path;
    } catch (e) {
      debugPrint('❌ Error generando Excel: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOJA 1 — Lista Completa de Asistencias (resumen por estudiante)
  // ═══════════════════════════════════════════════════════════════════════════
  void _crearHojaListaCompleta({
    required Excel excel,
    required List<Map<String, dynamic>> estudiantes,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    String? carrera,
    required int metaSellos,
  }) {
    final sheet = excel['Lista de Asistencias'];

    // Estilos
    final sTitulo = CellStyle(
      bold: true, fontSize: 15,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sSubtitulo = CellStyle(
      bold: false, fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#93C5FD'),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sSeparador = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_blue),
    );
    final sMetaLabel = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray700),
      backgroundColorHex: ExcelColor.fromHexString(_gray100),
    );
    final sMetaValue = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray900),
    );
    final sEnc = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_blue),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final sEncSellos = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString('#D97706'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sEncAsist = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString('#059669'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sIzq  = CellStyle(fontSize: 9,
        fontColorHex: ExcelColor.fromHexString(_gray900));
    final sCen  = CellStyle(fontSize: 9,
        fontColorHex: ExcelColor.fromHexString(_gray900),
        horizontalAlign: HorizontalAlign.Center);
    final sIzqP = CellStyle(fontSize: 9,
        backgroundColorHex: ExcelColor.fromHexString(_blueSoft),
        fontColorHex: ExcelColor.fromHexString(_gray900));
    final sCenP = CellStyle(fontSize: 9,
        backgroundColorHex: ExcelColor.fromHexString(_blueSoft),
        fontColorHex: ExcelColor.fromHexString(_gray900),
        horizontalAlign: HorizontalAlign.Center);
    final sBadgeAlto = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_greenLight),
      fontColorHex: ExcelColor.fromHexString(_greenDark),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sBadgeMedio = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_yellowLight),
      fontColorHex: ExcelColor.fromHexString(_yellowDark),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sBadgeBajo = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_redLight),
      fontColorHex: ExcelColor.fromHexString(_redDark),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sBadgeSellosAlto = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_greenLight),
      fontColorHex: ExcelColor.fromHexString(_greenDark),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sBadgeSellosMedio = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_yellowLight),
      fontColorHex: ExcelColor.fromHexString(_yellowDark),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sBadgeSellosBajo = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_redLight),
      fontColorHex: ExcelColor.fromHexString(_redDark),
      horizontalAlign: HorizontalAlign.Center,
    );

    // ── Banner ────────────────────────────────────────────────────────────────
    const totalCols = 8; // N°, NOMBRE, CÓDIGO, CICLO, GRUPO, SELLOS, N°ASIST, ÚLTIMA
    _cel(sheet, 0, 0, '  LISTA DE ASISTENCIAS', sTitulo);
    _cel(sheet, 1, 0, '  ${eventoNombre.toUpperCase()}', sSubtitulo);
    for (int c = 0; c < totalCols; c++) {
      _cel(sheet, 2, c, '', sSeparador);
    }
    sheet.setRowHeight(2, 4);

    // ── Metadatos ─────────────────────────────────────────────────────────────
    final fechaGen = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final totalGlobal = estudiantes.fold<int>(
        0, (s, e) => s + ((e['totalScans'] as int?) ?? 0));
    final metas = [
      ['  FILIAL', filialNombre],
      ['  FACULTAD', facultad],
      ['  CARRERA', carrera ?? 'Todas'],
      ['  TOTAL ESTUDIANTES', '${estudiantes.length}'],
      ['  ASISTENCIAS REGISTRADAS', '$totalGlobal'],
      ['  META DE SELLOS', metaSellos > 0 ? '$metaSellos' : 'Sin configurar'],
      ['  GENERADO', fechaGen],
    ];
    for (int i = 0; i < metas.length; i++) {
      _cel(sheet, i + 3, 0, metas[i][0], sMetaLabel);
      _cel(sheet, i + 3, 1, '  ${metas[i][1]}', sMetaValue);
      _merge(sheet, i + 3, 1, i + 3, totalCols - 1);
      sheet.setRowHeight(i + 3, 16);
    }
    sheet.setRowHeight(10, 8);

    // ── Encabezados tabla (fila 11) ───────────────────────────────────────────
    const fEnc = 11;
    const encabezados = [
      'N°', 'NOMBRE COMPLETO', 'CÓDIGO',
      'CICLO', 'GRUPO', 'SELLOS', 'N° ASISTENCIAS', 'ÚLTIMA ASISTENCIA',
    ];
    for (int c = 0; c < encabezados.length; c++) {
      CellStyle estilo;
      if (c == 5) {
        estilo = sEncSellos;
      } else if (c == 6) {
        estilo = sEncAsist;
      } else {
        estilo = sEnc;
      }
      _cel(sheet, fEnc, c, encabezados[c], estilo);
    }
    sheet.setRowHeight(fEnc, 28);

    final maxScans = estudiantes.isEmpty
        ? 1
        : estudiantes
            .map((e) => (e['totalScans'] as int?) ?? 0)
            .reduce((a, b) => a > b ? a : b)
            .clamp(1, 99999);

    // ── Filas de datos ────────────────────────────────────────────────────────
    for (int i = 0; i < estudiantes.length; i++) {
      final e = estudiantes[i];
      final fila = fEnc + 1 + i;
      final par = i % 2 == 0;

      final sI = par ? sIzqP : sIzq;
      final sC = par ? sCenP : sCen;

      // ── Última asistencia: se calcula directamente desde los timestamps de
      //    scans y personales (misma fuente que las otras hojas), para que
      //    siempre muestre fecha y hora reales. ────────────────────────────────
      DateTime? ultimoTs;
      for (final scan
          in (e['scans'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>()) {
        final ts = (scan['timestamp'] as Timestamp?)?.toDate();
        if (ts != null && (ultimoTs == null || ts.isAfter(ultimoTs))) {
          ultimoTs = ts;
        }
      }
      for (final p
          in (e['personales'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>()) {
        final ts = (p['timestamp'] as Timestamp?)?.toDate();
        if (ts != null && (ultimoTs == null || ts.isAfter(ultimoTs))) {
          ultimoTs = ts;
        }
      }
      // Fallback a lastScan si no se encontró timestamp en los detalles.
      if (ultimoTs == null && e['lastScan'] != null) {
        try {
          ultimoTs = (e['lastScan'] as dynamic).toDate() as DateTime;
        } catch (_) {}
      }
      final ultimaAsistencia = ultimoTs != null
          ? DateFormat('dd/MM/yyyy HH:mm').format(ultimoTs)
          : '—';

      final totalScans = (e['totalScans'] as int?) ?? 0;
      final ratio = totalScans / maxScans;
      final sBadge = ratio >= 0.66
          ? sBadgeAlto
          : ratio >= 0.33
              ? sBadgeMedio
              : sBadgeBajo;

      // Columna SELLOS: "ganados/meta" o solo "ganados" si no hay meta
      String textoSellos;
      CellStyle estiloSellos;
      if (metaSellos > 0) {
        textoSellos = '$totalScans/$metaSellos';
        final ratioSellos = totalScans / metaSellos;
        estiloSellos = ratioSellos >= 0.66
            ? sBadgeSellosAlto
            : ratioSellos >= 0.33
                ? sBadgeSellosMedio
                : sBadgeSellosBajo;
      } else {
        textoSellos = '$totalScans';
        estiloSellos = sBadge;
      }

      _cel(sheet, fila, 0, '${i + 1}', sC);
      _cel(sheet, fila, 1, e['nombre'] ?? '', sI);
      _cel(sheet, fila, 2, e['codigo'] ?? '', sC);
      _cel(sheet, fila, 3, e['ciclo'] ?? 'N/A', sC);
      _cel(sheet, fila, 4, e['grupo'] ?? 'N/A', sC);
      _cel(sheet, fila, 5, textoSellos, estiloSellos);
      _celNum(sheet, fila, 6, totalScans, sBadge);
      _cel(sheet, fila, 7, ultimaAsistencia, sC);
      sheet.setRowHeight(fila, 18);
    }

    // ── Merges banner ─────────────────────────────────────────────────────────
    _merge(sheet, 0, 0, 0, totalCols - 1);
    _merge(sheet, 1, 0, 1, totalCols - 1);

    // ── Anchos de columna ─────────────────────────────────────────────────────
    sheet.setColumnWidth(0, 5);   // N°
    sheet.setColumnWidth(1, 34);  // Nombre
    sheet.setColumnWidth(2, 14);  // Código
    sheet.setColumnWidth(3, 8);   // Ciclo
    sheet.setColumnWidth(4, 10);  // Grupo
    sheet.setColumnWidth(5, 12);  // Sellos
    sheet.setColumnWidth(6, 15);  // N° Asistencias
    sheet.setColumnWidth(7, 22);  // Última asistencia

    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 22);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOJA 2 (Proyectos) y HOJA 3 (Personales) — detalle por asistencia
  // ═══════════════════════════════════════════════════════════════════════════
  void _crearHojaDetalle({
    required Excel excel,
    required String nombreHoja,
    required List<Map<String, dynamic>> filas,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    String? carrera,
    required String colorFondo,
    required String colorBadge,
    required String icono,
    required String etiquetaTipo,
  }) {
    // ── Ordenar por ciclo y grupo (numérico), igual que Lista de Asistencias ──
    _ordenarPorCicloGrupo(filas);

    final sheet = excel[nombreHoja];

    final sTitulo = CellStyle(
      bold: true, fontSize: 15,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sSubtitulo = CellStyle(
      bold: false, fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#93C5FD'),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sSep = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(colorFondo),
    );
    final sMetaLabel = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray700),
      backgroundColorHex: ExcelColor.fromHexString(_gray100),
    );
    final sMetaValue = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray900),
    );
    final sEnc = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(colorFondo),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );

    const totalCols = 8;

    // Banner
    _cel(sheet, 0, 0, '  $etiquetaTipo — $eventoNombre', sTitulo);
    _cel(sheet, 1, 0, '  Reporte de asistencias por $etiquetaTipo', sSubtitulo);
    for (int c = 0; c < totalCols; c++) {
      _cel(sheet, 2, c, '', sSep);
    }
    sheet.setRowHeight(2, 4);

    // Metadatos
    final fechaGen = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final metas = [
      ['  FILIAL', filialNombre],
      ['  FACULTAD', facultad],
      ['  CARRERA', carrera ?? 'Todas'],
      ['  TOTAL REGISTROS', '${filas.length}'],
      ['  GENERADO', fechaGen],
    ];
    for (int i = 0; i < metas.length; i++) {
      _cel(sheet, i + 3, 0, metas[i][0], sMetaLabel);
      _cel(sheet, i + 3, 1, '  ${metas[i][1]}', sMetaValue);
      _merge(sheet, i + 3, 1, i + 3, totalCols - 1);
      sheet.setRowHeight(i + 3, 16);
    }
    sheet.setRowHeight(8, 8);

    // Encabezados
    const fEnc = 9;
    final encabezados = [
      'N°', 'NOMBRE COMPLETO', 'CÓDIGO',
      'CICLO', 'GRUPO', 'DETALLE', 'CATEGORÍA / TIPO', 'FECHA Y HORA',
    ];
    for (int c = 0; c < encabezados.length; c++) {
      _cel(sheet, fEnc, c, encabezados[c], sEnc);
    }
    sheet.setRowHeight(fEnc, 28);

    final sIzq  = CellStyle(fontSize: 9,
        fontColorHex: ExcelColor.fromHexString(_gray900));
    final sCen  = CellStyle(fontSize: 9,
        fontColorHex: ExcelColor.fromHexString(_gray900),
        horizontalAlign: HorizontalAlign.Center);
    final sIzqP = CellStyle(fontSize: 9,
        backgroundColorHex: ExcelColor.fromHexString(_blueSoft),
        fontColorHex: ExcelColor.fromHexString(_gray900));
    final sCenP = CellStyle(fontSize: 9,
        backgroundColorHex: ExcelColor.fromHexString(_blueSoft),
        fontColorHex: ExcelColor.fromHexString(_gray900),
        horizontalAlign: HorizontalAlign.Center);

    // Filas de datos
    for (int i = 0; i < filas.length; i++) {
      final f = filas[i];
      final fila = fEnc + 1 + i;
      final par = i % 2 == 0;
      final sI = par ? sIzqP : sIzq;
      final sC = par ? sCenP : sCen;

      String fechaHora = '—';
      final ts = (f['timestamp'] as Timestamp?)?.toDate();
      if (ts != null) {
        fechaHora = DateFormat('dd/MM/yyyy HH:mm').format(ts);
      }

      final cat = (f['categoria'] as String?)?.isNotEmpty == true
          ? f['categoria']
          : (f['subtitulo'] as String?)?.isNotEmpty == true
              ? f['subtitulo']
              : '—';

      _cel(sheet, fila, 0, '${i + 1}', sC);
      _cel(sheet, fila, 1, f['nombre'] ?? '', sI);
      _cel(sheet, fila, 2, f['codigo'] ?? '', sC);
      _cel(sheet, fila, 3, f['ciclo'] ?? 'N/A', sC);
      _cel(sheet, fila, 4, f['grupo'] ?? 'N/A', sC);
      _cel(sheet, fila, 5, f['detalle'] ?? '', sI);
      _cel(sheet, fila, 6, cat.toString(), sI);
      _cel(sheet, fila, 7, fechaHora, sC);
      sheet.setRowHeight(fila, 18);
    }

    if (filas.isEmpty) {
      _cel(
        sheet,
        fEnc + 1,
        0,
        'Sin registros',
        CellStyle(
          fontSize: 11,
          italic: true,
          fontColorHex: ExcelColor.fromHexString(_gray700),
          horizontalAlign: HorizontalAlign.Center,
        ),
      );
      _merge(sheet, fEnc + 1, 0, fEnc + 1, totalCols - 1);
    }

    // Merges banner
    _merge(sheet, 0, 0, 0, totalCols - 1);
    _merge(sheet, 1, 0, 1, totalCols - 1);

    // Anchos
    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 34);
    sheet.setColumnWidth(2, 14);
    sheet.setColumnWidth(3, 8);
    sheet.setColumnWidth(4, 10);
    sheet.setColumnWidth(5, 24);
    sheet.setColumnWidth(6, 20);
    sheet.setColumnWidth(7, 20);

    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 22);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOJAS 4 y 5 — Turno Mañana / Turno Tarde (todas las asistencias por hora)
  // ═══════════════════════════════════════════════════════════════════════════
  void _crearHojaTurno({
    required Excel excel,
    required String nombreHoja,
    required List<Map<String, dynamic>> filas,
    required String eventoNombre,
    required String filialNombre,
    required String facultad,
    String? carrera,
    required String colorFondo,
    required String etiquetaTurno,
    required String icono,
  }) {
    // ── Ordenar por ciclo y grupo (numérico), igual que Lista de Asistencias ──
    _ordenarPorCicloGrupo(filas);

    final sheet = excel[nombreHoja];

    final sTitulo = CellStyle(
      bold: true, fontSize: 15,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sSubtitulo = CellStyle(
      bold: false, fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#FDE68A'),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sSep = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(colorFondo),
    );
    final sMetaLabel = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray700),
      backgroundColorHex: ExcelColor.fromHexString(_gray100),
    );
    final sMetaValue = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_gray900),
    );
    final sEnc = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(colorFondo),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final sEncTipo = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString(_navy),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final sEncHora = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString(_white),
      backgroundColorHex: ExcelColor.fromHexString('#059669'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    const totalCols = 9;

    // Banner
    _cel(sheet, 0, 0, '  $etiquetaTurno', sTitulo);
    _cel(sheet, 1, 0, '  $eventoNombre', sSubtitulo);
    for (int c = 0; c < totalCols; c++) {
      _cel(sheet, 2, c, '', sSep);
    }
    sheet.setRowHeight(2, 4);

    // Metadatos
    final fechaGen = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final metas = [
      ['  FILIAL', filialNombre],
      ['  FACULTAD', facultad],
      ['  CARRERA', carrera ?? 'Todas'],
      ['  TOTAL REGISTROS', '${filas.length}'],
      ['  GENERADO', fechaGen],
    ];
    for (int i = 0; i < metas.length; i++) {
      _cel(sheet, i + 3, 0, metas[i][0], sMetaLabel);
      _cel(sheet, i + 3, 1, '  ${metas[i][1]}', sMetaValue);
      _merge(sheet, i + 3, 1, i + 3, totalCols - 1);
      sheet.setRowHeight(i + 3, 16);
    }
    sheet.setRowHeight(8, 8);

    // Encabezados (fila 9)
    const fEnc = 9;
    const encabezados = [
      'N°', 'NOMBRE COMPLETO', 'CÓDIGO',
      'CICLO', 'GRUPO', 'TIPO', 'DETALLE', 'CATEGORÍA / TIPO', 'HORA',
    ];
    for (int c = 0; c < encabezados.length; c++) {
      CellStyle estilo;
      if (c == 5) {
        estilo = sEncTipo;
      } else if (c == 8) {
        estilo = sEncHora;
      } else {
        estilo = sEnc;
      }
      _cel(sheet, fEnc, c, encabezados[c], estilo);
    }
    sheet.setRowHeight(fEnc, 28);

    // Estilos fila de datos
    final sIzq  = CellStyle(fontSize: 9,
        fontColorHex: ExcelColor.fromHexString(_gray900));
    final sCen  = CellStyle(fontSize: 9,
        fontColorHex: ExcelColor.fromHexString(_gray900),
        horizontalAlign: HorizontalAlign.Center);
    final sIzqP = CellStyle(fontSize: 9,
        backgroundColorHex: ExcelColor.fromHexString(_orangeLight),
        fontColorHex: ExcelColor.fromHexString(_gray900));
    final sCenP = CellStyle(fontSize: 9,
        backgroundColorHex: ExcelColor.fromHexString(_orangeLight),
        fontColorHex: ExcelColor.fromHexString(_gray900),
        horizontalAlign: HorizontalAlign.Center);
    final sBadgeProy = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_blueSoft),
      fontColorHex: ExcelColor.fromHexString('#1E40AF'),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sBadgePers = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_purpleLight),
      fontColorHex: ExcelColor.fromHexString(_purpleDark),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sHora = CellStyle(
      bold: true, fontSize: 9,
      fontColorHex: ExcelColor.fromHexString('#059669'),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sHoraP = CellStyle(
      bold: true, fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString(_orangeLight),
      fontColorHex: ExcelColor.fromHexString('#059669'),
      horizontalAlign: HorizontalAlign.Center,
    );

    // Filas — ordenadas por ciclo y grupo (numérico)
    for (int i = 0; i < filas.length; i++) {
      final f = filas[i];
      final fila = fEnc + 1 + i;
      final par = i % 2 == 0;
      final sI = par ? sIzqP : sIzq;
      final sC = par ? sCenP : sCen;
      final sH = par ? sHoraP : sHora;

      final ts = (f['timestamp'] as Timestamp?)?.toDate();
      final soloHora = ts != null
          ? DateFormat('HH:mm').format(ts)
          : '—';

      final esProyecto = f['tipo'] == 'Proyecto';
      final sBadgeTipo = esProyecto ? sBadgeProy : sBadgePers;

      final cat = (f['categoria'] as String?)?.isNotEmpty == true
          ? f['categoria']
          : (f['subtitulo'] as String?)?.isNotEmpty == true
              ? f['subtitulo']
              : '—';

      _cel(sheet, fila, 0, '${i + 1}', sC);
      _cel(sheet, fila, 1, f['nombre'] ?? '', sI);
      _cel(sheet, fila, 2, f['codigo'] ?? '', sC);
      _cel(sheet, fila, 3, f['ciclo'] ?? 'N/A', sC);
      _cel(sheet, fila, 4, f['grupo'] ?? 'N/A', sC);
      _cel(sheet, fila, 5, esProyecto ? 'Proyecto' : 'Personal', sBadgeTipo);
      _cel(sheet, fila, 6, f['detalle'] ?? '', sI);
      _cel(sheet, fila, 7, cat.toString(), sI);
      _cel(sheet, fila, 8, soloHora, sH);
      sheet.setRowHeight(fila, 18);
    }

    if (filas.isEmpty) {
      _cel(
        sheet,
        fEnc + 1,
        0,
        'Sin registros en este turno',
        CellStyle(
          fontSize: 11,
          italic: true,
          fontColorHex: ExcelColor.fromHexString(_gray700),
          horizontalAlign: HorizontalAlign.Center,
        ),
      );
      _merge(sheet, fEnc + 1, 0, fEnc + 1, totalCols - 1);
    }

    // Merges banner
    _merge(sheet, 0, 0, 0, totalCols - 1);
    _merge(sheet, 1, 0, 1, totalCols - 1);

    // Anchos de columna
    sheet.setColumnWidth(0, 5);   // N°
    sheet.setColumnWidth(1, 34);  // Nombre
    sheet.setColumnWidth(2, 14);  // Código
    sheet.setColumnWidth(3, 8);   // Ciclo
    sheet.setColumnWidth(4, 10);  // Grupo
    sheet.setColumnWidth(5, 12);  // Tipo
    sheet.setColumnWidth(6, 24);  // Detalle
    sheet.setColumnWidth(7, 20);  // Categoría / Tipo
    sheet.setColumnWidth(8, 10);  // Hora

    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 22);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helpers internos
  // ═══════════════════════════════════════════════════════════════════════════

  /// Ordena una lista de filas de detalle por ciclo y grupo en orden numérico,
  /// y como criterio final por nombre. Misma lógica que la hoja
  /// "Lista de Asistencias".
  void _ordenarPorCicloGrupo(List<Map<String, dynamic>> filas) {
    filas.sort((a, b) {
      final ca = _parseCiclo(a['ciclo'] as String?);
      final cb = _parseCiclo(b['ciclo'] as String?);
      if (ca != cb) return ca.compareTo(cb);

      final ga = _parseGrupo(a['grupo'] as String?);
      final gb = _parseGrupo(b['grupo'] as String?);
      if (ga != gb) return ga.compareTo(gb);

      final na = (a['nombre'] as String?) ?? '';
      final nb = (b['nombre'] as String?) ?? '';
      return na.compareTo(nb);
    });
  }

  void _cel(Sheet sheet, int row, int col, String value, CellStyle style) {
    final cell = sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(value);
    cell.cellStyle = style;
  }

  void _celNum(Sheet sheet, int row, int col, int value, CellStyle style) {
    final cell = sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = IntCellValue(value);
    cell.cellStyle = style;
  }

  void _merge(Sheet sheet, int r1, int c1, int r2, int c2) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: c1, rowIndex: r1),
      CellIndex.indexByColumnRow(columnIndex: c2, rowIndex: r2),
    );
  }

  String _idEstudiante(Map<String, dynamic> e) {
    final codigo = (e['codigo'] as String?) ?? '';
    if (codigo.isNotEmpty) return codigo;
    final dni = (e['dni'] as String?) ?? '';
    if (dni.isNotEmpty) return dni;
    return (e['nombre'] as String?) ?? 'unknown';
  }

  int _parseCiclo(String? ciclo) {
    if (ciclo == null || ciclo.isEmpty || ciclo == 'N/A') return 999;
    try {
      final m = RegExp(r'\d+').firstMatch(ciclo);
      if (m != null) return int.parse(m.group(0)!);
    } catch (_) {}
    return 999;
  }

  int _parseGrupo(String? grupo) {
    if (grupo == null || grupo.isEmpty || grupo == 'N/A') return 9999;
    final g = grupo.toLowerCase();
    if (g.contains('único') || g.contains('unico')) return 9998;
    try {
      final m = RegExp(r'\d+').firstMatch(grupo);
      if (m != null) return int.parse(m.group(0)!);
    } catch (_) {}
    return 9999;
  }

  String _sanitizar(String texto) {
    final s = texto
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(' ', '_');
    return s.substring(0, s.length > 40 ? 40 : s.length);
  }
}