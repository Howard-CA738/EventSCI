import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/logica/filiales_service.dart';
import 'listas_certificados_importados_screen.dart';

const _kPrimario       = Color(0xFF1E3A5F);
const _kPrimario10     = Color(0x1A1E3A5F);
const _kPrimario40     = Color(0x661E3A5F);
const _kTextoGris      = Color(0xFF64748B);
const _kTextoGrisClaro = Color(0xFF94A3B8);
const _kTextoOscuro    = Color(0xFF334155);
const _kFondo          = Color(0xFFE8EDF2);
const _kCampoFondo     = Color(0xFFF8FAFC);
const _kVerde          = Color(0xFF16A34A);
const _kAmbar          = Color(0xFFF59E0B);
const _kRojo           = Color(0xFFDC2626);
const _kAzulInfo       = Color(0xFF2563EB);

/// Estado de validación de cada código de estudiante pegado.
enum _Estado {
  ok,               // encontrado en esta carrera, certificado pendiente listo
  yaTieneCodigo,    // encontrado, pero el certificado ya tiene código asignado
  sinCertificado,   // encontrado en esta carrera, pero no tiene cert de ese evento+rol
  otraCarrera,      // encontrado, pero en otra filial/facultad/carrera
  noEncontrado,     // no existe en ningún lado
  duplicado,        // el código se repite dentro de lo pegado
}

/// Firmante cargado desde config_firmas (mismo esquema que
/// GenerarCertificadosScreen: grado, nombre, cargo, storageUrl).
class _Firmante {
  final String nombre;
  final String cargo;
  final String urlFirma;
  const _Firmante({this.nombre = '', this.cargo = '', this.urlFirma = ''});
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

String _generarFacultadId(String texto) => texto
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]'), '_')
    .replaceAll(RegExp(r'_+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');

/// Motivo del certificado según el rol. PONENTE ahora usa un motivo fijo
/// por lote (igual que ORGANIZADOR/ASISTENTE), sin título de investigación.
String _motivoPorRolImport({
  required String rol,
  required String evento,
  required String fecha,
  required String carrera,
  required String horas,
}) {
  switch (rol) {
    case 'PONENTE':
      return 'Por su valiosa participación en calidad de PONENTE, en la "$evento", '
          'evento desarrollado el $fecha.';
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

String _fechaActualImport() {
  final now = DateTime.now();
  const meses = [
    '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  return '${now.day} de ${meses[now.month]} de ${now.year}';
}

/// Estados que impiden avanzar al campo 2 (problemas reales de identificación
/// del estudiante, de un código ya asignado para ese rol, o duplicados).
bool _bloqueaCampo1(_Estado estado) =>
    estado == _Estado.otraCarrera ||
    estado == _Estado.noEncontrado ||
    estado == _Estado.yaTieneCodigo ||
    estado == _Estado.duplicado;

class _CodigoEntry {
  final int    linea;
  final String codigoEstudiante;

  _Estado estado;
  String  mensaje;

  String? estudianteId;
  String? estudianteNombre;
  String  estudianteDni = '';
  String? certId;
  String  codigoActual = '';

  // Solo aplica cuando estado == sinCertificado.
  // false = crear el documento de certificado solo con el código.
  // true  = crear el documento de certificado completo.
  bool generarCompleto = false;

  // Se llena al pegar el segundo campo.
  String codigoCertificadoNuevo = '';

  _CodigoEntry({
    required this.linea,
    required this.codigoEstudiante,
    this.estado  = _Estado.noEncontrado,
    this.mensaje = '',
  });

  // Válido para avanzar al campo 2: código correcto (con o sin certificado
  // ya existente).
  bool get esValido => !_bloqueaCampo1(estado);
}

class ImportarCodigosCertificadoScreen extends StatefulWidget {
  const ImportarCodigosCertificadoScreen({super.key});

  @override
  State<ImportarCodigosCertificadoScreen> createState() =>
      _ImportarCodigosCertificadoScreenState();
}

class _ImportarCodigosCertificadoScreenState
    extends State<ImportarCodigosCertificadoScreen> {

  // ── Selección manual (super admin) ────────────────────────────────
  final FilialesService _filialesService = FilialesService();
  Map<String, dynamic> _estructuraFiliales = {};
  bool _estructuraCargada = false;

  String? _selectedFilialId;
  String? _selectedFilialNombre;
  String? _selectedFacultad;
  String? _selectedCarrera;
  String? _selectedCarreraId;

  bool get _destinoSeleccionado =>
      _selectedFilialNombre != null &&
      _selectedFacultad != null &&
      _selectedCarrera != null;

  String get _docKey => '${_selectedFilialNombre}_$_selectedCarrera';

  // ── Eventos y rol ─────────────────────────────────────────────────
  List<Map<String, dynamic>> _eventos = [];
  Map<String, dynamic>? _eventoSeleccionado;
  String _rol = 'ASISTENTE';
  static const _roles = ['ASISTENTE', 'PONENTE', 'ORGANIZADOR'];

  // ── Campos de texto ───────────────────────────────────────────────
  final _codigosEstudianteController  = TextEditingController();
  final _codigosCertificadoController = TextEditingController();

  // ── Datos para "generar completo" (solo ASISTENTE/ORGANIZADOR) ────
  late final TextEditingController _fechaGenController;
  final _horasGenController = TextEditingController(text: '16');

  // ── Estado del proceso ────────────────────────────────────────────
  bool _isLoading    = true;
  bool _validando    = false;
  bool _guardando    = false;
  bool _campo1Listo  = false; // true si no hay códigos con problemas bloqueantes
  bool _previewListo = false; // true cuando ya se emparejó campo 2

  List<_CodigoEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _fechaGenController = TextEditingController(text: _fechaActualImport());
    _init();
  }

  @override
  void dispose() {
    _codigosEstudianteController.dispose();
    _codigosCertificadoController.dispose();
    _fechaGenController.dispose();
    _horasGenController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    try {
      await _filialesService.inicializarSiEsNecesario();
      final estructura = await _filialesService.getEstructuraCompleta();
      setState(() {
        _estructuraFiliales = estructura;
        _estructuraCargada  = true;
      });
    } catch (e) {
      debugPrint('Error cargando estructura de filiales: $e');
      _snack('Error cargando estructura: $e', color: _kRojo);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<String> get _filialesDisponibles => _estructuraFiliales.keys.toList();

  List<String> _getFacultades(String filialId) {
    final filial = _estructuraFiliales[filialId];
    if (filial == null) return [];
    return (filial['facultades'] as Map<String, dynamic>).keys.toList();
  }

  List<Map<String, dynamic>> _getCarreras(String filialId, String facultad) {
    final filial = _estructuraFiliales[filialId];
    if (filial == null) return [];
    final facs = filial['facultades'] as Map<String, dynamic>;
    final facData = facs[facultad];
    if (facData == null) return [];
    return List<Map<String, dynamic>>.from(facData['carreras'] ?? []);
  }

  String _getNombreFilial(String filialId) =>
      _estructuraFiliales[filialId]?['nombre'] ?? filialId;

  void _onFilialChanged(String? filialId) {
    setState(() {
      _selectedFilialId     = filialId;
      _selectedFilialNombre = filialId != null ? _getNombreFilial(filialId) : null;
      _selectedFacultad     = null;
      _selectedCarrera      = null;
      _selectedCarreraId    = null;
    });
    _resetDestino();
  }

  void _onFacultadChanged(String? facultad) {
    setState(() {
      _selectedFacultad  = facultad;
      _selectedCarrera   = null;
      _selectedCarreraId = null;
    });
    _resetDestino();
  }

  void _onCarreraChanged(String? nombreCarrera) {
    if (nombreCarrera == null || _selectedFilialId == null || _selectedFacultad == null) {
      return;
    }
    final carreras = _getCarreras(_selectedFilialId!, _selectedFacultad!);
    final carreraData = carreras.firstWhere(
      (c) => c['nombre'] == nombreCarrera,
      orElse: () => {},
    );
    setState(() {
      _selectedCarrera   = nombreCarrera;
      _selectedCarreraId = carreraData.isNotEmpty ? carreraData['id'] as String? : null;
    });
    _resetDestino();
    if (_destinoSeleccionado) _cargarEventos();
  }

  void _resetDestino() {
    _eventos             = [];
    _eventoSeleccionado  = null;
    _resetTodo();
  }

  Future<void> _cargarEventos() async {
    if (_selectedFilialId == null ||
        _selectedFacultad == null ||
        _selectedCarreraId == null) {
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .where('filialId', isEqualTo: _selectedFilialId)
          .where('facultad', isEqualTo: _selectedFacultad)
          .where('carreraId', isEqualTo: _selectedCarreraId)
          .orderBy('createdAt', descending: true)
          .get();
      if (mounted) {
        setState(() {
          _eventos = snap.docs
              .map((d) => {'id': d.id, 'name': d.data()['name'] ?? 'Sin nombre'})
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error cargando eventos: $e');
    }
  }

  void _resetTodo() {
    setState(() {
      _entries.clear();
      _campo1Listo  = false;
      _previewListo = false;
      _codigosCertificadoController.clear();
    });
  }

  void _snack(String msg, {Color color = _kPrimario}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Parseo de texto pegado ────────────────────────────────────────
  List<String> _parsearLineas(String texto) {
    return texto
        .split(RegExp(r'[\s,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // ── VALIDACIÓN DEL CAMPO 1 ────────────────────────────────────────
  Future<void> _validarCodigosEstudiante() async {
    if (_eventoSeleccionado == null) {
      _snack('⚠️ Selecciona primero un evento', color: _kAmbar);
      return;
    }
    final codigos = _parsearLineas(_codigosEstudianteController.text);
    if (codigos.isEmpty) {
      _snack('⚠️ Pega al menos un código de estudiante', color: _kAmbar);
      return;
    }

    setState(() {
      _validando    = true;
      _campo1Listo  = false;
      _previewListo = false;
      _entries      = [];
    });

    final eventoNombre = _eventoSeleccionado!['name'] as String;

    // 1) Cargar todos los estudiantes de la carrera actual en un mapa.
    final Map<String, Map<String, dynamic>> estudiantesLocales = {};
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_docKey)
          .collection('students')
          .get();
      for (final doc in snap.docs) {
        final codigo = (doc.data()['codigoUniversitario'] ?? '').toString().trim();
        if (codigo.isNotEmpty) {
          estudiantesLocales[codigo] = {
            'id': doc.id,
            'name': doc.data()['name'] ?? 'Sin nombre',
            'dni': (doc.data()['dni'] ?? '').toString(),
          };
        }
      }
    } catch (e) {
      debugPrint('Error cargando estudiantes locales: $e');
    }

    final Set<String> vistos = {};
    final List<_CodigoEntry> nuevas = [];

    for (int i = 0; i < codigos.length; i++) {
      final codigo = codigos[i];
      final entry  = _CodigoEntry(linea: i + 1, codigoEstudiante: codigo);

      if (vistos.contains(codigo)) {
        entry.estado  = _Estado.duplicado;
        entry.mensaje = 'Código repetido dentro de la lista pegada';
        nuevas.add(entry);
        continue;
      }
      vistos.add(codigo);

      final local = estudiantesLocales[codigo];
      if (local == null) {
        // Buscar en todo el sistema (otras filiales/carreras).
        await _buscarEnOtraCarrera(entry, codigo);
        nuevas.add(entry);
        continue;
      }

      entry.estudianteId     = local['id'] as String;
      entry.estudianteNombre = local['name'] as String;
      entry.estudianteDni    = local['dni'] as String? ?? '';

      // Buscar el certificado de este evento + rol para este estudiante.
      try {
        final certsSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(_docKey)
            .collection('students')
            .doc(entry.estudianteId)
            .collection('certificados')
            .where('evento', isEqualTo: eventoNombre)
            .where('rol', isEqualTo: _rol)
            .get();

        final docsFiltrados = certsSnap.docs;

        if (docsFiltrados.isEmpty) {
          entry.estado  = _Estado.sinCertificado;
          entry.mensaje = 'No tiene certificado de $_rol para este evento. '
              'Elige abajo si quieres solo guardar el código o generar el '
              'certificado completo.';
        } else {
          // Si hay más de uno, tomar el más reciente por timestamp del certId.
          final docsOrdenados = [...docsFiltrados]
            ..sort((a, b) => _timestampDeCertId(b.id)
                .compareTo(_timestampDeCertId(a.id)));
          final masReciente = docsOrdenados.first;
          final codigoActual =
              (masReciente.data()['codigoCertificado'] ?? '').toString();

          entry.certId      = masReciente.id;
          entry.codigoActual = codigoActual;

          if (codigoActual.isNotEmpty) {
            entry.estado  = _Estado.yaTieneCodigo;
            entry.mensaje = 'Ya tiene código asignado para $_rol: $codigoActual';
          } else {
            entry.estado  = _Estado.ok;
            entry.mensaje = docsOrdenados.length > 1
                ? 'Listo (se actualizará el más reciente de '
                  '${docsOrdenados.length} certificados encontrados)'
                : 'Listo para asignar';
          }
        }
      } catch (e) {
        entry.estado  = _Estado.sinCertificado;
        entry.mensaje = 'Error consultando certificados: $e';
      }

      nuevas.add(entry);
    }

    if (mounted) {
      setState(() {
        _entries     = nuevas;
        _campo1Listo = nuevas.isNotEmpty &&
            nuevas.every((e) => !_bloqueaCampo1(e.estado));
        _validando   = false;
      });
      if (_campo1Listo) {
        _snack('✅ ${nuevas.length} códigos validados correctamente', color: _kVerde);
      } else {
        final bloqueantes = nuevas.where((e) => _bloqueaCampo1(e.estado)).length;
        _snack('⚠️ $bloqueantes código(s) con problemas bloqueantes. Revisa la lista.',
            color: _kAmbar);
      }
    }
  }

  Future<(_Firmante, _Firmante, _Firmante)> _cargarFirmantesParaEnvio() async {
    try {
      final db      = FirebaseFirestore.instance;
      final vSnap   = await db.collection('config_firmas').doc('vicerrector').get();
      final dSnap   = await db.collection('config_firmas').doc('director_investigacion').get();
      final facId   = _generarFacultadId(_selectedFacultad ?? '');
      final decSnap = await db
          .collection('config_firmas')
          .doc('decanos')
          .collection('facultades')
          .doc(facId)
          .get();
      return (
        _Firmante.fromDoc(vSnap.exists ? vSnap.data() : null),
        _Firmante.fromDoc(decSnap.exists ? decSnap.data() : null),
        _Firmante.fromDoc(dSnap.exists ? dSnap.data() : null),
      );
    } catch (e) {
      debugPrint('Error cargando firmantes: $e');
      return (const _Firmante(), const _Firmante(), const _Firmante());
    }
  }

  int _timestampDeCertId(String certId) {
    final partes = certId.split('_');
    if (partes.isEmpty) return 0;
    return int.tryParse(partes.last) ?? 0;
  }

  Future<void> _buscarEnOtraCarrera(_CodigoEntry entry, String codigo) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collectionGroup('students')
          .where('codigoUniversitario', isEqualTo: codigo)
          .limit(3)
          .get();

      if (snap.docs.isEmpty) {
        entry.estado  = _Estado.noEncontrado;
        entry.mensaje = 'Código no encontrado en ningún carrera/filial';
        return;
      }

      final doc          = snap.docs.first;
      final data         = doc.data();
      final nombre       = data['name'] as String? ?? 'Sin nombre';
      final carreraDatos = data['carrera']  as String? ?? '';
      final filialDatos  = data['filial']   as String? ?? '';
      final facultadDato = data['facultad'] as String? ?? '';

      entry.estado  = _Estado.otraCarrera;
      entry.estudianteNombre = nombre;
      entry.mensaje = 'Pertenece a: $carreraDatos'
          '${facultadDato.isNotEmpty ? " · $facultadDato" : ""}'
          '${filialDatos.isNotEmpty ? " · $filialDatos" : ""}';
    } catch (e) {
      entry.estado  = _Estado.noEncontrado;
      entry.mensaje = 'No se pudo buscar en otras carreras: $e\n'
          '(Puede que falte crear un índice de Firestore para '
          'collectionGroup "students" + "codigoUniversitario". '
          'Firestore suele dar un enlace para crearlo automáticamente '
          'en la consola de errores).';
    }
  }

  // ── EMPAREJAR CAMPO 2 ─────────────────────────────────────────────
  void _procesarCodigosCertificado() {
    final codigos = _parsearLineas(_codigosCertificadoController.text);
    if (codigos.isEmpty) {
      _snack('⚠️ Pega los códigos de certificado', color: _kAmbar);
      return;
    }
    if (codigos.length != _entries.length) {
      _snack(
        '⚠️ Cantidad distinta: ${_entries.length} estudiantes vs '
        '${codigos.length} códigos de certificado. Deben coincidir.',
        color: _kAmbar,
      );
      return;
    }
    for (int i = 0; i < _entries.length; i++) {
      _entries[i].codigoCertificadoNuevo = codigos[i];
    }
    setState(() => _previewListo = true);
  }

  // ── GUARDAR EN FIRESTORE ──────────────────────────────────────────
  Future<void> _confirmarYGuardar() async {
    final aCrear = _entries.where((e) => e.estado == _Estado.sinCertificado).length;
    final aActualizar = _entries.length - aCrear;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.rocket_launch, color: _kPrimario),
          SizedBox(width: 10),
          Text('Confirmar importación',
              style: TextStyle(color: _kPrimario, fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'Rol "$_rol" · Evento "${_eventoSeleccionado?['name']}"\n\n'
          '• $aActualizar certificado(s) existentes se actualizarán\n'
          '• $aCrear certificado(s) nuevos se crearán\n\n¿Continuar?',
          style: const TextStyle(fontSize: 14, color: _kTextoGris),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimario, foregroundColor: Colors.white),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _guardando = true);
    int exitosos = 0;
    int errores  = 0;

    // Si hay al menos un caso "generar completo", cargamos los firmantes
    // reales una sola vez y calculamos un único motivo para todo el lote
    // (mismo motivo para todos los estudiantes de esta importación,
    // incluido PONENTE).
    final necesitaCompleto = _entries.any(
        (e) => e.estado == _Estado.sinCertificado && e.generarCompleto);
    _Firmante firma1 = const _Firmante();
    _Firmante firma2 = const _Firmante();
    _Firmante firma3 = const _Firmante();
    String motivo = '';
    if (necesitaCompleto) {
      final firmantes = await _cargarFirmantesParaEnvio();
      firma1 = firmantes.$1;
      firma2 = firmantes.$2;
      firma3 = firmantes.$3;
      motivo = _motivoPorRolImport(
        rol: _rol,
        evento: _eventoSeleccionado!['name'] as String,
        fecha: _fechaGenController.text,
        carrera: _selectedCarrera ?? '',
        horas: _horasGenController.text,
      );
    }
    final ahora = Timestamp.now();

    const batchSize = 500;
    for (int i = 0; i < _entries.length; i += batchSize) {
      final lote  = _entries.skip(i).take(batchSize).toList();
      final batch = FirebaseFirestore.instance.batch();
      for (final e in lote) {
        final coleccionCert = FirebaseFirestore.instance
            .collection('users')
            .doc(_docKey)
            .collection('students')
            .doc(e.estudianteId)
            .collection('certificados');

        if (e.estado == _Estado.sinCertificado) {
          // No existía certificado de este evento+rol: se crea uno nuevo.
          final nuevoId = '${_rol}_${DateTime.now().millisecondsSinceEpoch}_${e.linea}';
          final ref = coleccionCert.doc(nuevoId);
          Map<String, dynamic> data;
          if (e.generarCompleto) {
            data = {
              'facultad': _selectedFacultad,
              'carrera': _selectedCarrera,
              'campus': _selectedFilialNombre,
              'motivo': motivo,
              'fecha': _fechaGenController.text,
              'horas': _horasGenController.text,
              'evento': _eventoSeleccionado!['name'],
              'rol': _rol,
              'director1': firma1.nombre, 'cargo1': firma1.cargo,
              'director2': firma2.nombre, 'cargo2': firma2.cargo,
              'director3': firma3.nombre, 'cargo3': firma3.cargo,
              'urlFirma1': firma1.urlFirma,
              'urlFirma2': firma2.urlFirma,
              'urlFirma3': firma3.urlFirma,
              'creadoEn': ahora,
              'nombreEstudiante': e.estudianteNombre,
              'codigoCertificado': e.codigoCertificadoNuevo,
            };
          } else {
            data = {
              'evento': _eventoSeleccionado!['name'],
              'rol': _rol,
              'codigoCertificado': e.codigoCertificadoNuevo,
            };
          }
          e.certId = nuevoId;
          batch.set(ref, data);
        } else {
          final ref = coleccionCert.doc(e.certId);
          batch.update(ref, {'codigoCertificado': e.codigoCertificadoNuevo});
        }
      }
      try {
        await batch.commit();
        exitosos += lote.length;
      } catch (err) {
        errores += lote.length;
        debugPrint('Error en lote de guardado: $err');
      }
    }

    // Registrar la lista de importación (Filial + Carrera + Evento + Rol).
    if (errores == 0) {
      try {
        await FirebaseFirestore.instance.collection('listas_certificados').add({
          'filialId': _selectedFilialId,
          'filialNombre': _selectedFilialNombre,
          'facultad': _selectedFacultad,
          'carrera': _selectedCarrera,
          'carreraId': _selectedCarreraId,
          'eventoId': _eventoSeleccionado!['id'],
          'evento': _eventoSeleccionado!['name'],
          'rol': _rol,
          'fecha': ahora,
          'totalEstudiantes': _entries.length,
          'estudiantes': _entries.map((e) => {
                'estudianteId': e.estudianteId,
                'nombre': e.estudianteNombre,
                'dni': e.estudianteDni,
                'codigoEstudiante': e.codigoEstudiante,
                'codigoCertificado': e.codigoCertificadoNuevo,
                'certId': e.certId,
                'generadoCompleto': e.generarCompleto && e.estado == _Estado.sinCertificado,
              }).toList(),
        });
      } catch (e) {
        debugPrint('Error creando lista de importación: $e');
      }
    }

    if (mounted) {
      setState(() => _guardando = false);
      if (errores == 0) {
        _snack('✅ $exitosos códigos de certificado asignados correctamente',
            color: _kVerde);
        _resetTodo();
        _codigosEstudianteController.clear();
      } else {
        _snack('⚠️ $exitosos correctos, $errores con error', color: _kAmbar);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════
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
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _kPrimario))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        _buildFiltrosCard(),
                        const SizedBox(height: 14),
                        _buildCampo1Card(),
                        const SizedBox(height: 14),
                        if (_entries.isNotEmpty) _buildResultadosValidacion(),
                        if (_entries.any((e) =>
                            e.estado == _Estado.sinCertificado && e.generarCompleto)) ...[
                          const SizedBox(height: 14),
                          _buildDatosCertificadoCompletoCard(),
                        ],
                        const SizedBox(height: 14),
                        _buildCampo2Card(),
                        if (_previewListo) ...[
                          const SizedBox(height: 14),
                          _buildPreviewFinal(),
                        ],
                      ],
                    ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration:
                BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.qr_code_2_rounded, color: _kPrimario, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Importar Códigos de Certificado',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              Text('Pega códigos desde Excel y asígnalos en bloque',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt_rounded, color: Colors.white, size: 24),
            tooltip: 'Ver listas de importación',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ListasCertificadosImportadosScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ]),
      );

  Widget _card({required Widget child}) => Card(
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );

  Widget _sectionTitle(IconData icon, String title, {Color color = _kPrimario}) => Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );

  // ── Filtros: filial/facultad/carrera + evento + rol ────────────────
  Widget _buildFiltrosCard() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.tune, 'Filtros de destino'),
        const SizedBox(height: 14),

        const Text('Sede (Filial)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimario)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedFilialId,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true, fillColor: _kCampoFondo,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          hint: const Text('Selecciona una sede', style: TextStyle(fontSize: 13)),
          items: _filialesDisponibles
              .map((id) => DropdownMenuItem<String>(
                    value: id,
                    child: Text(_getNombreFilial(id), overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: _estructuraCargada ? _onFilialChanged : null,
        ),

        const SizedBox(height: 12),
        const Text('Facultad',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimario)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedFacultad,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: _selectedFilialId != null ? _kCampoFondo : Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          hint: const Text('Selecciona una facultad', style: TextStyle(fontSize: 13)),
          items: _selectedFilialId != null
              ? _getFacultades(_selectedFilialId!)
                  .map((f) => DropdownMenuItem<String>(
                        value: f,
                        child: Text(f, overflow: TextOverflow.ellipsis),
                      ))
                  .toList()
              : const [],
          onChanged: _selectedFilialId != null ? _onFacultadChanged : null,
        ),

        const SizedBox(height: 12),
        const Text('Carrera',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimario)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedCarrera,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: _selectedFacultad != null ? _kCampoFondo : Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          hint: const Text('Selecciona una carrera', style: TextStyle(fontSize: 13)),
          items: (_selectedFilialId != null && _selectedFacultad != null)
              ? _getCarreras(_selectedFilialId!, _selectedFacultad!)
                  .map((c) => DropdownMenuItem<String>(
                        value: c['nombre'] as String,
                        child: Text(c['nombre'] as String, overflow: TextOverflow.ellipsis),
                      ))
                  .toList()
              : const [],
          onChanged: _selectedFacultad != null ? _onCarreraChanged : null,
        ),

        const SizedBox(height: 14),
        const Text('Evento',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimario)),
        const SizedBox(height: 6),
        if (!_destinoSeleccionado)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
            child: const Text('Selecciona sede, facultad y carrera primero',
                style: TextStyle(fontSize: 12, color: _kTextoGris)),
          )
        else if (_eventos.isEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
            child: const Text('No hay eventos disponibles para esta carrera',
                style: TextStyle(fontSize: 12, color: Color(0xFF78350F))),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _eventoSeleccionado?['id'] as String?,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true, fillColor: _kCampoFondo,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            items: _eventos
                .map((e) => DropdownMenuItem<String>(
                      value: e['id'] as String,
                      child: Text(e['name'] as String, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (id) {
              setState(() {
                _eventoSeleccionado = _eventos.firstWhere((e) => e['id'] == id);
              });
              _resetTodo();
            },
          ),

        const SizedBox(height: 14),
        const Text('Rol de los certificados',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimario)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _roles
              .map((r) => ChoiceChip(
                    label: Text(r,
                        style: TextStyle(

                            fontSize: 11, color: _rol == r ? Colors.white : _kPrimario)),
                    selected: _rol == r,
                    selectedColor: _kPrimario,
                    backgroundColor: Colors.grey.shade100,
                    onSelected: (_) {
                      setState(() => _rol = r);
                      _resetTodo();
                    },
                  ))
              .toList(),
        ),
      ]),
    );
  }

  // ── Campo 1 ────────────────────────────────────────────────────────
  Widget _buildCampo1Card() {
    final habilitado = _eventoSeleccionado != null;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.looks_one_rounded, '1. Códigos de estudiante'),
        const SizedBox(height: 10),
        TextField(
          controller: _codigosEstudianteController,
          enabled: habilitado,
          maxLines: 8,
          minLines: 4,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: habilitado
                ? 'Pega aquí los códigos de estudiante (uno por línea, por espacio o por coma)...'
                : 'Selecciona un evento primero',
            hintStyle: const TextStyle(fontSize: 12, color: _kTextoGrisClaro),
            filled: true, fillColor: _kCampoFondo,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton.icon(
            onPressed: (habilitado && !_validando) ? _validarCodigosEstudiante : null,
            icon: _validando
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.fact_check_outlined, size: 20),
            label: Text(_validando ? 'Validando...' : 'Validar códigos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimario, foregroundColor: Colors.white,
              disabledBackgroundColor: _kPrimario40,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Resultados de validación ───────────────────────────────────────
  Widget _buildResultadosValidacion() {
    final ok        = _entries.where((e) => e.estado == _Estado.ok).length;
    final sinCert   = _entries.where((e) => e.estado == _Estado.sinCertificado).length;
    final problemas = _entries.where((e) => _bloqueaCampo1(e.estado)).length;
    final total     = _entries.length;

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.checklist_rounded, 'Resultado de validación',
            color: _campo1Listo ? _kVerde : _kAmbar),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _statMini('$ok', 'Correctos', _kVerde)),
          const SizedBox(width: 6),
          Expanded(child: _statMini('$sinCert', 'Sin cert.', _kAzulInfo)),
          const SizedBox(width: 6),
          Expanded(child: _statMini('$problemas', 'Bloqueantes', _kAmbar)),
          const SizedBox(width: 6),
          Expanded(child: _statMini('$total', 'Total', _kPrimario)),
        ]),
        const SizedBox(height: 12),
        ...List.generate(_entries.length, (i) => _buildEntryTile(_entries[i])),
        if (!_campo1Listo) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(children: [
              Icon(Icons.lock_outline, size: 16, color: Color(0xFF78350F)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Corrige los códigos de otra carrera, no encontrados, '
                  'duplicados o con código ya asignado para desbloquear el '
                  'segundo campo.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _statMini(String value, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
          Text(label, style: TextStyle(fontSize: 9, color: color.withOpacity(0.85))),
        ]),
      );

  Widget _chipModo(String label, bool selected, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? _kAzulInfo : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kAzulInfo.withOpacity(0.5)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  color: selected ? Colors.white : _kAzulInfo,
                  fontWeight: FontWeight.w600)),
        ),
      );

  Widget _buildEntryTile(_CodigoEntry e) {
    final (color, icon) = switch (e.estado) {
      _Estado.ok             => (_kVerde, Icons.check_circle_outline),
      _Estado.yaTieneCodigo  => (_kRojo, Icons.block_rounded),
      _Estado.sinCertificado => (_kAzulInfo, Icons.info_outline),
      _Estado.otraCarrera    => (_kRojo, Icons.error_outline),
      _Estado.noEncontrado   => (_kRojo, Icons.help_outline),
      _Estado.duplicado      => (_kRojo, Icons.content_copy_rounded),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('#${e.linea}  ${e.codigoEstudiante}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              if (e.estudianteNombre != null) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(e.estudianteNombre!,
                      style: const TextStyle(fontSize: 11, color: _kTextoGris),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ]),
            if (e.mensaje.isNotEmpty)
              Text(e.mensaje, style: TextStyle(fontSize: 10.5, color: color)),
            if (e.estado == _Estado.sinCertificado) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                _chipModo('Solo código', !e.generarCompleto,
                    () => setState(() => e.generarCompleto = false)),
                _chipModo('Generar completo', e.generarCompleto,
                    () => setState(() => e.generarCompleto = true)),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  // ── Datos para certificado completo ────────────────────────────────
  Widget _buildDatosCertificadoCompletoCard() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.workspace_premium_outlined,
            'Datos del certificado completo', color: _kAzulInfo),
        const SizedBox(height: 6),
        const Text(
          'Se usan para armar el motivo y los datos de los certificados '
          'nuevos marcados como "Generar completo". Los firmantes se toman '
          'de Configurar Firmas automáticamente.',
          style: TextStyle(fontSize: 11, color: _kTextoGrisClaro),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _fechaGenController,
          style: const TextStyle(fontSize: 13, color: _kPrimario),
          decoration: InputDecoration(
            labelText: 'Fecha de emisión',
            labelStyle: const TextStyle(fontSize: 12, color: _kTextoGris),
            prefixIcon: const Icon(Icons.calendar_today, size: 18, color: _kTextoGrisClaro),
            filled: true, fillColor: _kCampoFondo,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        if (_rol == 'ASISTENTE') ...[
          const SizedBox(height: 10),
          TextField(
            controller: _horasGenController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13, color: _kPrimario),
            decoration: InputDecoration(
              labelText: 'Horas académicas',
              labelStyle: const TextStyle(fontSize: 12, color: _kTextoGris),
              prefixIcon: const Icon(Icons.timer_outlined, size: 18, color: _kTextoGrisClaro),
              filled: true, fillColor: _kCampoFondo,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ]),
    );
  }

  // ── Campo 2 ────────────────────────────────────────────────────────
  Widget _buildCampo2Card() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.looks_two_rounded, '2. Códigos de certificado',
            color: _campo1Listo ? _kPrimario : _kTextoGrisClaro),
        const SizedBox(height: 6),
        Text(
          _campo1Listo
              ? 'Pega ${_entries.length} código(s), en el mismo orden que la lista anterior.'
              : 'Se habilita cuando el paso 1 no tenga códigos bloqueantes.',
          style: const TextStyle(fontSize: 11, color: _kTextoGrisClaro),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _codigosCertificadoController,
          enabled: _campo1Listo && !_guardando,
          maxLines: 8,
          minLines: 4,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'Ej: EVT-26-F0401001',
            hintStyle: const TextStyle(fontSize: 12, color: _kTextoGrisClaro),
            filled: true,
            fillColor: _campo1Listo ? _kCampoFondo : Colors.grey.shade100,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton.icon(
            onPressed: _campo1Listo ? _procesarCodigosCertificado : null,
            icon: const Icon(Icons.preview_rounded, size: 20),
            label: const Text('Emparejar y previsualizar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimario, foregroundColor: Colors.white,
              disabledBackgroundColor: _kPrimario40,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Vista previa final + guardar ──────────────────────────────────
  Widget _buildPreviewFinal() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.rule_folder_outlined, 'Vista previa final'),
        const SizedBox(height: 10),
        ...List.generate(_entries.length, (i) {
          final e = _entries[i];
          final esNuevo = e.estado == _Estado.sinCertificado;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _kCampoFondo,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(children: [
              SizedBox(
                width: 24,
                child: Text('${i + 1}',
                    style: const TextStyle(fontSize: 11, color: _kTextoGrisClaro)),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(e.estudianteNombre ?? '',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: _kTextoOscuro),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (esNuevo) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: _kAzulInfo.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          e.generarCompleto ? 'Nuevo · completo' : 'Nuevo · solo código',
                          style: const TextStyle(fontSize: 9, color: _kAzulInfo),
                        ),
                      ),
                    ],
                  ]),
                  Text(e.codigoEstudiante,
                      style: const TextStyle(fontSize: 10, color: _kTextoGrisClaro, fontFamily: 'monospace')),
                ]),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 14, color: _kTextoGrisClaro),
              const SizedBox(width: 8),
              Text(e.codigoCertificadoNuevo,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: _kVerde, fontFamily: 'monospace')),
            ]),
          );
        }),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: _guardando ? null : _confirmarYGuardar,
            icon: _guardando
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_rounded, size: 22),
            label: Text(_guardando
                ? 'Guardando...'
                : 'Guardar ${_entries.length} código(s) de certificado'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kVerde, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    );
  }
}