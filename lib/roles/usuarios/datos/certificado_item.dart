import '/shared/certificado_builder.dart';

class CertificadoItem {
  final String id;
  final DatosCertificado datos;
  final DateTime? creadoEn;
  final String nombreEstudiante;

  const CertificadoItem({
    required this.id,
    required this.datos,
    this.creadoEn,
    this.nombreEstudiante = '',
  });
}
