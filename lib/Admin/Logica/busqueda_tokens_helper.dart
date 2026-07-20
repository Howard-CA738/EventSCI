class BusquedaTokensHelper {
  static String normalizarTexto(String texto) {
    var normalizado = texto.trim().toLowerCase();
    const acentos = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n', 'ç': 'c',
    };
    acentos.forEach((a, r) => normalizado = normalizado.replaceAll(a, r));
    return normalizado;
  }

  static List<String> generarTokens({
    required String name,
    String? codigoUniversitario,
    String? username,
  }) {
    final Set<String> tokens = {};

    void agregarPrefijos(String palabra) {
      final limpia = palabra.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (limpia.length < 2) return;
      for (int i = 2; i <= limpia.length; i++) {
        tokens.add(limpia.substring(0, i));
      }
    }

    final nombreNormalizado = normalizarTexto(name);
    for (final palabra in nombreNormalizado.split(RegExp(r'\s+'))) {
      agregarPrefijos(palabra);
    }

    if (codigoUniversitario != null && codigoUniversitario.trim().isNotEmpty) {
      agregarPrefijos(codigoUniversitario.toLowerCase());
    }

    if (username != null && username.trim().isNotEmpty) {
      for (final parte in username.toLowerCase().split('.')) {
        agregarPrefijos(parte);
      }
    }

    return tokens.toList();
  }

  static List<String> extraerPalabrasBusqueda(String term, {int maxPalabras = 5}) {
    final normalizado = normalizarTexto(term);
    return normalizado
        .split(RegExp(r'\s+'))
        .map((p) => p.replaceAll(RegExp(r'[^a-z0-9]'), ''))
        .where((p) => p.length >= 2)
        .take(maxPalabras)
        .toList();
  }
}