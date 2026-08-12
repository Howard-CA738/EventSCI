class CategoriaData {
  final String nombre;
  final List<Map<String, dynamic>> proyectos;
  final int conEval;

  CategoriaData({required this.nombre, required this.proyectos})
      : conEval =
            proyectos.where((p) => p['tieneEvaluaciones'] == true).length;
}
