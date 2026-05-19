import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import '/prefs_helper.dart';
import 'certificado_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTES DE COLOR
// ─────────────────────────────────────────────────────────────────────────────
const _kPrimario       = Color(0xFF1E3A5F);
const _kPrimario10     = Color(0x1A1E3A5F);
const _kPrimario40     = Color(0x661E3A5F);
const _kPrimario50     = Color(0x801E3A5F);
const _kTextoGris      = Color(0xFF64748B);
const _kTextoGrisClaro = Color(0xFF94A3B8);
const _kTextoOscuro    = Color(0xFF334155);
const _kFondo          = Color(0xFFE8EDF2);
const _kCampoFondo     = Color(0xFFF8FAFC);
const _kCampoFondo2    = Color(0xFFF1F5F9);

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────
String _fechaActual(String ciudad) {
  final now = DateTime.now();
  const meses = [
    '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  return '${now.day} de ${meses[now.month]} de ${now.year}';
}

String _generarFacultadId(String texto) => texto
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]'), '_')
    .replaceAll(RegExp(r'_+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');

String _motivoPorRol({
  required String rol,
  required String evento,
  required String fecha,
  required String carrera,
  required String horas,
  required String tituloPonencia,
  required String modalidadPonencia,
}) {
  switch (rol) {
    case 'PONENTE':
      return 'Por su valioso aporte en calidad de PONENTE, en la "$evento", '
          'desarrollado el $fecha, donde exhibió la investigación titulada '
          '"$tituloPonencia". en presentación $modalidadPonencia.';
    case 'JURADO':
      return 'Por su participación en calidad de JURADO en la "$evento", '
          'organizado por la Escuela Profesional de $carrera; '
          'realizado el $fecha. Su experticia y conocimientos han contribuido '
          'significativamente en la evaluación de trabajos de investigación.';
    case 'ORGANIZADOR':
      return 'Por su participación en calidad de ORGANIZADOR en la "$evento", '
          'promovido por la Escuela Profesional de $carrera; '
          'realizado el $fecha, su apoyo ha contribuido en el éxito y el '
          'desarrollo del evento científico.';
    case 'ASISTENTE':
    default:
      return 'Por su participación en calidad de ASISTENTE en la "$evento", '
          'organizado por la Escuela Profesional de $carrera; '
          'realizado el $fecha, con equivalencia a un total de $horas horas académicas.';
  }
}

class _Firmante {
  final String nombre;
  final String cargo;
  final String urlFirma;
  final Uint8List? bytesImagen;

  const _Firmante({
    this.nombre    = '',
    this.cargo     = '',
    this.urlFirma  = '',
    this.bytesImagen,
  });

  bool get configurado => nombre.isNotEmpty;

  factory _Firmante.fromDoc(Map<String, dynamic>? d) {
    if (d == null) return const _Firmante();
    final grado  = (d['grado']  as String? ?? '').trim();
    final nombre = (d['nombre'] as String? ?? '').trim();
    return _Firmante(
      nombre:   grado.isEmpty ? nombre : '$grado $nombre',
      cargo:    (d['cargo']      as String? ?? '').trim(),
      urlFirma: (d['storageUrl'] as String? ?? '').trim(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class GenerarCertificadosScreen extends StatefulWidget {
  const GenerarCertificadosScreen({super.key});

  @override
  State<GenerarCertificadosScreen> createState() =>
      _GenerarCertificadosScreenState();
}

class _GenerarCertificadosScreenState
    extends State<GenerarCertificadosScreen> {
  // ── Datos del admin ──────────────────────────────────────────────────────
  String _carrera  = '';
  String _facultad = '';
  String _sede     = '';
  String _filial   = '';
  String _filialId  = '';
  String _carreraId = '';

  // ── Firmantes cargados de Firestore ──────────────────────────────────────
  _Firmante _firma1 = const _Firmante();
  _Firmante _firma2 = const _Firmante();
  _Firmante _firma3 = const _Firmante();
  bool _firmasConfiguradas = false;

  // ── Formulario ───────────────────────────────────────────────────────────
  late final TextEditingController _fechaController;
  final _horasController          = TextEditingController(text: '16');
  final _eventoController         = TextEditingController(
      text: 'XXI JORNADA CIENTÍFICA DE INVESTIGACIÓN E INNOVACIÓN');
  final _tituloPonenciaController = TextEditingController(text: 'xxxx');
  late final TextEditingController _motivoController;

  String _modalidadPonencia = 'ORAL';
  String _rolParticipante   = 'ASISTENTE';

  // ── Estudiantes ──────────────────────────────────────────────────────────
  List<Estudiante> _estudiantes = [];
  List<Estudiante> _estudiantesFiltrados = [];
  int _seleccionadosCount = 0;

  Map<String, String> _titulosPorCodigo = {};

  bool _isLoading = false;
  bool _generando = false;
  bool _enviando  = false;

  String _searchQuery = '';
  final _searchController = TextEditingController();
  Timer? _debounceSearch;

  int  _enviados    = 0;
  int  _totalEnviar = 0;
  bool _cancelarEnvio = false;

  bool _seccionConfig = true;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fechaController  = TextEditingController(text: _fechaActual('Juliaca'));
    _motivoController = TextEditingController(text: _motivoPorRol(
      rol: _rolParticipante,
      evento: 'XXI JORNADA CIENTÍFICA DE INVESTIGACIÓN E INNOVACIÓN',
      fecha: _fechaActual('Juliaca'),
      carrera: '',
      horas: '16',
      tituloPonencia: 'xxxx',
      modalidadPonencia: 'ORAL',
    ));
    _init();
  }

  @override
  void dispose() {
    _cancelarEnvio = true;
    _debounceSearch?.cancel();
    _fechaController.dispose();
    _horasController.dispose();
    _eventoController.dispose();
    _tituloPonenciaController.dispose();
    _motivoController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _init() async {
    setState(() => _isLoading = true);
    final data = await PrefsHelper.getAdminCarreraData();
    if (data != null) {
      setState(() {
        _carrera  = data['carrera']      ?? '';
        _facultad = data['facultad']     ?? '';
        _sede     = data['filialNombre'] ?? '';
        _filial   = data['filialNombre'] ?? '';
        _filialId  = data['filial']    ?? '';
        _carreraId = data['carreraId'] ?? data['carrera'] ?? '';
        _fechaController.text = _fechaActual(_sede);
      });
      _actualizarMotivo();
      await Future.wait([
        _cargarFirmantes(),
        _cargarEstudiantes(),
        _cargarTitulosProyectos(),
      ]);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CARGAR TÍTULOS DE PROYECTOS POR CÓDIGO DE INTEGRANTE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _cargarTitulosProyectos() async {
    try {
      final eventosSnap = await FirebaseFirestore.instance
          .collection('events')
          .where('filialId', isEqualTo: _filialId)
          .where('facultad', isEqualTo: _facultad)
          .where('carreraId', isEqualTo: _carreraId)
          .get();

      final Map<String, String> mapa = {};

      for (final eventoDoc in eventosSnap.docs) {
        final proyectosSnap = await FirebaseFirestore.instance
            .collection('events')
            .doc(eventoDoc.id)
            .collection('proyectos')
            .get();

        for (final proyectoDoc in proyectosSnap.docs) {
          final data   = proyectoDoc.data();
          final titulo = data['Título']?.toString() ?? '';
          if (titulo.isEmpty) continue;

          final integrantes = data['Integrantes'];
          List<String> codigos = [];
          if (integrantes is List) {
            codigos = integrantes.map((e) => e.toString()).toList();
          } else if (integrantes is String && integrantes.isNotEmpty) {
            codigos = integrantes.split(',').map((e) => e.trim()).toList();
          }

          for (final codigo in codigos) {
            if (codigo.isNotEmpty) mapa[codigo] = titulo;
          }
        }
      }

      if (mounted) setState(() => _titulosPorCodigo = mapa);
      debugPrint('✅ Títulos cargados: ${mapa.length} integrantes mapeados');
    } catch (e) {
      debugPrint('Error cargando títulos de proyectos: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CARGAR FIRMANTES DESDE FIRESTORE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _cargarFirmantes() async {
    try {
      final db = FirebaseFirestore.instance;

      final vSnap = await db
          .collection('config_firmas')
          .doc('vicerrector')
          .get();

      final dSnap = await db
          .collection('config_firmas')
          .doc('director_investigacion')
          .get();

      final facultadId = _generarFacultadId(_facultad);
      final decSnap = await db
          .collection('config_firmas')
          .doc('decanos')
          .collection('facultades')
          .doc(facultadId)
          .get();

      final f1 = _Firmante.fromDoc(vSnap.exists   ? vSnap.data()   : null);
      final f2 = _Firmante.fromDoc(decSnap.exists ? decSnap.data() : null);
      final f3 = _Firmante.fromDoc(dSnap.exists   ? dSnap.data()   : null);

      if (mounted) {
        setState(() {
          _firma1 = f1;
          _firma2 = f2;
          _firma3 = f3;
          _firmasConfiguradas =
              f1.configurado || f2.configurado || f3.configurado;
        });
      }

      debugPrint('✅ Firmantes cargados:');
      debugPrint('  Firma1 (Vicerrector): ${f1.nombre}');
      debugPrint('  Firma2 (Decano $facultadId): ${f2.nombre}');
      debugPrint('  Firma3 (Director Inv): ${f3.nombre}');
    } catch (e) {
      debugPrint('Error cargando firmantes: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  void _actualizarMotivo() {
    _motivoController.text = _motivoPorRol(
      rol:               _rolParticipante,
      evento:            _eventoController.text,
      fecha:             _fechaController.text,
      carrera:           _carrera,
      horas:             _horasController.text,
      tituloPonencia:    _tituloPonenciaController.text,
      modalidadPonencia: _modalidadPonencia,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _cargarEstudiantes() async {
    try {
      final docKey = '${_filial}_$_carrera';
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(docKey)
          .collection('students')
          .orderBy('name')
          .get();

      final lista = snap.docs.map((doc) {
        final d = doc.data();
        return Estudiante(
          id:     doc.id,
          nombre: d['name']                ?? 'Sin nombre',
          dni:    d['dni']                 ?? '',
          codigo: d['codigoUniversitario'] ?? '',
          email:  d['email']              ?? '',
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _estudiantes = lista;
        _actualizarFiltros(notify: false);
      });
    } catch (e) {
      debugPrint('Error cargando estudiantes: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  void _actualizarFiltros({bool notify = true}) {
    final q = _searchQuery.toLowerCase();
    final filtrados = _estudiantes.where((e) {
      if (q.isEmpty) return true;
      return e.nombre.toLowerCase().contains(q) ||
          e.dni.contains(q) ||
          e.codigo.toLowerCase().contains(q);
    }).toList();

    if (notify) {
      setState(() => _estudiantesFiltrados = filtrados);
    } else {
      _estudiantesFiltrados = filtrados;
    }
  }

  void _toggleEstudiante(Estudiante est, bool val) {
    setState(() {
      est.seleccionado = val;
      _seleccionadosCount += val ? 1 : -1;
    });

    if (_rolParticipante == 'PONENTE') {
      final seleccionados = _estudiantes.where((e) => e.seleccionado).toList();
      if (seleccionados.length == 1) {
        final titulo = _titulosPorCodigo[seleccionados.first.codigo];
        if (titulo != null && titulo.isNotEmpty) {
          setState(() => _tituloPonenciaController.text = titulo);
          _actualizarMotivo();
        }
      }
    }
  }

  void _toggleTodos(bool? val) {
    final seleccionar = val ?? false;
    setState(() {
      for (final e in _estudiantesFiltrados) {
        if (e.seleccionado != seleccionar) {
          e.seleccionado = seleccionar;
          _seleccionadosCount += seleccionar ? 1 : -1;
        }
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  DatosCertificado get _datosCertificado => DatosCertificado(
        facultad:  _facultad,
        carrera:   _carrera,
        campus:    _sede,
        motivo:    _motivoController.text,
        fecha:     _fechaController.text,
        horas:     _horasController.text,
        evento:    _eventoController.text,
        rol:       _rolParticipante,
        director1: _firma1.nombre,
        cargo1:    _firma1.cargo,
        director2: _firma2.nombre,
        cargo2:    _firma2.cargo,
        director3: _firma3.nombre,
        cargo3:    _firma3.cargo,
      );

  Future<Uint8List?> _descargarFirma(String url) async {
    if (url.isEmpty) return null;

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        debugPrint('✅ Firma descargada directo (${response.bodyBytes.length}b)');
        return response.bodyBytes;
      }
      debugPrint('HTTP ${response.statusCode} — intentando refrescar URL...');
    } catch (e) {
      debugPrint('Error HTTP directo: $e — intentando refrescar...');
    }

    try {
      final uri      = Uri.parse(url);
      final segments = uri.path.split('/o/');
      if (segments.length < 2) return null;
      final fullPath = Uri.decodeComponent(segments.last.split('?').first);
      final newUrl   = await FirebaseStorage.instance
          .ref(fullPath)
          .getDownloadURL();
      final response = await http
          .get(Uri.parse(newUrl))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        debugPrint('✅ Firma descargada con URL refrescada');
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('❌ Error refrescando URL: $e');
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GENERAR PDF
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _generarCertificados() async {
    final seleccionados = _estudiantes.where((e) => e.seleccionado).toList();
    if (seleccionados.isEmpty) {
      _snack('Selecciona al menos un estudiante');
      return;
    }

    if (!_firmasConfiguradas) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
            SizedBox(width: 10),
            Text('Sin firmantes configurados',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                    color: _kPrimario)),
          ]),
          content: const Text(
            'No hay firmantes configurados. El certificado se generará '
            'sin imágenes de firma. ¿Deseas continuar?',
            style: TextStyle(fontSize: 14, color: _kTextoGris),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: _kTextoGris)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimario,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Continuar sin firmas'),
            ),
          ],
        ),
      );
      if (continuar != true) return;
    }

    setState(() => _generando = true);

    try {
      await _cargarFirmantes();

      final bytes1 = await _descargarFirma(_firma1.urlFirma);
      final bytes2 = await _descargarFirma(_firma2.urlFirma);
      final bytes3 = await _descargarFirma(_firma3.urlFirma);

      debugPrint('Firmas descargadas — '
          'F1: ${bytes1?.length ?? 0}b  '
          'F2: ${bytes2?.length ?? 0}b  '
          'F3: ${bytes3?.length ?? 0}b');

      final datos = DatosCertificado(
        facultad:    _facultad,
        carrera:     _carrera,
        campus:      _sede,
        motivo:      _motivoController.text,
        fecha:       _fechaController.text,
        horas:       _horasController.text,
        evento:      _eventoController.text,
        rol:         _rolParticipante,
        director1:   _firma1.nombre,  cargo1: _firma1.cargo,
        director2:   _firma2.nombre,  cargo2: _firma2.cargo,
        director3:   _firma3.nombre,  cargo3: _firma3.cargo,
        bytesFirma1: bytes1,
        bytesFirma2: bytes2,
        bytesFirma3: bytes3,
      );

      final builder  = CertificadoBuilder(datos);
      final pdfBytes = await builder.buildPdf(seleccionados);
      if (!mounted) return;

      if (seleccionados.length == 1) {
        await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
      } else {
        await Printing.sharePdf(
          bytes:    pdfBytes,
          filename: 'certificados_${_carrera.replaceAll(' ', '_')}.pdf',
        );
      }
    } catch (e) {
      if (mounted) _snack('Error generando PDF: $e');
      debugPrint('Error generando PDF: $e');
    }

    if (mounted) setState(() => _generando = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ENVIAR CERTIFICADOS
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _enviarCertificados() async {
    final seleccionados = _estudiantes.where((e) => e.seleccionado).toList();
    if (seleccionados.isEmpty) {
      _snack('Selecciona al menos un estudiante');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.send_rounded, color: _kPrimario, size: 26),
          SizedBox(width: 10),
          Text('Enviar certificados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kPrimario)),
        ]),
        content: Text(
          'Se enviarán ${seleccionados.length} certificado(s) a los estudiantes '
          'seleccionados. Podrán verlos y descargarlos desde su panel.',
          style: const TextStyle(fontSize: 14, color: _kTextoGris),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: _kTextoGris)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimario, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    _cancelarEnvio = false;
    if (mounted) {
      setState(() {
        _enviando    = true;
        _enviados    = 0;
        _totalEnviar = seleccionados.length;
      });
    }

    try {
      const batchSize = 500;
      final docKey    = '${_filial}_$_carrera';
      final datos = {
        ..._datosCertificado.toMap(),
        'urlFirma1': _firma1.urlFirma,
        'urlFirma2': _firma2.urlFirma,
        'urlFirma3': _firma3.urlFirma,
      };
      final ahora  = Timestamp.now();
      int errores  = 0;

      for (int i = 0; i < seleccionados.length; i += batchSize) {
        if (_cancelarEnvio) break;

        final lote  = seleccionados.skip(i).take(batchSize).toList();
        final batch = FirebaseFirestore.instance.batch();

        for (final est in lote) {
          // ── Código único por estudiante (guardado solo en Firestore, no visible en PDF) ──
          final codigoUnico =
              'EVT-${DateTime.now().year}-'
              '${est.codigo.isNotEmpty ? est.codigo : est.dni}-'
              '${DateTime.now().millisecondsSinceEpoch}';

          final ref = FirebaseFirestore.instance
              .collection('users')
              .doc(docKey)
              .collection('students')
              .doc(est.id)
              .collection('certificados')
              .doc('${datos['rol']}_${DateTime.now().millisecondsSinceEpoch}');

          batch.set(ref, {
            ...datos,
            'creadoEn':          ahora,
            'nombreEstudiante':  est.nombre,
            'codigoCertificado': codigoUnico, // ← oculto en Firestore, no aparece en PDF
          });
        }

        try {
          await batch.commit();
          if (mounted) setState(() => _enviados += lote.length);
        } catch (e) {
          errores += lote.length;
          debugPrint('Error en batch [$i – ${i + lote.length}]: $e');
        }
      }

      if (!mounted) return;
      if (errores == 0) {
        _snack('✅ ${seleccionados.length} certificado(s) enviados correctamente');
      } else {
        _snack('⚠️ $_enviados enviados, $errores con error');
      }
    } catch (e) {
      if (mounted) _snack('Error al enviar certificados: $e');
    }

    if (mounted) setState(() => _enviando = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ELIMINAR CERTIFICADOS
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _eliminarCertificados() async {
    final seleccionados = _estudiantes.where((e) => e.seleccionado).toList();
    if (seleccionados.isEmpty) {
      _snack('Selecciona al menos un estudiante');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.delete_forever, color: Colors.red, size: 26),
          SizedBox(width: 10),
          Text('Eliminar certificados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
        ]),
        content: Text(
          'Se eliminarán TODOS los certificados enviados de '
          '${seleccionados.length} estudiante(s). Esta acción no se puede deshacer.',
          style: const TextStyle(fontSize: 14, color: _kTextoGris),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: _kTextoGris)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _enviando = true);

    try {
      final docKey   = '${_filial}_$_carrera';
      int eliminados = 0;

      for (final est in seleccionados) {
        if (_cancelarEnvio) break;
        final colRef = FirebaseFirestore.instance
            .collection('users')
            .doc(docKey)
            .collection('students')
            .doc(est.id)
            .collection('certificados');

        final snap  = await colRef.get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snap.docs) batch.delete(doc.reference);
        await batch.commit();
        eliminados++;
      }

      if (mounted) _snack('🗑️ Certificados eliminados de $eliminados estudiante(s)');
    } catch (e) {
      if (mounted) _snack('Error al eliminar: $e');
    }

    if (mounted) setState(() => _enviando = false);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _kPrimario,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPrimario,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _kFondo,
                borderRadius: BorderRadius.only(
                  topLeft:  Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _kPrimario))
                  : _buildBody(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.all(20),
    child: Row(children: [
      Container(
        width: 50, height: 50,
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(12)),
        child: Image.asset('assets/logo.png', fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
                Icons.workspace_premium, color: _kPrimario, size: 28)),
      ),
      const SizedBox(width: 16),
      const Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Generar Certificados',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          Text('Selecciona estudiantes y personaliza',
              style: TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
      ),
      IconButton(
        icon: const Icon(Icons.close, color: Colors.white, size: 26),
        onPressed: () => Navigator.pop(context),
      ),
    ]),
  );

  Widget _buildBody() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _buildCardFirmantes(),
      const SizedBox(height: 12),
      _buildCardConfig(),
      const SizedBox(height: 12),
      _buildCardEstudiantes(),
      const SizedBox(height: 20),
      _buildBotonesAccion(),
      const SizedBox(height: 20),
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // CARD FIRMANTES
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCardFirmantes() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kPrimario10, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.draw_outlined, color: _kPrimario, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Firmantes del Certificado',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kPrimario)),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _kTextoGrisClaro, size: 20),
              onPressed: () async {
                await _cargarFirmantes();
                _snack('Firmantes actualizados');
              },
              tooltip: 'Recargar firmantes',
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildFirmanteChip('Firma 1', 'Vicerrector', _firma1)),
            const SizedBox(width: 8),
            Expanded(child: _buildFirmanteChip('Firma 2', 'Decano', _firma2)),
            const SizedBox(width: 8),
            Expanded(child: _buildFirmanteChip('Firma 3', 'Dir. Inv.', _firma3)),
          ]),
          if (!_firmasConfiguradas) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'No hay firmantes configurados. Ve al panel de Super Admin → Configurar Firmas.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFirmanteChip(String etiqueta, String rol, _Firmante f) {
    final ok       = f.configurado;
    final tieneImg = f.urlFirma.isNotEmpty;
    final color    = ok && tieneImg
        ? const Color(0xFF16A34A)
        : ok
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text(etiqueta,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Icon(
          ok && tieneImg
              ? Icons.check_circle
              : ok
                  ? Icons.warning_amber
                  : Icons.error_outline,
          color: color, size: 18,
        ),
        const SizedBox(height: 2),
        Text(rol, style: const TextStyle(fontSize: 9, color: _kTextoGris)),
        Text(
          ok && tieneImg ? 'Listo' : ok ? 'Sin imagen' : 'Pendiente',
          style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CARD CONFIGURACIÓN
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCardConfig() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.edit_document,
            title: 'Configurar Certificado',
            expanded: _seccionConfig,
            onToggle: () => setState(() => _seccionConfig = !_seccionConfig),
          ),
          if (_seccionConfig) ...[
            const SizedBox(height: 16),
            const Text('Rol del participante',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimario)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: ['ASISTENTE', 'PONENTE', 'JURADO', 'ORGANIZADOR']
                  .map((rol) => ChoiceChip(
                        label: Text(rol,
                            style: TextStyle(fontSize: 11,
                                color: _rolParticipante == rol ? Colors.white : _kPrimario)),
                        selected: _rolParticipante == rol,
                        selectedColor: _kPrimario,
                        backgroundColor: Colors.grey.shade100,
                        onSelected: (_) => setState(() {
                          _rolParticipante = rol;
                          _actualizarMotivo();
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),
            _Campo(controller: _eventoController, label: 'Nombre del evento',
                icon: Icons.event, maxLines: 2,
                onChanged: (_) => setState(() => _actualizarMotivo())),
            const SizedBox(height: 12),
            if (_rolParticipante == 'ASISTENTE') ...[
              _Campo(controller: _horasController, label: 'Horas académicas',
                  icon: Icons.timer_outlined, keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() => _actualizarMotivo())),
              const SizedBox(height: 12),
            ],
            if (_rolParticipante == 'PONENTE') ...[
              _Campo(controller: _tituloPonenciaController,
                  label: 'Título de la investigación',
                  icon: Icons.article_outlined, maxLines: 2,
                  onChanged: (_) => setState(() => _actualizarMotivo())),
              const SizedBox(height: 12),
              const Text('Modalidad de presentación',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimario)),
              const SizedBox(height: 8),
              Row(
                children: ['ORAL', 'POSTER']
                    .map((m) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            label: Text(m, style: TextStyle(fontSize: 11,
                                color: _modalidadPonencia == m ? Colors.white : _kPrimario)),
                            selected: _modalidadPonencia == m,
                            selectedColor: _kPrimario,
                            backgroundColor: Colors.grey.shade100,
                            onSelected: (_) => setState(() {
                              _modalidadPonencia = m;
                              _actualizarMotivo();
                            }),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            _Campo(controller: _fechaController, label: 'Fecha de emisión',
                icon: Icons.calendar_today,
                onChanged: (_) => setState(() => _actualizarMotivo())),
            const SizedBox(height: 16),
            const Text('Motivo del certificado',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimario)),
            const SizedBox(height: 8),
            _Campo(controller: _motivoController, label: 'Motivo',
                icon: Icons.description_outlined, maxLines: 5),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _actualizarMotivo()),
                icon: const Icon(Icons.refresh, size: 14, color: _kPrimario),
                label: const Text('Regenerar automáticamente',
                    style: TextStyle(fontSize: 11, color: _kPrimario)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CARD ESTUDIANTES
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCardEstudiantes() {
    final todosSeleccionados = _estudiantesFiltrados.isNotEmpty &&
        _estudiantesFiltrados.every((e) => e.seleccionado);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _kPrimario10, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.people_alt_outlined, color: _kPrimario, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Seleccionar Estudiantes',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kPrimario)),
                Text('$_seleccionadosCount de ${_estudiantes.length} seleccionados',
                    style: const TextStyle(fontSize: 11, color: _kTextoGris)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (q) {
              _debounceSearch?.cancel();
              _debounceSearch = Timer(const Duration(milliseconds: 300), () {
                _searchQuery = q;
                _actualizarFiltros();
              });
            },
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, DNI o código...',
              hintStyle: const TextStyle(fontSize: 12, color: _kTextoGrisClaro),
              prefixIcon: const Icon(Icons.search, color: _kTextoGrisClaro, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: _kTextoGrisClaro, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _searchQuery = '';
                        _actualizarFiltros();
                      },
                    )
                  : null,
              filled: true, fillColor: _kCampoFondo2,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Todos los estudiantes',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kPrimario)),
            const Spacer(),
            const Text('Todos', style: TextStyle(fontSize: 11, color: _kTextoGris)),
            Checkbox(
              value: todosSeleccionados,
              onChanged: _toggleTodos,
              activeColor: _kPrimario,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ]),
          const SizedBox(height: 6),
          if (_estudiantesFiltrados.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  _estudiantes.isEmpty
                      ? 'No hay estudiantes registrados'
                      : 'Sin resultados para "$_searchQuery"',
                  style: const TextStyle(
                      color: _kTextoGrisClaro, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            _buildListaEstudiantes(_estudiantesFiltrados),
        ],
      ),
    );
  }

  Widget _buildListaEstudiantes(List<Estudiante> lista) {
    final itemH      = _rolParticipante == 'PONENTE' ? 70.0 : 57.0;
    const maxVisible = 8;
    final height     = (lista.length > maxVisible
            ? maxVisible * itemH
            : lista.length * itemH)
        .clamp(itemH, double.infinity);

    return SizedBox(
      height: height,
      child: ListView.separated(
        itemCount: lista.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, i) => _buildEstudianteItem(lista[i]),
      ),
    );
  }

  Widget _buildEstudianteItem(Estudiante est) {
    final tituloProyecto = _rolParticipante == 'PONENTE'
        ? _titulosPorCodigo[est.codigo]
        : null;

    return InkWell(
      key: ValueKey(est.id),
      onTap: () => _toggleEstudiante(est, !est.seleccionado),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: est.seleccionado ? _kPrimario : _kCampoFondo2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                est.nombre.isNotEmpty ? est.nombre[0].toUpperCase() : '?',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: est.seleccionado ? Colors.white : _kPrimario,
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(est.nombre,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: est.seleccionado ? _kPrimario : _kTextoOscuro)),
              if (est.dni.isNotEmpty || est.codigo.isNotEmpty)
                Text(
                  [
                    if (est.codigo.isNotEmpty) est.codigo,
                  ].join('  ·  '),
                  style: const TextStyle(fontSize: 11, color: _kTextoGrisClaro),
                ),
              if (tituloProyecto != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.article_outlined,
                      size: 11, color: Color(0xFF16A34A)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      tituloProyecto,
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF16A34A),
                          fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ],
            ]),
          ),
          Checkbox(
            value: est.seleccionado,
            onChanged: (val) => _toggleEstudiante(est, val ?? false),
            activeColor: _kPrimario,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOTONES DE ACCIÓN
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBotonesAccion() {
    final count   = _seleccionadosCount;
    final ocupado = _generando || _enviando;

    return Column(children: [
      SizedBox(
        width: double.infinity, height: 56,
        child: ElevatedButton(
          onPressed: ocupado ? null : _generarCertificados,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimario, foregroundColor: Colors.white,
            disabledBackgroundColor: _kPrimario50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
          ),
          child: _generando
              ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Generando PDF...', style: TextStyle(fontSize: 15)),
                ])
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.workspace_premium, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    count == 0
                        ? 'Selecciona estudiantes'
                        : count == 1
                            ? 'Generar certificado (previsualizar)'
                            : 'Generar $count certificados (PDF)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ]),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity, height: 56,
        child: OutlinedButton(
          onPressed: (ocupado || count == 0) ? null : _enviarCertificados,
          style: OutlinedButton.styleFrom(
            foregroundColor: _kPrimario,
            disabledForegroundColor: _kPrimario40,
            side: BorderSide(color: count == 0 ? _kPrimario40 : _kPrimario, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _enviando
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: _kPrimario, strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Text('Enviando... $_enviados / $_totalEnviar',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: _totalEnviar > 0 ? _enviados / _totalEnviar : 0,
                    backgroundColor: _kPrimario10, color: _kPrimario,
                  ),
                ])
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.send_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    count == 0
                        ? 'Selecciona estudiantes para enviar'
                        : 'Enviar $count certificado(s) a estudiantes',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ]),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity, height: 56,
        child: OutlinedButton(
          onPressed: (ocupado || count == 0) ? null : _eliminarCertificados,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            disabledForegroundColor: Colors.red.shade200,
            side: BorderSide(color: count == 0 ? Colors.red.shade200 : Colors.red, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.delete_forever, size: 20),
            SizedBox(width: 10),
            Text('Eliminar certificados enviados',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
      if (count > 0) ...[
        const SizedBox(height: 8),
        Text(
          'Los estudiantes podrán ver y descargar sus certificados desde su panel',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500,
              fontStyle: FontStyle.italic),
        ),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS HELPER
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Card(
    elevation: 2, shadowColor: Colors.black12,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    color: Colors.white,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  const _CardHeader({required this.icon, required this.title,
      required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onToggle,
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: _kPrimario10, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: _kPrimario, size: 20),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kPrimario))),
      Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: _kTextoGrisClaro),
    ]),
  );
}

class _Campo extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final String? hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _Campo({required this.controller, required this.label,
      required this.icon, this.maxLines = 1, this.hint,
      this.keyboardType, this.onChanged});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller, maxLines: maxLines,
    keyboardType: keyboardType, onChanged: onChanged,
    style: const TextStyle(fontSize: 13, color: _kPrimario),
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      labelStyle: const TextStyle(fontSize: 12, color: _kTextoGris),
      hintStyle: const TextStyle(fontSize: 11, color: _kTextoGrisClaro),
      prefixIcon: Icon(icon, size: 18, color: _kTextoGrisClaro),
      filled: true, fillColor: _kCampoFondo,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kPrimario, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}