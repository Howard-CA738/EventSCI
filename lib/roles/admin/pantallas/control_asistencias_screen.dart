import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ControlAsistenciasScreen extends StatefulWidget {
  const ControlAsistenciasScreen({super.key});

  @override
  State<ControlAsistenciasScreen> createState() =>
      _ControlAsistenciasScreenState();
}

class _ControlAsistenciasScreenState extends State<ControlAsistenciasScreen> {
  static const Color _primary = Color(0xFF1E3A5F);
  static const Color _primaryLight = Color(0xFF2D5F8D);
  static const Color _bg = Color(0xFFE8EDF2);
  static const Color _danger = Color(0xFFE53935);
  static const Color _success = Color(0xFF43A047);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _surface = Colors.white;
  static const Color _muted = Color(0xFF64748B);

  static final List<BoxShadow> _cardShadow = [
    BoxShadow(
      color: _primary.withValues(alpha: 0.07),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _eventos = [];
  bool _cargandoEventos = true;
  Map<String, dynamic>? _eventoSeleccionado;

  final TextEditingController _buscarEventoCtrl = TextEditingController();
  String _queryEvento = '';

  List<Map<String, dynamic>> _asistentes = [];
  bool _cargandoAsistentes = false;
  String _buscarAsistente = '';
  final TextEditingController _buscarAsistenteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_cargarEventos());
  }

  @override
  void dispose() {
    _buscarEventoCtrl.dispose();
    _buscarAsistenteCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false, bool warn = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            error
                ? Icons.error_outline
                : warn
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
        ]),
        backgroundColor: error ? _danger : warn ? _warning : _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatTs(dynamic ts) {
    if (ts == null) return '—';
    try {
      DateTime dt;
      if (ts is Timestamp) {
        dt = ts.toDate();
      } else if (ts is DateTime) {
        dt = ts;
      } else {
        return ts.toString();
      }
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return '—';
    }
  }

  Future<void> _cargarEventos() async {
    setState(() => _cargandoEventos = true);
    try {
      final snap = await _firestore
          .collection('events')
          .orderBy('createdAt', descending: true)
          .get();

      final lista = snap.docs.map((doc) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        return d;
      }).toList();

      if (mounted) setState(() => _eventos = lista);
    } catch (e) {
      _snack('Error cargando eventos: $e', error: true);
    } finally {
      if (mounted) setState(() => _cargandoEventos = false);
    }
  }

  List<Map<String, dynamic>> get _eventosFiltrados {
    if (_queryEvento.trim().isEmpty) return _eventos;
    final q = _queryEvento.toLowerCase();
    return _eventos.where((e) {
      final nombre = (e['name'] ?? e['nombre'] ?? '').toString().toLowerCase();
      final filial = (e['filialNombre'] ?? '').toString().toLowerCase();
      final facultad = (e['facultad'] ?? '').toString().toLowerCase();
      final carrera = (e['carreraNombre'] ?? '').toString().toLowerCase();
      return nombre.contains(q) ||
          filial.contains(q) ||
          facultad.contains(q) ||
          carrera.contains(q);
    }).toList();
  }
Future<void> _cargarAsistentes(String eventId) async {
  setState(() {
    _cargandoAsistentes = true;
    _asistentes = [];
  });
  try {

    final futures = await Future.wait([
      _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias')
          .get(),
      _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias_personales')
          .get(),
      _firestore
          .collectionGroup('registros')
          .where('eventId', isEqualTo: eventId)
          .where('type', isEqualTo: 'asistencia_personal')
          .get(),
    ]);

    final resumenSnap = futures[0];
    final personalesSnap = futures[1];
    final huerfanosSnap = futures[2];


    final scansResults = await Future.wait(
      resumenSnap.docs.map((resumenDoc) => _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias')
          .doc(resumenDoc.id)
          .collection('scans')
          .orderBy('timestamp', descending: true)
          .get()),
    );

    final List<Map<String, dynamic>> lista = [];

    for (var i = 0; i < resumenSnap.docs.length; i++) {
      final resumenDoc = resumenSnap.docs[i];
      final rd = Map<String, dynamic>.from(resumenDoc.data());
      rd['studentId'] = resumenDoc.id;
      rd['tipo'] = 'proyecto';
      rd['scans'] = scansResults[i].docs.map((s) {
        final sd = Map<String, dynamic>.from(s.data());
        sd['scanId'] = s.id;
        return sd;
      }).toList();
      lista.add(rd);
    }


    final registrosResults = await Future.wait(
      personalesSnap.docs.map((asistDoc) => _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias_personales')
          .doc(asistDoc.id)
          .collection('registros')
          .get()),
    );

    final Map<String, List<Map<String, dynamic>>> personalesPorEstudiante =
        {};


    final Set<String> asistenciasVivas =
        personalesSnap.docs.map((d) => d.id).toSet();


    final Map<String, String> nombrePorAsistenciaId = {};
    for (final regDoc in huerfanosSnap.docs) {
      final rd = regDoc.data();
      final asistId = rd['asistenciaId']?.toString() ?? '';
      final nombre =
          rd['asistenciaNombre']?.toString() ?? 'Asistencia personal';
      if (asistId.isNotEmpty) {
        nombrePorAsistenciaId.putIfAbsent(asistId, () => nombre);
      }
    }


    for (var i = 0; i < personalesSnap.docs.length; i++) {
      final asistDoc = personalesSnap.docs[i];
      final asistData = Map<String, dynamic>.from(asistDoc.data());

      for (final regDoc in registrosResults[i].docs) {
        final regData = Map<String, dynamic>.from(regDoc.data());
        regData['registroId'] = regDoc.id;
        regData['asistenciaId'] = asistDoc.id;
        regData['asistenciaNombre'] =
            asistData['nombre'] ?? regData['asistenciaNombre'] ?? 'Personal';
        regData['tipo'] = 'personal';
        final sid = regDoc.id;
        personalesPorEstudiante[sid] ??= [];
        personalesPorEstudiante[sid]!.add(regData);
      }
    }


    for (final regDoc in huerfanosSnap.docs) {
      final regData = Map<String, dynamic>.from(regDoc.data());
      final asistId = regData['asistenciaId']?.toString() ?? '';


      if (asistenciasVivas.contains(asistId)) continue;

      regData['registroId'] = regDoc.id;
      regData['asistenciaId'] = asistId;
      regData['asistenciaNombre'] = regData['asistenciaNombre'] ??
          nombrePorAsistenciaId[asistId] ??
          'Personal';
      regData['tipo'] = 'personal';
      final sid = regDoc.id;
      personalesPorEstudiante[sid] ??= [];
      personalesPorEstudiante[sid]!.add(regData);
    }


    for (final entry in personalesPorEstudiante.entries) {
      final sid = entry.key;
      final registros = entry.value;
      final idx = lista.indexWhere((a) => a['studentId'] == sid);
      if (idx >= 0) {
        lista[idx]['registrosPersonales'] = registros;
      } else {
        final primer = registros.first;
        lista.add({
          'studentId': sid,
          'studentName': primer['studentName'] ?? '—',
          'studentUsername': primer['studentUsername'] ?? '',
          'studentCodigo': primer['studentCodigo'] ?? '',
          'facultad': primer['facultad'] ?? '',
          'carrera': primer['carrera'] ?? '',
          'filial': primer['filial'] ?? '',
          'ciclo': primer['ciclo'] ?? '',
          'grupo': primer['grupo'] ?? '',
          'lastScan': primer['timestamp'],
          'totalScans': 0,
          'scans': [],
          'registrosPersonales': registros,
          'tipo': 'solo_personal',
        });
      }
    }

    lista.sort((a, b) => (a['studentName'] ?? '')
        .toString()
        .compareTo((b['studentName'] ?? '').toString()));

    if (mounted) setState(() => _asistentes = lista);
  } catch (e) {
    _snack('Error cargando asistentes: $e', error: true);
  } finally {
    if (mounted) setState(() => _cargandoAsistentes = false);
  }
}

  List<Map<String, dynamic>> get _asistentesFiltrados {
    if (_buscarAsistente.trim().isEmpty) return _asistentes;
    final q = _buscarAsistente.toLowerCase();
    return _asistentes.where((a) {
      final name = (a['studentName'] ?? '').toString().toLowerCase();
      final code = (a['studentCodigo'] ?? '').toString().toLowerCase();
      final user = (a['studentUsername'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q) || user.contains(q);
    }).toList();
  }

  Future<void> _eliminarScan({
    required String eventId,
    required String studentId,
    required String scanId,
    required Map<String, dynamic> asistente,
  }) async {
    final confirm = await _dialogConfirmar(
      titulo: 'Eliminar registro',
      mensaje:
          '¿Eliminar este scan?\n\nEl contador de asistencias se actualizará.',
      labelConfirmar: 'Eliminar',
    );
    if (confirm != true) return;

    try {
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias')
          .doc(studentId)
          .collection('scans')
          .doc(scanId)
          .delete();

      final currentTotal = (asistente['totalScans'] as int?) ?? 0;
      final newTotal = (currentTotal - 1).clamp(0, 99999);
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias')
          .doc(studentId)
          .update({'totalScans': newTotal});

      _snack('Scan eliminado');
      await _cargarAsistentes(eventId);
    } catch (e) {
      _snack('Error eliminando scan: $e', error: true);
    }
  }

  Future<void> _eliminarRegistroPersonal({
    required String eventId,
    required String asistenciaId,
    required String studentId,
  }) async {
    final confirm = await _dialogConfirmar(
      titulo: 'Eliminar asistencia personal',
      mensaje: '¿Eliminar este registro de asistencia personal?',
      labelConfirmar: 'Eliminar',
    );
    if (confirm != true) return;

    try {
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias_personales')
          .doc(asistenciaId)
          .collection('registros')
          .doc(studentId)
          .delete();

      _snack('Asistencia personal eliminada');
      await _cargarAsistentes(eventId);
    } catch (e) {
      _snack('Error eliminando registro: $e', error: true);
    }
  }

  Future<void> _eliminarTodasAsistencias({
    required String eventId,
    required Map<String, dynamic> asistente,
  }) async {
    final nombre = asistente['studentName'] ?? 'este alumno';
    final confirm = await _dialogConfirmar(
      titulo: 'Eliminar todas las asistencias',
      mensaje:
          '¿Eliminar TODOS los registros de "$nombre" en este evento?\n\nEsto incluye scans normales y asistencias personales.',
      labelConfirmar: 'Eliminar todo',
    );
    if (confirm != true) return;

    try {
      final studentId = asistente['studentId'] as String;
      final batch = _firestore.batch();
      int ops = 0;

      Future<void> commitIfFull() async {
        if (ops >= 490) {
          await batch.commit();
          ops = 0;
        }
      }

      final scans =
          List<Map<String, dynamic>>.from(asistente['scans'] ?? []);
      for (final scan in scans) {
        final scanId = scan['scanId'] as String?;
        if (scanId == null) continue;
        batch.delete(_firestore
            .collection('events')
            .doc(eventId)
            .collection('asistencias')
            .doc(studentId)
            .collection('scans')
            .doc(scanId));
        ops++;
        await commitIfFull();
      }

      batch.delete(_firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias')
          .doc(studentId));
      ops++;
      await commitIfFull();

      final personales = List<Map<String, dynamic>>.from(
          asistente['registrosPersonales'] ?? []);
      for (final reg in personales) {
        final asistenciaId = reg['asistenciaId'] as String?;
        if (asistenciaId == null) continue;
        batch.delete(_firestore
            .collection('events')
            .doc(eventId)
            .collection('asistencias_personales')
            .doc(asistenciaId)
            .collection('registros')
            .doc(studentId));
        ops++;
        await commitIfFull();
      }

      if (ops > 0) await batch.commit();

      _snack('Asistencias eliminadas');
      await _cargarAsistentes(eventId);
    } catch (e) {
      _snack('Error eliminando asistencias: $e', error: true);
    }
  }

  Future<void> _editarScan({
    required String eventId,
    required String studentId,
    required Map<String, dynamic> scan,
  }) async {
    final scanId = scan['scanId'] as String;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _DialogEditarScan(scan: scan),
    );
    if (result == null) return;

    try {
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias')
          .doc(studentId)
          .collection('scans')
          .doc(scanId)
          .update(result);

      _snack('Scan actualizado');
      await _cargarAsistentes(eventId);
    } catch (e) {
      _snack('Error actualizando scan: $e', error: true);
    }
  }


  Future<void> _editarRegistroPersonal({
    required String eventId,
    required String studentId,
    required Map<String, dynamic> registro,
  }) async {
    final asistenciaId = registro['asistenciaId'] as String?;
    if (asistenciaId == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _DialogEditarRegistroPersonal(registro: registro),
    );
    if (result == null) return;

    try {
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias_personales')
          .doc(asistenciaId)
          .collection('registros')
          .doc(studentId)
          .update(result);

      _snack('Asistencia personal actualizada');
      await _cargarAsistentes(eventId);
    } catch (e) {
      _snack('Error actualizando registro: $e', error: true);
    }
  }

Future<void> _agregarAsistenciaManual() async {
  final eventId = _eventoSeleccionado?['id'] as String?;
  if (eventId == null) return;

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => _DialogAgregarAsistencia(
      evento: _eventoSeleccionado!,
      firestore: _firestore,
    ),
  );
  if (result == null) return;

  final eventName =
      _eventoSeleccionado!['name'] ?? _eventoSeleccionado!['nombre'] ?? '';
  final fechaHora = result['fechaHora'] as DateTime;
  final ts = Timestamp.fromDate(fechaHora);

  final alumnos =
      List<Map<String, dynamic>>.from(result['alumnos'] as List);
  final asistencias =
      List<Map<String, dynamic>>.from(result['asistencias'] as List);

  int creados = 0;
  int omitidos = 0;

  try {
    for (final studentData in alumnos) {
      final studentId = studentData['studentId'] as String;

      for (final asist in asistencias) {
        final kind = asist['_kind'] as String;

        if (kind == 'personal') {
          final asistenciaId = asist['asistenciaId'] as String;

          final registroRef = _firestore
              .collection('events')
              .doc(eventId)
              .collection('asistencias_personales')
              .doc(asistenciaId)
              .collection('registros')
              .doc(studentId);

          final existing = await registroRef.get();
          if (existing.exists) {
            omitidos++;
            continue;
          }

          await registroRef.set({
            'studentId': studentId,
            'studentName': studentData['name'] ?? '',
            'studentUsername': studentData['username'] ?? '',
            'studentDNI': studentData['dni'] ?? '',
            'studentCodigo': studentData['codigoUniversitario'] ?? '',
            'facultad': studentData['facultad'] ?? '',
            'carrera': studentData['carrera'] ?? '',
            'filial': studentData['filial'] ?? '',
            'ciclo': studentData['ciclo'] ?? '',
            'grupo': studentData['grupo'] ?? '',
            'eventId': eventId,
            'eventName': eventName,
            'asistenciaId': asistenciaId,
            'asistenciaNombre': asist['nombre'] ?? '',
            'asistenciaTipo':
                asist['tipo'] ?? 'Asistencia Personal',
            'qrId': asist['qrId'] ?? '',
            'type': 'asistencia_personal',
            'timestamp': ts,
            'registrationMethod': 'manual_superadmin',
            'registradoPor': 'super_admin',
          });

          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('asistencias_personales')
              .doc(asistenciaId)
              .set({
            'totalRegistros': FieldValue.increment(1),
            'lastScan': ts,
          }, SetOptions(merge: true));

          creados++;
        } else {
          final codigoProyecto =
              (asist['codigoProyecto'] as String?) ?? '';
          final tituloProyecto =
              (asist['tituloProyecto'] as String?) ?? '';
          final categoria = (asist['categoria'] as String?) ?? '';
          final grupo = (asist['grupo'] as String?) ?? '';
          final qrId = (asist['qrId'] as String?) ?? '';

          final scanId = codigoProyecto.isNotEmpty
              ? '${eventId}_${studentId}_$codigoProyecto'
              : '${eventId}_${studentId}_${qrId.isNotEmpty ? qrId : DateTime.now().millisecondsSinceEpoch}';

          final scanRef = _firestore
              .collection('events')
              .doc(eventId)
              .collection('asistencias')
              .doc(studentId)
              .collection('scans')
              .doc(scanId);

          final existing = await scanRef.get();
          if (existing.exists) {
            omitidos++;
            continue;
          }

          final resumenRef = _firestore
              .collection('events')
              .doc(eventId)
              .collection('asistencias')
              .doc(studentId);

          final batch = _firestore.batch();

          batch.set(scanRef, {
            'codigoProyecto': codigoProyecto.isEmpty
                ? 'Sin código'
                : codigoProyecto,
            'tituloProyecto': tituloProyecto.isEmpty
                ? 'Sin título'
                : tituloProyecto,
            'categoria': categoria.isEmpty ? 'Sin categoría' : categoria,
            'grupo': grupo.isEmpty ? null : grupo,
            'qrId': qrId,
            'timestamp': ts,
            'qrTimestamp': ts,
            'registrationMethod': 'manual_superadmin',
            'registradoPor': 'super_admin',
          });

          batch.set(
            resumenRef,
            {
              'studentName': studentData['name'] ?? '',
              'studentUsername': studentData['username'] ?? '',
              'studentDNI': studentData['dni'] ?? '',
              'studentCodigo':
                  studentData['codigoUniversitario'] ?? '',
              'facultad': studentData['facultad'] ?? '',
              'carrera': studentData['carrera'] ?? '',
              'filial': studentData['filial'] ?? '',
              'ciclo': studentData['ciclo'] ?? '',
              'grupo': studentData['grupo'] ?? '',
              'eventId': eventId,
              'eventName': eventName,
              'lastScan': ts,
              'totalScans': FieldValue.increment(1),
            },
            SetOptions(merge: true),
          );

          await batch.commit();
          creados++;
        }
      }
    }

    if (!mounted) return;

    if (omitidos > 0) {
      _snack(
        '$creados registro${creados != 1 ? 's' : ''} creado${creados != 1 ? 's' : ''}, $omitidos omitido${omitidos != 1 ? 's' : ''} por duplicado',
        warn: true,
      );
    } else {
      _snack(
          '$creados registro${creados != 1 ? 's' : ''} registrado${creados != 1 ? 's' : ''} correctamente');
    }

    await _cargarAsistentes(eventId);
  } catch (e) {
    _snack('Error registrando asistencias: $e', error: true);
  }
}

  Future<bool?> _dialogConfirmar({
    required String titulo,
    required String mensaje,
    required String labelConfirmar,
    Color colorConfirmar = _danger,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorConfirmar.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.warning_amber_rounded,
                      color: colorConfirmar, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _primary),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Text(mensaje,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.5)),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancelar',
                      style: TextStyle(color: Colors.grey.shade600)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorConfirmar,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text(labelConfirmar,
                      style:
                          const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isSmall = sw < 360;
    final hPad = isSmall ? 14.0 : 20.0;

    return Scaffold(
      backgroundColor: _primary,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8, 14, hPad, 14),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  if (_eventoSeleccionado != null) {
                    setState(() {
                      _eventoSeleccionado = null;
                      _asistentes = [];
                      _buscarAsistenteCtrl.clear();
                      _buscarAsistente = '';
                    });
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                tooltip: _eventoSeleccionado != null ? 'Volver' : 'Salir',
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.admin_panel_settings,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Control de Asistencias',
                      style: TextStyle(
                        fontSize: isSmall ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (_eventoSeleccionado != null)
                      Text(
                        _eventoSeleccionado!['name'] ??
                            _eventoSeleccionado!['nombre'] ??
                            '',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              if (_eventoSeleccionado != null)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () => _cargarAsistentes(
                      _eventoSeleccionado!['id'] as String),
                  tooltip: 'Actualizar',
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _cargarEventos,
                  tooltip: 'Actualizar',
                ),
            ]),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: _eventoSeleccionado == null
                  ? _buildListaEventos(hPad)
                  : _buildPantallaEvento(hPad),
            ),
          ),
        ]),
      ),
      floatingActionButton: _eventoSeleccionado != null
          ? FloatingActionButton.extended(
              onPressed: _agregarAsistenciaManual,
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Agregar',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  Widget _buildListaEventos(double hPad) {
    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 12),
        child: TextField(
          controller: _buscarEventoCtrl,
          onChanged: (v) => setState(() => _queryEvento = v),
          decoration: InputDecoration(
            hintText: 'Buscar evento por nombre, filial...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            prefixIcon: const Icon(Icons.search, color: _primary, size: 20),
            suffixIcon: _queryEvento.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _buscarEventoCtrl.clear();
                      setState(() => _queryEvento = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: _surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
      ),
      Expanded(
        child: _cargandoEventos
            ? const Center(
                child: CircularProgressIndicator(color: _primary))
            : _eventosFiltrados.isEmpty
                ? _buildEstadoVacio(
                    icon: Icons.event_busy,
                    titulo: 'No hay eventos',
                    subtitulo: _queryEvento.isNotEmpty
                        ? 'Sin resultados para "$_queryEvento"'
                        : 'No se encontraron eventos registrados',
                  )
                : RefreshIndicator(
                    onRefresh: _cargarEventos,
                    color: _primary,
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 100),
                      itemCount: _eventosFiltrados.length,
                      itemBuilder: (ctx, i) =>
                          _buildEventoCard(_eventosFiltrados[i]),
                    ),
                  ),
      ),
    ]);
  }

  Widget _buildEventoCard(Map<String, dynamic> evento) {
    final nombre =
        (evento['name'] ?? evento['nombre'] ?? 'Sin nombre').toString();
    final filial = (evento['filialNombre'] ?? '').toString();
    final facultad = (evento['facultad'] ?? '').toString();
    final carrera = (evento['carreraNombre'] ?? '').toString();
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'E';

    return GestureDetector(
      onTap: () {
        setState(() => _eventoSeleccionado = evento);
        unawaited(_cargarAsistentes(evento['id'] as String));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_primary, _primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(inicial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _primary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2),
                const SizedBox(height: 4),
                if (filial.isNotEmpty)
                  _buildMetaRow(Icons.location_city, filial),
                if (facultad.isNotEmpty)
                  _buildMetaRow(Icons.account_balance, facultad),
                if (carrera.isNotEmpty)
                  _buildMetaRow(Icons.menu_book, carrera),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: _primary),
        ]),
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(children: [
        Icon(icon, size: 11, color: _muted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: _muted),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  Widget _buildPantallaEvento(double hPad) {
    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_primary, _primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.event, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _eventoSeleccionado!['name'] ??
                        _eventoSeleccionado!['nombre'] ??
                        '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  Text(
                    '${_eventoSeleccionado!['filialNombre'] ?? ''} · ${_eventoSeleccionado!['facultad'] ?? ''}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_asistentes.length} alumnos',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 8),
        child: TextField(
          controller: _buscarAsistenteCtrl,
          onChanged: (v) => setState(() => _buscarAsistente = v),
          decoration: InputDecoration(
            hintText: 'Buscar alumno, código...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            prefixIcon: const Icon(Icons.search, color: _primary, size: 20),
            suffixIcon: _buscarAsistente.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _buscarAsistenteCtrl.clear();
                      setState(() => _buscarAsistente = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: _surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
      ),
      Expanded(
        child: _cargandoAsistentes
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: _primary),
                    SizedBox(height: 12),
                    Text('Cargando asistentes...',
                        style: TextStyle(color: _muted, fontSize: 13)),
                  ],
                ),
              )
            : _asistentesFiltrados.isEmpty
                ? _buildEstadoVacio(
                    icon: Icons.people_outline,
                    titulo: 'Sin asistentes',
                    subtitulo: _buscarAsistente.isNotEmpty
                        ? 'No se encontraron resultados'
                        : 'No hay asistencias registradas en este evento',
                  )
                : RefreshIndicator(
                    onRefresh: () => _cargarAsistentes(
                        _eventoSeleccionado!['id'] as String),
                    color: _primary,
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 100),
                      itemCount: _asistentesFiltrados.length,
                      itemBuilder: (ctx, i) => _buildAsistenteCard(
                          _asistentesFiltrados[i],
                          _eventoSeleccionado!['id'] as String),
                    ),
                  ),
      ),
    ]);
  }

  Widget _buildAsistenteCard(Map<String, dynamic> asistente, String eventId) {
    final nombre = (asistente['studentName'] ?? 'Sin nombre').toString();
    final codigo = (asistente['studentCodigo'] ?? '').toString();
    final ciclo = (asistente['ciclo'] ?? '').toString();
    final grupo = (asistente['grupo'] ?? '').toString();
    final lastScan = asistente['lastScan'];
    final studentId = asistente['studentId'] as String;
    final scans =
        List<Map<String, dynamic>>.from(asistente['scans'] ?? []);
    final personales = List<Map<String, dynamic>>.from(
        asistente['registrosPersonales'] ?? []);
    final totalRegistros = scans.length + personales.length;
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _cardShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: CircleAvatar(
            backgroundColor: _primary,
            radius: 22,
            child: Text(inicial,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
          title: Text(nombre,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _primary),
              overflow: TextOverflow.ellipsis),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (codigo.isNotEmpty)
                  Text('Cód: $codigo',
                      style: const TextStyle(fontSize: 11, color: _muted)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (ciclo.isNotEmpty) _chip('Ciclo $ciclo', Colors.blue),
                  if (grupo.isNotEmpty) _chip('Grupo $grupo', Colors.purple),
                  _chip(
                      '$totalRegistros registro${totalRegistros != 1 ? 's' : ''}',
                      _success),
                  if (lastScan != null)
                    _chip(_formatTs(lastScan), Colors.orange),
                ]),
              ],
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: _danger, size: 22),
            tooltip: 'Eliminar todas las asistencias',
            onPressed: () => _eliminarTodasAsistencias(
                eventId: eventId, asistente: asistente),
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 10),
            if (scans.isNotEmpty) ...[
              _seccionLabel('Asistencias de proyectos', Icons.qr_code_2,
                  Colors.blue.shade700),
              ...scans.map((scan) => _buildScanRow(
                  scan: scan,
                  eventId: eventId,
                  studentId: studentId,
                  asistente: asistente)),
            ],
            if (personales.isNotEmpty) ...[
              if (scans.isNotEmpty) const SizedBox(height: 8),
              _seccionLabel('Asistencias personales',
                  Icons.how_to_reg_rounded, Colors.deepPurple.shade600),
              ...personales.map((reg) => _buildPersonalRow(
                  registro: reg,
                  eventId: eventId,
                  studentId: studentId)),
            ],
            if (scans.isEmpty && personales.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Sin registros detallados',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade400)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _seccionLabel(String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color)),
      ]),
    );
  }

  Widget _buildScanRow({
    required Map<String, dynamic> scan,
    required String eventId,
    required String studentId,
    required Map<String, dynamic> asistente,
  }) {
    final codigo = (scan['codigoProyecto'] ?? '—').toString();
    final titulo = (scan['tituloProyecto'] ?? '').toString();
    final cat = (scan['categoria'] ?? '').toString();
    final ts = scan['timestamp'];
    final method = (scan['registrationMethod'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.qr_code_2, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Código: $codigo',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: _primary)),
              if (cat.isNotEmpty)
                Text('Cat: $cat',
                    style: const TextStyle(fontSize: 11, color: _muted)),
              if (titulo.isNotEmpty)
                Text(titulo,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              Text(_formatTs(ts),
                  style: const TextStyle(fontSize: 10, color: _muted)),
              if (method == 'manual_superadmin')
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Text('Registrado manualmente',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
        Column(children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.edit_outlined,
                color: _primaryLight, size: 18),
            tooltip: 'Editar',
            onPressed: () => _editarScan(
                eventId: eventId,
                studentId: studentId,
                scan: scan),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon:
                const Icon(Icons.delete_outline, color: _danger, size: 18),
            tooltip: 'Eliminar',
            onPressed: () => _eliminarScan(
                eventId: eventId,
                studentId: studentId,
                scanId: scan['scanId'] as String,
                asistente: asistente),
          ),
        ]),
      ]),
    );
  }


  Widget _buildPersonalRow({
    required Map<String, dynamic> registro,
    required String eventId,
    required String studentId,
  }) {
    final nombre =
        (registro['asistenciaNombre'] ?? 'Personal').toString();
    final tipo = (registro['asistenciaTipo'] ?? '').toString();
    final ts = registro['timestamp'];
    final asistenciaId = registro['asistenciaId'] as String? ?? '';
    final method =
        (registro['registrationMethod'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Colors.deepPurple.withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: Colors.deepPurple.shade600,
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.how_to_reg_rounded,
              color: Colors.white, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: _primary)),
              if (tipo.isNotEmpty)
                Text('Tipo: $tipo',
                    style: const TextStyle(fontSize: 11, color: _muted)),
              Text(_formatTs(ts),
                  style: const TextStyle(fontSize: 10, color: _muted)),
              if (method == 'manual_superadmin')
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Text('Registrado manualmente',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
        Column(children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.edit_outlined,
                color: _primaryLight, size: 18),
            tooltip: 'Editar',
            onPressed: () => _editarRegistroPersonal(
                eventId: eventId,
                studentId: studentId,
                registro: registro),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon:
                const Icon(Icons.delete_outline, color: _danger, size: 18),
            tooltip: 'Eliminar',
            onPressed: () => _eliminarRegistroPersonal(
                eventId: eventId,
                asistenciaId: asistenciaId,
                studentId: studentId),
          ),
        ]),
      ]),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildEstadoVacio(
      {required IconData icon,
      required String titulo,
      required String subtitulo}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child:
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(titulo,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _primary),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitulo,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}




class _DialogEditarScan extends StatefulWidget {
  final Map<String, dynamic> scan;
  const _DialogEditarScan({required this.scan});

  @override
  State<_DialogEditarScan> createState() => _DialogEditarScanState();
}

class _DialogEditarScanState extends State<_DialogEditarScan> {
  static const Color _primary = Color(0xFF1E3A5F);

  late TextEditingController _codigoCtrl;
  late TextEditingController _tituloCtrl;
  late TextEditingController _categoriaCtrl;
  late TextEditingController _grupoCtrl;
  DateTime? _fechaHora;

  @override
  void initState() {
    super.initState();
    _codigoCtrl = TextEditingController(
        text: widget.scan['codigoProyecto']?.toString() ?? '');
    _tituloCtrl = TextEditingController(
        text: widget.scan['tituloProyecto']?.toString() ?? '');
    _categoriaCtrl = TextEditingController(
        text: widget.scan['categoria']?.toString() ?? '');
    _grupoCtrl =
        TextEditingController(text: widget.scan['grupo']?.toString() ?? '');
    final ts = widget.scan['timestamp'];
    if (ts is Timestamp) _fechaHora = ts.toDate();
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _tituloCtrl.dispose();
    _categoriaCtrl.dispose();
    _grupoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFechaHora() async {
    final now = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaHora ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (fecha == null) return;
    if (!mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaHora ?? now),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (hora == null) return;
    setState(() {
      _fechaHora =
          DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = _fechaHora != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(_fechaHora!)
        : 'No seleccionada';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit, color: _primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Text('Editar Scan de Proyecto',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: _primary)),
              ),
            ]),
            const SizedBox(height: 20),
            _field(_codigoCtrl, 'Código de proyecto', Icons.qr_code_2),
            const SizedBox(height: 12),
            _field(_tituloCtrl, 'Título de proyecto', Icons.article_outlined),
            const SizedBox(height: 12),
            _field(_categoriaCtrl, 'Categoría', Icons.category_outlined),
            const SizedBox(height: 12),
            _field(_grupoCtrl, 'Grupo', Icons.group_outlined),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickFechaHora,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today,
                      color: _primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Fecha y hora: $fmt',
                        style: TextStyle(
                            fontSize: 13,
                            color: _fechaHora != null
                                ? Colors.black87
                                : Colors.grey.shade400)),
                  ),
                  const Icon(Icons.edit, size: 16, color: Colors.grey),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final updates = <String, dynamic>{};
                  if (_codigoCtrl.text.trim().isNotEmpty) {
                    updates['codigoProyecto'] = _codigoCtrl.text.trim();
                  }
                  if (_tituloCtrl.text.trim().isNotEmpty) {
                    updates['tituloProyecto'] = _tituloCtrl.text.trim();
                  }
                  if (_categoriaCtrl.text.trim().isNotEmpty) {
                    updates['categoria'] = _categoriaCtrl.text.trim();
                  }
                  updates['grupo'] = _grupoCtrl.text.trim().isEmpty
                      ? null
                      : _grupoCtrl.text.trim();
                  if (_fechaHora != null) {
                    updates['timestamp'] = Timestamp.fromDate(_fechaHora!);
                  }
                  Navigator.pop(context, updates);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Guardar',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }
}




class _DialogEditarRegistroPersonal extends StatefulWidget {
  final Map<String, dynamic> registro;
  const _DialogEditarRegistroPersonal({required this.registro});

  @override
  State<_DialogEditarRegistroPersonal> createState() =>
      _DialogEditarRegistroPersonalState();
}

class _DialogEditarRegistroPersonalState
    extends State<_DialogEditarRegistroPersonal> {
  static const Color _primary = Color(0xFF1E3A5F);

  late TextEditingController _nombreCtrl;
  late TextEditingController _tipoCtrl;
  DateTime? _fechaHora;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(
        text: widget.registro['asistenciaNombre']?.toString() ?? '');
    _tipoCtrl = TextEditingController(
        text: widget.registro['asistenciaTipo']?.toString() ?? '');
    final ts = widget.registro['timestamp'];
    if (ts is Timestamp) _fechaHora = ts.toDate();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _tipoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFechaHora() async {
    final now = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaHora ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (fecha == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaHora ?? now),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (hora == null || !mounted) return;
    setState(() {
      _fechaHora =
          DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = _fechaHora != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(_fechaHora!)
        : 'No seleccionada';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit,
                    color: Colors.deepPurple.shade600, size: 20),
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Text('Editar Asistencia Personal',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: _primary)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              'Modifica el nombre, tipo y/o fecha del registro.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),


            TextField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nombre de la asistencia',
                prefixIcon: const Icon(Icons.label_outline, size: 18),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primary, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),


            TextField(
              controller: _tipoCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Tipo de asistencia',
                prefixIcon:
                    const Icon(Icons.how_to_reg_rounded, size: 18),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primary, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),


            GestureDetector(
              onTap: _pickFechaHora,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today,
                      color: _primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fecha y hora del registro',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                        const SizedBox(height: 2),
                        Text(fmt,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _fechaHora != null
                                    ? Colors.black87
                                    : Colors.grey.shade400)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_calendar_outlined,
                        size: 16, color: _primary),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 24),


            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  final updates = <String, dynamic>{};
                  if (_nombreCtrl.text.trim().isNotEmpty) {
                    updates['asistenciaNombre'] = _nombreCtrl.text.trim();
                  }
                  if (_tipoCtrl.text.trim().isNotEmpty) {
                    updates['asistenciaTipo'] = _tipoCtrl.text.trim();
                  }
                  if (_fechaHora != null) {
                    updates['timestamp'] = Timestamp.fromDate(_fechaHora!);
                  }
                  if (updates.isEmpty) {
                    Navigator.pop(context);
                    return;
                  }
                  Navigator.pop(context, updates);
                },
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Guardar',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}







class _DialogAgregarAsistencia extends StatefulWidget {
  final Map<String, dynamic> evento;
  final FirebaseFirestore firestore;

  const _DialogAgregarAsistencia({
    required this.evento,
    required this.firestore,
  });

  @override
  State<_DialogAgregarAsistencia> createState() =>
      _DialogAgregarAsistenciaState();
}

class _DialogAgregarAsistenciaState extends State<_DialogAgregarAsistencia> {
  static const Color _primary = Color(0xFF1E3A5F);
  static const Color _success = Color(0xFF43A047);
  static const Color _muted = Color(0xFF64748B);
  static const Color _warning = Color(0xFFF59E0B);

  int _paso = 0;


  final TextEditingController _buscarCtrl = TextEditingController();
  bool _buscando = false;
  List<Map<String, dynamic>> _resultados = [];
  final List<Map<String, dynamic>> _alumnosSeleccionados = [];


  bool _cargandoAsist = false;
  List<Map<String, dynamic>> _personales = [];
  List<Map<String, dynamic>> _proyectos = [];
  final Set<String> _asistSeleccionadasIds = {};
  final TextEditingController _buscarAsistCtrl = TextEditingController();
  String _queryAsist = '';


  DateTime _fechaHora = DateTime.now();

  @override
  void dispose() {
    _buscarCtrl.dispose();
    _buscarAsistCtrl.dispose();
    super.dispose();
  }


  String _asistKey(Map<String, dynamic> a) {
    final kind = a['_kind'] as String;
    if (kind == 'personal') return 'p_${a['asistenciaId']}';
    return 'q_${a['qrId']}';
  }

  List<Map<String, dynamic>> get _todasAsistencias {
    return [
      ..._personales.map((p) => {...p, '_kind': 'personal'}),
      ..._proyectos.map((q) => {...q, '_kind': 'proyecto'}),
    ];
  }

  List<Map<String, dynamic>> get _asistenciasFiltradas {
    final lista = _todasAsistencias;
    final q = _queryAsist.toLowerCase().trim();
    if (q.isEmpty) return lista;
    return lista.where((a) {
      final kind = a['_kind'] as String;
      if (kind == 'personal') {
        final nombre = (a['nombre'] ?? '').toString().toLowerCase();
        final desc = (a['descripcion'] ?? '').toString().toLowerCase();
        return nombre.contains(q) || desc.contains(q);
      } else {
        final cod = (a['codigoProyecto'] ?? '').toString().toLowerCase();
        final tit = (a['tituloProyecto'] ?? '').toString().toLowerCase();
        final cat = (a['categoria'] ?? '').toString().toLowerCase();
        final nom = (a['nombre'] ?? '').toString().toLowerCase();
        return cod.contains(q) ||
            tit.contains(q) ||
            cat.contains(q) ||
            nom.contains(q);
      }
    }).toList();
  }

  List<Map<String, dynamic>> get _asistSeleccionadasList =>
      _todasAsistencias.where((a) => _asistSeleccionadasIds.contains(_asistKey(a))).toList();


  Future<void> _buscarEstudiante() async {
    final q = _buscarCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _buscando = true;
      _resultados = [];
    });

    try {
      final futures = await Future.wait([
        widget.firestore
            .collectionGroup('students')
            .where('userType', isEqualTo: 'student')
            .orderBy('name')
            .startAt([q])
            .endAt(['$q\uf8ff'])
            .limit(10)
            .get(),
        widget.firestore
            .collectionGroup('students')
            .where('codigoUniversitario', isEqualTo: q)
            .limit(5)
            .get(),
        widget.firestore
            .collectionGroup('students')
            .where('username', isEqualTo: q.toLowerCase())
            .limit(5)
            .get(),
      ]);

      final Set<String> seen = {};
      final List<Map<String, dynamic>> encontrados = [];
      for (final snap in futures) {
        for (final doc in snap.docs) {
          if (seen.contains(doc.id)) continue;
          seen.add(doc.id);
          final data = Map<String, dynamic>.from(doc.data());
          data['studentId'] = doc.id;
          encontrados.add(data);
        }
      }

      if (mounted) setState(() => _resultados = encontrados);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error buscando: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _toggleAlumno(Map<String, dynamic> r) {
    final sid = r['studentId'] as String;
    setState(() {
      final idx = _alumnosSeleccionados.indexWhere((a) => a['studentId'] == sid);
      if (idx >= 0) {
        _alumnosSeleccionados.removeAt(idx);
      } else {
        _alumnosSeleccionados.add(r);
      }
    });
  }

  bool _alumnoEstaSeleccionado(String sid) =>
      _alumnosSeleccionados.any((a) => a['studentId'] == sid);


  Future<void> _cargarAsistenciasEvento() async {
    setState(() {
      _cargandoAsist = true;
      _personales = [];
      _proyectos = [];
    });
    final eventId = widget.evento['id'] as String;

    try {
      final results = await Future.wait([
        widget.firestore
            .collection('events')
            .doc(eventId)
            .collection('asistencias_personales')
            .get(),
        widget.firestore
            .collection('events')
            .doc(eventId)
            .collection('qr_codes')
            .get(),
      ]);

      final personales = results[0].docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['asistenciaId'] = d.id;
        return data;
      }).toList();

      final proyectos = results[1].docs
          .map((d) {
            final data = Map<String, dynamic>.from(d.data());
            data['qrId'] = d.id;
            return data;
          })
          .where((d) => (d['type']?.toString() ?? '') != 'asistencia_personal')
          .toList();

      if (mounted) {
        setState(() {
          _personales = personales;
          _proyectos = proyectos;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error cargando asistencias: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _cargandoAsist = false);
    }
  }


  Future<void> _pickFechaHora() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaHora,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (fecha == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaHora),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (hora == null || !mounted) return;
    setState(() {
      _fechaHora =
          DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
    });
  }


  void _confirmar() {
    Navigator.pop(context, {
      'tipo': 'bulk',
      'alumnos': List<Map<String, dynamic>>.from(_alumnosSeleccionados),
      'asistencias': _asistSeleccionadasList,
      'fechaHora': _fechaHora,
    });
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _paso == 0
            ? _buildPasoAlumnos()
            : _paso == 1
                ? _buildPasoAsistencias()
                : _buildPasoConfirmar(),
      ),
    );
  }




  Widget _buildPasoAlumnos() {
    return ConstrainedBox(
      key: const ValueKey('paso0'),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.group_add, color: _primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Seleccionar alumnos',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: _primary)),
                    Text('Paso 1 de 3',
                        style: TextStyle(fontSize: 11, color: _muted)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),


          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _buscarCtrl,
                  decoration: InputDecoration(
                    hintText: 'Nombre, código o usuario',
                    hintStyle:
                        TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    prefixIcon:
                        const Icon(Icons.search, color: _primary, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 13),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _buscarEstudiante(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _buscando ? null : _buscarEstudiante,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _buscando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search),
              ),
            ]),
          ),


          if (_alumnosSeleccionados.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _primary.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${_alumnosSeleccionados.length} alumno${_alumnosSeleccionados.length != 1 ? 's' : ''} seleccionado${_alumnosSeleccionados.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _primary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _alumnosSeleccionados.map((a) {
                        final nombre = (a['name'] ?? '—').toString();
                        return Chip(
                          label: Text(nombre,
                              style: const TextStyle(fontSize: 11)),
                          deleteIcon:
                              const Icon(Icons.close, size: 14),
                          onDeleted: () => _toggleAlumno(a),
                          backgroundColor: _primary.withValues(alpha: 0.08),
                          deleteIconColor: _primary,
                          labelStyle: const TextStyle(color: _primary),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),


          Flexible(
            child: _resultados.isEmpty && !_buscando
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          _buscarCtrl.text.isNotEmpty
                              ? 'No se encontraron estudiantes'
                              : 'Busca alumnos por nombre, código o usuario',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : _buscando
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child:
                              CircularProgressIndicator(color: _primary),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        itemCount: _resultados.length,
                        itemBuilder: (ctx, i) {
                          final r = _resultados[i];
                          final sid = r['studentId'] as String;
                          final nombre =
                              (r['name'] ?? 'Sin nombre').toString();
                          final codigo =
                              (r['codigoUniversitario'] ?? '').toString();
                          final carrera =
                              (r['carrera'] ?? '').toString();
                          final filial = (r['filial'] ?? '').toString();
                          final seleccionado =
                              _alumnoEstaSeleccionado(sid);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: seleccionado
                                  ? _success
                                  : _primary,
                              child: seleccionado
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 18)
                                  : Text(
                                      nombre.isNotEmpty
                                          ? nombre[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                            ),
                            title: Text(nombre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            subtitle: Text(
                                [
                                  if (codigo.isNotEmpty) 'Cód: $codigo',
                                  carrera,
                                  filial
                                ]
                                    .where((s) => s.isNotEmpty)
                                    .join(' · '),
                                style: const TextStyle(fontSize: 11)),
                            trailing: seleccionado
                                ? const Icon(Icons.check_circle,
                                    color: _success)
                                : const Icon(Icons.add_circle_outline,
                                    color: _primary),
                            onTap: () => _toggleAlumno(r),
                          );
                        },
                      ),
          ),


          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _alumnosSeleccionados.isEmpty
                    ? null
                    : () {
                        setState(() => _paso = 1);
                        unawaited(_cargarAsistenciasEvento());
                      },
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  _alumnosSeleccionados.isEmpty
                      ? 'Selecciona al menos un alumno'
                      : 'Siguiente → Elegir asistencias',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }




  Widget _buildPasoAsistencias() {
    final filtradas = _asistenciasFiltradas;
    final totalSelec = _asistSeleccionadasIds.length;
    final todosSeleccionados = filtradas.isNotEmpty &&
        filtradas.every((a) => _asistSeleccionadasIds.contains(_asistKey(a)));

    return ConstrainedBox(
      key: const ValueKey('paso1'),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: _primary),
                onPressed: () => setState(() => _paso = 0),
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Seleccionar asistencias',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: _primary)),
                    Text('Paso 2 de 3',
                        style: TextStyle(fontSize: 11, color: _muted)),
                  ],
                ),
              ),
            ]),
          ),


          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _buscarAsistCtrl,
              onChanged: (v) => setState(() => _queryAsist = v),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, código, categoría...',
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon:
                    const Icon(Icons.search, color: _primary, size: 18),
                suffixIcon: _queryAsist.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _buscarAsistCtrl.clear();
                          setState(() => _queryAsist = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: _primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),


          if (!_cargandoAsist && filtradas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(children: [
                Expanded(
                  child: Text(
                    '$totalSelec seleccionada${totalSelec != 1 ? 's' : ''} de ${_todasAsistencias.length}',
                    style:
                        const TextStyle(fontSize: 12, color: _muted),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (todosSeleccionados) {
                        for (final a in filtradas) {
                          _asistSeleccionadasIds.remove(_asistKey(a));
                        }
                      } else {
                        for (final a in filtradas) {
                          _asistSeleccionadasIds.add(_asistKey(a));
                        }
                      }
                    });
                  },
                  icon: Icon(
                    todosSeleccionados
                        ? Icons.deselect
                        : Icons.select_all,
                    size: 16,
                  ),
                  label: Text(
                    todosSeleccionados
                        ? 'Deseleccionar visibles'
                        : 'Seleccionar visibles',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ]),
            ),

          const Divider(height: 1),


          Flexible(
            child: _cargandoAsist
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: _primary),
                    ),
                  )
                : filtradas.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              _queryAsist.isNotEmpty
                                  ? 'Sin resultados para "$_queryAsist"'
                                  : 'Este evento no tiene asistencias creadas',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        itemCount: filtradas.length,
                        itemBuilder: (ctx, i) {
                          final a = filtradas[i];
                          final key = _asistKey(a);
                          final kind = a['_kind'] as String;
                          final selec =
                              _asistSeleccionadasIds.contains(key);

                          final String titulo;
                          final String subtitulo;
                          final IconData icon;
                          final Color color;

                          if (kind == 'personal') {
                            titulo = (a['nombre'] ?? 'Asistencia personal')
                                .toString();
                            subtitulo =
                                (a['descripcion'] ?? '').toString();
                            icon = Icons.how_to_reg_rounded;
                            color = Colors.deepPurple.shade600;
                          } else {
                            final cod =
                                (a['codigoProyecto'] ?? '').toString();
                            final nom =
                                (a['nombre'] ?? '').toString();
                            titulo = cod.isNotEmpty
                                ? 'Código: $cod'
                                : (nom.isNotEmpty ? nom : 'Proyecto');
                            final cat =
                                (a['categoria'] ?? '').toString();
                            final tit =
                                (a['tituloProyecto'] ?? '').toString();
                            subtitulo = [
                              if (cat.isNotEmpty) cat,
                              if (tit.isNotEmpty) tit,
                            ].join(' · ');
                            icon = Icons.qr_code_2;
                            color = Colors.blue.shade700;
                          }

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (selec) {
                                  _asistSeleccionadasIds.remove(key);
                                } else {
                                  _asistSeleccionadasIds.add(key);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: selec
                                    ? color.withValues(alpha: 0.1)
                                    : color.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selec
                                      ? color.withValues(alpha: 0.6)
                                      : color.withValues(alpha: 0.2),
                                  width: selec ? 1.5 : 1,
                                ),
                              ),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                      color: color,
                                      borderRadius:
                                          BorderRadius.circular(9)),
                                  child: Icon(icon,
                                      color: Colors.white, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(titulo,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: selec
                                                  ? color
                                                  : _primary),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis),
                                      if (subtitulo.isNotEmpty)
                                        Text(subtitulo,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: _muted),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedSwitcher(
                                  duration:
                                      const Duration(milliseconds: 150),
                                  child: selec
                                      ? Icon(Icons.check_circle,
                                          key: const ValueKey('checked'),
                                          color: color,
                                          size: 22)
                                      : Icon(Icons.circle_outlined,
                                          key: const ValueKey('unchecked'),
                                          color: Colors.grey.shade400,
                                          size: 22),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
          ),


          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _asistSeleccionadasIds.isEmpty
                    ? null
                    : () {
                        _fechaHora = DateTime.now();
                        setState(() => _paso = 2);
                      },
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  _asistSeleccionadasIds.isEmpty
                      ? 'Selecciona al menos una asistencia'
                      : 'Siguiente → Confirmar (${_asistSeleccionadasIds.length} asist. × ${_alumnosSeleccionados.length} alumnos)',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }




  Widget _buildPasoConfirmar() {
    final asistencias = _asistSeleccionadasList;
    final alumnos = _alumnosSeleccionados;
    final fmt = DateFormat('dd/MM/yyyy HH:mm').format(_fechaHora);
    final totalRegistros = alumnos.length * asistencias.length;

    return SingleChildScrollView(
      key: const ValueKey('paso2'),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: _primary),
              onPressed: () => setState(() => _paso = 1),
            ),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Confirmar registro masivo',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: _primary)),
                  Text('Paso 3 de 3',
                      style: TextStyle(fontSize: 11, color: _muted)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),


          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_primary, Color(0xFF2D5F8D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              const Icon(Icons.bolt, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalRegistros registros a crear',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    Text(
                      '${alumnos.length} alumno${alumnos.length != 1 ? 's' : ''} × ${asistencias.length} asistencia${asistencias.length != 1 ? 's' : ''}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),


          _resumenSeccion(
            'Alumnos',
            Icons.group,
            Colors.blue.shade700,
            alumnos.map((a) {
              final nombre = (a['name'] ?? '—').toString();
              final cod = (a['codigoUniversitario'] ?? '').toString();
              return cod.isNotEmpty ? '$nombre  ·  $cod' : nombre;
            }).toList(),
          ),
          const SizedBox(height: 10),


          _resumenSeccion(
            'Asistencias',
            Icons.assignment_turned_in_outlined,
            Colors.deepPurple.shade600,
            asistencias.map((a) {
              final kind = a['_kind'] as String;
              if (kind == 'personal') {
                return (a['nombre'] ?? 'Personal').toString();
              }
              final cod = (a['codigoProyecto'] ?? '').toString();
              final nom = (a['nombre'] ?? '').toString();
              return cod.isNotEmpty
                  ? 'Cód: $cod'
                  : (nom.isNotEmpty ? nom : 'Proyecto');
            }).toList(),
          ),
          const SizedBox(height: 10),


          GestureDetector(
            onTap: _pickFechaHora,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.access_time, color: _primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fecha y hora de registro',
                          style:
                              TextStyle(fontSize: 11, color: _muted)),
                      Text(fmt,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_calendar_outlined,
                      size: 15, color: _primary),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),


          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _warning.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: _warning, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sin restricciones: se omiten validaciones de pago, carrera y cooldown. Los duplicados se saltarán automáticamente.',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange.shade800,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),


          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _confirmar,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                'Registrar $totalRegistros asistencia${totalRegistros != 1 ? 's' : ''}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumenSeccion(
      String titulo, IconData icon, Color color, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(titulo,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: items.map((label) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}