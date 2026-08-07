const double escalaBaseParticipantes = 20.0;

String formatearTexto(dynamic v, [String fallback = '—']) {
  if (v == null) return fallback;
  final s = v.toString().trim();
  return s.isEmpty ? fallback : s;
}

String formatearDecimal(dynamic v, [int dec = 2]) {
  final d = v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  return d.toStringAsFixed(dec);
}

List<String> extraerCodigosIntegrantes(dynamic integrantes) {
  if (integrantes == null) return [];
  if (integrantes is List) {
    return integrantes.map((e) => e.toString().trim()).toList();
  }
  if (integrantes is String) {
    return integrantes
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return [];
}

class ResultadoRanking {
  final double promedio;
  final double promedioJurados;
  final double promedioRaw;
  final double? notaDocente;
  final double notaMax;
  final double notaMin;
  final int cantidadJurados;
  final String nombresJurados;
  final List<double> notas;
  final List<double> notasRaw;
  final bool tieneEvaluaciones;
  final bool tieneNotaDocente;

  const ResultadoRanking({
    required this.promedio,
    required this.promedioJurados,
    required this.promedioRaw,
    required this.notaDocente,
    required this.notaMax,
    required this.notaMin,
    required this.cantidadJurados,
    required this.nombresJurados,
    required this.notas,
    required this.notasRaw,
    required this.tieneEvaluaciones,
    required this.tieneNotaDocente,
  });

  factory ResultadoRanking.sinEvaluaciones({String nombresJurados = ''}) {
    return ResultadoRanking(
      promedio: 0.0,
      promedioJurados: 0.0,
      promedioRaw: 0.0,
      notaDocente: null,
      notaMax: 0.0,
      notaMin: 0.0,
      cantidadJurados: 0,
      nombresJurados: nombresJurados,
      notas: const <double>[],
      notasRaw: const <double>[],
      tieneEvaluaciones: false,
      tieneNotaDocente: false,
    );
  }
}

/// Calcula el ranking (promedios, notaDocente combinada, nota final) a partir
/// de los datos crudos de evaluaciones ya obtenidos de Firestore. No hace
/// ninguna llamada de red — recibe todo como parámetros, por lo que es
/// fácilmente testeable con datos de ejemplo.
ResultadoRanking calcularRanking({
  required List<Map<String, dynamic>> evaluaciones,
  required List<String> codigosIntegrantes,
  required Map<String, double> notasDocente,
}) {
  if (evaluaciones.isEmpty) return ResultadoRanking.sinEvaluaciones();

  final notasNormalizadas = <double>[];
  final notasRaw = <double>[];
  final nombresJurados = <String>[];

  for (final data in evaluaciones) {
    final notaTotal = (data['notaTotal'] ?? 0.0 as num).toDouble();

    final nombreJurado = formatearTexto(data['juradoNombre'], '');
    if (nombreJurado.isNotEmpty) {
      nombresJurados.add(nombreJurado);
    }

    if (!data.containsKey('puntajeMaximo')) continue;

    final puntajeMax = (data['puntajeMaximo'] as num).toDouble();
    final maxSeguro = puntajeMax > 0 ? puntajeMax : escalaBaseParticipantes;
    final normalizada = ((notaTotal / maxSeguro) * escalaBaseParticipantes)
        .clamp(0.0, escalaBaseParticipantes);

    notasNormalizadas.add(double.parse(normalizada.toStringAsFixed(2)));
    notasRaw.add(notaTotal);
  }

  if (notasNormalizadas.isEmpty) {
    return ResultadoRanking.sinEvaluaciones(
        nombresJurados: nombresJurados.join(', '));
  }

  final promedio =
      notasNormalizadas.reduce((a, b) => a + b) / notasNormalizadas.length;
  final promedioRaw = notasRaw.reduce((a, b) => a + b) / notasRaw.length;
  final notaMax = notasNormalizadas.reduce((a, b) => a > b ? a : b);
  final notaMin = notasNormalizadas.reduce((a, b) => a < b ? a : b);

  double? notaDoc;
  if (notasDocente.isNotEmpty) {
    for (final cod in codigosIntegrantes) {
      if (notasDocente.containsKey(cod)) {
        notaDoc = notasDocente[cod];
        break;
      }
    }
  }

  final notaFinal = notaDoc != null ? (promedio + notaDoc) / 2.0 : promedio;

  return ResultadoRanking(
    promedio: double.parse(notaFinal.toStringAsFixed(2)),
    promedioJurados: double.parse(promedio.toStringAsFixed(2)),
    promedioRaw: double.parse(promedioRaw.toStringAsFixed(2)),
    notaDocente: notaDoc,
    notaMax: notaMax,
    notaMin: notaMin,
    cantidadJurados: notasNormalizadas.length,
    nombresJurados: nombresJurados.join(', '),
    notas: notasNormalizadas,
    notasRaw: notasRaw,
    tieneEvaluaciones: true,
    tieneNotaDocente: notaDoc != null,
  );
}
