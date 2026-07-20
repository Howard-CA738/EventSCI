import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '/admin/logica/filiales_service.dart';


class _C {
  static const navy    = Color(0xFF1E3A5F);
  static const accent  = Color(0xFF3B82F6);
  static const green   = Color(0xFF059669);
  static const greenL  = Color(0xFFD1FAE5);
  static const orange  = Color(0xFFD97706);
  static const orangeL = Color(0xFFFEF3C7);
  static const red     = Color(0xFFDC2626);
  static const redL    = Color(0xFFFEE2E2);
  static const purple  = Color(0xFF7C3AED);
  static const surface = Color(0xFFE8EDF2);
  static const card    = Colors.white;
  static const border  = Color(0xFFE2E8F0);
  static const txt1    = Color(0xFF0F172A);
  static const txt2    = Color(0xFF475569);
  static const txt3    = Color(0xFF94A3B8);

  // Nombres EXACTOS de las columnas esperadas en el Excel.
  static const colCodigo = 'Código Estudiante';
  static const colNota   = 'Nota Docente';
}

/// Una fila ya procesada del Excel, clasificada.
class _FilaNota {
  final String codigoCrudo;   // lo que venía en el Excel (para mostrar)
  final String codigo;        // normalizado
  final double? nota;         // null si inválida/vacía
  final String? nombre;       // nombre del estudiante si cruzó
  final _EstadoFila estado;
  const _FilaNota({
    required this.codigoCrudo,
    required this.codigo,
    required this.nota,
    required this.nombre,
    required this.estado,
  });
}

enum _EstadoFila { valida, noEncontrada, notaInvalida, codigoVacio }

class ImportarNotasDocenteScreen extends StatefulWidget {
  const ImportarNotasDocenteScreen({super.key});

  @override
  State<ImportarNotasDocenteScreen> createState() =>
      _ImportarNotasDocenteScreenState();
}

class _ImportarNotasDocenteScreenState
    extends State<ImportarNotasDocenteScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FilialesService _filialesService = FilialesService();

  // ── Estructura filiales ──────────────────────────────────────
  Map<String, dynamic> _estructura = {};
  bool _cargandoEstructura = true;

  // ── Selección en cascada ─────────────────────────────────────
  String? _filialId;            // 'lima' | 'juliaca' | 'tarapoto'
  String? _filialNombre;        // 'Campus Lima' ...
  String? _facultad;            // nombre de la facultad
  String? _carreraNombre;       // nombre de la carrera
  String? _carreraId;           // id del doc de carrera

  List<String> _facultades = [];
  List<Map<String, dynamic>> _carreras = [];

  // ── Eventos ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _eventos = [];
  String? _eventoId;
  String? _eventoNombre;
  bool _cargandoEventos = false;

  // ── Archivo procesado ────────────────────────────────────────
  String? _nombreArchivo;
  bool _procesando = false;
  List<_FilaNota> _filas = [];
  bool _huboProcesamiento = false;

  bool _guardando = false;

  List<_FilaNota> get _validas =>
      _filas.where((f) => f.estado == _EstadoFila.valida).toList();
  List<_FilaNota> get _noEncontradas =>
      _filas.where((f) => f.estado == _EstadoFila.noEncontrada).toList();
  List<_FilaNota> get _invalidas => _filas
      .where((f) =>
          f.estado == _EstadoFila.notaInvalida ||
          f.estado == _EstadoFila.codigoVacio)
      .toList();

  @override
  void initState() {
    super.initState();
    _cargarEstructura();
  }

  Future<void> _cargarEstructura() async {
    setState(() => _cargandoEstructura = true);
    try {
      await _filialesService.inicializarSiEsNecesario();
      _estructura = await _filialesService.getEstructuraCompleta();
    } catch (e) {
      _snack('Error al cargar filiales: $e', isError: true);
    } finally {
      if (mounted) setState(() => _cargandoEstructura = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CASCADA
  // ─────────────────────────────────────────────────────────────
  void _onFilialChanged(String? filial) {
    setState(() {
      _filialId = filial;
      _filialNombre =
          filial != null ? _filialesService.getNombreFilial(filial) : null;
      _facultad = null;
      _carreraNombre = null;
      _carreraId = null;
      _facultades = [];
      _carreras = [];
      _resetEvento();

      if (filial != null && _estructura.containsKey(filial)) {
        final facs = _estructura[filial]['facultades'] as Map<String, dynamic>?;
        if (facs != null) _facultades = facs.keys.toList();
      }
    });
  }

  void _onFacultadChanged(String? facultad) {
    setState(() {
      _facultad = facultad;
      _carreraNombre = null;
      _carreraId = null;
      _carreras = [];
      _resetEvento();

      if (_filialId != null && facultad != null) {
        final facs =
            _estructura[_filialId!]['facultades'] as Map<String, dynamic>?;
        if (facs != null && facs.containsKey(facultad)) {
          _carreras =
              List<Map<String, dynamic>>.from(facs[facultad]['carreras'] ?? []);
        }
      }
    });
  }

  void _onCarreraChanged(String? nombreCarrera) {
    if (nombreCarrera == null) return;
    final data = _carreras.firstWhere(
      (c) => c['nombre'] == nombreCarrera,
      orElse: () => {},
    );
    setState(() {
      _carreraNombre = nombreCarrera;
      _carreraId = data.isNotEmpty ? data['id'] as String? : null;
      _resetEvento();
    });
    if (_carreraId != null) _cargarEventos();
  }

  void _resetEvento() {
    _eventos = [];
    _eventoId = null;
    _eventoNombre = null;
    _resetArchivo();
  }

  void _resetArchivo() {
    _nombreArchivo = null;
    _filas = [];
    _huboProcesamiento = false;
  }

  // ─────────────────────────────────────────────────────────────
  // EVENTOS
  // ─────────────────────────────────────────────────────────────
  Future<void> _cargarEventos() async {
    setState(() => _cargandoEventos = true);
    try {
      // Filtramos por filialId + facultad; la carrera se afina en cliente
      // (carreraId O carreraNombre) para tolerar eventos antiguos.
      final snap = await _firestore
          .collection('events')
          .where('filialId', isEqualTo: _filialId)
          .where('facultad', isEqualTo: _facultad)
          .get();

      final lista = snap.docs.where((d) {
        final data = d.data();
        return data['carreraId'] == _carreraId ||
            data['carreraNombre'] == _carreraNombre;
      }).map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': data['name'] ?? 'Sin nombre',
        };
      }).toList();

      setState(() => _eventos = lista);
    } catch (e) {
      _snack('Error al cargar eventos: $e', isError: true);
    } finally {
      if (mounted) setState(() => _cargandoEventos = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PLANTILLA
  // ─────────────────────────────────────────────────────────────
  Future<void> _descargarPlantilla() async {
    try {
      final excel = Excel.createExcel();
      final hojaDefault = excel.getDefaultSheet()!;
      excel.rename(hojaDefault, 'Notas');
      final sheet = excel['Notas'];

      // Encabezados
      sheet.cell(CellIndex.indexByString('A1')).value =
          TextCellValue(_C.colCodigo);
      sheet.cell(CellIndex.indexByString('B1')).value =
          TextCellValue(_C.colNota);

      // Fila de ejemplo (orientativa)
      sheet.cell(CellIndex.indexByString('A2')).value =
          TextCellValue('202612549');
      sheet.cell(CellIndex.indexByString('B2')).value = DoubleCellValue(16.5);

      final bytes = excel.encode();
      if (bytes == null) {
        _snack('No se pudo generar la plantilla', isError: true);
        return;
      }

      final dir = await getTemporaryDirectory();
      final ruta = '${dir.path}/plantilla_notas_docente.xlsx';
      final file = File(ruta);
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      _mostrarOpcionesArchivo(ruta);
    } catch (e) {
      _snack('Error al generar plantilla: $e', isError: true);
    }
  }

  void _mostrarOpcionesArchivo(String ruta) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Plantilla lista',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: const Text(
          'Descarga o comparte la plantilla, llénala con los códigos y notas, '
          'y luego súbela aquí.',
          style: TextStyle(fontSize: 14, color: _C.txt2),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final r = await OpenFilex.open(ruta);
                if (r.type != ResultType.done && mounted) {
                  _snack('No se encontró app para abrir Excel. Prueba compartir.',
                      isError: true);
                }
              },
              icon: const Icon(Icons.open_in_new, size: 20),
              label: const Text('Abrir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await Share.shareXFiles([XFile(ruta)],
                    subject: 'Plantilla Notas Docente');
              },
              icon: const Icon(Icons.share, size: 20),
              label: const Text('Compartir'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.navy,
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: _C.navy, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LECTURA Y PROCESAMIENTO DEL EXCEL
  // ─────────────────────────────────────────────────────────────

  /// Normaliza un valor de celda a String "limpio".
  /// Quita el ".0" que el paquete excel suele añadir a códigos numéricos.
  String _celdaAString(CellValue? v) {
    if (v == null) return '';
    if (v is TextCellValue) {
      return v.value.text?.trim() ?? '';
    }
    if (v is IntCellValue) {
      return v.value.toString().trim();
    }
    if (v is DoubleCellValue) {
      final d = v.value;
      // Si es entero (202612549.0) → "202612549"
      if (d == d.roundToDouble()) {
        return d.toInt().toString();
      }
      return d.toString().trim();
    }
    // Cualquier otro tipo: a texto plano
    final s = v.toString().trim();
    if (s.endsWith('.0')) return s.substring(0, s.length - 2);
    return s;
  }

  /// Intenta parsear la nota a double en escala 0–20.
  double? _parseNota(CellValue? v) {
    if (v == null) return null;
    if (v is IntCellValue) return v.value.toDouble();
    if (v is DoubleCellValue) return v.value;
    if (v is TextCellValue) {
      final t = (v.value.text ?? '').trim().replaceAll(',', '.');
      if (t.isEmpty) return null;
      return double.tryParse(t);
    }
    return double.tryParse(v.toString().trim().replaceAll(',', '.'));
  }

 Future<void> _seleccionarYProcesar() async {
  if (_eventoId == null) return;
  setState(() {
    _procesando = true;
    _resetArchivo();
  });

  try {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) {
      setState(() => _procesando = false);
      return;
    }

    final picked = res.files.first;
    final bytes = picked.bytes ??
        (picked.path != null ? await File(picked.path!).readAsBytes() : null);
    if (bytes == null) {
      _snack('No se pudo leer el archivo', isError: true);
      setState(() => _procesando = false);
      return;
    }

    _nombreArchivo = picked.name;

    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      _snack('El archivo no tiene hojas', isError: true);
      setState(() => _procesando = false);
      return;
    }

    final sheet = excel.tables.values.first;
    if (sheet.maxRows < 2) {
      _snack('El archivo no tiene filas de datos', isError: true);
      setState(() => _procesando = false);
      return;
    }

    // Localizar columnas por nombre en la fila 0 (encabezados).
    final header = sheet.rows.first;
    int colCodigo = -1;
    int colNota = -1;
    for (int i = 0; i < header.length; i++) {
      final txt = _celdaAString(header[i]?.value).toLowerCase();
      final norm = _sinTildes(txt);
      if (colCodigo == -1 &&
          (norm.contains('codigo') || norm == 'cod')) {
        colCodigo = i;
      }
      if (colNota == -1 && norm.contains('nota')) {
        colNota = i;
      }
    }

    if (colCodigo == -1 || colNota == -1) {
      _snack(
        'No se encontraron las columnas "${_C.colCodigo}" y "${_C.colNota}". '
        'Usa la plantilla descargable.',
        isError: true,
      );
      setState(() => _procesando = false);
      return;
    }

    // Cargar estudiantes reales de la carrera.
    final mapaEstudiantes = await _cargarEstudiantes();

    // Nota heredada para celdas combinadas (merged cells).
    double? _ultimaNota;

    final List<_FilaNota> filas = [];
    for (int r = 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      if (row.isEmpty) continue;

      final codigoCrudo = colCodigo < row.length
          ? _celdaAString(row[colCodigo]?.value)
          : '';

      // Limpiar caracteres invisibles del código.
      final codigo = codigoCrudo
          .trim()
          .replaceAll('\t', '')
          .replaceAll('\u00A0', ''); // espacio no separable

      // Propagar nota de celdas combinadas: si la celda actual es null
      // se hereda la última nota válida leída.
      final notaRaw = colNota < row.length
          ? _parseNota(row[colNota]?.value)
          : null;
      if (notaRaw != null) _ultimaNota = notaRaw;
      final notaVal = notaRaw ?? _ultimaNota;

      // Fila completamente vacía → ignorar.
      if (codigo.isEmpty && notaVal == null) continue;

      if (codigo.isEmpty) {
        filas.add(_FilaNota(
          codigoCrudo: codigoCrudo,
          codigo: '',
          nota: notaVal,
          nombre: null,
          estado: _EstadoFila.codigoVacio,
        ));
        continue;
      }

      final nombre = mapaEstudiantes[codigo];
      if (nombre == null) {
        filas.add(_FilaNota(
          codigoCrudo: codigoCrudo,
          codigo: codigo,
          nota: notaVal,
          nombre: null,
          estado: _EstadoFila.noEncontrada,
        ));
        continue;
      }

      if (notaVal == null || notaVal < 0 || notaVal > 20) {
        filas.add(_FilaNota(
          codigoCrudo: codigoCrudo,
          codigo: codigo,
          nota: notaVal,
          nombre: nombre,
          estado: _EstadoFila.notaInvalida,
        ));
        continue;
      }

      filas.add(_FilaNota(
        codigoCrudo: codigoCrudo,
        codigo: codigo,
        nota: double.parse(notaVal.toStringAsFixed(2)),
        nombre: nombre,
        estado: _EstadoFila.valida,
      ));
    }

    setState(() {
      _filas = filas;
      _huboProcesamiento = true;
      _procesando = false;
    });

    if (filas.isEmpty) {
      _snack('No se encontraron filas con datos', isError: true);
    }
  } catch (e) {
    _snack('Error al procesar el archivo: $e', isError: true);
    setState(() => _procesando = false);
  }
}

  /// Carga los estudiantes de la carrera y devuelve { codigoUniversitario: name }.
  /// Prueba varias rutas candidatas (como hace la evaluación final).
  Future<Map<String, String>> _cargarEstudiantes() async {
    final candidatos = <String>[
      '${_filialNombre}_$_carreraNombre',
      '${_filialNombre}_$_carreraId',
      '${_filialId}_$_carreraNombre',
      '${_filialId}_$_carreraId',
    ];

    final Map<String, String> mapa = {};
    for (final path in candidatos) {
      final snap = await _firestore
          .collection('users')
          .doc(path)
          .collection('students')
          .get();
      if (snap.docs.isNotEmpty) {
        for (final d in snap.docs) {
          final data = d.data();
          final cod = (data['codigoUniversitario'] ?? '').toString().trim();
          final nom = (data['name'] ?? '').toString().trim();
          if (cod.isNotEmpty) mapa[cod] = nom.isEmpty ? cod : nom;
        }
        break; // encontramos la ruta correcta
      }
    }
    return mapa;
  }

  // ─────────────────────────────────────────────────────────────
  // GUARDAR
  // ─────────────────────────────────────────────────────────────
  Future<void> _guardar() async {
    final validas = _validas;
    if (_eventoId == null || validas.isEmpty) return;

    setState(() => _guardando = true);
    try {
      // Batches de máximo 450 operaciones (límite Firestore = 500).
      const tope = 450;
      for (int i = 0; i < validas.length; i += tope) {
        final batch = _firestore.batch();
        final lote = validas.sublist(
            i, (i + tope > validas.length) ? validas.length : i + tope);
        for (final f in lote) {
          final ref = _firestore
              .collection('events')
              .doc(_eventoId)
              .collection('notas_docente')
              .doc(f.codigo);
          batch.set(ref, {
            'nota': f.nota,
            'nombre': f.nombre,
            'codigo': f.codigo,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        await batch.commit();
      }

      // Marca de última importación en el evento (estilo lastImportAt).
      await _firestore.collection('events').doc(_eventoId).set({
        'lastImportNotasDocenteAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      _snack('${validas.length} notas guardadas ✓');
      setState(() {
        _guardando = false;
        _resetArchivo();
      });
    } catch (e) {
      _snack('Error al guardar: $e', isError: true);
      setState(() => _guardando = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────
  String _sinTildes(String s) => s
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n');

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _C.red : _C.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.navy,
      appBar: AppBar(
        backgroundColor: _C.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Importar Notas Docente',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: const BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: _cargandoEstructura
              ? const Center(child: CircularProgressIndicator(color: _C.navy))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSelectores(),
                      const SizedBox(height: 16),
                      if (_carreraId != null) _buildSelectorEvento(),
                      if (_eventoId != null) ...[
                        const SizedBox(height: 16),
                        _buildAccionesArchivo(),
                      ],
                      if (_huboProcesamiento) ...[
                        const SizedBox(height: 16),
                        _buildResumen(),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSelectores() {
    return _cardWrap(
      icon: Icons.tune_rounded,
      color: _C.navy,
      titulo: 'Filial, facultad y carrera',
      child: Column(
        children: [
          _dropdown<String>(
            label: 'Filial',
            icon: Icons.location_city,
            value: _filialId,
            items: _estructura.keys
                .map((k) => DropdownMenuItem(
                      value: k,
                      child: Text(_filialesService.getNombreFilial(k),
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: _onFilialChanged,
          ),
          if (_filialId != null) ...[
            const SizedBox(height: 12),
            _dropdown<String>(
              label: 'Facultad',
              icon: Icons.business,
              value: _facultad,
              items: _facultades
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _onFacultadChanged,
            ),
          ],
          if (_facultad != null) ...[
            const SizedBox(height: 12),
            _dropdown<String>(
              label: 'Carrera',
              icon: Icons.school,
              value: _carreraNombre,
              items: _carreras
                  .map((c) => DropdownMenuItem(
                        value: c['nombre'] as String,
                        child: Text(c['nombre'] as String,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _onCarreraChanged,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectorEvento() {
    return _cardWrap(
      icon: Icons.event_rounded,
      color: _C.green,
      titulo: 'Evento',
      child: _cargandoEventos
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator(color: _C.navy)),
            )
          : _eventos.isEmpty
              ? _infoBox('No hay eventos para esta carrera.', _C.orange,
                  Icons.event_busy_rounded)
              : _dropdown<String>(
                  label: 'Selecciona el evento',
                  icon: Icons.event,
                  value: _eventoId,
                  items: _eventos
                      .map((e) => DropdownMenuItem(
                            value: e['id'] as String,
                            child: Text(e['name'] as String,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final nombre =
                        _eventos.firstWhere((e) => e['id'] == v)['name']
                            as String;
                    setState(() {
                      _eventoId = v;
                      _eventoNombre = nombre;
                      _resetArchivo();
                    });
                  },
                ),
    );
  }

  Widget _buildAccionesArchivo() {
    return _cardWrap(
      icon: Icons.upload_file_rounded,
      color: _C.purple,
      titulo: 'Archivo Excel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoBox(
            'El Excel debe tener las columnas "${_C.colCodigo}" y "${_C.colNota}" '
            '(nota de 0 a 20). Descarga la plantilla para no equivocarte.',
            _C.accent,
            Icons.info_outline,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _descargarPlantilla,
            icon: const Icon(Icons.download_rounded, size: 20),
            label: const Text('Descargar plantilla'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _C.navy,
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: _C.navy, width: 1.5),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _procesando ? null : _seleccionarYProcesar,
            icon: _procesando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.file_open_rounded, size: 20),
            label: Text(_procesando ? 'Procesando...' : 'Seleccionar archivo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
          if (_nombreArchivo != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.description_rounded,
                    size: 16, color: _C.txt3),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_nombreArchivo!,
                      style: const TextStyle(fontSize: 12, color: _C.txt2),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResumen() {
    final validas = _validas;
    final noEnc = _noEncontradas;
    final inval = _invalidas;

    return _cardWrap(
      icon: Icons.fact_check_rounded,
      color: _C.navy,
      titulo: 'Previsualización',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _statChip('Válidas', validas.length, _C.green),
              const SizedBox(width: 8),
              _statChip('No encontradas', noEnc.length, _C.orange),
              const SizedBox(width: 8),
              _statChip('Inválidas', inval.length, _C.red),
            ],
          ),
          if (noEnc.isNotEmpty) ...[
            const SizedBox(height: 16),
            _listaProblema(
              'Códigos no encontrados en el sistema',
              _C.orange,
              noEnc
                  .map((f) => f.codigoCrudo.isEmpty ? '(vacío)' : f.codigoCrudo)
                  .toList(),
            ),
          ],
          if (inval.isNotEmpty) ...[
            const SizedBox(height: 12),
            _listaProblema(
              'Filas con problemas (código vacío o nota inválida)',
              _C.red,
              inval.map((f) {
                final cod =
                    f.codigoCrudo.isEmpty ? '(código vacío)' : f.codigoCrudo;
                final nota = f.nota?.toStringAsFixed(1) ?? 'sin nota';
                return '$cod → $nota';
              }).toList(),
            ),
          ],
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed:
                (validas.isEmpty || _guardando) ? null : _guardar,
            icon: _guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_rounded, size: 20),
            label: Text(_guardando
                ? 'Guardando...'
                : 'Guardar ${validas.length} nota${validas.length == 1 ? '' : 's'} válida${validas.length == 1 ? '' : 's'}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
          if (validas.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'No hay notas válidas para guardar.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _C.txt3),
              ),
            ),
        ],
      ),
    );
  }

  // ── Widgets reutilizables ──────────────────────────────────────
  Widget _cardWrap({
    required IconData icon,
    required Color color,
    required String titulo,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(titulo,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _C.navy),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?)? onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: 320,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _C.navy, size: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.navy, width: 1.5)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _statChip(String label, int valor, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text('$valor',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _listaProblema(String titulo, Color color, List<String> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 8),
          ...items.take(50).map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('• $t',
                    style: const TextStyle(fontSize: 12, color: _C.txt2)),
              )),
          if (items.length > 50)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('… y ${items.length - 50} más',
                  style: const TextStyle(
                      fontSize: 11,
                      color: _C.txt3,
                      fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }

  Widget _infoBox(String msg, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: TextStyle(color: color, fontSize: 12, height: 1.4))),
        ],
      ),
    );
  }
}