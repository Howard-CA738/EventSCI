import 'package:flutter/material.dart';
import '../../logica/participantes_ranking_calculator.dart';
import 'ver_ganadores_shared.dart';

class NotaDocenteButton extends StatelessWidget {
  final bool tieneNotas;
  final VoidCallback onImportar;
  final VoidCallback onEliminar;

  const NotaDocenteButton({
    super.key,
    required this.tieneNotas,
    required this.onImportar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tieneNotas ? 'Notas docente cargadas' : 'Importar notas docente',
      child: GestureDetector(
        onTap: tieneNotas ? null : onImportar,
        onLongPress: tieneNotas ? onEliminar : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: tieneNotas
                ? Colors.green.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: tieneNotas
                  ? Colors.greenAccent.withValues(alpha: 0.6)
                  : Colors.white30,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                tieneNotas ? Icons.how_to_reg : Icons.upload_file,
                color: tieneNotas ? Colors.greenAccent : Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 5),
              Text(
                tieneNotas ? 'Docente ✓' : 'Docente',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tieneNotas ? Colors.greenAccent : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VistaToggle extends StatelessWidget {
  final ModoVistaGanadores modoActual;
  final ValueChanged<ModoVistaGanadores> onChange;

  const VistaToggle({super.key, required this.modoActual, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(
            icon: Icons.view_list_rounded,
            activo: modoActual == ModoVistaGanadores.lista,
            onTap: () => onChange(ModoVistaGanadores.lista),
            tooltip: 'Lista',
          ),
          _ToggleBtn(
            icon: Icons.table_chart_rounded,
            activo: modoActual == ModoVistaGanadores.tabla,
            onTap: () => onChange(ModoVistaGanadores.tabla),
            tooltip: 'Tabla',
          ),
          _ToggleBtn(
            icon: Icons.bar_chart_rounded,
            activo: modoActual == ModoVistaGanadores.grafico,
            onTap: () => onChange(ModoVistaGanadores.grafico),
            tooltip: 'Gráfico',
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool activo;
  final VoidCallback onTap;
  final String tooltip;

  const _ToggleBtn({
    required this.icon,
    required this.activo,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: activo ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 18, color: activo ? GColores.primary : Colors.white70),
        ),
      ),
    );
  }
}

class CenteredLoader extends StatelessWidget {
  final String mensaje;
  const CenteredLoader({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: GColores.primary),
            const SizedBox(height: 16),
            Text(mensaje,
                style: const TextStyle(color: GColores.textSecondary, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class InfoCarreraCard extends StatelessWidget {
  final String? carrera;
  final String? facultad;
  final String? filialNombre;

  const InfoCarreraCard({super.key, this.carrera, this.facultad, this.filialNombre});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GColores.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: GColores.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.emoji_events, color: GColores.gold, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatearTexto(carrera),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        overflow: TextOverflow.ellipsis),
                    maxLines: 2),
                const SizedBox(height: 3),
                Text(formatearTexto(facultad),
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        overflow: TextOverflow.ellipsis),
                    maxLines: 1),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on_outlined, color: Colors.white54, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(formatearTexto(filialNombre),
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            overflow: TextOverflow.ellipsis),
                        maxLines: 1),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String? subtitulo;

  const SectionTitle({super.key, required this.icon, required this.titulo, this.subtitulo});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: GColores.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: GColores.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: GColores.primary,
                      overflow: TextOverflow.ellipsis),
                  maxLines: 1),
              if (subtitulo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitulo!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: GColores.textSecondary,
                          overflow: TextOverflow.ellipsis),
                      maxLines: 1),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class EventoCard extends StatelessWidget {
  final Map<String, dynamic> evento;
  final VoidCallback onTap;

  const EventoCard({super.key, required this.evento, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nombre = formatearTexto(evento['name'], 'Sin nombre');
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(inicial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: GColores.primary,
                              overflow: TextOverflow.ellipsis),
                          maxLines: 2),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.emoji_events, size: 12, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text('Ver ganadores',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Colors.amber[700])),
                        ),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: GColores.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chevron_right_rounded,
                      color: GColores.gold, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyEventos extends StatelessWidget {
  const EmptyEventos({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Color(0xFFFFF8E1), shape: BoxShape.circle),
            child: const Icon(Icons.event_busy_rounded, size: 48, color: Colors.amber),
          ),
          const SizedBox(height: 16),
          const Text('No hay eventos disponibles',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: GColores.primary)),
          const SizedBox(height: 8),
          const Text('No se encontraron eventos para tu carrera.',
              style: TextStyle(fontSize: 13, color: GColores.textSecondary, height: 1.5),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class EventoBanner extends StatelessWidget {
  final String nombre;
  final int totalCategorias;
  final bool tieneNotaDocente;
  final int cantidadCodigos;
  final VoidCallback onTap;

  const EventoBanner({
    super.key,
    required this.nombre,
    required this.totalCategorias,
    required this.tieneNotaDocente,
    required this.cantidadCodigos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: GColores.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: GColores.gold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(nombre,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          overflow: TextOverflow.ellipsis),
                      maxLines: 1),
                  Row(children: [
                    Flexible(
                      child: Text('Toca para cambiar · ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ),
                    if (tieneNotaDocente)
                      Flexible(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.school, size: 11, color: Colors.greenAccent),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text('$cantidadCodigos doc.',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
                          ),
                        ]),
                      )
                    else
                      const Text('solo jurados',
                          maxLines: 1, style: TextStyle(fontSize: 11, color: Colors.white38)),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$totalCategorias categ.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SinEvaluaciones extends StatelessWidget {
  const SinEvaluaciones({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration:
                  const BoxDecoration(color: Color(0xFFFFF8E1), shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_empty_rounded, size: 56, color: Colors.amber),
            ),
            const SizedBox(height: 20),
            const Text('Sin evaluaciones completadas',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold, color: GColores.primary),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Ningún proyecto tiene evaluaciones finalizadas en este evento todavía.',
              style: TextStyle(fontSize: 13, color: GColores.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
