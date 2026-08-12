List<String> facultadesDisponibles(
    Map<String, dynamic> estructuraFiliales, String? filial) {
  if (filial == null || !estructuraFiliales.containsKey(filial)) return [];
  final filialData = estructuraFiliales[filial];
  final facultades = filialData['facultades'] as Map<String, dynamic>?;
  if (facultades == null) return [];
  return facultades.keys.toList();
}

List<Map<String, dynamic>> carrerasDisponibles(
  Map<String, dynamic> estructuraFiliales,
  String? filial,
  String? facultad,
) {
  if (filial == null ||
      facultad == null ||
      !estructuraFiliales.containsKey(filial)) {
    return [];
  }
  final filialData = estructuraFiliales[filial];
  final facultades = filialData['facultades'] as Map<String, dynamic>?;
  if (facultades == null || !facultades.containsKey(facultad)) return [];
  final facultadData = facultades[facultad];
  return List<Map<String, dynamic>>.from(facultadData['carreras'] ?? []);
}
