import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _parseFecha(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  return null;
}

class AsistenciaPersonalConfig {
  final bool qrActivo;
  final bool tiempoLimiteActivo;
  final int tiempoLimiteMinutos;
  final bool ventanaHorariaActiva;
  final DateTime? ventanaInicio;
  final DateTime? ventanaFin;
  final DateTime? activadoEn;

  const AsistenciaPersonalConfig({
    required this.qrActivo,
    required this.tiempoLimiteActivo,
    required this.tiempoLimiteMinutos,
    required this.ventanaHorariaActiva,
    this.ventanaInicio,
    this.ventanaFin,
    this.activadoEn,
  });

  factory AsistenciaPersonalConfig.fromMap(Map<String, dynamic> data) {
    return AsistenciaPersonalConfig(
      qrActivo: data['activo'] == true,
      tiempoLimiteActivo: data['tiempoLimiteActivo'] == true,
      tiempoLimiteMinutos:
          (data['tiempoLimiteMinutos'] as num?)?.toInt() ?? 30,
      ventanaHorariaActiva: data['ventanaHorariaActiva'] == true,
      ventanaInicio: _parseFecha(data['ventanaInicio']),
      ventanaFin: _parseFecha(data['ventanaFin']),
      activadoEn: _parseFecha(data['activadoEn']),
    );
  }

  AsistenciaPersonalConfig copyWith({
    bool? qrActivo,
    bool? tiempoLimiteActivo,
    int? tiempoLimiteMinutos,
    bool? ventanaHorariaActiva,
    DateTime? ventanaInicio,
    DateTime? ventanaFin,
    DateTime? activadoEn,
  }) {
    return AsistenciaPersonalConfig(
      qrActivo: qrActivo ?? this.qrActivo,
      tiempoLimiteActivo: tiempoLimiteActivo ?? this.tiempoLimiteActivo,
      tiempoLimiteMinutos: tiempoLimiteMinutos ?? this.tiempoLimiteMinutos,
      ventanaHorariaActiva: ventanaHorariaActiva ?? this.ventanaHorariaActiva,
      ventanaInicio: ventanaInicio ?? this.ventanaInicio,
      ventanaFin: ventanaFin ?? this.ventanaFin,
      activadoEn: activadoEn ?? this.activadoEn,
    );
  }

  String get estadoEfectivo {
    if (!qrActivo) return 'inactivo';
    final ahora = DateTime.now();
    if (ventanaHorariaActiva && ventanaInicio != null && ventanaFin != null) {
      if (ahora.isBefore(ventanaInicio!)) return 'programado';
      if (ahora.isAfter(ventanaFin!)) return 'fuera_ventana';
    }
    if (tiempoLimiteActivo && activadoEn != null) {
      final expira = activadoEn!.add(Duration(minutes: tiempoLimiteMinutos));
      if (ahora.isAfter(expira)) return 'expirado';
    }
    return 'activo';
  }

  Duration? get tiempoRestante {
    if (!tiempoLimiteActivo || activadoEn == null) return null;
    final expira = activadoEn!.add(Duration(minutes: tiempoLimiteMinutos));
    final r = expira.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  Duration? get tiempoParaInicio {
    if (!ventanaHorariaActiva || ventanaInicio == null) return null;
    final r = ventanaInicio!.difference(DateTime.now());
    return r.isNegative ? null : r;
  }
}

String formatearDuracion(Duration d) {
  if (d.inHours > 0) {
    return '${d.inHours}h ${d.inMinutes.remainder(60).toString().padLeft(2, '0')}m ${d.inSeconds.remainder(60).toString().padLeft(2, '0')}s';
  }
  if (d.inMinutes > 0) {
    return '${d.inMinutes}m ${d.inSeconds.remainder(60).toString().padLeft(2, '0')}s';
  }
  return '${d.inSeconds}s';
}
