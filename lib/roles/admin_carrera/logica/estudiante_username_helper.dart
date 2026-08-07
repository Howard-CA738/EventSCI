const _acentos = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
};

String limpiarUsername(String input) {
  String cleaned = input.toLowerCase();
  _acentos.forEach((k, v) => cleaned = cleaned.replaceAll(k, v));
  return cleaned.replaceAll(RegExp(r'[^a-z0-9.]'), '');
}

String generarUsernameDesdeNombres(String nombres, String apellidos) {
  if (nombres.isEmpty && apellidos.isEmpty) return '';
  final n =
      nombres.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();
  final a =
      apellidos.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();
  String username = n.isNotEmpty ? n[0] : '';
  if (a.isNotEmpty) username += username.isNotEmpty ? '.${a[0]}' : a[0];
  return limpiarUsername(username);
}

String extraerUsernameDeCorreo(String correo) {
  if (correo.contains('@upeu.edu.pe')) {
    return correo.split('@')[0];
  }
  return '';
}
