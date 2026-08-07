import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../datos/asistencia_personal_config.dart';
import '../logica/configuracion_asistencia_personal_service.dart';

class ConfiguracionAsistenciaPersonalScreen extends StatefulWidget {
  final Map<String, dynamic> asistencia;
  final String docId;
  final String eventId;
  final String qrId;

  const ConfiguracionAsistenciaPersonalScreen({
    super.key,
    required this.asistencia,
    required this.docId,
    required this.eventId,
    required this.qrId,
  });

  @override
  State<ConfiguracionAsistenciaPersonalScreen> createState() =>
      _ConfiguracionAsistenciaPersonalScreenState();
}

class _ConfiguracionAsistenciaPersonalScreenState
    extends State<ConfiguracionAsistenciaPersonalScreen>
    with SingleTickerProviderStateMixin {
  final ConfiguracionAsistenciaPersonalService _service =
      ConfiguracionAsistenciaPersonalService();

  late AsistenciaPersonalConfig _config;

  bool _guardandoConfig = false;
  bool _cargandoDoc = true;

  Timer? _tickTimer;
  StreamSubscription? _asistenciaSub;

  late AnimationController _fadeCtrl;

  static const List<int> _opcionesMinutos = [5, 10, 15, 20, 30, 45, 60, 90, 120];

  static const Color _primary = Color(0xFF1E3A5F);
  static const Color _danger = Color(0xFFE53935);
  static const Color _success = Color(0xFF43A047);
  static const Color _warning = Color(0xFFFF8F00);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _initDesdeAsistencia(widget.asistencia);
    _tickTimer =
        Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
    _escucharAsistencia();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _tickTimer?.cancel();
    _asistenciaSub?.cancel();
    super.dispose();
  }

  void _initDesdeAsistencia(Map<String, dynamic> data) {
    _config = AsistenciaPersonalConfig.fromMap(data);
    _cargandoDoc = false;
  }

  void _escucharAsistencia() {
    _asistenciaSub = _service
        .watchAsistencia(eventId: widget.eventId, docId: widget.docId)
        .listen((data) {
      if (!mounted) return;
      setState(() => _initDesdeAsistencia(data));
    });
  }

  Future<void> _guardarConfiguracion() async {
    if (_config.ventanaHorariaActiva) {
      if (_config.ventanaInicio == null || _config.ventanaFin == null) {
        _snack('Define hora de inicio y fin de la ventana', error: true);
        return;
      }
      if (_config.ventanaFin!.isBefore(_config.ventanaInicio!)) {
        _snack('La hora de fin debe ser posterior al inicio', error: true);
        return;
      }
    }

    setState(() => _guardandoConfig = true);

    try {
      final updates = <String, dynamic>{
        'activo': _config.qrActivo,
        'tiempoLimiteActivo': _config.tiempoLimiteActivo,
        'tiempoLimiteMinutos': _config.tiempoLimiteMinutos,
        'ventanaHorariaActiva': _config.ventanaHorariaActiva,
        'ventanaInicio': (_config.ventanaHorariaActiva && _config.ventanaInicio != null)
            ? Timestamp.fromDate(_config.ventanaInicio!)
            : null,
        'ventanaFin': (_config.ventanaHorariaActiva && _config.ventanaFin != null)
            ? Timestamp.fromDate(_config.ventanaFin!)
            : null,
      };

      if (_config.qrActivo) {
        updates['activadoEn'] = FieldValue.serverTimestamp();
        updates['finalizadoAt'] = null;
        _config = _config.copyWith(activadoEn: DateTime.now());
      } else {
        updates['finalizadoAt'] = FieldValue.serverTimestamp();
      }

      await _service.guardarConfiguracion(
        eventId: widget.eventId,
        docId: widget.docId,
        qrId: widget.qrId,
        updates: updates,
      );

      _snack('✅ Configuración guardada');
    } catch (e) {
      _snack('Error al guardar: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardandoConfig = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final nombre = widget.asistencia['nombre'] ?? 'Asistencia';
    final eventName = widget.asistencia['eventName'] ?? '';

    return Scaffold(
      backgroundColor: _primary,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(nombre.toString(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(eventName.toString(),
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _guardandoConfig
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : IconButton(
                    icon: const Icon(Icons.save_rounded),
                    tooltip: 'Guardar configuración',
                    onPressed: _guardarConfiguracion,
                  ),
          ),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.only(top: 16),
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: _cargandoDoc
            ? const Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_primary)))
            : FadeTransition(
                opacity: _fadeCtrl,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildInfoCard(),
                        const SizedBox(height: 16),
                        _buildEstadoRealtime(),
                        const SizedBox(height: 16),
                        _buildSeccionConfig(),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed:
                              _guardandoConfig ? null : _guardarConfiguracion,
                          icon: _guardandoConfig
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.save_rounded, size: 22),
                          label: Text(
                            _guardandoConfig
                                ? 'Guardando...'
                                : 'Guardar configuración',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                        const SizedBox(height: 24),
                      ]),
                ),
              ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final nombre = widget.asistencia['nombre'] ?? 'Sin nombre';
    final eventName = widget.asistencia['eventName'] ?? '';
    final descripcion = widget.asistencia['descripcion'] ?? '';

    final nombreStr = nombre.toString();
    final inicial =
        nombreStr.isNotEmpty ? nombreStr.substring(0, 1).toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2D5F8D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              inicial,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombreStr,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _primary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.event_rounded,
                      size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(eventName.toString(),
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                if (descripcion.toString().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(descripcion.toString(),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade400),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ]),
        ),
      ]),
    );
  }

  Widget _buildEstadoRealtime() {
    final estado = _config.estadoEfectivo;
    final restante = _config.tiempoRestante;
    final paraInicio = _config.tiempoParaInicio;

    final (colorEstado, iconoEstado, labelEstado) = switch (estado) {
      'activo' => (_success, Icons.check_circle_rounded, 'QR ACTIVO'),
      'inactivo' => (
          const Color(0xFF90A4AE),
          Icons.cancel_rounded,
          'QR INACTIVO'
        ),
      'programado' => (Colors.blue, Icons.schedule_rounded, 'PROGRAMADO'),
      'expirado' => (_danger, Icons.timer_off_rounded, 'TIEMPO EXPIRADO'),
      'fuera_ventana' => (
          _warning,
          Icons.access_time_filled_rounded,
          'FUERA DE VENTANA'
        ),
      _ => (_success, Icons.check_circle_rounded, 'QR ACTIVO'),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorEstado.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorEstado.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: colorEstado.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(iconoEstado, color: colorEstado, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estado actual',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color: colorEstado.withValues(alpha: 0.7))),
                  Text(labelEstado,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorEstado)),
                ]),
          ),
          if (estado == 'activo')
            _buildPulsingDot(colorEstado),
        ]),
        if (estado == 'activo' && restante != null && restante > Duration.zero) ...[
          const SizedBox(height: 12),
          _buildCountdownRow(restante, '⏱ Expira en', Colors.orange.shade700),
        ],
        if (estado == 'programado' && paraInicio != null) ...[
          const SizedBox(height: 12),
          _buildCountdownRow(paraInicio, '🕐 Inicia en', Colors.blue.shade700),
        ],
        if (estado == 'expirado') ...[
          const SizedBox(height: 12),
          _buildAlertaRow('Tiempo agotado. Reactiva el QR para continuar.',
              _danger),
        ],
        if (estado == 'fuera_ventana') ...[
          const SizedBox(height: 12),
          _buildAlertaRow('El QR está fuera del rango horario configurado.',
              _warning),
        ],
      ]),
    );
  }

  Widget _buildPulsingDot(Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 900),
      builder: (ctx, v, _) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: v),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 6 * v,
                  spreadRadius: 1)
            ],
          ),
        );
      },
    );
  }

  Widget _buildCountdownRow(Duration d, String prefijo, Color color) {
    final urgente = d.inMinutes < 5;
    final c = urgente ? _danger : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.hourglass_bottom_rounded, size: 15, color: c),
        const SizedBox(width: 8),
        Flexible(
          child: Text('$prefijo  ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: c)),
        ),
        Text(formatearDuracion(d),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: c,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }

  Widget _buildAlertaRow(String msg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.warning_rounded, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _buildSeccionConfig() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.05),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.tune_rounded,
                  color: _primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Configuración del QR',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _primary)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildConfigBloque(
                  titulo: 'Estado del QR',
                  icono: Icons.qr_code_2_rounded,
                  color: _config.qrActivo
                      ? _success
                      : const Color(0xFF90A4AE),
                  child: _buildToggle(
                    label: _config.qrActivo ? 'QR Activo' : 'QR Inactivo',
                    descripcion: _config.qrActivo
                        ? 'Los estudiantes pueden escanear este QR'
                        : 'Nadie puede escanear este QR',
                    valor: _config.qrActivo,
                    colorOn: _success,
                    colorOff: const Color(0xFF90A4AE),
                    iconoOn: Icons.lock_open_rounded,
                    iconoOff: Icons.lock_rounded,
                    onChanged: (v) =>
                        setState(() => _config = _config.copyWith(qrActivo: v)),
                  ),
                ),
                const SizedBox(height: 14),
                _buildConfigBloque(
                  titulo: 'Límite de tiempo',
                  icono: Icons.timer_rounded,
                  color: _config.tiempoLimiteActivo
                      ? Colors.orange.shade700
                      : Colors.grey.shade400,
                  child: Column(children: [
                    _buildToggle(
                      label: 'Activar límite de tiempo',
                      descripcion:
                          'El QR expira automáticamente después del tiempo indicado',
                      valor: _config.tiempoLimiteActivo,
                      colorOn: Colors.orange.shade700,
                      colorOff: Colors.grey,
                      iconoOn: Icons.timer_rounded,
                      iconoOff: Icons.timer_off_rounded,
                      onChanged: (v) => setState(() =>
                          _config = _config.copyWith(tiempoLimiteActivo: v)),
                    ),
                    if (_config.tiempoLimiteActivo) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _opcionesMinutos.map((min) {
                          final sel = _config.tiempoLimiteMinutos == min;
                          return GestureDetector(
                            onTap: () => setState(() => _config =
                                _config.copyWith(tiempoLimiteMinutos: min)),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: sel
                                    ? Colors.orange.shade700
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: sel
                                        ? Colors.orange.shade700
                                        : Colors.grey.shade300),
                                boxShadow: sel
                                    ? [
                                        BoxShadow(
                                            color: Colors.orange
                                                .withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2))
                                      ]
                                    : [],
                              ),
                              child: Text(
                                min >= 60 ? '${min ~/ 60}h' : '${min}min',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: sel
                                        ? Colors.white
                                        : Colors.grey.shade700),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        const Icon(Icons.remove, size: 18, color: _primary),
                        Expanded(
                          child: Slider(
                            value: _config.tiempoLimiteMinutos
                                .clamp(1, 120)
                                .toDouble(),
                            min: 1,
                            max: 120,
                            divisions: 119,
                            activeColor: Colors.orange.shade700,
                            onChanged: (v) => setState(() => _config =
                                _config.copyWith(
                                    tiempoLimiteMinutos: v.toInt())),
                          ),
                        ),
                        const Icon(Icons.add, size: 18, color: _primary),
                      ]),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _config.tiempoLimiteMinutos >= 60
                                ? '${_config.tiempoLimiteMinutos ~/ 60}h ${_config.tiempoLimiteMinutos % 60 > 0 ? '${_config.tiempoLimiteMinutos % 60}min' : ''}'
                                : '${_config.tiempoLimiteMinutos} minutos',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildInfoTip(
                        icono: Icons.info_outline,
                        texto:
                            'El contador inicia al guardar con el QR activo. Puedes reactivarlo cuando quieras.',
                        color: Colors.orange.shade700,
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 14),
                _buildConfigBloque(
                  titulo: 'Ventana horaria',
                  icono: Icons.access_time_rounded,
                  color: _config.ventanaHorariaActiva
                      ? Colors.blue.shade700
                      : Colors.grey.shade400,
                  child: Column(children: [
                    _buildToggle(
                      label: 'Activar ventana horaria',
                      descripcion:
                          'El QR solo funciona dentro del rango de horas que definas',
                      valor: _config.ventanaHorariaActiva,
                      colorOn: Colors.blue.shade700,
                      colorOff: Colors.grey,
                      iconoOn: Icons.access_time_rounded,
                      iconoOff: Icons.access_time_filled_rounded,
                      onChanged: (v) => setState(() =>
                          _config = _config.copyWith(ventanaHorariaActiva: v)),
                    ),
                    if (_config.ventanaHorariaActiva) ...[
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: _buildSelectorHora(
                            label: 'INICIO',
                            hora: _config.ventanaInicio != null
                                ? TimeOfDay(
                                    hour: _config.ventanaInicio!.hour,
                                    minute: _config.ventanaInicio!.minute)
                                : null,
                            color: Colors.blue.shade700,
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _config.ventanaInicio != null
                                    ? TimeOfDay(
                                        hour: _config.ventanaInicio!.hour,
                                        minute: _config.ventanaInicio!.minute)
                                    : TimeOfDay.now(),
                                builder: (ctx, child) => Theme(
                                  data: Theme.of(ctx).copyWith(
                                      colorScheme:
                                          const ColorScheme.light(
                                              primary: _primary)),
                                  child: child!,
                                ),
                              );
                              if (picked != null && mounted) {
                                final ahora = DateTime.now();
                                setState(() => _config = _config.copyWith(
                                    ventanaInicio: DateTime(
                                        ahora.year,
                                        ahora.month,
                                        ahora.day,
                                        picked.hour,
                                        picked.minute)));
                              }
                            },
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.arrow_forward_rounded,
                              color: Colors.grey.shade400, size: 22),
                        ),
                        Expanded(
                          child: _buildSelectorHora(
                            label: 'FIN',
                            hora: _config.ventanaFin != null
                                ? TimeOfDay(
                                    hour: _config.ventanaFin!.hour,
                                    minute: _config.ventanaFin!.minute)
                                : null,
                            color: Colors.red.shade700,
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _config.ventanaFin != null
                                    ? TimeOfDay(
                                        hour: _config.ventanaFin!.hour,
                                        minute: _config.ventanaFin!.minute)
                                    : TimeOfDay.now(),
                                builder: (ctx, child) => Theme(
                                  data: Theme.of(ctx).copyWith(
                                      colorScheme:
                                          const ColorScheme.light(
                                              primary: _primary)),
                                  child: child!,
                                ),
                              );
                              if (picked != null && mounted) {
                                final ahora = DateTime.now();
                                setState(() => _config = _config.copyWith(
                                    ventanaFin: DateTime(
                                        ahora.year,
                                        ahora.month,
                                        ahora.day,
                                        picked.hour,
                                        picked.minute)));
                              }
                            },
                          ),
                        ),
                      ]),
                      if (_config.ventanaInicio != null &&
                          _config.ventanaFin != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.schedule_rounded,
                                    size: 16, color: Colors.blue),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Activo de ${_config.ventanaInicio!.hour.toString().padLeft(2, '0')}:${_config.ventanaInicio!.minute.toString().padLeft(2, '0')} a ${_config.ventanaFin!.hour.toString().padLeft(2, '0')}:${_config.ventanaFin!.minute.toString().padLeft(2, '0')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue),
                                  ),
                                ),
                              ]),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _buildInfoTip(
                        icono: Icons.info_outline,
                        texto:
                            'Si combinas con límite de tiempo, ambas restricciones aplican a la vez.',
                        color: Colors.blue.shade700,
                      ),
                    ],
                  ]),
                ),
              ]),
        ),
      ]),
    );
  }

  Widget _buildConfigBloque({
    required String titulo,
    required IconData icono,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Icon(icono, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(14), child: child),
      ]),
    );
  }

  Widget _buildToggle({
    required String label,
    required String descripcion,
    required bool valor,
    required Color colorOn,
    required Color colorOff,
    required IconData iconoOn,
    required IconData iconoOff,
    required ValueChanged<bool> onChanged,
  }) {
    final color = valor ? colorOn : colorOff;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(valor ? iconoOn : iconoOff, size: 18, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _primary)),
              const SizedBox(height: 3),
              Text(descripcion,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
            ]),
      ),
      Switch(value: valor, onChanged: onChanged, activeThumbColor: colorOn),
    ]);
  }

  Widget _buildSelectorHora({
    required String label,
    required TimeOfDay? hora,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Icon(Icons.access_time_rounded, size: 20, color: color),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              hora != null
                  ? '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}'
                  : '--:--',
              maxLines: 1,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: hora != null ? color : Colors.grey.shade400),
            ),
          ),
          const SizedBox(height: 4),
          Text('Toca para cambiar',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 9, color: color.withValues(alpha: 0.6))),
        ]),
      ),
    );
  }

  Widget _buildInfoTip(
      {required IconData icono,
      required String texto,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(icono, size: 13, color: color),
        const SizedBox(width: 8),
        Expanded(
            child:
                Text(texto, style: TextStyle(fontSize: 11, color: color))),
      ]),
    );
  }
}
