import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '/prefs_helper.dart';
import 'configuracion_asistencias_personales.dart';
import 'dart:convert';

class AsistenciasPersonalesScreen extends StatefulWidget {
  const AsistenciasPersonalesScreen({super.key});

  @override
  State<AsistenciasPersonalesScreen> createState() =>
      _AsistenciasPersonalesScreenState();
}

class _AsistenciasPersonalesScreenState
    extends State<AsistenciasPersonalesScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Sesión ────────────────────────────────────────────────────────────────
  String? _filialId;
  String? _filialNombre;
  String? _facultad;
  String? _carreraId;
  String? _carreraNombre;
  bool _isLoadingSession = true;

  // ── Eventos ───────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _eventos = [];
  bool _cargandoEventos = false;
  Map<String, dynamic>? _eventoSeleccionado;

  // ── Vista actual: 0=lista eventos, 1=formulario crear, 2=QR resultado ─────
  int _paso = 0;

  // ── Tab: 0=Crear, 1=Mis asistencias ──────────────────────────────────────
  int _tabActual = 0;
  late TabController _tabController;

  // ── Formulario ────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  // ── QR resultado ─────────────────────────────────────────────────────────
  String? _qrData;
  String? _qrId;
  String? _asistenciaDocId;
  bool _creandoQR = false;
  Map<String, dynamic>? _asistenciaCreada;

  // ── Lista de asistencias ─────────────────────────────────────────────────
  List<Map<String, dynamic>> _misAsistencias = [];
  bool _cargandoAsistencias = false;
  String? _filtroEventoId; // null = todas

  // ── Animaciones ───────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late AnimationController _qrScaleCtrl;

  // ── Colores ───────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF1E3A5F);
  static const Color _accent = Color(0xFF0D7377);
  static const Color _danger = Color(0xFFE53935);
  static const Color _success = Color(0xFF43A047);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() => _tabActual = _tabController.index);
      if (_tabController.index == 1) _cargarMisAsistencias();
    });
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _qrScaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _loadSessionData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeCtrl.dispose();
    _qrScaleCtrl.dispose();
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SESIÓN
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadSessionData() async {
    setState(() => _isLoadingSession = true);
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData != null) {
        setState(() {
          _filialId = adminData['filial'];
          _filialNombre = adminData['filialNombre'];
          _facultad = adminData['facultad'];
          _carreraId = adminData['carreraId'] ?? adminData['carrera'];
          _carreraNombre = adminData['carrera'];
        });
        await _cargarEventos();
      }
    } catch (e) {
      _snack('Error al cargar la sesión', error: true);
    } finally {
      setState(() => _isLoadingSession = false);
    }
  }

  Future<void> _cargarEventos() async {
    if (_filialId == null || _facultad == null || _carreraId == null) return;
    setState(() => _cargandoEventos = true);
    try {
      final snap = await _firestore
          .collection('events')
          .where('filialId', isEqualTo: _filialId)
          .where('facultad', isEqualTo: _facultad)
          .where('carreraId', isEqualTo: _carreraId)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _eventos = snap.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        _cargandoEventos = false;
      });
    } catch (e) {
      setState(() => _cargandoEventos = false);
      _snack('Error al cargar eventos: $e', error: true);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MIS ASISTENCIAS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _cargarMisAsistencias() async {
    if (_eventos.isEmpty) return;
    setState(() => _cargandoAsistencias = true);
    try {
      final List<Map<String, dynamic>> todas = [];

      // Determinar eventos a consultar
      final eventosAConsultar = _filtroEventoId != null
          ? _eventos.where((e) => e['id'] == _filtroEventoId).toList()
          : _eventos;

      for (final evento in eventosAConsultar) {
        final snap = await _firestore
            .collection('events')
            .doc(evento['id'] as String)
            .collection('asistencias_personales')
            .orderBy('createdAt', descending: true)
            .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          data['docId'] = doc.id;
          data['eventId'] = evento['id'];
          data['eventName'] =
              evento['name'] ?? evento['nombre'] ?? 'Evento';
          todas.add(data);
        }
      }

      setState(() {
        _misAsistencias = todas;
        _cargandoAsistencias = false;
      });
    } catch (e) {
      setState(() => _cargandoAsistencias = false);
      _snack('Error al cargar asistencias: $e', error: true);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ELIMINAR ASISTENCIA
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _confirmarEliminar(Map<String, dynamic> asistencia) async {
    final nombre = asistencia['nombre'] ?? 'esta asistencia';
    final docId = asistencia['docId'] as String;
    final eventId = asistencia['eventId'] as String;
    final qrId = asistencia['qrId'] as String? ?? '';

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.delete_outline_rounded,
                color: _danger, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Eliminar asistencia',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _primary)),
          ),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade700, height: 1.5),
              children: [
                const TextSpan(text: '¿Seguro que deseas eliminar '),
                TextSpan(
                  text: '"$nombre"',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: _primary),
                ),
                const TextSpan(text: '?'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _danger.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: _danger.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded,
                  size: 16, color: _danger.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Se eliminará el QR y todos los datos asociados. Esta acción no se puede deshacer.',
                  style: TextStyle(fontSize: 12, color: _danger),
                ),
              ),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancelar',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Eliminar',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      await _eliminarAsistencia(
          docId: docId, eventId: eventId, qrId: qrId, nombre: nombre);
    }
  }

  Future<void> _eliminarAsistencia({
    required String docId,
    required String eventId,
    required String qrId,
    required String nombre,
  }) async {
    try {
      // Eliminar asistencia_personal
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias_personales')
          .doc(docId)
          .delete();

      // Eliminar qr_code asociado (si existe)
      if (qrId.isNotEmpty) {
        await _firestore
            .collection('events')
            .doc(eventId)
            .collection('qr_codes')
            .doc(qrId)
            .delete();
      }

      // Quitar de la lista local inmediatamente
      setState(() {
        _misAsistencias
            .removeWhere((a) => a['docId'] == docId);
      });

      _snack('Asistencia "$nombre" eliminada');
    } catch (e) {
      _snack('Error al eliminar: $e', error: true);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CREAR ASISTENCIA Y QR
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _crearAsistenciaYQR() async {
    if (!_formKey.currentState!.validate()) return;
    if (_eventoSeleccionado == null) return;
    setState(() => _creandoQR = true);

    try {
      final eventId = _eventoSeleccionado!['id'] as String;
      final eventName =
          _eventoSeleccionado!['name'] ?? _eventoSeleccionado!['nombre'] ?? 'Evento';

      final asistenciaRef = _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias_personales')
          .doc();
      final asistenciaId = asistenciaRef.id;

      final qrRef = _firestore
          .collection('events')
          .doc(eventId)
          .collection('qr_codes')
          .doc();
      final qrId = qrRef.id;

      final ahora = DateTime.now();

      final payload = {
        'filialId': _filialId,
        'filialNombre': _filialNombre,
        'facultad': _facultad,
        'carreraId': _carreraId,
        'carrera': _carreraNombre,
        'eventId': eventId,
        'eventName': eventName,
        'asistenciaId': asistenciaId,
        'nombre': _nombreCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'qrId': qrId,
        'timestamp': ahora.toIso8601String(),
        'type': 'asistencia_personal',
      };

      await asistenciaRef.set({
        'filialId': _filialId,
        'filialNombre': _filialNombre,
        'facultad': _facultad,
        'carreraId': _carreraId,
        'carrera': _carreraNombre,
        'eventId': eventId,
        'eventName': eventName,
        'nombre': _nombreCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'qrId': qrId,
        'createdAt': FieldValue.serverTimestamp(),
        'generadoPor': 'admin_carrera',
        'activo': true,
        'activadoEn': FieldValue.serverTimestamp(),
        'finalizadoAt': null,
        'tiempoLimiteActivo': false,
        'tiempoLimiteMinutos': 30,
        'ventanaHorariaActiva': false,
        'ventanaInicio': null,
        'ventanaFin': null,
      });

      await qrRef.set({
        'filialId': _filialId,
        'filialNombre': _filialNombre,
        'facultad': _facultad,
        'carreraId': _carreraId,
        'carrera': _carreraNombre,
        'eventId': eventId,
        'eventName': eventName,
        'nombre': _nombreCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'asistenciaId': asistenciaId,
        'activo': true,
        'type': 'asistencia_personal',
        'createdAt': FieldValue.serverTimestamp(),
        'finalizadoAt': null,
        'generadoPor': 'admin_carrera',
        'tiempoLimiteActivo': false,
        'tiempoLimiteMinutos': 30,
        'ventanaHorariaActiva': false,
        'ventanaInicio': null,
        'ventanaFin': null,
      });

      setState(() {
        _qrData = jsonEncode(payload);
        _qrId = qrId;
        _asistenciaDocId = asistenciaId;
        _asistenciaCreada = {
          'nombre': _nombreCtrl.text.trim(),
          'descripcion': _descripcionCtrl.text.trim(),
          'eventName': eventName,
          'eventId': eventId,
          'asistenciaId': asistenciaId,
          'qrId': qrId,
        };
        _creandoQR = false;
        _paso = 2;
      });

      _qrScaleCtrl.forward(from: 0);
      _snack('¡Asistencia creada y QR generado!');
    } catch (e) {
      setState(() => _creandoQR = false);
      _snack('Error al crear asistencia: $e', error: true);
    }
  }

  void _resetearFlujo() {
    setState(() {
      _paso = 0;
      _eventoSeleccionado = null;
      _qrData = null;
      _qrId = null;
      _asistenciaDocId = null;
      _asistenciaCreada = null;
      _nombreCtrl.clear();
      _descripcionCtrl.clear();
    });
    _fadeCtrl.forward(from: 0);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            error ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: error ? _danger : _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primary,
      appBar: _buildAppBar(),
      body: Column(children: [
        // Tab bar solo cuando está en la pantalla principal (paso 0)
        if (_paso == 0) _buildTabBar(),
        Expanded(
          child: Container(
            margin: _paso == 0
                ? EdgeInsets.zero
                : const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: _paso == 0
                  ? BorderRadius.zero
                  : const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
            ),
            child: _isLoadingSession
                ? const Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_primary)))
                : _buildCuerpo(),
          ),
        ),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final titulos = {
      0: 'Asistencias Personales',
      1: 'Seleccionar Evento',
      2: 'QR Generado',
    };
    return AppBar(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (_paso == 1) {
            setState(() => _paso = 0);
          } else if (_paso == 2) {
            // Volver al tab de lista y recargar
            setState(() => _paso = 0);
            _tabController.animateTo(1);
            _cargarMisAsistencias();
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulos[_paso]!,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        const Text('Asistencias Personales',
            style: TextStyle(fontSize: 11, color: Colors.white60)),
      ]),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(26),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            const Icon(Icons.location_city, color: Colors.white60, size: 13),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '${_filialNombre ?? ''} › ${_facultad ?? ''} › ${_carreraNombre ?? ''}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: _primary,
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: const [
          Tab(icon: Icon(Icons.add_circle_outline, size: 18), text: 'Crear'),
          Tab(
              icon: Icon(Icons.list_alt_rounded, size: 18),
              text: 'Mis asistencias'),
        ],
      ),
    );
  }

  Widget _buildCuerpo() {
    if (_paso == 1) return _buildPasoSeleccionEvento();
    if (_paso == 2) return _buildPasoQRResultado();

    // Paso 0: tabs
    return TabBarView(
      controller: _tabController,
      children: [
        _buildTabCrear(),
        _buildTabLista(),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1 — CREAR ASISTENCIA
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTabCrear() {
    return FadeTransition(
      opacity: _fadeCtrl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Info tip
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Crea una asistencia con el nombre que quieras, luego configura cuándo funciona el QR desde "Mis asistencias".',
                  style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // Evento seleccionado o selector
          if (_eventoSeleccionado == null)
            _buildSelectorEventoTarjeta()
          else
            _buildEventoSeleccionadoChip(),

          const SizedBox(height: 20),

          // Formulario (solo si hay evento seleccionado)
          if (_eventoSeleccionado != null) _buildFormularioCrear(),
        ]),
      ),
    );
  }

  Widget _buildSelectorEventoTarjeta() {
    return GestureDetector(
      onTap: () {
        setState(() => _paso = 1);
        _fadeCtrl.forward(from: 0);
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _primary.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: _primary.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.event_rounded, color: _primary, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selecciona un evento',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _primary)),
                  SizedBox(height: 4),
                  Text('Toca para elegir el evento al que pertenecerá',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ]),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.arrow_forward_ios_rounded,
                color: _primary, size: 14),
          ),
        ]),
      ),
    );
  }

  Widget _buildEventoSeleccionadoChip() {
    final nombre = _eventoSeleccionado?['name'] ??
        _eventoSeleccionado?['nombre'] ??
        'Evento';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _primary, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.event_rounded, color: Colors.white70, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Evento seleccionado',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                Text(nombre,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ]),
        ),
        GestureDetector(
          onTap: () {
            setState(() => _paso = 1);
            _fadeCtrl.forward(from: 0);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
            child: const Text('Cambiar',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ),
        ),
      ]),
    );
  }

  Widget _buildFormularioCrear() {
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Nombre libre
        TextFormField(
          controller: _nombreCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Nombre de la asistencia',
            hintText: 'Ej: Ingreso Mañana, Control Tarde, Cierre...',
            prefixIcon: const Icon(Icons.edit_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE3EA))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE3EA))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primary, width: 1.5)),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Campo requerido' : null,
        ),

        const SizedBox(height: 14),

        TextFormField(
          controller: _descripcionCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Descripción (opcional)',
            hintText: 'Agrega detalles adicionales...',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 42),
              child: Icon(Icons.notes_rounded),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE3EA))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE3EA))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primary, width: 1.5)),
          ),
        ),

        const SizedBox(height: 28),

        ElevatedButton.icon(
          onPressed: _creandoQR ? null : _crearAsistenciaYQR,
          icon: _creandoQR
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.qr_code_2_rounded, size: 22),
          label: Text(
            _creandoQR ? 'Creando...' : 'Crear y generar QR',
            style:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2 — MIS ASISTENCIAS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTabLista() {
    return RefreshIndicator(
      onRefresh: _cargarMisAsistencias,
      color: _primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Filtro por evento
          if (_eventos.isNotEmpty) _buildFiltroEvento(),

          const SizedBox(height: 16),

          // Header con contador
          Row(children: [
            const Text('Asistencias creadas',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _primary)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${_misAsistencias.length}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: _primary,
                      fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _cargarMisAsistencias,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8)),
                child:
                    const Icon(Icons.refresh, size: 18, color: _primary),
              ),
            ),
          ]),

          const SizedBox(height: 12),

          if (_cargandoAsistencias)
            const Center(
                child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_primary)),
            ))
          else if (_misAsistencias.isEmpty)
            _buildEmptyAsistencias()
          else
            ...List.generate(_misAsistencias.length, (i) {
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 260 + i * 50),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutCubic,
                builder: (ctx, v, child) => Transform.translate(
                  offset: Offset(0, 14 * (1 - v)),
                  child: Opacity(opacity: v, child: child),
                ),
                child: _buildAsistenciaCard(_misAsistencias[i]),
              );
            }),
        ]),
      ),
    );
  }

  Widget _buildFiltroEvento() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Chip "Todos"
          _buildFiltroChip(
            label: 'Todos',
            seleccionado: _filtroEventoId == null,
            onTap: () {
              setState(() => _filtroEventoId = null);
              _cargarMisAsistencias();
            },
          ),
          const SizedBox(width: 8),
          ..._eventos.map((e) {
            final id = e['id'] as String;
            final nombre = e['name'] ?? e['nombre'] ?? 'Evento';
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFiltroChip(
                label: nombre.toString(),
                seleccionado: _filtroEventoId == id,
                onTap: () {
                  setState(() => _filtroEventoId = id);
                  _cargarMisAsistencias();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(
      {required String label,
      required bool seleccionado,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: seleccionado ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: seleccionado ? _primary : const Color(0xFFDDE3EA)),
          boxShadow: seleccionado
              ? [
                  BoxShadow(
                      color: _primary.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: seleccionado ? Colors.white : _primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _buildEmptyAsistencias() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9), shape: BoxShape.circle),
          child: const Icon(Icons.qr_code_2_rounded,
              size: 48, color: Color(0xFF43A047)),
        ),
        const SizedBox(height: 16),
        const Text('Sin asistencias aún',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _primary)),
        const SizedBox(height: 8),
        Text(
          'Ve a la pestaña "Crear" para generar\ntu primera asistencia con QR.',
          style:
              TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _tabController.animateTo(0),
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Crear asistencia'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ),
      ]),
    );
  }

  Widget _buildAsistenciaCard(Map<String, dynamic> asistencia) {
    final nombre = asistencia['nombre'] ?? 'Sin nombre';
    final eventName = asistencia['eventName'] ?? '';
    final activo = asistencia['activo'] == true;
    final descripcion = asistencia['descripcion'] ?? '';
    final docId = asistencia['docId'] as String;
    final eventId = asistencia['eventId'] as String;
    final qrId = asistencia['qrId'] as String? ?? '';

    final colorEstado = activo ? _success : const Color(0xFF90A4AE);
    final labelEstado = activo ? 'Activo' : 'Inactivo';

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _confirmarEliminar(asistencia);
        // Siempre retornamos false: la eliminación se maneja en _eliminarAsistencia
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _danger,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          const Text('Eliminar',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: [
          // Cabecera
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF2D5F8D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    nombre.toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre.toString(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _primary)),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.event_rounded,
                            size: 11, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(eventName.toString(),
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                      if (descripcion.toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(descripcion.toString(),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade400),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ]),
              ),
              // Badge estado
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: colorEstado.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: colorEstado, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(labelEstado,
                      style: TextStyle(
                          fontSize: 11,
                          color: colorEstado,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),

          // Configuraciones activas (si las hay)
          _buildConfigResumen(asistencia),

          // Botones del footer: Configurar | Eliminar
          Container(
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.04),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(children: [
              // Botón Configurar
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16)),
                    onTap: () => _abrirConfiguracion(
                        asistencia: asistencia,
                        docId: docId,
                        eventId: eventId,
                        qrId: qrId),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.tune_rounded,
                                color: _primary, size: 15),
                            SizedBox(width: 6),
                            Text('Configurar QR',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _primary)),
                          ]),
                    ),
                  ),
                ),
              ),

              // Divisor vertical
              Container(
                  width: 1,
                  height: 36,
                  color: _primary.withValues(alpha: 0.08)),

              // Botón Eliminar
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(16)),
                  onTap: () => _confirmarEliminar(asistencia),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded,
                          color: _danger.withValues(alpha: 0.8), size: 15),
                      const SizedBox(width: 6),
                      Text('Eliminar',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _danger.withValues(alpha: 0.8))),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildConfigResumen(Map<String, dynamic> a) {
    final tiempoActivo = a['tiempoLimiteActivo'] == true;
    final ventanaActiva = a['ventanaHorariaActiva'] == true;
    if (!tiempoActivo && !ventanaActiva) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        if (tiempoActivo)
          _buildMiniChip(
            Icons.timer_rounded,
            '${a['tiempoLimiteMinutos'] ?? 30} min',
            Colors.orange.shade700,
          ),
        if (ventanaActiva)
          _buildMiniChip(
            Icons.access_time_rounded,
            'Ventana horaria',
            Colors.blue.shade700,
          ),
      ]),
    );
  }

  Widget _buildMiniChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10.5,
                color: color,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  void _abrirConfiguracion({
    required Map<String, dynamic> asistencia,
    required String docId,
    required String eventId,
    required String qrId,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfiguracionAsistenciaPersonalScreen(
          asistencia: asistencia,
          docId: docId,
          eventId: eventId,
          qrId: qrId,
        ),
      ),
    );
    // Al volver, recargar lista
    _cargarMisAsistencias();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PASO 1 — SELECCIÓN DE EVENTO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPasoSeleccionEvento() {
    return FadeTransition(
      opacity: _fadeCtrl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Eventos de tu carrera',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _primary)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${_eventos.length}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: _primary,
                      fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _cargarEventos,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8)),
                child:
                    const Icon(Icons.refresh, size: 18, color: _primary),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (_cargandoEventos)
            const Center(
                child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_primary)),
            ))
          else if (_eventos.isEmpty)
            _buildEmptyEventos()
          else
            ...List.generate(_eventos.length, (i) {
              final evento = _eventos[i];
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 280 + i * 50),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutCubic,
                builder: (ctx, v, child) => Transform.translate(
                  offset: Offset(0, 16 * (1 - v)),
                  child: Opacity(opacity: v, child: child),
                ),
                child: _buildEventoCard(evento),
              );
            }),
        ]),
      ),
    );
  }

  Widget _buildEmptyEventos() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
              color: Color(0xFFFFF3E0), shape: BoxShape.circle),
          child: const Icon(Icons.event_busy_rounded,
              size: 48, color: Color(0xFFFF9800)),
        ),
        const SizedBox(height: 16),
        const Text('No hay eventos disponibles',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _primary)),
        const SizedBox(height: 8),
        Text(
          'No hay eventos registrados para esta carrera.\nCrea uno en Gestión de Eventos.',
          style:
              TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.5),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  Widget _buildEventoCard(Map<String, dynamic> evento) {
    final nombre = evento['name'] ?? evento['nombre'] ?? 'Sin nombre';
    final periodo = evento['periodoNombre'] ?? '';

    return GestureDetector(
      onTap: () {
        setState(() {
          _eventoSeleccionado = evento;
          _paso = 0;
        });
        _fadeCtrl.forward(from: 0);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF2D5F8D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(nombre.toString().substring(0, 1).toUpperCase(),
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
                  Text(nombre.toString(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _primary)),
                  if (periodo.toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.calendar_today,
                          size: 11, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(periodo.toString(),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B))),
                    ]),
                  ],
                ]),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.check_rounded,
                color: _primary, size: 16),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PASO 2 — QR RESULTADO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPasoQRResultado() {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.88, end: 1.0).animate(
          CurvedAnimation(parent: _qrScaleCtrl, curve: Curves.easeOutBack)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                        color: _primary.withValues(alpha: 0.10),
                        blurRadius: 24,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: Column(children: [
                  // Badge éxito
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                        color: _success,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('ASISTENCIA CREADA',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ]),
                  ),

                  const SizedBox(height: 20),

                  // QR
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFE0E7ED), width: 2),
                    ),
                    child: QrImageView(
                      data: _qrData!,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Info resumida
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF5F8FA),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(Icons.event, 'Evento:',
                              _asistenciaCreada?['eventName'] ?? ''),
                          _infoRow(Icons.label, 'Nombre:',
                              _asistenciaCreada?['nombre'] ?? ''),
                          if ((_asistenciaCreada?['descripcion'] ?? '')
                              .toString()
                              .isNotEmpty)
                            _infoRow(Icons.notes, 'Descripción:',
                                _asistenciaCreada!['descripcion'].toString()),
                        ]),
                  ),

                  const SizedBox(height: 16),

                  // Aviso: configurar desde lista
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Para configurar el tiempo límite, ventana horaria o desactivar el QR, ve a "Mis asistencias".',
                          style: TextStyle(
                              fontSize: 12, color: Colors.blue[700]),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // Botones
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _paso = 0);
                          _tabController.animateTo(1);
                          _cargarMisAsistencias();
                        },
                        icon:
                            const Icon(Icons.list_alt_rounded, size: 16),
                        label: const Text('Ver lista'),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: _primary),
                          foregroundColor: _primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _resetearFlujo,
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text('Crear otra'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ]),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 13, color: _primary.withValues(alpha: 0.45)),
        const SizedBox(width: 6),
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: _primary)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: Color(0xFF4A5568), fontSize: 12.5),
              overflow: TextOverflow.ellipsis,
              maxLines: 3),
        ),
      ]),
    );
  }
}