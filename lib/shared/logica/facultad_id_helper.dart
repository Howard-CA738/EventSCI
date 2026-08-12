// Mismo algoritmo que FilialesService._generarId() (usado al crear las
// facultades): normaliza un nombre de facultad al mismo id de documento
// que ya vive en filiales/{filial}/facultades/{id} y en
// config_firmas/decanos/facultades/{id}.
String generarFacultadId(String texto) => texto
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]'), '_')
    .replaceAll(RegExp(r'_+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');
