import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _primary = Color(0xFF1E3A5F);
const _primaryLight = Color(0xFF2D5F8D);
const _danger = Color(0xFFE53935);
const _success = Color(0xFF43A047);
const _surface = Colors.white;
const _muted = Color(0xFF64748B);

final List<BoxShadow> _cardShadow = [
  BoxShadow(
    color: _primary.withValues(alpha: 0.06),
    blurRadius: 14,
    offset: const Offset(0, 4),
  ),
];

class AsistenciaPersonalCard extends StatelessWidget {
  final Map<String, dynamic> asistencia;
  final VoidCallback onVerQR;
  final VoidCallback onConfigurar;
  final Future<void> Function() onEliminar;

  const AsistenciaPersonalCard({
    super.key,
    required this.asistencia,
    required this.onVerQR,
    required this.onConfigurar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = (asistencia['nombre'] as String?) ?? 'Sin nombre';
    final inicial =
        nombre.isNotEmpty ? nombre.substring(0, 1).toUpperCase() : '?';
    final eventName = (asistencia['eventName'] as String?) ?? '';
    final activo = asistencia['activo'] == true;
    final descripcion = (asistencia['descripcion'] as String?) ?? '';
    final docId = asistencia['docId'] as String;

    final colorEstado = activo ? _success : const Color(0xFF90A4AE);
    final labelEstado = activo ? 'Activo' : 'Inactivo';

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await onEliminar();
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _danger,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.delete_rounded, color: Colors.white, size: 28),
              SizedBox(height: 4),
              Text('Eliminar',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ]),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _cardShadow,
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_primary, _primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    inicial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.event_rounded,
                            size: 11, color: _muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            eventName,
                            style: const TextStyle(
                                fontSize: 11, color: _muted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                      if (descripcion.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          descripcion,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: colorEstado.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: colorEstado, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(labelEstado,
                      style: TextStyle(
                          fontSize: 11,
                          color: colorEstado,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
          _buildConfigResumen(asistencia),
          Container(
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
            ),
            child: Row(children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16)),
                    onTap: onVerQR,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2_rounded,
                                color: _success, size: 15),
                            SizedBox(width: 6),
                            Text('Ver QR',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _success)),
                          ]),
                    ),
                  ),
                ),
              ),
              Container(
                  width: 1,
                  height: 36,
                  color: _primary.withValues(alpha: 0.08)),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onConfigurar();
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.tune_rounded,
                                color: _primary, size: 15),
                            SizedBox(width: 6),
                            Text('Configurar',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _primary)),
                          ]),
                    ),
                  ),
                ),
              ),
              Container(
                  width: 1,
                  height: 36,
                  color: _primary.withValues(alpha: 0.08)),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(16)),
                  onTap: onEliminar,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Icon(Icons.delete_outline_rounded,
                        color: _danger.withValues(alpha: 0.8), size: 17),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildConfigResumen(Map<String, dynamic> a) {
    final tiempoActivo = a['tiempoLimiteActivo'] == true;
    final ventanaActiva = a['ventanaHorariaActiva'] == true;
    final codigo = (a['codigo'] as String?) ?? '';
    if (!tiempoActivo && !ventanaActiva && codigo.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        if (codigo.isNotEmpty)
          _buildMiniChip(
            Icons.dialpad_rounded,
            'Cód. $codigo',
            _primary,
          ),
        if (tiempoActivo)
          _buildMiniChip(
            Icons.timer_rounded,
            '${a['tiempoLimiteMinutos'] ?? 30} min',
            Colors.orange.shade700,
          ),
        if (ventanaActiva)
          _buildMiniChip(
            Icons.access_time_rounded,
            'Ventana horaria',
            Colors.blue.shade700,
          ),
      ]),
    );
  }

  Widget _buildMiniChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10.5,
                color: color,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
