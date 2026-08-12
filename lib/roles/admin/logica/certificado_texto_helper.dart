const List<String> kTitulosAcademicos = [
  'dr','Dr','Mg','Psic', 'dra', 'ing', 'mg', 'mag', 'mtra', 'mtro', 'lic', 'abg',
  'msc', 'phd', 'prof', 'bach', 'econ', 'arq', 'cpc', 'psic',
];

String quitarTitulo(String nombre) {
  var r = nombre.trim();
  bool cambio = true;
  while (cambio) {
    cambio = false;
    for (final t in kTitulosAcademicos) {
      final regex = RegExp('^$t\\.?\\s+', caseSensitive: false);
      if (regex.hasMatch(r)) {
        r = r.replaceFirst(regex, '').trim();
        cambio = true;
      }
    }
  }
  return r;
}

String motivoPorRol({
  required String rol,
  required String evento,
  required String fecha,
  required String carrera,
  required String horas,
}) {
  final credito = horas.trim() == '16' ? ' con 1 crédito' : '';
  switch (rol) {
    case 'PONENTE':
      return 'Por su valiosa participación en calidad de PONENTE, en la "$evento", '
          'evento desarrollado el $fecha.';
    case 'JURADO':
      return 'Por su participación en calidad de JURADO en la "$evento", '
          'organizado por la Escuela Profesional de $carrera; '
          'realizado el $fecha. Su experticia y conocimientos han contribuido '
          'significativamente en la evaluación de trabajos de investigación.';
    case 'ORGANIZADOR':
      return 'Por su participación en calidad de ORGANIZADOR en la "$evento", '
          'promovido por la Escuela Profesional de $carrera; '
          'realizado el $fecha, con equivalencia a un total de $horas horas académicas$credito. '
          'Su apoyo ha contribuido en el éxito y el desarrollo del evento científico.';
    case 'ASISTENTE':
    default:
      return 'Por su participación en calidad de ASISTENTE en la "$evento", '
          'organizado por la Escuela Profesional de $carrera; '
          'realizado el $fecha, con equivalencia a un total de $horas horas académicas$credito.';
  }
}

const List<String> kMesesEs = [
  '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

String formatearFechaEs(DateTime d) =>
    '${d.day} de ${kMesesEs[d.month]} de ${d.year}';

String fechaActual() => formatearFechaEs(DateTime.now());
