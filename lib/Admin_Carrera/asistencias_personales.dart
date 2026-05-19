import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '/prefs_helper.dart';
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

  // ── Datos de sesión (cargados igual que GestionGruposCarreraScreen) ───────
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

  // ── Paso del flujo: 0=lista eventos, 1=formulario, 2=QR ──────────────────
  int _paso = 0;

  // ── Formulario ────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  String _tipoSeleccionado = 'Primera Asistencia';

  static const List<String> _tiposAsistencia = [
    'Primera Asistencia',
    'Asistencia Intermedia',
    'Asistencia Final',
    'Asistencia de Apertura',
    'Asistencia de Clausura',
    'Asistencia de Control',
    'Personalizada',
  ];

  // ── QR ────────────────────────────────────────────────────────────────────
  String? _qrData;
  String? _qrId;
  bool _qrFinalizado = false;
  bool _finalizando = false;
  bool _creandoQR = false;
  Map<String, dynamic>? _asistenciaCreada;

  // ── Animaciones ───────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late AnimationController _qrScaleCtrl;

  // ── Colores ───────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF1E3A5F);
  static const Color _accent = Color(0xFF0D7377);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _qrScaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _loadSessionData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _qrScaleCtrl.dispose();
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CARGA DE SESIÓN — idéntica a GestionGruposCarreraScreen
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
      debugPrint('Error cargando datos de sesión: $e');
      _snack('Error al cargar datos de la sesión', error: true);
    } finally {
      setState(() => _isLoadingSession = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CARGA DE EVENTOS — mismo query que GestionGruposCarreraScreen
  //   filialId + facultad + carreraId
  // ══════════════════════════════════════════════════════════════════════════

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

      final eventos = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      setState(() {
        _eventos = eventos;
        _cargandoEventos = false;
      });
    } catch (e) {
      setState(() => _cargandoEventos = false);
      _snack('Error al cargar eventos: $e', error: true);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CREAR ASISTENCIA PERSONAL Y GENERAR QR
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

      final payload = {
        // Identidad de sesión (para validación en el escáner)
        'filialId': _filialId,
        'filialNombre': _filialNombre,
        'facultad': _facultad,
        'carreraId': _carreraId,
        'carrera': _carreraNombre,
        // Evento
        'eventId': eventId,
        'eventName': eventName,
        // Asistencia
        'asistenciaId': asistenciaId,
        'tipo': _tipoSeleccionado,
        'nombre': _nombreCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        // Control QR
        'qrId': qrId,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'asistencia_personal',
        'activo': true,
      };

      // Guardar asistencia personal
      await asistenciaRef.set({
        'filialId': _filialId,
        'filialNombre': _filialNombre,
        'facultad': _facultad,
        'carreraId': _carreraId,
        'carrera': _carreraNombre,
        'eventId': eventId,
        'eventName': eventName,
        'tipo': _tipoSeleccionado,
        'nombre': _nombreCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'qrId': qrId,
        'createdAt': FieldValue.serverTimestamp(),
        'generadoPor': 'admin_carrera',
      });

      // Guardar QR
      await qrRef.set({
        'filialId': _filialId,
        'filialNombre': _filialNombre,
        'facultad': _facultad,
        'carreraId': _carreraId,
        'carrera': _carreraNombre,
        'eventId': eventId,
        'eventName': eventName,
        'tipo': _tipoSeleccionado,
        'nombre': _nombreCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'asistenciaId': asistenciaId,
        'activo': true,
        'type': 'asistencia_personal',
        'createdAt': FieldValue.serverTimestamp(),
        'finalizadoAt': null,
        'generadoPor': 'admin_carrera',
      });

      setState(() {
        _qrData = jsonEncode(payload);
        _qrId = qrId;
        _qrFinalizado = false;
        _asistenciaCreada = {
          'tipo': _tipoSeleccionado,
          'nombre': _nombreCtrl.text.trim(),
          'descripcion': _descripcionCtrl.text.trim(),
          'eventName': eventName,
          'eventId': eventId,
          'asistenciaId': asistenciaId,
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

  // ══════════════════════════════════════════════════════════════════════════
  // FINALIZAR QR
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _finalizarQR() async {
    if (_qrId == null || _qrFinalizado) return;
    setState(() => _finalizando = true);

    try {
      final eventId = _asistenciaCreada!['eventId'] as String;
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('qr_codes')
          .doc(_qrId)
          .update({
        'activo': false,
        'finalizadoAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _qrFinalizado = true;
        _finalizando = false;
      });

      _snack('QR finalizado. Ya no podrá escanearse.');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) _resetearFlujo();
    } catch (e) {
      setState(() => _finalizando = false);
      _snack('Error al finalizar QR: $e', error: true);
    }
  }

  void _resetearFlujo() {
    setState(() {
      _paso = 0;
      _eventoSeleccionado = null;
      _qrData = null;
      _qrId = null;
      _qrFinalizado = false;
      _asistenciaCreada = null;
      _nombreCtrl.clear();
      _descripcionCtrl.clear();
      _tipoSeleccionado = 'Primera Asistencia';
    });
    _fadeCtrl.forward(from: 0);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor:
            error ? const Color(0xFFE53935) : const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD PRINCIPAL
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primary,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: _isLoadingSession
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_primary),
                      ),
                    )
                  : _buildCuerpo(),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final titulos = [
      'Seleccionar Evento',
      'Crear Asistencia',
      'Código QR',
    ];
    return AppBar(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (_paso == 1) {
            setState(() => _paso = 0);
          } else if (_paso == 2 && !_qrFinalizado) {
            setState(() => _paso = 1);
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulos[_paso],
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const Text(
            'Asistencias Personales',
            style: TextStyle(fontSize: 11, color: Colors.white60),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(26),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.location_city,
                  color: Colors.white60, size: 13),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  '${_filialNombre ?? ''} › ${_facultad ?? ''} › ${_carreraNombre ?? ''}',
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCuerpo() {
    switch (_paso) {
      case 0:
        return _buildPasoEventos();
      case 1:
        return _buildPasoFormulario();
      case 2:
        return _buildPasoQR();
      default:
        return const SizedBox.shrink();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PASO 0 — LISTA DE EVENTOS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPasoEventos() {
    return FadeTransition(
      opacity: _fadeCtrl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tarjeta de contexto (igual que GestionGruposCarreraScreen) ─
            _buildContextCard(),
            const SizedBox(height: 20),

            // ── Banner informativo ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha:0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha:0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Crea asistencias manuales como "Primera Asistencia" o "Asistencia Final". Toca un evento para comenzar.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Encabezado con contador ────────────────────────────────────
            Row(
              children: [
                const Text(
                  'Eventos de tu carrera',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _primary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_eventos.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                // Botón recargar
                GestureDetector(
                  onTap: _cargarEventos,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha:0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.refresh,
                        size: 18, color: _primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Lista o estado vacío ───────────────────────────────────────
            if (_cargandoEventos)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_primary),
                  ),
                ),
              )
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
          ],
        ),
      ),
    );
  }

  /// Tarjeta de contexto idéntica a GestionGruposCarreraScreen
  Widget _buildContextCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.school, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _carreraNombre ?? '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _facultad ?? '—',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _filialNombre ?? '—',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30),
            ),
            child: const Text(
              'Tu carrera',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyEventos() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF3E0),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_busy_rounded,
                size: 48, color: Color(0xFFFF9800)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay eventos disponibles',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay eventos registrados para esta carrera.\nCrea uno en Gestión de Eventos.',
            style: TextStyle(
                fontSize: 13, color: Colors.grey[500], height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEventoCard(Map<String, dynamic> evento) {
    final nombre = evento['name'] ?? evento['nombre'] ?? 'Sin nombre';
    final periodo = evento['periodoNombre'] ?? '';

    return GestureDetector(
      onTap: () {
        setState(() {
          _eventoSeleccionado = evento;
          _nombreCtrl.text = _tipoSeleccionado;
          _paso = 1;
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
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar con inicial del evento
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF2D5F8D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  nombre.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
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
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _primary,
                    ),
                  ),
                  if (periodo.toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 11, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          periodo.toString(),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: _primary,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PASO 1 — FORMULARIO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPasoFormulario() {
    final eventName = _eventoSeleccionado?['name'] ??
        _eventoSeleccionado?['nombre'] ??
        'Evento';

    return FadeTransition(
      opacity: _fadeCtrl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Evento seleccionado ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_rounded,
                        color: Colors.white70, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Evento seleccionado',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 11),
                          ),
                          Text(
                            eventName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _paso = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha:0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Cambiar',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Tipo de asistencia',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _primary),
              ),
              const SizedBox(height: 10),

              // ── Chips de tipo ──────────────────────────────────────────
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tiposAsistencia.map((tipo) {
                  final sel = tipo == _tipoSeleccionado;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _tipoSeleccionado = tipo);
                      if (tipo != 'Personalizada') {
                        _nombreCtrl.text = tipo;
                      } else {
                        _nombreCtrl.clear();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? _primary : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel
                              ? _primary
                              : const Color(0xFFDDE3EA),
                          width: sel ? 1.5 : 1,
                        ),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                  color: _primary.withValues(alpha:0.22),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : [],
                      ),
                      child: Text(
                        tipo,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : _primary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // ── Nombre ─────────────────────────────────────────────────
              TextFormField(
                controller: _nombreCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre de la asistencia',
                  hintText: 'Ej: Primera Asistencia - Turno Mañana',
                  prefixIcon: const Icon(Icons.label_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFDDE3EA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFDDE3EA)),
                  ),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Campo requerido'
                    : null,
              ),

              const SizedBox(height: 14),

              // ── Descripción ────────────────────────────────────────────
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
                    borderSide:
                        const BorderSide(color: Color(0xFFDDE3EA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFDDE3EA)),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Botón crear ────────────────────────────────────────────
              ElevatedButton.icon(
                onPressed: _creandoQR ? null : _crearAsistenciaYQR,
                icon: _creandoQR
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
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
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PASO 2 — VISTA DEL QR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPasoQR() {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.88, end: 1.0).animate(
        CurvedAnimation(
            parent: _qrScaleCtrl, curve: Curves.easeOutBack),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha:0.10),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Badge estado ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: _qrFinalizado
                      ? Colors.red.shade600
                      : _primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _qrFinalizado
                          ? Icons.block
                          : Icons.assignment_turned_in_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _qrFinalizado
                            ? 'QR FINALIZADO'
                            : (_asistenciaCreada?['nombre'] ?? ''),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Imagen QR ──────────────────────────────────────────────
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _qrFinalizado
                            ? Colors.red.shade300
                            : const Color(0xFFE0E7ED),
                        width: 2,
                      ),
                    ),
                    child: Opacity(
                      opacity: _qrFinalizado ? 0.2 : 1.0,
                      child: QrImageView(
                        data: _qrData!,
                        version: QrVersions.auto,
                        size: 240,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  if (_qrFinalizado)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block,
                              color: Colors.white, size: 44),
                          SizedBox(height: 6),
                          Text(
                            'QR INACTIVO',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Info ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Contexto'),
                    _infoRow(Icons.location_city, 'Filial:',
                        _filialNombre ?? ''),
                    _infoRow(Icons.account_balance, 'Facultad:',
                        _facultad ?? ''),
                    _infoRow(Icons.menu_book, 'Carrera:',
                        _carreraNombre ?? ''),
                    const Divider(height: 20, thickness: 0.6),
                    _sectionLabel('Asistencia'),
                    _infoRow(Icons.event, 'Evento:',
                        _asistenciaCreada?['eventName'] ?? ''),
                    _infoRow(Icons.category, 'Tipo:',
                        _asistenciaCreada?['tipo'] ?? ''),
                    _infoRow(Icons.label, 'Nombre:',
                        _asistenciaCreada?['nombre'] ?? ''),
                    if ((_asistenciaCreada?['descripcion'] ?? '')
                        .toString()
                        .isNotEmpty)
                      _infoRow(Icons.notes, 'Descripción:',
                          _asistenciaCreada!['descripcion'].toString()),
                    const Divider(height: 20, thickness: 0.6),
                    _sectionLabel('Control'),
                    _infoRow(
                        Icons.fingerprint, 'ID QR:', _qrId ?? 'N/A'),
                    _infoRow(
                      Icons.circle,
                      'Estado:',
                      _qrFinalizado ? '🔴 Inactivo' : '🟢 Activo',
                    ),
                    _infoRow(
                      Icons.schedule,
                      'Generado:',
                      DateTime.now().toString().split('.')[0],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Botones ────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _qrFinalizado ? null : _resetearFlujo,
                      icon: const Icon(Icons.add_circle_outline,
                          size: 18),
                      label: const Text('Nueva'),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: _qrFinalizado
                              ? Colors.grey.shade300
                              : _primary,
                        ),
                        foregroundColor: _qrFinalizado
                            ? Colors.grey.shade400
                            : _primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _qrFinalizado || _finalizando
                          ? null
                          : _finalizarQR,
                      icon: _finalizando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Icon(
                              _qrFinalizado
                                  ? Icons.check_circle
                                  : Icons.lock_outline,
                              size: 18,
                            ),
                      label: Text(
                        _finalizando
                            ? 'Finalizando...'
                            : _qrFinalizado
                                ? 'Finalizado'
                                : 'Finalizar QR',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: _qrFinalizado
                            ? Colors.grey.shade400
                            : (_finalizando
                                ? Colors.orange.shade600
                                : Colors.red.shade600),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers de UI ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: _accent,
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: _primary.withValues(alpha:0.45)),
          const SizedBox(width: 6),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: _primary),
            ),
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
        ],
      ),
    );
  }
}