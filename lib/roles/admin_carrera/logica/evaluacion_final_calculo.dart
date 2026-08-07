import '../datos/eval_final_config.dart';

String normalizarNombre(String s) {
  var t = s.toLowerCase().trim();
  const conTilde = 'áàäâãéèëêíìïîóòöôõúùüûñ';
  const sinTilde = 'aaaaaeeeeiiiiooooouuuun';
  for (var i = 0; i < conTilde.length; i++) {
    t = t.replaceAll(conTilde[i], sinTilde[i]);
  }
  final palabras = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList()
    ..sort();
  return palabras.join(' ');
}

double calcularNotaFinal({
  required bool seleccionado,
  required double notaAsist,
  required double notaJurado,
  required double notaDocente,
  required EvalFinalConfig config,
}) {
  double notaFinal;

  if (!seleccionado) {
    if (config.incluirDocenteNoSel) {
      notaFinal = (notaAsist * config.pctAsistNoSel / 100) +
          (notaDocente * config.pctDocenteNoSel / 100);
    } else {
      notaFinal = notaAsist * config.pctAsistNoSel / 100;
    }
  } else {
    if (config.modalidad == 'jurado') {
      notaFinal = (notaAsist * config.pctAsistSel / 100) +
          (notaJurado * config.pctJuradoSel / 100);
    } else {
      notaFinal = (notaAsist * config.pctAsistSelMixta / 100) +
          (notaJurado * config.pctJuradoSelMixta / 100) +
          (notaDocente * config.pctDocenteSelMixta / 100);
    }
  }

  return notaFinal.clamp(0.0, 20.0);
}
