import 'package:flutter/material.dart';
import '../../logica/participantes_ranking_calculator.dart';
import 'participantes_shared.dart';

class DetalleProyectoSheet extends StatelessWidget {
  final Map<String, dynamic> proyecto;
  final int posicion;

  const DetalleProyectoSheet({
    super.key,
    required this.proyecto,
    required this.posicion,
  });

  @override
  Widget build(BuildContext context) {
    final promedio        = (proyecto['promedio']        as num?)?.toDouble() ?? 0.0;
    final promedioJurados = (proyecto['promedioJurados'] as num?)?.toDouble() ?? promedio;
    final promedioRaw     = (proyecto['promedioRaw']     as num?)?.toDouble() ?? 0.0;
    final notaDocente     = proyecto['notaDocente'] as double?;
    final notaMax         = (proyecto['notaMax']     as num?)?.toDouble() ?? 0.0;
    final notaMin         = (proyecto['notaMin']     as num?)?.toDouble() ?? 0.0;
    final jurados         = (proyecto['cantidadJurados'] as int?) ?? 0;
    final nombresJurados  = formatearTexto(proyecto['nombresJurados'], '');
    final notas           = (proyecto['notas']    as List?)?.cast<double>() ?? [];
    final notasRaw        = (proyecto['notasRaw'] as List?)?.cast<double>() ?? [];
    final tieneEval       = proyecto['tieneEvaluaciones'] == true;
    final tieneNotaDocente = proyecto['tieneNotaDocente'] == true;
    final escala          = (proyecto['escalaBase'] as num?)?.toDouble() ?? escalaBaseParticipantes;

    final color    = posColor(posicion, tieneEval);
    final icono    = posIcono(posicion, tieneEval);
    final etiqueta = !tieneEval
        ? 'Sin evaluación'
        : posicion == 0
            ? '1er lugar'
            : posicion == 1
                ? '2do lugar'
                : posicion == 2
                    ? '3er lugar'
                    : '${posicion + 1}° lugar';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width:  40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Container(
                    width:  52,
                    height: 52,
                    decoration: BoxDecoration(
                      color:  color.withValues(alpha: 0.15),
                      shape:  BoxShape.circle,
                      border: Border.all(
                          color: color.withValues(alpha: 0.5), width: 2),
                    ),
                    child: Center(
                        child: Text(icono,
                            style: const TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(etiqueta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize:   11,
                                  fontWeight: FontWeight.bold,
                                  color:      color)),
                        ),
                        const SizedBox(height: 4),
                        Text(formatearTexto(proyecto['titulo'], 'Sin título'),
                            style: const TextStyle(
                                fontSize:   15,
                                fontWeight: FontWeight.bold,
                                color:      PColores.primary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: PColores.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  if (tieneEval)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [PColores.primary, PColores.primaryLight],
                          begin:  Alignment.topLeft,
                          end:    Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: StatItem(
                                    label:  tieneNotaDocente
                                        ? 'Final'
                                        : 'Prom./${escala.toStringAsFixed(0)}',
                                    value:  formatearDecimal(promedio),
                                    icon:   Icons.star_rounded,
                                    color:  PColores.gold,
                                    grande: true),
                              ),
                              Container(
                                  width: 1, height: 40, color: Colors.white24),
                              Expanded(
                                child: StatItem(
                                    label: 'Jurados',
                                    value: formatearDecimal(promedioJurados),
                                    icon:  Icons.gavel_rounded,
                                    color: Colors.lightBlueAccent),
                              ),
                              if (tieneNotaDocente) ...[
                                Container(
                                    width: 1, height: 40, color: Colors.white24),
                                Expanded(
                                  child: StatItem(
                                      label: 'Docente',
                                      value: formatearDecimal(notaDocente ?? 0),
                                      icon:  Icons.school_rounded,
                                      color: Colors.greenAccent),
                                ),
                              ],
                              Container(
                                  width: 1, height: 40, color: Colors.white24),
                              Expanded(
                                child: StatItem(
                                    label: 'J. cant.',
                                    value: '$jurados',
                                    icon:  Icons.how_to_vote_outlined,
                                    color: Colors.orangeAccent),
                              ),
                            ],
                          ),
                          if (promedioRaw > 0) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Nota original promedio: ${formatearDecimal(promedioRaw)} pts (sin normalizar)',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white60),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:  Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hourglass_empty_rounded,
                              color: PColores.textSecondary, size: 20),
                          SizedBox(width: 10),
                          Flexible(
                            child: Text(
                                'Este proyecto aún no tiene evaluaciones',
                                style: TextStyle(
                                    fontSize: 13, color: PColores.textSecondary)),
                          ),
                        ],
                      ),
                    ),

                  if (tieneEval && tieneNotaDocente) ...[
                    const SizedBox(height: 14),
                    FormulaDesglose(
                      promedioJurados: promedioJurados,
                      notaDocente:     notaDocente!,
                      notaFinal:       promedio,
                    ),
                  ],

                  const SizedBox(height: 20),
                  if (notas.isNotEmpty) ...[
                    SheetSection(
                        titulo: 'Notas por jurado (normalizadas a /${escala.toStringAsFixed(0)})',
                        icon:   Icons.how_to_vote_rounded),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing:    8,
                      runSpacing: 8,
                      children: notas.asMap().entries.map((e) {
                        final isMax = e.value == notaMax;
                        final isMin = e.value == notaMin && jurados > 1;
                        final rawVal = e.key < notasRaw.length
                            ? notasRaw[e.key]
                            : null;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isMax
                                ? Colors.green.shade50
                                : isMin
                                    ? Colors.red.shade50
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isMax
                                  ? Colors.green.shade300
                                  : isMin
                                      ? Colors.red.shade300
                                      : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('J${e.key + 1}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600)),
                              Text(formatearDecimal(e.value),
                                  style: TextStyle(
                                      fontSize:   14,
                                      fontWeight: FontWeight.bold,
                                      color: isMax
                                          ? Colors.green.shade700
                                          : isMin
                                              ? Colors.red.shade700
                                              : PColores.primary)),
                              if (rawVal != null)
                                Text('(${formatearDecimal(rawVal)} orig.)',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey.shade500)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (nombresJurados.isNotEmpty) ...[
                    const SheetSection(
                        titulo: 'Jurados evaluadores',
                        icon:   Icons.gavel_rounded),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(nombresJurados,
                          style: const TextStyle(
                              fontSize: 13,
                              color:    PColores.textSecondary,
                              height:   1.5)),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const SheetSection(
                      titulo: 'Información del proyecto',
                      icon:   Icons.info_outline_rounded),
                  const SizedBox(height: 10),
                  InfoRow(
                      icon:  Icons.qr_code_rounded,
                      label: 'Código',
                      value: formatearTexto(proyecto['codigo'])),
                  InfoRow(
                      icon:  Icons.category_outlined,
                      label: 'Categoría',
                      value: formatearTexto(proyecto['clasificacion'])),
                  if (formatearTexto(proyecto['sala'], '').isNotEmpty)
                    InfoRow(
                        icon:  Icons.room_outlined,
                        label: 'Sala',
                        value: 'Sala ${formatearTexto(proyecto['sala'])}'),
                  if (formatearTexto(proyecto['integrantes'], '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const SheetSection(
                        titulo: 'Integrantes',
                        icon:   Icons.people_outline_rounded),
                    const SizedBox(height: 8),
                    IntegrantesCard(texto: formatearTexto(proyecto['integrantes'])),
                  ],
                  if (formatearTexto(proyecto['asesor'], '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    InfoRow(
                        icon:  Icons.school_outlined,
                        label: 'Asesor',
                        value: formatearTexto(proyecto['asesor'])),
                  ],
                  if (formatearTexto(proyecto['descripcion'], '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const SheetSection(
                        titulo: 'Descripción',
                        icon:   Icons.description_outlined),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(formatearTexto(proyecto['descripcion']),
                          style: const TextStyle(
                              fontSize: 13,
                              color:    PColores.textSecondary,
                              height:   1.6)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FormulaDesglose extends StatelessWidget {
  final double promedioJurados;
  final double notaDocente;
  final double notaFinal;

  const FormulaDesglose({
    super.key,
    required this.promedioJurados,
    required this.notaDocente,
    required this.notaFinal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FFF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined,
                  size: 15, color: Colors.green),
              const SizedBox(width: 6),
              const Text('Cálculo nota final',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green)),
            ],
          ),
          const SizedBox(height: 10),
          _FormulaRow(
            label: 'Prom. jurados',
            valor: formatearDecimal(promedioJurados),
            color: Colors.blue,
            peso: '50%',
          ),
          const SizedBox(height: 4),
          _FormulaRow(
            label: 'Nota docente',
            valor: formatearDecimal(notaDocente),
            color: Colors.green,
            peso: '50%',
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('= Nota final',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: PColores.primary)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: PColores.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(formatearDecimal(notaFinal),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormulaRow extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;
  final String peso;

  const _FormulaRow({
    required this.label,
    required this.valor,
    required this.color,
    required this.peso,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: PColores.textSecondary)),
        ),
        Text(peso,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color)),
        const SizedBox(width: 10),
        Text(valor,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: PColores.primary)),
      ],
    );
  }
}

class StatItem extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  final bool     grande;

  const StatItem({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.grande = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: grande ? 18 : 14),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              maxLines: 1,
              style: TextStyle(
                  color:      Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize:   grande ? 22 : 15)),
        ),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }
}

class SheetSection extends StatelessWidget {
  final String   titulo;
  final IconData icon;

  const SheetSection({super.key, required this.titulo, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: PColores.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(titulo,
              style: const TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.bold,
                  color:      PColores.primary)),
        ),
      ],
    );
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;

  const InfoRow(
      {super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: PColores.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: PColores.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                    color:      PColores.primary)),
          ),
        ],
      ),
    );
  }
}

class IntegrantesCard extends StatelessWidget {
  final String texto;
  const IntegrantesCard({super.key, required this.texto});

  @override
  Widget build(BuildContext context) {
    final items = texto
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (items.length <= 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(texto,
            style: const TextStyle(
                fontSize: 13, color: PColores.textSecondary)),
      );
    }

    return Column(
      children: items.map((nombre) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                width:  28,
                height: 28,
                decoration: BoxDecoration(
                  color: PColores.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontSize:   11,
                          fontWeight: FontWeight.bold,
                          color:      PColores.primary)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(nombre,
                    style: const TextStyle(
                        fontSize: 13, color: PColores.textSecondary)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
