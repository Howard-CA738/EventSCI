class FirmanteResumen {
  final String nombre;
  final String cargo;
  final String urlFirma;
  const FirmanteResumen({this.nombre = '', this.cargo = '', this.urlFirma = ''});

  bool get configurado => nombre.isNotEmpty;

  factory FirmanteResumen.fromDoc(Map<String, dynamic>? d) {
    if (d == null) return const FirmanteResumen();
    final grado  = (d['grado']  as String? ?? '').trim();
    final nombre = (d['nombre'] as String? ?? '').trim();
    return FirmanteResumen(
      nombre:   grado.isEmpty ? nombre : '$grado $nombre',
      cargo:    (d['cargo']      as String? ?? '').trim(),
      urlFirma: (d['storageUrl'] as String? ?? '').trim(),
    );
  }
}
