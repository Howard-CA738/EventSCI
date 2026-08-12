import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';


class NotaDocenteImportResult {
  final int gruposImportados;
  final int codigosTotales;
  final List<String> errores;

  const NotaDocenteImportResult({
    required this.gruposImportados,
    required this.codigosTotales,
    required this.errores,
  });
}

class NotaDocenteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;




  Future<Map<String, double>> obtenerNotasDocente(String eventId) async {
    try {
      final snap = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('notasDocentes')
          .get();

      final Map<String, double> resultado = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final nota = (data['notaDocente'] as num?)?.toDouble();
        if (nota != null) {
          resultado[doc.id] = nota;
        }
      }
      return resultado;
    } catch (e) {
      debugPrint('Error al obtener notas docente: $e');
      return {};
    }
  }


  Future<NotaDocenteImportResult?> importarDesdeExcel(
    String eventId, {
    String? filialNombre,
    String? filialId,
    String? carreraNombre,
    String? carreraId,
  }) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null) return null;

      final bytes = result.files.single.bytes ??
          (result.files.single.path != null
              ? await File(result.files.single.path!).readAsBytes()
              : null);

      if (bytes == null) return null;

      return await _procesarYGuardar(
        eventId,
        bytes,
        filialNombre: filialNombre,
        filialId: filialId,
        carreraNombre: carreraNombre,
        carreraId: carreraId,
      );
    } catch (e) {
      debugPrint('Error al importar notas docente: $e');
      rethrow;
    }
  }

  // Mismo patrón de rutas candidatas que importar_notas_docente.dart (SuperAdmin).
  Future<Set<String>> _cargarCodigosRoster({
    required String? filialNombre,
    required String? filialId,
    required String? carreraNombre,
    required String? carreraId,
  }) async {
    final candidatos = <String>{
      if (filialNombre != null && carreraNombre != null)
        '${filialNombre}_$carreraNombre',
      if (filialNombre != null && carreraId != null)
        '${filialNombre}_$carreraId',
      if (filialId != null && carreraNombre != null)
        '${filialId}_$carreraNombre',
      if (filialId != null && carreraId != null) '${filialId}_$carreraId',
    };

    final Set<String> codigos = {};
    for (final path in candidatos) {
      final snap = await _firestore
          .collection('users')
          .doc(path)
          .collection('students')
          .get();
      if (snap.docs.isNotEmpty) {
        for (final d in snap.docs) {
          final cod =
              (d.data()['codigoUniversitario'] ?? '').toString().trim();
          if (cod.isNotEmpty) codigos.add(cod);
        }
        break;
      }
    }
    return codigos;
  }

  Future<NotaDocenteImportResult> _procesarYGuardar(
    String eventId,
    Uint8List bytes, {
    String? filialNombre,
    String? filialId,
    String? carreraNombre,
    String? carreraId,
  }) async {
    final excel = Excel.decodeBytes(bytes);
    final errores = <String>[];

    // Igual que importar_notas_docente.dart (SuperAdmin): si no hay contexto
    // de carrera, el roster queda vacío y no se filtra por existencia.
    final roster = await _cargarCodigosRoster(
      filialNombre: filialNombre,
      filialId: filialId,
      carreraNombre: carreraNombre,
      carreraId: carreraId,
    );

    final Map<String, double> notas = {};

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName];
      if (sheet == null || sheet.maxRows < 2) continue;


      final headers = sheet.rows.first
          .map((c) => c?.value?.toString().trim().toUpperCase() ?? '')
          .toList();

      final idxCodigo = _findCol(
          headers, ['CÓDIGO ESTUDIANTE', 'CODIGO ESTUDIANTE', 'CÓDIGO', 'CODIGO']);
      final idxNota = _findCol(
          headers, ['NOTA DOCENTE', 'NOTA', 'NOTADOCENTE']);

      if (idxCodigo == -1 || idxNota == -1) {
        errores.add(
            'Hoja "$sheetName": no se encontraron columnas esperadas. '
            'Headers encontrados: $headers');
        continue;
      }





      double? ultimaNota;

      for (int i = 1; i < sheet.maxRows; i++) {
        final row = sheet.rows[i];

        final codigoRaw = _cell(row, idxCodigo);
        if (codigoRaw.isEmpty) continue;

        if (roster.isNotEmpty && !roster.contains(codigoRaw)) {
          errores.add(
              'Fila ${i + 1}: código "$codigoRaw" no pertenece a esta carrera — fila omitida');
          continue;
        }

        final notaRaw = _cell(row, idxNota);

        if (notaRaw.isNotEmpty) {
          final parsed = double.tryParse(notaRaw);
          if (parsed == null) {
            errores.add('Fila ${i + 1}: nota "$notaRaw" no es un número');
            ultimaNota = null;
          } else if (parsed < 0 || parsed > 20) {
            errores.add(
                'Fila ${i + 1}: nota $parsed fuera de rango 0–20 para código $codigoRaw — fila omitida');
            ultimaNota = null;
          } else {
            ultimaNota = parsed;
          }
        }


        if (ultimaNota != null) {
          notas[codigoRaw] = ultimaNota;
        }
      }
    }

    if (notas.isEmpty) {
      return NotaDocenteImportResult(
        gruposImportados: 0,
        codigosTotales: 0,
        errores: [...errores, 'No se encontraron notas válidas en el archivo'],
      );
    }


    final entries = notas.entries.toList();
    for (int i = 0; i < entries.length; i += 500) {
      final batch = _firestore.batch();
      final lote = entries.skip(i).take(500);
      for (final e in lote) {
        final ref = _firestore
            .collection('events')
            .doc(eventId)
            .collection('notasDocentes')
            .doc(e.key);
        batch.set(ref, {
          'notaDocente': e.value,
          'actualizadoEn': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }



    // gruposImportados refleja exactamente lo guardado (antes se calculaba
    // dos veces: una con notasUnicas.length, descartada, y otra re-escaneando
    // el Excel sin aplicar rango/roster — quedaba desalineada con lo real).
    debugPrint('✅ Notas docente guardadas: ${notas.length} códigos');

    return NotaDocenteImportResult(
      gruposImportados: notas.length,
      codigosTotales: notas.length,
      errores: errores,
    );
  }


  Future<void> eliminarNotasDocente(String eventId) async {
    final snap = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('notasDocentes')
        .get();

    for (int i = 0; i < snap.docs.length; i += 500) {
      final batch = _firestore.batch();
      for (final doc in snap.docs.skip(i).take(500)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }


  int _findCol(List<String> headers, List<String> candidates) {
    for (int i = 0; i < headers.length; i++) {
      for (final c in candidates) {
        if (headers[i] == c.toUpperCase().trim()) return i;
      }
    }
    return -1;
  }

  String _cell(List<Data?> row, int idx) {
    if (idx < 0 || idx >= row.length) return '';
    return row[idx]?.value?.toString().trim() ?? '';
  }
}