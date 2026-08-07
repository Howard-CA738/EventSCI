class NotaFinalItem {
  final String studentId;
  final String nombre;
  final String codigo;
  final String ciclo;
  final String grupo;
  final bool seleccionado;
  final String proyectoCodigo;
  final double notaAsist;
  final double notaJurado;
  final double notaDocente;
  final double notaFinal;

  const NotaFinalItem({
    required this.studentId,
    required this.nombre,
    required this.codigo,
    required this.ciclo,
    required this.grupo,
    required this.seleccionado,
    required this.proyectoCodigo,
    required this.notaAsist,
    required this.notaJurado,
    required this.notaDocente,
    required this.notaFinal,
  });
}
