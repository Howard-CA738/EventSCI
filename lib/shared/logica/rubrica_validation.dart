import 'gestion_criterios.dart';

String? validarPesosSecciones({
  required List<SeccionRubrica> secciones,
  required double puntajeMaximo,
}) {
  final sumaSecciones =
      secciones.fold<double>(0.0, (s, sec) => s + sec.pesoTotal);

  if (sumaSecciones > puntajeMaximo + 0.01) {
    return 'La suma de pesos de secciones (${sumaSecciones.toStringAsFixed(2)} pts) '
        'supera el puntaje maximo (${puntajeMaximo.toStringAsFixed(2)} pts). '
        'Ajusta los pesos antes de guardar.';
  }
  return null;
}
