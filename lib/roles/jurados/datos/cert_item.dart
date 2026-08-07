import '/shared/certificado_builder.dart';

class CertItem {
  final String id;
  final DatosCertificado datos;
  final DateTime? creadoEn;
  final String nombreJurado;

  const CertItem({
    required this.id,
    required this.datos,
    this.creadoEn,
    this.nombreJurado = '',
  });
}
