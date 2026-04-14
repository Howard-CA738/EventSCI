import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import '/prefs_helper.dart';
import 'certificado_builder.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTES DE COLOR — evita crear objetos Color en cada build()
// ─────────────────────────────────────────────────────────────────────────────
const _kPrimario        = Color(0xFF1E3A5F);
const _kPrimario05      = Color(0x0D1E3A5F); // 5%
const _kPrimario08      = Color(0x141E3A5F); // 8%
const _kPrimario10      = Color(0x1A1E3A5F); // 10%
const _kPrimario20      = Color(0x331E3A5F); // 20%
const _kPrimario40      = Color(0x661E3A5F); // 40%
const _kPrimario50      = Color(0x801E3A5F); // 50%
const _kTextoGris       = Color(0xFF64748B);
const _kTextoGrisClaro  = Color(0xFF94A3B8);
const _kTextoOscuro     = Color(0xFF334155);
const _kFondo           = Color(0xFFE8EDF2);
const _kCampoFondo      = Color(0xFFF8FAFC);
const _kCampoFondo2     = Color(0xFFF1F5F9);

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS DE FECHA
// ─────────────────────────────────────────────────────────────────────────────
String _fechaActual(String ciudad) {
  final now = DateTime.now();
  const meses = [
    '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  final ciudad_ = ciudad.trim().isEmpty ? 'Juliaca' : ciudad.trim();
  return '$ciudad_, ${now.day} de ${meses[now.month]} de ${now.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// MOTIVOS POR ROL
// ─────────────────────────────────────────────────────────────────────────────
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

  // ── Formulario ───────────────────────────────────────────────────────────
  late final TextEditingController _fechaController;
  final _horasController          = TextEditingController(text: '16');
  final _eventoController         = TextEditingController(
      text: 'XXI JORNADA CIENTÍFICA DE INVESTIGACIÓN E INNOVACIÓN');
  final _director1Controller      = TextEditingController(text: 'Dr. Carlos Coaquira Tuco');
  final _cargo1Controller         = TextEditingController(text: 'DIRECTOR GENERAL');
  final _director2Controller      = TextEditingController(text: 'Dr. Danny Lévano Rodríguez');
  final _cargo2Controller         = TextEditingController(text: 'Coordinador de la EP');
  final _tituloPonenciaController = TextEditingController(text: 'xxxx');

  String _modalidadPonencia = 'ORAL';
  String _rolParticipante   = 'ASISTENTE';

  // ── Estudiantes ──────────────────────────────────────────────────────────
  List<Estudiante> _estudiantes = [];

  // ✅ OPT: listas filtradas cacheadas — no se recalculan en cada build()
  List<Estudiante> _pagaronFiltrados    = [];
  List<Estudiante> _pendientesFiltrados = [];

  // ✅ OPT: contador cacheado — no recorre la lista en cada build()
  int _seleccionadosCount = 0;

  bool _isLoading = true;
  bool _generando = false;
  bool _enviando  = false;

  String _searchQuery = '';
  final _searchController = TextEditingController();

  // ✅ OPT: debounce para búsqueda — evita setState en cada letra
  Timer? _debounceSearch;

  // ── Progreso de envío ────────────────────────────────────────────────────
  int  _enviados    = 0;
  int  _totalEnviar = 0;

  // ✅ OPT: bandera para cancelar envío si el usuario sale de la pantalla
  bool _cancelarEnvio = false;

  // ── Secciones colapsables ────────────────────────────────────────────────
  bool _seccionConfig = true;
  bool _seccionFirmas = false;

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fechaController = TextEditingController(text: _fechaActual('Juliaca'));
    _init();
  }

  @override
  void dispose() {
    _cancelarEnvio = true;
    _debounceSearch?.cancel();
    _fechaController.dispose();
    _horasController.dispose();
    _eventoController.dispose();
    _director1Controller.dispose();
    _cargo1Controller.dispose();
    _director2Controller.dispose();
    _cargo2Controller.dispose();
    _tituloPonenciaController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _init() async {
    final data = await PrefsHelper.getAdminCarreraData();
    if (data != null) {
      setState(() {
        _carrera  = data['carrera']      ?? '';
        _facultad = data['facultad']     ?? '';
        _sede     = data['filialNombre'] ?? '';
        _filial   = data['filialNombre'] ?? '';
        _fechaController.text = _fechaActual(_sede);
      });
      await _cargarEstudiantes();
    }
    if (mounted) setState(() => _isLoading = false);
  }

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
        final d       = doc.data();
        final pagoRaw = (d['pago'] ?? '').toString().trim().toLowerCase();
        final pagado  = pagoRaw.isNotEmpty &&
            pagoRaw != 'no' &&
            pagoRaw != '0' &&
            pagoRaw != 'false' &&
            pagoRaw != 'pendiente';

        return Estudiante(
          id:     doc.id,
          nombre: d['name']                ?? 'Sin nombre',
          dni:    d['dni']                 ?? '',
          codigo: d['codigoUniversitario'] ?? '',
          email:  d['email']               ?? '',
          pagado: pagado,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _estudiantes = lista;
        // ✅ OPT: inicializar filtros al cargar
        _actualizarFiltros(notify: false);
      });
    } catch (e) {
      debugPrint('Error cargando estudiantes: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ✅ OPT: FILTROS CACHEADOS
  // Se llama solo cuando cambia _searchQuery o _estudiantes.
  // notify: false → se usa dentro de un setState existente para no anidar.
  // ─────────────────────────────────────────────────────────────────────────
  void _actualizarFiltros({bool notify = true}) {
    final q = _searchQuery.toLowerCase();

    bool matchSearch(Estudiante e) {
      if (q.isEmpty) return true;
      return e.nombre.toLowerCase().contains(q) ||
          e.dni.contains(q) ||
          e.codigo.toLowerCase().contains(q);
    }

    final pagaron    = _estudiantes.where((e) => e.pagado  && matchSearch(e)).toList();
    final pendientes = _estudiantes.where((e) => !e.pagado && matchSearch(e)).toList();

    if (notify) {
      setState(() {
        _pagaronFiltrados    = pagaron;
        _pendientesFiltrados = pendientes;
      });
    } else {
      _pagaronFiltrados    = pagaron;
      _pendientesFiltrados = pendientes;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ✅ OPT: TOGGLE CON CONTADOR — no recorre la lista completa en cada build
  // ─────────────────────────────────────────────────────────────────────────
  void _toggleEstudiante(Estudiante est, bool val) {
    setState(() {
      est.seleccionado = val;
      _seleccionadosCount += val ? 1 : -1;
    });
  }

  void _toggleGrupo(List<Estudiante> grupo, bool? val) {
    final seleccionar = val ?? false;
    setState(() {
      for (final e in grupo) {
        if (e.seleccionado != seleccionar) {
          e.seleccionado = seleccionar;
          _seleccionadosCount += seleccionar ? 1 : -1;
        }
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOTIVO AUTO-GENERADO
  // ─────────────────────────────────────────────────────────────────────────
  String get _motivoGenerado => _motivoPorRol(
        rol:               _rolParticipante,
        evento:            _eventoController.text,
        fecha:             _fechaController.text,
        carrera:           _carrera,
        horas:             _horasController.text,
        tituloPonencia:    _tituloPonenciaController.text,
        modalidadPonencia: _modalidadPonencia,
      );

  // ─────────────────────────────────────────────────────────────────────────
  // DATOS DEL CERTIFICADO ACTUAL
  // ─────────────────────────────────────────────────────────────────────────
  DatosCertificado get _datosCertificado => DatosCertificado(
        facultad:  _facultad,
        carrera:   _carrera,
        campus:    _sede,
        motivo:    _motivoGenerado,
        fecha:     _fechaController.text,
        horas:     _horasController.text,
        evento:    _eventoController.text,
        rol:       _rolParticipante,
        director1: _director1Controller.text,
        cargo1:    _cargo1Controller.text,
        director2: _director2Controller.text,
        cargo2:    _cargo2Controller.text,
      );

  // ─────────────────────────────────────────────────────────────────────────
  // GENERAR PDF (previsualizar / compartir)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _generarCertificados() async {
    final seleccionados = _estudiantes.where((e) => e.seleccionado).toList();
    if (seleccionados.isEmpty) {
      _snack('Selecciona al menos un estudiante');
      return;
    }

    setState(() => _generando = true);

    try {
      final builder = CertificadoBuilder(_datosCertificado);
      final bytes   = await builder.buildPdf(seleccionados);
      if (!mounted) return;

      if (seleccionados.length == 1) {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      } else {
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'certificados_${_carrera.replaceAll(' ', '_')}.pdf',
        );
      }
    } catch (e) {
      if (mounted) _snack('Error generando PDF: $e');
    }

    if (mounted) setState(() => _generando = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ✅ OPT: ENVIAR CERTIFICADOS A FIRESTORE
  // - Batch writes de 500 (límite Firestore)
  // - mounted check antes de cada setState
  // - bandera _cancelarEnvio para salida segura
  // - NO guarda PDF en base64
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
        title: const Row(
          children: [
            Icon(Icons.send_rounded, color: _kPrimario, size: 26),
            SizedBox(width: 10),
            Text('Enviar certificados',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kPrimario)),
          ],
        ),
        content: Text(
          'Se enviarán ${seleccionados.length} certificado(s) a los estudiantes '
          'seleccionados. Podrán verlos y descargarlos desde su panel.',
          style: const TextStyle(fontSize: 14, color: _kTextoGris),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: _kTextoGris)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimario,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
      final datos     = _datosCertificado.toMap();
      final ahora     = Timestamp.now();
      int errores     = 0;

      for (int i = 0; i < seleccionados.length; i += batchSize) {
        // ✅ OPT: salir limpio si el widget fue destruido
        if (_cancelarEnvio) break;

        final lote  = seleccionados.skip(i).take(batchSize).toList();
        final batch = FirebaseFirestore.instance.batch();

        for (final est in lote) {
          final ref = FirebaseFirestore.instance
              .collection('users')
              .doc(docKey)
              .collection('students')
              .doc(est.id)
              .collection('certificados')
              .doc();

          batch.set(ref, {
            ...datos,
            'creadoEn': ahora,
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
        child: Column(
          children: [
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
                    ? const Center(
                        child: CircularProgressIndicator(color: _kPrimario))
                    : _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: Image.asset('assets/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.workspace_premium,
                    color: _kPrimario,
                    size: 28)),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Generar Certificados',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text('Selecciona estudiantes y personaliza',
                    style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 26),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCardConfig(),
        const SizedBox(height: 12),
        _buildCardFirmas(),
        const SizedBox(height: 12),
        _buildCardEstudiantes(),
        const SizedBox(height: 20),
        _buildBotonesAccion(),
        const SizedBox(height: 20),
      ],
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
            onToggle: () =>
                setState(() => _seccionConfig = !_seccionConfig),
          ),
          if (_seccionConfig) ...[
            const SizedBox(height: 16),

            // ── Rol ──────────────────────────────────────────────────────
            const Text('Rol del participante',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kPrimario)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: ['ASISTENTE', 'PONENTE', 'JURADO', 'ORGANIZADOR']
                  .map((rol) => ChoiceChip(
                        label: Text(rol,
                            style: TextStyle(
                                fontSize: 11,
                                color: _rolParticipante == rol
                                    ? Colors.white
                                    : _kPrimario)),
                        selected: _rolParticipante == rol,
                        selectedColor: _kPrimario,
                        backgroundColor: Colors.grey.shade100,
                        onSelected: (_) =>
                            setState(() => _rolParticipante = rol),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),

            // ── Evento ───────────────────────────────────────────────────
            _Campo(
              controller: _eventoController,
              label: 'Nombre del evento',
              icon: Icons.event,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // ── Horas (solo ASISTENTE) ────────────────────────────────
            if (_rolParticipante == 'ASISTENTE') ...[
              _Campo(
                controller: _horasController,
                label: 'Horas académicas',
                icon: Icons.timer_outlined,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],

            // ── Campos extra para PONENTE ─────────────────────────────
            if (_rolParticipante == 'PONENTE') ...[
              _Campo(
                controller: _tituloPonenciaController,
                label: 'Título de la investigación',
                icon: Icons.article_outlined,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              const Text('Modalidad de presentación',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kPrimario)),
              const SizedBox(height: 8),
              Row(
                children: ['ORAL', 'POSTER']
                    .map((m) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            label: Text(m,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _modalidadPonencia == m
                                        ? Colors.white
                                        : _kPrimario)),
                            selected: _modalidadPonencia == m,
                            selectedColor: _kPrimario,
                            backgroundColor: Colors.grey.shade100,
                            onSelected: (_) =>
                                setState(() => _modalidadPonencia = m),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],

            // ── Fecha ────────────────────────────────────────────────────
            _Campo(
              controller: _fechaController,
              label: 'Fecha de emisión',
              icon: Icons.calendar_today,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // ── Vista previa del motivo ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kPrimario05,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kPrimario20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.preview, size: 14, color: _kPrimario),
                      SizedBox(width: 6),
                      Text('Vista previa del motivo',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _kPrimario)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _motivoGenerado,
                    style: const TextStyle(
                        fontSize: 11, color: _kTextoOscuro, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CARD FIRMAS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCardFirmas() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.draw_outlined,
            title: 'Firmas del Certificado',
            expanded: _seccionFirmas,
            onToggle: () =>
                setState(() => _seccionFirmas = !_seccionFirmas),
          ),
          if (_seccionFirmas) ...[
            const SizedBox(height: 16),
            const Text('Firmante 1',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kPrimario)),
            const SizedBox(height: 8),
            _Campo(
                controller: _director1Controller,
                label: 'Nombre y título',
                icon: Icons.person_outline),
            const SizedBox(height: 8),
            _Campo(
                controller: _cargo1Controller,
                label: 'Cargo',
                icon: Icons.badge_outlined),
            const SizedBox(height: 14),
            const Text('Firmante 2',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kPrimario)),
            const SizedBox(height: 8),
            _Campo(
                controller: _director2Controller,
                label: 'Nombre y título',
                icon: Icons.person_outline),
            const SizedBox(height: 8),
            _Campo(
                controller: _cargo2Controller,
                label: 'Cargo',
                icon: Icons.badge_outlined),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CARD ESTUDIANTES
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCardEstudiantes() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kPrimario10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.people_alt_outlined,
                    color: _kPrimario, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Seleccionar Estudiantes',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _kPrimario)),
                    // ✅ OPT: usa _seleccionadosCount cacheado
                    Text(
                        '$_seleccionadosCount de ${_estudiantes.length} seleccionados',
                        style: const TextStyle(
                            fontSize: 11, color: _kTextoGris)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Buscador con debounce ─────────────────────────────────────
          TextField(
            controller: _searchController,
            onChanged: (q) {
              // ✅ OPT: debounce de 300ms — no filtra en cada letra
              _debounceSearch?.cancel();
              _debounceSearch =
                  Timer(const Duration(milliseconds: 300), () {
                _searchQuery = q;
                _actualizarFiltros();
              });
            },
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, DNI o código...',
              hintStyle: const TextStyle(
                  fontSize: 12, color: _kTextoGrisClaro),
              prefixIcon: const Icon(Icons.search,
                  color: _kTextoGrisClaro, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: _kTextoGrisClaro, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _searchQuery = '';
                        _actualizarFiltros();
                      },
                    )
                  : null,
              filled: true,
              fillColor: _kCampoFondo2,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          const SizedBox(height: 16),

          // ── Grupo: PAGARON ───────────────────────────────────────────
          _buildGrupoHeader(
            icon: Icons.check_circle,
            iconColor: Colors.green.shade600,
            bgColor: Colors.green.shade50,
            titulo: 'Pagaron',
            count: _pagaronFiltrados.length,   // ✅ OPT: usa lista cacheada
            grupo: _pagaronFiltrados,
          ),
          const SizedBox(height: 6),
          if (_pagaronFiltrados.isEmpty)
            _emptyGrupo('Sin estudiantes con pago registrado')
          else
            // ✅ OPT: SizedBox con altura fija — renderiza solo los visibles
            _buildListaEstudiantes(_pagaronFiltrados, Colors.green.shade600),

          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 12),

          // ── Grupo: PENDIENTES ────────────────────────────────────────
          _buildGrupoHeader(
            icon: Icons.access_time_filled,
            iconColor: Colors.orange.shade700,
            bgColor: Colors.orange.shade50,
            titulo: 'Pago pendiente',
            count: _pendientesFiltrados.length, // ✅ OPT: usa lista cacheada
            grupo: _pendientesFiltrados,
          ),
          const SizedBox(height: 6),
          if (_pendientesFiltrados.isEmpty)
            _emptyGrupo('Sin estudiantes con pago pendiente')
          else
            _buildListaEstudiantes(
                _pendientesFiltrados, Colors.orange.shade700),
        ],
      ),
    );
  }

  Widget _buildGrupoHeader({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String titulo,
    required int count,
    required List<Estudiante> grupo,
  }) {
    final todosSeleccionados =
        grupo.isNotEmpty && grupo.every((e) => e.seleccionado);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: bgColor, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          '$titulo  ($count)',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: iconColor),
        ),
        const Spacer(),
        const Text('Todos',
            style: TextStyle(fontSize: 11, color: _kTextoGris)),
        Checkbox(
          value: todosSeleccionados,
          onChanged: (val) => _toggleGrupo(grupo, val),
          activeColor: _kPrimario,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ],
    );
  }

  Widget _emptyGrupo(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(msg,
            style: const TextStyle(
                color: _kTextoGrisClaro,
                fontSize: 12,
                fontStyle: FontStyle.italic)),
      ),
    );
  }

  // ✅ OPT: SizedBox con altura fija para que ListView.builder recicle
  //         widgets correctamente — NO usa shrinkWrap: true con listas grandes
  Widget _buildListaEstudiantes(
      List<Estudiante> lista, Color accentColor) {
    const itemH     = 57.0; // altura aproximada de cada item
    const maxVisible = 8;   // máximo de items visibles sin scroll interno
    final height = (lista.length > maxVisible
            ? maxVisible * itemH
            : lista.length * itemH)
        .clamp(itemH, double.infinity);

    return SizedBox(
      height: height,
      child: ListView.separated(
        itemCount: lista.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, i) => _buildEstudianteItem(lista[i]),
      ),
    );
  }

  // ✅ OPT: extraído como método para que Flutter pueda reutilizar el widget
  Widget _buildEstudianteItem(Estudiante est) {
    return InkWell(
      key: ValueKey(est.id), // ✅ OPT: key para reconciliación eficiente
      onTap: () => _toggleEstudiante(est, !est.seleccionado),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: est.seleccionado ? _kPrimario : _kCampoFondo2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  est.nombre.isNotEmpty
                      ? est.nombre[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: est.seleccionado ? Colors.white : _kPrimario,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    est.nombre,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: est.seleccionado ? _kPrimario : _kTextoOscuro,
                    ),
                  ),
                  if (est.dni.isNotEmpty || est.codigo.isNotEmpty)
                    Text(
                      [
                        if (est.dni.isNotEmpty) 'DNI: ${est.dni}',
                        if (est.codigo.isNotEmpty) est.codigo,
                      ].join('  ·  '),
                      style: const TextStyle(
                          fontSize: 11, color: _kTextoGrisClaro),
                    ),
                ],
              ),
            ),
            Checkbox(
              value: est.seleccionado,
              onChanged: (val) =>
                  _toggleEstudiante(est, val ?? false),
              activeColor: _kPrimario,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOTONES DE ACCIÓN
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBotonesAccion() {
    final count   = _seleccionadosCount; // ✅ OPT: ya cacheado
    final ocupado = _generando || _enviando;

    return Column(
      children: [
        // ── Botón: Generar / Previsualizar ───────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: ocupado ? null : _generarCertificados,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimario,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _kPrimario50,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 3,
            ),
            child: _generando
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Generando PDF...',
                          style: TextStyle(fontSize: 15)),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.workspace_premium, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        count == 0
                            ? 'Selecciona estudiantes'
                            : count == 1
                                ? 'Generar certificado (previsualizar)'
                                : 'Generar $count certificados (PDF)',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Botón: Enviar a estudiantes ──────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: (ocupado || count == 0) ? null : _enviarCertificados,
            style: OutlinedButton.styleFrom(
              foregroundColor: _kPrimario,
              disabledForegroundColor: _kPrimario40,
              side: BorderSide(
                color: count == 0 ? _kPrimario40 : _kPrimario,
                width: 2,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: _enviando
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: _kPrimario, strokeWidth: 2)),
                          const SizedBox(width: 10),
                          Text(
                            'Enviando... $_enviados / $_totalEnviar',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _totalEnviar > 0
                            ? _enviados / _totalEnviar
                            : 0,
                        backgroundColor: _kPrimario10,
                        color: _kPrimario,
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        count == 0
                            ? 'Selecciona estudiantes para enviar'
                            : 'Enviar $count certificado(s) a estudiantes',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),

        if (count > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Los estudiantes podrán ver y descargar sus certificados desde su panel',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS HELPER
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool expanded;
  final VoidCallback onToggle;

  const _CardHeader({
    required this.icon,
    required this.title,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kPrimario10,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(icon, color: _kPrimario, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _kPrimario)),
          ),
          Icon(
            expanded
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down,
            color: _kTextoGrisClaro,
          ),
        ],
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final String? hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _Campo({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.hint,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: _kPrimario),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 12, color: _kTextoGris),
        hintStyle:
            const TextStyle(fontSize: 11, color: _kTextoGrisClaro),
        prefixIcon:
            Icon(icon, size: 18, color: _kTextoGrisClaro),
        filled: true,
        fillColor: _kCampoFondo,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kPrimario, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}