import 'package:flutter/material.dart';
import '../../logica/participantes_ranking_calculator.dart';
import 'participantes_shared.dart';

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
      message: tieneNotas
          ? 'Notas docente cargadas (mantén pulsado para quitar)'
          : 'Importar notas docente',
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
  final ModoVista modoActual;
  final ValueChanged<ModoVista> onChange;

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
            icon:    Icons.view_list_rounded,
            activo:  modoActual == ModoVista.lista,
            onTap:   () => onChange(ModoVista.lista),
            tooltip: 'Lista',
          ),
          _ToggleBtn(
            icon:    Icons.table_chart_rounded,
            activo:  modoActual == ModoVista.tabla,
            onTap:   () => onChange(ModoVista.tabla),
            tooltip: 'Tabla',
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
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: activo ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon,
              size: 18, color: activo ? PColores.primary : Colors.white70),
        ),
      ),
    );
  }
}

class SearchBarParticipantes extends StatelessWidget {
  final TextEditingController controller;
  final String busqueda;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const SearchBarParticipantes({
    super.key,
    required this.controller,
    required this.busqueda,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged:  onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14, color: PColores.primary),
      decoration: InputDecoration(
        hintText: 'Buscar por título, código, integrante o asesor...',
        hintStyle: const TextStyle(fontSize: 13, color: PColores.textSecondary),
        prefixIcon: const Icon(Icons.search, color: PColores.textSecondary),
        suffixIcon: busqueda.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear,
                    color: PColores.textSecondary, size: 18),
                onPressed: onClear,
              )
            : null,
        filled:      true,
        fillColor:   Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PColores.primary, width: 1.5),
        ),
      ),
    );
  }
}

class BotonExportarExcelParticipantes extends StatelessWidget {
  final bool cargando;
  final bool generando;
  final VoidCallback onPressed;

  const BotonExportarExcelParticipantes({
    super.key,
    required this.cargando,
    required this.generando,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: cargando
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF27AE60).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: ElevatedButton.icon(
        onPressed: cargando ? null : onPressed,
        icon: cargando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white54),
              )
            : const Icon(Icons.file_download_rounded, size: 22),
        label: Text(
          generando ? 'Generando Excel...' : 'Exportar Reporte Excel',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:        const Color(0xFF27AE60),
          foregroundColor:        Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class ContextCard extends StatelessWidget {
  final String carrera;
  final String facultad;
  final String filialNombre;

  const ContextCard({
    super.key,
    required this.carrera,
    required this.facultad,
    required this.filialNombre,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PColores.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color:  PColores.primary.withValues(alpha: 0.3),
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
            child: const Icon(Icons.groups_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(carrera,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        overflow: TextOverflow.ellipsis),
                    maxLines: 2),
                const SizedBox(height: 3),
                Text(facultad,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        overflow: TextOverflow.ellipsis),
                    maxLines: 1),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      color: Colors.white54, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(filialNombre,
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

class EventoBanner extends StatelessWidget {
  final String nombre;
  final int totalProyectos;
  final int totalCategorias;
  final int totalConEval;
  final bool tieneNotaDocente;
  final int cantidadCodigos;
  final VoidCallback onTap;

  const EventoBanner({
    super.key,
    required this.nombre,
    required this.totalProyectos,
    required this.totalCategorias,
    required this.totalConEval,
    required this.tieneNotaDocente,
    required this.cantidadCodigos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:  const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PColores.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_rounded,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(nombre,
                      style: const TextStyle(
                          color:         Colors.white,
                          fontWeight:    FontWeight.bold,
                          fontSize:      13,
                          overflow:      TextOverflow.ellipsis),
                      maxLines: 1),
                ),
                if (tieneNotaDocente)
                  Flexible(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.school,
                          size: 12, color: Colors.greenAccent),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text('$cantidadCodigos doc.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.greenAccent)),
                      ),
                      const SizedBox(width: 8),
                    ]),
                  ),
                const Text('Cambiar',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(width: 4),
                const Icon(Icons.swap_horiz_rounded,
                    color: Colors.white54, size: 16),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _BannerStat(
                    valor: '$totalProyectos',
                    label: 'proyectos',
                    icon:  Icons.science_outlined),
                const _BannerDivider(),
                _BannerStat(
                    valor: '$totalCategorias',
                    label: 'categorías',
                    icon:  Icons.category_outlined),
                const _BannerDivider(),
                _BannerStat(
                    valor: '$totalConEval',
                    label: 'evaluados',
                    icon:  Icons.check_circle_outline),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final String valor;
  final String label;
  final IconData icon;

  const _BannerStat(
      {required this.valor, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: Colors.white54),
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(valor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color:      Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize:   14)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerDivider extends StatelessWidget {
  const _BannerDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.2));
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
        color:  Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color:     Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset:    const Offset(0, 2))
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
                      colors: [PColores.primary, PColores.primaryLight],
                      begin:  Alignment.topLeft,
                      end:    Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(inicial,
                        style: const TextStyle(
                            color:      Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize:   20)),
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
                              fontSize:   14,
                              color:      PColores.primary,
                              overflow:   TextOverflow.ellipsis),
                          maxLines: 2),
                      const SizedBox(height: 4),
                      const Row(children: [
                        Icon(Icons.groups_outlined,
                            size: 12, color: PColores.textSecondary),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text('Ver todos los participantes',
                              style: TextStyle(
                                  fontSize: 11, color: PColores.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: PColores.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chevron_right_rounded,
                      color: PColores.primary, size: 18),
                ),
              ],
            ),
          ),
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
          mainAxisSize:      MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: PColores.primary),
            const SizedBox(height: 16),
            Text(mensaje,
                style: const TextStyle(
                    color: PColores.textSecondary, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   titulo;
  final String   subtitulo;

  const EmptyState({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.titulo,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize:      MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration:
                  const BoxDecoration(color: PColores.bg, shape: BoxShape.circle),
              child: Icon(icon, size: 56, color: iconColor),
            ),
            const SizedBox(height: 20),
            Text(titulo,
                style: const TextStyle(
                    fontSize:   17,
                    fontWeight: FontWeight.bold,
                    color:      PColores.primary),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitulo,
                style: const TextStyle(
                    fontSize: 13, color: PColores.textSecondary, height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
