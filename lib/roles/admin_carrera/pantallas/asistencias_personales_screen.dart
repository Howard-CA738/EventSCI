import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '/prefs_helper.dart';
import 'configuracion_asistencias_personales.dart';
import '../logica/asistencias_personales_service.dart';
import 'widgets/skeleton.dart';
import 'widgets/asistencia_personal_qr_dialog.dart';
import 'widgets/asistencia_personal_card.dart';

class AsistenciasPersonalesScreen extends StatefulWidget {


  final String? filialId;
  final String? filialNombre;
  final String? facultad;
  final String? carreraId;
  final String? carreraNombre;

  const AsistenciasPersonalesScreen({
    super.key,
    this.filialId,
    this.filialNombre,
    this.facultad,
    this.carreraId,
    this.carreraNombre,
  });

  @override
  State<AsistenciasPersonalesScreen> createState() =>
      _AsistenciasPersonalesScreenState();
}

class _AsistenciasPersonalesScreenState
    extends State<AsistenciasPersonalesScreen> with TickerProviderStateMixin {
  final AsistenciasPersonalesService _service = AsistenciasPersonalesService();

  String? _filialId;
  String? _filialNombre;
  String? _facultad;
  String? _carreraId;
  String? _carreraNombre;
  bool _isLoadingSession = true;

  List<Map<String, dynamic>> _eventos = [];
  bool _cargandoEventos = false;
  Map<String, dynamic>? _eventoSeleccionado;

  int _paso = 0;

  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  String? _qrData;
  bool _creandoQR = false;
  Map<String, dynamic>? _asistenciaCreada;

  List<Map<String, dynamic>> _misAsistencias = [];
  bool _cargandoAsistencias = false;
  String? _filtroEventoId;

  late AnimationController _fadeCtrl;
  late AnimationController _qrScaleCtrl;




  static const Color _primary = Color(0xFF1E3A5F);
  static const Color _primaryLight = Color(0xFF2D5F8D);
  static const Color _danger = Color(0xFFE53935);
  static const Color _success = Color(0xFF43A047);
  static const Color _bg = Color(0xFFF5F7FA);
  static const Color _surface = Colors.white;
  static const Color _muted = Color(0xFF64748B);


  static final List<BoxShadow> _cardShadow = [
    BoxShadow(
      color: _primary.withValues(alpha: 0.06),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
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

  Future<void> _loadSessionData() async {
  setState(() => _isLoadingSession = true);
  try {

    final tieneSesionExterna = widget.facultad != null ||
        widget.carreraId != null ||
        widget.filialId != null;

    if (tieneSesionExterna) {
      setState(() {
        _filialId = widget.filialId;
        _filialNombre = widget.filialNombre;
        _facultad = widget.facultad;
        _carreraId = widget.carreraId;
        _carreraNombre = widget.carreraNombre;
      });
      await _cargarEventos();
      return;
    }

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

  if (_facultad == null && _carreraNombre == null) return;
  setState(() => _cargandoEventos = true);
  try {
    final filtrados = await _service.cargarEventos(
      filialNombre: _filialNombre,
      facultad: _facultad,
      carreraNombre: _carreraNombre,
    );

    setState(() {
      _eventos = filtrados;
      _cargandoEventos = false;
    });
  } catch (e) {
    setState(() => _cargandoEventos = false);
    _snack('Error al cargar eventos: $e', error: true);
  }
}

  Future<void> _cargarMisAsistencias() async {
    if (_eventos.isEmpty) return;
    setState(() => _cargandoAsistencias = true);
    try {
      final todas = await _service.cargarMisAsistencias(
        eventos: _eventos,
        filtroEventoId: _filtroEventoId,
      );

      setState(() {
        _misAsistencias = todas;
        _cargandoAsistencias = false;
      });
    } catch (e) {
      setState(() => _cargandoAsistencias = false);
      _snack('Error al cargar asistencias: $e', error: true);
    }
  }

  Future<void> _confirmarEliminar(Map<String, dynamic> asistencia) async {
    final nombre = asistencia['nombre'] ?? 'esta asistencia';
    final docId = asistencia['docId'] as String;
    final eventId = asistencia['eventId'] as String;
    final qrId = asistencia['qrId'] as String? ?? '';
    final codigo = asistencia['codigo'] as String? ?? '';

    final mq = MediaQuery.of(context);
    final maxH = (mq.size.height
            - mq.viewInsets.bottom
            - mq.padding.top
            - mq.padding.bottom
            - 48)
        .clamp(260.0, 440.0);

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
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
                    child: Text(
                      'Eliminar asistencia',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _primary),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.5),
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
                    border: Border.all(
                        color: _danger.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: _danger.withValues(alpha: 0.8)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Se eliminará el QR, el código y todos los datos asociados. Esta acción no se puede deshacer.',
                        style: TextStyle(fontSize: 12, color: _danger),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancelar',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.delete_rounded, size: 16),
                      label: const Text('Eliminar',
                          style:
                              TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmado == true) {
      HapticFeedback.mediumImpact();
      await _eliminarAsistencia(
          docId: docId,
          eventId: eventId,
          qrId: qrId,
          codigo: codigo,
          nombre: nombre);
    }
  }

  Future<void> _eliminarAsistencia({
    required String docId,
    required String eventId,
    required String qrId,
    required String codigo,
    required String nombre,
  }) async {
    try {
      await _service.eliminarAsistencia(
        docId: docId,
        eventId: eventId,
        qrId: qrId,
        codigo: codigo,
      );

      setState(() {
        _misAsistencias.removeWhere((a) => a['docId'] == docId);
      });

      _snack('Asistencia "$nombre" eliminada');
    } catch (e) {
      _snack('Error al eliminar: $e', error: true);
    }
  }

  Future<void> _crearAsistenciaYQR() async {
    if (!_formKey.currentState!.validate()) return;
    if (_eventoSeleccionado == null) return;
    HapticFeedback.lightImpact();
    setState(() => _creandoQR = true);

    try {
      final eventId = _eventoSeleccionado!['id'] as String;
      final eventName = _eventoSeleccionado!['name'] ??
          _eventoSeleccionado!['nombre'] ??
          'Evento';

      final resultado = await _service.crearAsistenciaYQR(
        eventId: eventId,
        eventName: eventName,
        filialId: _filialId,
        filialNombre: _filialNombre,
        facultad: _facultad,
        carreraId: _carreraId,
        carreraNombre: _carreraNombre,
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
      );

      setState(() {
        _qrData = resultado['qrData'] as String;
        _asistenciaCreada = resultado;
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primary,
      appBar: _buildAppBar(),
      body: Column(children: [
        if (_paso == 0) _buildTabBar(),
        Expanded(
          child: Container(
            margin: _paso == 0
                ? EdgeInsets.zero
                : const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              color: _bg,
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
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_primary)))
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
            setState(() => _paso = 0);
            _tabController.animateTo(1);
            _cargarMisAsistencias();
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulos[_paso]!,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: -0.3),
            ),
            const Text(
              'Asistencias Personales',
              style: TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ]),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(26),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            const Icon(Icons.location_city,
                color: Colors.white60, size: 13),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '${_filialNombre ?? ''} › ${_facultad ?? ''} › ${_carreraNombre ?? ''}',
                style:
                    const TextStyle(color: Colors.white60, fontSize: 12),
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
        labelStyle: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 13),
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

    return TabBarView(
      controller: _tabController,
      children: [
        _buildTabCrear(),
        _buildTabLista(),
      ],
    );
  }

  Widget _buildTabCrear() {
    return FadeTransition(
      opacity: _fadeCtrl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Crea una asistencia con el nombre que quieras, luego configura cuándo funciona el QR desde "Mis asistencias".',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          height: 1.4),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              if (_eventoSeleccionado == null)
                _buildSelectorEventoTarjeta()
              else
                _buildEventoSeleccionadoChip(),
              const SizedBox(height: 20),
              if (_eventoSeleccionado != null) _buildFormularioCrear(),
            ]),
      ),
    );
  }

  Widget _buildSelectorEventoTarjeta() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _paso = 1);
        _fadeCtrl.forward(from: 0);
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _primary.withValues(alpha: 0.3), width: 1.5),
          boxShadow: _cardShadow,
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.event_rounded,
                color: _primary, size: 24),
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
                  Text(
                      'Toca para elegir el evento al que pertenecerá',
                      style: TextStyle(fontSize: 12, color: _muted)),
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
        gradient: const LinearGradient(
            colors: [_primary, _primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        boxShadow: _cardShadow,
      ),
      child: Row(children: [
        const Icon(Icons.event_rounded, color: Colors.white70, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Evento seleccionado',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 11)),
                Text(
                  nombre.toString(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _paso = 1);
            _fadeCtrl.forward(from: 0);
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
            child: const Text('Cambiar',
                style:
                    TextStyle(color: Colors.white70, fontSize: 11)),
          ),
        ),
      ]),
    );
  }

  Widget _buildFormularioCrear() {
    return Form(
      key: _formKey,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nombre de la asistencia',
                hintText: 'Ej: Ingreso Mañana, Control Tarde, Cierre...',
                prefixIcon: const Icon(Icons.edit_rounded),
                filled: true,
                fillColor: _surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFDDE3EA))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFDDE3EA))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _primary, width: 1.5)),
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
                fillColor: _surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFDDE3EA))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFDDE3EA))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _primary, width: 1.5)),
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
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
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

  Widget _buildTabLista() {
    return RefreshIndicator(
      onRefresh: _cargarMisAsistencias,
      color: _primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_eventos.isNotEmpty) _buildFiltroEvento(),
              const SizedBox(height: 16),
              Row(children: [
                const Flexible(
                  child: Text(
                    'Asistencias creadas',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
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
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _cargarMisAsistencias();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.refresh,
                        size: 18, color: _primary),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (_cargandoAsistencias)
                Column(
                    children: List.generate(
                        4, (_) => _buildSkeletonCard()))
              else if (_misAsistencias.isEmpty)
                _buildEmptyAsistencias()
              else
                ...List.generate(_misAsistencias.length, (i) {
                  final asistencia = _misAsistencias[i];
                  return TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 260 + i * 50),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutCubic,
                    builder: (ctx, v, child) => Transform.translate(
                      offset: Offset(0, 14 * (1 - v)),
                      child: Opacity(opacity: v, child: child),
                    ),
                    child: AsistenciaPersonalCard(
                      asistencia: asistencia,
                      onVerQR: () => mostrarQrAsistenciaPersonalDialog(
                          context, asistencia),
                      onConfigurar: () => _abrirConfiguracion(
                        asistencia: asistencia,
                        docId: asistencia['docId'] as String,
                        eventId: asistencia['eventId'] as String,
                        qrId: (asistencia['qrId'] as String?) ?? '',
                      ),
                      onEliminar: () => _confirmarEliminar(asistencia),
                    ),
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

  Widget _buildFiltroChip({
    required String label,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: seleccionado ? _primary : _surface,
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
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: seleccionado ? Colors.white : _primary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }


  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _cardShadow,
      ),
      child: Row(children: [
        const Skeleton(height: 46, width: 46, radius: 12),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Skeleton(height: 13, width: 170, radius: 6),
              SizedBox(height: 9),
              Skeleton(height: 10, width: 110, radius: 6),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildEmptyAsistencias() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _cardShadow),
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
                fontWeight: FontWeight.w700,
                color: _primary)),
        const SizedBox(height: 8),
        Text(
          'Ve a la pestaña "Crear" para generar\ntu primera asistencia con QR.',
          style: TextStyle(
              fontSize: 13, color: Colors.grey[500], height: 1.5),
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            elevation: 0,
          ),
        ),
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
    _cargarMisAsistencias();
  }

  Widget _buildPasoSeleccionEvento() {
    return FadeTransition(
      opacity: _fadeCtrl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Flexible(
                  child: Text(
                    'Eventos de tu carrera',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
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
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _cargarEventos();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.refresh,
                        size: 18, color: _primary),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (_cargandoEventos)
                Column(
                    children: List.generate(
                        4, (_) => _buildSkeletonCard()))
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
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _cardShadow),
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
                fontWeight: FontWeight.w700,
                color: _primary)),
        const SizedBox(height: 8),
        Text(
          'No hay eventos registrados para esta carrera.\nCrea uno en Gestión de Eventos.',
          style: TextStyle(
              fontSize: 13, color: Colors.grey[500], height: 1.5),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  Widget _buildEventoCard(Map<String, dynamic> evento) {
    final nombreRaw =
        evento['name'] ?? evento['nombre'] ?? 'Sin nombre';
    final nombre = nombreRaw.toString();
    final inicial =
        nombre.isNotEmpty ? nombre.substring(0, 1).toUpperCase() : '?';
    final periodo = (evento['periodoNombre'] ?? '').toString();

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _eventoSeleccionado = evento;
          _paso = 0;
        });
        _fadeCtrl.forward(from: 0);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_primary, _primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                inicial,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (periodo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.calendar_today,
                          size: 11, color: _muted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          periodo,
                          style: const TextStyle(
                              fontSize: 12, color: _muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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

  Widget _buildPasoQRResultado() {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.88, end: 1.0).animate(
          CurvedAnimation(
              parent: _qrScaleCtrl, curve: Curves.easeOutBack)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                        color: _primary.withValues(alpha: 0.10),
                        blurRadius: 24,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: Column(children: [
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
                                  letterSpacing: 0.5,
                                  color: Colors.white)),
                        ]),
                  ),
                  const SizedBox(height: 20),
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


                  if ((_asistenciaCreada?['codigo'] ?? '')
                      .toString()
                      .isNotEmpty) ...[
                    const SizedBox(height: 16),
                    buildCodigoManualBox(
                        _asistenciaCreada!['codigo'].toString()),
                  ],

                  const SizedBox(height: 20),
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
                            _infoRow(
                                Icons.notes,
                                'Descripción:',
                                _asistenciaCreada!['descripcion']
                                    .toString()),
                        ]),
                  ),
                  const SizedBox(height: 16),
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
                              fontSize: 12,
                              color: Colors.blue[700],
                              height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _paso = 0);
                          _tabController.animateTo(1);
                          _cargarMisAsistencias();
                        },
                        icon: const Icon(Icons.list_alt_rounded, size: 16),
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
                        icon: const Icon(Icons.add_circle_outline,
                            size: 16),
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
          child: Text(
            value,
            style: const TextStyle(
                color: Color(0xFF4A5568), fontSize: 12.5),
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
        ),
      ]),
    );
  }
}
