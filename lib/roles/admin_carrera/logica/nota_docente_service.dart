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


  Future<NotaDocenteImportResult?> importarDesdeExcel(String eventId) async {
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

      return await _procesarYGuardar(eventId, bytes);
    } catch (e) {
      debugPrint('Error al importar notas docente: $e');
      rethrow;
    }
  }


  Future<NotaDocenteImportResult> _procesarYGuardar(
    String eventId,
    Uint8List bytes,
  ) async {
    final excel = Excel.decodeBytes(bytes);
    final errores = <String>[];


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

        final notaRaw = _cell(row, idxNota);

        if (notaRaw.isNotEmpty) {
          final parsed = double.tryParse(notaRaw);
          if (parsed == null) {
            errores.add('Fila ${i + 1}: nota "$notaRaw" no es un número');
            ultimaNota = null;
          } else if (parsed < 0 || parsed > 20) {
            errores.add(
                'Fila ${i + 1}: nota $parsed fuera de rango 0–20 para código $codigoRaw');
            ultimaNota = parsed.clamp(0.0, 20.0);
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


    int gruposGuardados = 0;

    final notasUnicas = notas.values.toSet();
    gruposGuardados = notasUnicas.length;

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



    gruposGuardados = _contarGruposConNota(bytes);

    debugPrint(
        '✅ Notas docente guardadas: ${notas.length} códigos, '
        '$gruposGuardados grupos');

    return NotaDocenteImportResult(
      gruposImportados: gruposGuardados,
      codigosTotales: notas.length,
      errores: errores,
    );
  }


  int _contarGruposConNota(Uint8List bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);
      int count = 0;
      for (final sheetName in excel.tables.keys) {
        final sheet = excel.tables[sheetName];
        if (sheet == null || sheet.maxRows < 2) continue;
        final headers = sheet.rows.first
            .map((c) => c?.value?.toString().trim().toUpperCase() ?? '')
            .toList();
        final idxNota =
            _findCol(headers, ['NOTA DOCENTE', 'NOTA', 'NOTADOCENTE']);
        if (idxNota == -1) continue;
        for (int i = 1; i < sheet.maxRows; i++) {
          final v = _cell(sheet.rows[i], idxNota);
          if (v.isNotEmpty && double.tryParse(v) != null) count++;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
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