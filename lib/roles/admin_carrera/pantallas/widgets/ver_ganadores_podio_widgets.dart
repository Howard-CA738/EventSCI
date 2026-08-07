import 'package:flutter/material.dart';
import '../../logica/participantes_ranking_calculator.dart';
import 'ver_ganadores_shared.dart';

class CategoriaSection extends StatelessWidget {
  final String categoria;
  final List<Map<String, dynamic>> ganadores;
  final void Function(Map<String, dynamic> proyecto, int posicion) onTapGanador;

  const CategoriaSection({
    super.key,
    required this.categoria,
    required this.ganadores,
    required this.onTapGanador,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: GColores.primary,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.category_outlined,
                      color: GColores.gold, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(categoria,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          overflow: TextOverflow.ellipsis),
                      maxLines: 1),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${ganadores.length} proy.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              children: List.generate(
                ganadores.length,
                (i) => GanadorCard(
                  proyecto: ganadores[i],
                  posicion: i,
                  onTap: () => onTapGanador(ganadores[i], i),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_outlined, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text('Toca una tarjeta para ver detalle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GanadorCard extends StatelessWidget {
  final Map<String, dynamic> proyecto;
  final int posicion;
  final VoidCallback onTap;

  const GanadorCard({
    super.key,
    required this.proyecto,
    required this.posicion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final promedio = (proyecto['promedio'] as num?)?.toDouble() ?? 0.0;
    final jurados = (proyecto['cantidadJurados'] as int?) ?? 0;
    final titulo = formatearTexto(proyecto['titulo'], 'Sin título');
    final codigo = formatearTexto(proyecto['codigo'], '—');
    final integrantes = formatearTexto(proyecto['integrantes'], '');
    final sala = formatearTexto(proyecto['sala'], '');
    final tieneNotaDocente = proyecto['tieneNotaDocente'] as bool? ?? false;

    final color =
        posicion < 4 ? GColores.podioColors[posicion] : const Color(0xFF90A4AE);
    final fondo =
        posicion < 4 ? GColores.podioFondos[posicion] : const Color(0xFFF5F5F5);
    final icono = posicion < 4 ? GColores.podioIconos[posicion] : '🏅';
    final etiqueta =
        posicion < 4 ? GColores.podioEtiquetas[posicion] : '${posicion + 1}° lugar';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: posicion == 0 ? 0.5 : 0.25),
            width: posicion == 0 ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
              ),
              child: Center(
                child: Text(icono, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      MiniChip(label: codigo, bg: GColores.primary, fg: Colors.white),
                      MiniChip(
                          label: etiqueta, bg: color.withValues(alpha: 0.18), fg: color),
                      if (tieneNotaDocente)
                        MiniChip(
                          label: '+ Docente',
                          bg: Colors.green.withValues(alpha: 0.12),
                          fg: Colors.green[700]!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(titulo,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold, color: GColores.primary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (integrantes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.people_outline, size: 12, color: GColores.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(integrantes,
                            style: const TextStyle(fontSize: 11, color: GColores.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                  if (sala.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.room_outlined, size: 12, color: GColores.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text('Sala $sala',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: GColores.textSecondary)),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.info_outline, size: 11, color: color.withValues(alpha: 0.7)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text('Ver detalle completo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(formatearDecimal(promedio),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 4),
                const Text('pts', style: TextStyle(fontSize: 10, color: GColores.textSecondary)),
                const SizedBox(height: 2),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.how_to_vote_outlined, size: 10, color: GColores.textSecondary),
                  const SizedBox(width: 3),
                  Text('$jurados j.',
                      style: const TextStyle(fontSize: 10, color: GColores.textSecondary)),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MiniChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const MiniChip({super.key, required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: fg, overflow: TextOverflow.ellipsis),
          maxLines: 1),
    );
  }
}

class VistaTabla extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> ganadoresPorCategoria;
  final void Function(Map<String, dynamic> proyecto, int posicion) onTapFila;

  const VistaTabla({
    super.key,
    required this.ganadoresPorCategoria,
    required this.onTapFila,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: ganadoresPorCategoria.entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                color: GColores.primary,
                child: Row(
                  children: [
                    const Icon(Icons.category_outlined, color: GColores.gold, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(entry.key,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              overflow: TextOverflow.ellipsis),
                          maxLines: 1),
                    ),
                  ],
                ),
              ),
              Container(
                color: GColores.primary.withValues(alpha: 0.06),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: const Row(
                  children: [
                    SizedBox(
                        width: 32,
                        child: Text('#',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: GColores.textSecondary))),
                    Expanded(
                        flex: 3,
                        child: Text('Proyecto',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: GColores.textSecondary))),
                    SizedBox(
                        width: 52,
                        child: Text('Final',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: GColores.textSecondary),
                            textAlign: TextAlign.center)),
                    SizedBox(
                        width: 36,
                        child: Text('J.',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: GColores.textSecondary),
                            textAlign: TextAlign.center)),
                  ],
                ),
              ),
              ...entry.value.asMap().entries.map((e) {
                final i = e.key;
                final p = e.value;
                final color = i < 4 ? GColores.podioColors[i] : const Color(0xFF90A4AE);
                final icono = i < 4 ? GColores.podioIconos[i] : '🏅';
                final promedio = (p['promedio'] as num?)?.toDouble() ?? 0.0;
                final jurados = (p['cantidadJurados'] as int?) ?? 0;
                final tieneDoc = p['tieneNotaDocente'] as bool? ?? false;

                return InkWell(
                  onTap: () => onTapFila(p, i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[100]!),
                      ),
                      color: i == 0 ? GColores.gold.withValues(alpha: 0.04) : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text(icono, style: const TextStyle(fontSize: 18)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formatearTexto(p['titulo'], 'Sin título'),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: GColores.primary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              Row(children: [
                                Text(formatearTexto(p['codigo'], '—'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(fontSize: 10, color: GColores.textSecondary)),
                                if (tieneDoc) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.school, size: 10, color: Colors.green),
                                ],
                              ]),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 52,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(formatearDecimal(promedio),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                    textAlign: TextAlign.center),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text('$jurados',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: GColores.textSecondary),
                              textAlign: TextAlign.center),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_outlined, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text('Toca una fila para ver detalle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class VistaGrafico extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> ganadoresPorCategoria;

  const VistaGrafico({super.key, required this.ganadoresPorCategoria});

  double get _maxNota {
    double max = 0;
    for (final lista in ganadoresPorCategoria.values) {
      for (final p in lista) {
        final v = (p['promedio'] as num?)?.toDouble() ?? 0.0;
        if (v > max) max = v;
      }
    }
    return max == 0 ? 100 : max;
  }

  @override
  Widget build(BuildContext context) {
    final maxNota = _maxNota;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: ganadoresPorCategoria.entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                color: GColores.primary,
                child: Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded, color: GColores.gold, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(entry.key,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              overflow: TextOverflow.ellipsis),
                          maxLines: 1),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: entry.value.asMap().entries.map((e) {
                    final i = e.key;
                    final p = e.value;
                    final promedio = (p['promedio'] as num?)?.toDouble() ?? 0.0;
                    final porcentaje = maxNota > 0 ? promedio / maxNota : 0.0;
                    final color = i < 4 ? GColores.podioColors[i] : const Color(0xFF90A4AE);
                    final icono = i < 4 ? GColores.podioIconos[i] : '🏅';
                    final tieneDoc = p['tieneNotaDocente'] as bool? ?? false;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(icono, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  formatearTexto(p['titulo'], 'Sin título'),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: GColores.primary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (tieneDoc)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(Icons.school, size: 12, color: Colors.green),
                                ),
                              const SizedBox(width: 6),
                              Text(formatearDecimal(promedio),
                                  style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                              const Text(' pts',
                                  style: TextStyle(fontSize: 11, color: GColores.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LayoutBuilder(
                            builder: (_, constraints) {
                              return Stack(
                                children: [
                                  Container(
                                    height: 14,
                                    width: constraints.maxWidth,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 700),
                                    curve: Curves.easeOutCubic,
                                    height: 14,
                                    width: constraints.maxWidth * porcentaje.clamp(0.0, 1.0),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 3),
                          Row(children: [
                            Flexible(
                              child: Text(formatearTexto(p['codigo'], '—'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, color: GColores.textSecondary)),
                            ),
                            if (formatearTexto(p['sala'], '').isNotEmpty) ...[
                              Flexible(
                                child: Text(' · Sala ${formatearTexto(p['sala'])}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(fontSize: 10, color: GColores.textSecondary)),
                              ),
                            ],
                          ]),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
