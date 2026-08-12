class Persona {
  final String id;
  final String nombre;
  final String dni;
  final String codigo;
  final bool esJurado;

  Persona({
    required this.id,
    required this.nombre,
    this.dni = '',
    this.codigo = '',
    this.esJurado = false,
  });
}
