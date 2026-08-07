import 'package:cloud_firestore/cloud_firestore.dart';

class CertificadoEnviado {
  final String id;
  final String evento;
  final String rol;
  final String fecha;
  final String codigoCertificado;
  final Timestamp? creadoEn;
  final Map<String, dynamic> raw;

  CertificadoEnviado({
    required this.id,
    required this.evento,
    required this.rol,
    required this.fecha,
    required this.codigoCertificado,
    this.creadoEn,
    required this.raw,
  });

  bool get tieneDatosCompletos =>
      (raw['motivo'] as String? ?? '').trim().isNotEmpty;

  factory CertificadoEnviado.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return CertificadoEnviado(
      id: doc.id,
      evento: (d['evento'] as String? ?? '').trim(),
      rol: (d['rol'] as String? ?? '').trim(),
      fecha: (d['fecha'] as String? ?? '').trim(),
      codigoCertificado: (d['codigoCertificado'] as String? ?? '').trim(),
      creadoEn: d['creadoEn'] as Timestamp?,
      raw: d,
    );
  }
}
