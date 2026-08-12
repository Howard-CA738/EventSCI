import 'package:flutter/material.dart';
import '../../datos/categoria_data.dart';
import '../../logica/participantes_ranking_calculator.dart';
import 'participantes_shared.dart';

class CategoriaAcordeon extends StatefulWidget {
  final CategoriaData data;
  final void Function(Map<String, dynamic> p, int i) onTapProyecto;

  const CategoriaAcordeon({
    super.key,
    required this.data,
    required this.onTapProyecto,
  });

  @override
  State<CategoriaAcordeon> createState() => _CategoriaAcordeonState();
}

class _CategoriaAcordeonState extends State<CategoriaAcordeon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _expandAnim;
  late Animation<double>   _rotateAnim;

  bool _expandida    = false;
  bool _fueExpandido = false;
  late final List<Widget> _hijosPrebuilts;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _rotateAnim = Tween<double>(begin: 0.0, end: 0.5).animate(_expandAnim);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<Widget> _buildHijos() {
    _fueExpandido = true;
    final cat = widget.data;
    _hijosPrebuilts = List.generate(cat.proyectos.length, (i) {
      return RepaintBoundary(
        key: ValueKey(cat.proyectos[i]['proyectoId']),
        child: ProyectoCard(
          proyecto: cat.proyectos[i],
          posicion: i,
          onTap: () => widget.onTapProyecto(cat.proyectos[i], i),
        ),
      );
    });
    return _hijosPrebuilts;
  }

  void _toggle() {
    if (!_fueExpandido) _buildHijos();
    setState(() => _expandida = !_expandida);
    _expandida ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final cat     = widget.data;
    final conEval = cat.conEval;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color:      Color(0x0F000000),
              blurRadius: 12,
              offset:     Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: PColores.primary,
            child: InkWell(
              onTap:          _toggle,
              splashColor:    Colors.white12,
              highlightColor: Colors.white10,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.category_outlined,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.nombre,
                            style: const TextStyle(
                                fontSize:   14,
                                fontWeight: FontWeight.bold,
                                color:      Colors.white,
                                overflow:   TextOverflow.ellipsis),
                            maxLines: 1,
                          ),
                          Text(
                            '${cat.proyectos.length} proyectos · $conEval evaluados',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    RotationTransition(
                      turns: _rotateAnim,
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white70, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizeTransition(
            sizeFactor:    _expandAnim,
            axisAlignment: -1.0,
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _fueExpandido ? _hijosPrebuilts : const [],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProyectoCard extends StatelessWidget {
  final Map<String, dynamic> proyecto;
  final int posicion;
  final VoidCallback onTap;

  const ProyectoCard({
    super.key,
    required this.proyecto,
    required this.posicion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final promedio  = (proyecto['promedio'] as num?)?.toDouble() ?? 0.0;
    final jurados   = (proyecto['cantidadJurados'] as int?) ?? 0;
    final tieneEval = proyecto['tieneEvaluaciones'] == true;
    final tieneDoc  = proyecto['tieneNotaDocente'] == true;
    final escala    = (proyecto['escalaBase'] as num?)?.toDouble() ?? escalaBaseParticipantes;

    final color = posColor(posicion, tieneEval);
    final icono = posIcono(posicion, tieneEval);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tieneEval
              ? (posicion == 0
                  ? PColores.gold.withValues(alpha: 0.06)
                  : const Color(0xFFF8FAFC))
              : const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: posicion < 3 && tieneEval
                ? color.withValues(alpha: 0.3)
                : const Color(0xFFE5E7EB),
            width: posicion == 0 && tieneEval ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Center(
                child: posicion < 3 && tieneEval
                    ? Text(icono, style: const TextStyle(fontSize: 20))
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: tieneEval
                              ? PColores.primary.withValues(alpha: 0.1)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tieneEval ? '${posicion + 1}°' : 'S/E',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: tieneEval ? PColores.primary : Colors.grey),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 5, runSpacing: 4, children: [
                    MiniChip(
                        label: formatearTexto(proyecto['codigo'], '—'),
                        bg:    PColores.primary,
                        fg:    Colors.white),
                    if (formatearTexto(proyecto['sala'], '').isNotEmpty)
                      MiniChip(
                          label: 'Sala ${formatearTexto(proyecto['sala'])}',
                          bg:    const Color(0xFFE5E7EB),
                          fg:    PColores.textSecondary),
                    if (tieneDoc)
                      MiniChip(
                          label: '+ Docente',
                          bg:    Colors.green.withValues(alpha: 0.12),
                          fg:    Colors.green.shade700),
                  ]),
                  const SizedBox(height: 5),
                  Text(formatearTexto(proyecto['titulo'], 'Sin título'),
                      style: const TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.bold,
                          color:      PColores.primary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (formatearTexto(proyecto['integrantes'], '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.people_outline,
                          size: 11, color: PColores.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(formatearTexto(proyecto['integrantes']),
                            style: const TextStyle(
                                fontSize: 11, color: PColores.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.touch_app_outlined,
                        size:  11,
                        color: PColores.textSecondary.withValues(alpha: 0.6)),
                    const SizedBox(width: 3),
                    Text('Ver detalle',
                        style: TextStyle(
                            fontSize: 10,
                            color: PColores.textSecondary.withValues(alpha: 0.7))),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: tieneEval ? color : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tieneEval ? formatearDecimal(promedio) : 'S/E',
                    style: TextStyle(
                        fontSize:   tieneEval ? 16 : 12,
                        fontWeight: FontWeight.bold,
                        color:      Colors.white),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tieneEval ? '/${escala.toStringAsFixed(0)}' : 'Sin eval.',
                  style: const TextStyle(
                      fontSize: 10, color: PColores.textSecondary),
                ),
                if (tieneEval) ...[
                  const SizedBox(height: 2),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.how_to_vote_outlined,
                        size: 10, color: PColores.textSecondary),
                    const SizedBox(width: 3),
                    Text('$jurados j.',
                        style: const TextStyle(
                            fontSize: 10, color: PColores.textSecondary)),
                  ]),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TablaCategoria extends StatelessWidget {
  final CategoriaData data;
  final void Function(Map<String, dynamic> p, int i) onTapFila;

  const TablaCategoria({
    super.key,
    required this.data,
    required this.onTapFila,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color:     Color(0x0F000000),
              blurRadius: 12,
              offset:    Offset(0, 4))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            color: PColores.primary,
            child: Row(
              children: [
                const Icon(Icons.category_outlined,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(data.nombre,
                      style: const TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.bold,
                          color:      Colors.white,
                          overflow:   TextOverflow.ellipsis),
                      maxLines: 1),
                ),
                Text('${data.proyectos.length} proyectos',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          ColoredBox(
            color: const Color(0x101E3A5F),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                      width: 32,
                      child: Text('#',
                          style: TextStyle(
                              fontSize:   11,
                              fontWeight: FontWeight.bold,
                              color:      PColores.textSecondary))),
                  const Expanded(
                      flex: 3,
                      child: Text('Proyecto',
                          style: TextStyle(
                              fontSize:   11,
                              fontWeight: FontWeight.bold,
                              color:      PColores.textSecondary))),
                  SizedBox(
                      width: 60,
                      child: Text('Prom./${escalaBaseParticipantes.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize:   10,
                              fontWeight: FontWeight.bold,
                              color:      PColores.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center)),
                  const SizedBox(
                      width: 36,
                      child: Text('J.',
                          style: TextStyle(
                              fontSize:   11,
                              fontWeight: FontWeight.bold,
                              color:      PColores.textSecondary),
                          textAlign: TextAlign.center)),
                ],
              ),
            ),
          ),
          ...List.generate(data.proyectos.length, (i) {
            final p         = data.proyectos[i];
            final tieneEval = p['tieneEvaluaciones'] == true;
            final tieneDoc  = p['tieneNotaDocente'] == true;
            final promedio  = (p['promedio'] as num?)?.toDouble() ?? 0.0;
            final jurados   = (p['cantidadJurados'] as int?) ?? 0;
            final color     = posColor(i, tieneEval);
            final icono     = posIcono(i, tieneEval);

            return InkWell(
              onTap: () => onTapFila(p, i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Colors.grey.shade100)),
                  color: i == 0 && tieneEval
                      ? PColores.gold.withValues(alpha: 0.04)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: i < 3 && tieneEval
                          ? Text(icono,
                              style: const TextStyle(fontSize: 16))
                          : Text(tieneEval ? '${i + 1}°' : 'S/E',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize:   11,
                                  fontWeight: FontWeight.bold,
                                  color: tieneEval
                                      ? PColores.textSecondary
                                      : Colors.grey)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatearTexto(p['titulo'], 'Sin título'),
                              style: const TextStyle(
                                  fontSize:   12,
                                  fontWeight: FontWeight.w600,
                                  color:      PColores.primary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          Row(children: [
                            Text(formatearTexto(p['codigo'], '—'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 10, color: PColores.textSecondary)),
                            if (tieneDoc) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.school,
                                  size: 10, color: Colors.green),
                            ],
                          ]),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tieneEval ? formatearDecimal(promedio) : 'S/E',
                            style: const TextStyle(
                                fontSize:   11,
                                fontWeight: FontWeight.bold,
                                color:      Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(tieneEval ? '$jurados' : '—',
                          style: const TextStyle(
                              fontSize: 12, color: PColores.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                Icon(Icons.touch_app_outlined,
                    size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Flexible(
                  child: Text('Toca una fila para ver detalle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade400)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MiniChip extends StatelessWidget {
  final String label;
  final Color  bg;
  final Color  fg;

  const MiniChip(
      {super.key, required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize:   10,
              fontWeight: FontWeight.bold,
              color:      fg,
              overflow:   TextOverflow.ellipsis),
          maxLines: 1),
    );
  }
}
