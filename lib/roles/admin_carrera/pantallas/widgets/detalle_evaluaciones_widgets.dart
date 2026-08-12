import 'package:flutter/material.dart';
import '/shared/logica/gestion_criterios.dart';

class DColores {
  static const navy = Color(0xFF0F2342);
  static const accent = Color(0xFF3B82F6);
  static const accentLight = Color(0xFFDBEAFE);
  static const success = Color(0xFF059669);
  static const successLight = Color(0xFFD1FAE5);
  static const warning = Color(0xFFD97706);
  static const warningLight = Color(0xFFFEF3C7);
  static const danger = Color(0xFFDC2626);
  static const dangerLight = Color(0xFFFEE2E2);
  static const purple = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFFEDE9FE);
  static const surface = Color(0xFFF8FAFC);
  static const card = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const borderMed = Color(0xFFCBD5E1);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textTertiary = Color(0xFF94A3B8);
  static const divider = Color(0xFFF1F5F9);
}

class EvaluacionCard extends StatelessWidget {
  final Map<String, dynamic> evaluacion;
  final bool esPendiente;
  final VoidCallback onVerDetalle;
  final VoidCallback onEditar;
  final VoidCallback onToggleBloqueo;

  const EvaluacionCard({
    super.key,
    required this.evaluacion,
    required this.esPendiente,
    required this.onVerDetalle,
    required this.onEditar,
    required this.onToggleBloqueo,
  });

  @override
  Widget build(BuildContext context) {
    final bloqueada = evaluacion['bloqueada'] as bool;
    final notaTotal = (evaluacion['notaTotal'] as num).toDouble();
    final integrantes = evaluacion['integrantes']?.toString() ?? '';
    final rubricaNombre = evaluacion['rubricaNombre']?.toString() ?? '';

    final Color estadoColor;
    final IconData estadoIcon;
    final String estadoLabel;
    if (bloqueada) {
      estadoColor = DColores.danger;
      estadoIcon = Icons.lock_rounded;
      estadoLabel = 'Bloqueada';
    } else if (esPendiente) {
      estadoColor = DColores.warning;
      estadoIcon = Icons.hourglass_top_rounded;
      estadoLabel = 'Pendiente';
    } else {
      estadoColor = DColores.success;
      estadoIcon = Icons.check_circle_rounded;
      estadoLabel = 'Evaluada';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: DColores.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: esPendiente ? DColores.warningLight : DColores.successLight,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 100),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: DColores.navy,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      evaluacion['codigo']?.toString() ?? '—',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: estadoColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: estadoColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(estadoIcon, size: 11, color: estadoColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              estadoLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: estadoColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!esPendiente) ...[
                    Container(
                      constraints: const BoxConstraints(maxWidth: 90),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: DColores.successLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${notaTotal.toStringAsFixed(1)} pts',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: DColores.success,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Semantics(
                    button: true,
                    label: bloqueada
                        ? 'Desbloquear evaluación'
                        : 'Bloquear evaluación',
                    child: GestureDetector(
                      onTap: onToggleBloqueo,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bloqueada
                              ? DColores.dangerLight
                              : DColores.border.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          bloqueada
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          size: 18,
                          color:
                              bloqueada ? DColores.danger : DColores.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                evaluacion['titulo']?.toString() ?? 'Sin título',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: DColores.textPrimary,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              MetaRow(
                icon: Icons.person_rounded,
                text: evaluacion['juradoNombre']?.toString() ?? '—',
              ),
              const SizedBox(height: 4),
              if (rubricaNombre.isNotEmpty) ...[
                MetaRow(
                  icon: Icons.checklist_rounded,
                  text: rubricaNombre,
                ),
                const SizedBox(height: 4),
              ],
              if (integrantes.isNotEmpty)
                MetaRow(
                  icon: Icons.group_rounded,
                  text: integrantes,
                ),
              const SizedBox(height: 14),
              Container(height: 1, color: DColores.divider),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      label: 'Ver detalle',
                      icon: Icons.visibility_rounded,
                      onTap: onVerDetalle,
                      style: ActionStyle.outlined,
                    ),
                  ),
                  if (!esPendiente) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ActionButton(
                        label: 'Editar nota',
                        icon: Icons.edit_rounded,
                        onTap: onEditar,
                        style: ActionStyle.purple,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum ActionStyle { outlined, purple }

class ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final ActionStyle style;

  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final isOutlined = style == ActionStyle.outlined;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: isOutlined ? Colors.transparent : DColores.purple,
            borderRadius: BorderRadius.circular(10),
            border: isOutlined ? Border.all(color: DColores.borderMed) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isOutlined ? DColores.textSecondary : Colors.white,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOutlined ? DColores.textSecondary : Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const MetaRow({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: DColores.textTertiary),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: DColores.textSecondary,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final IconData icon;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: confirmColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: confirmColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: DColores.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: DColores.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: DColores.border),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        color: DColores.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      minimumSize: const Size(0, 44),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DetalleBottomSheet extends StatelessWidget {
  final Map<String, dynamic> evaluacion;

  const DetalleBottomSheet({super.key, required this.evaluacion});

  @override
  Widget build(BuildContext context) {
    final rubrica = evaluacion['rubrica'] as Rubrica?;
    final notas = evaluacion['notas'] as Map<String, dynamic>;
    final evaluada = evaluacion['evaluada'] as bool;
    final notaTotal = (evaluacion['notaTotal'] as num).toDouble();

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: DColores.card,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: DColores.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 90),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: DColores.navy,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  evaluacion['codigo']?.toString() ?? '—',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Jurado: ${evaluacion['juradoNombre'] ?? '—'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: DColores.textTertiary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            evaluacion['titulo']?.toString() ?? 'Sin título',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: DColores.textPrimary,
                              height: 1.3,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      constraints: const BoxConstraints(minWidth: 64),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            evaluada ? DColores.successLight : DColores.warningLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            notaTotal.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: evaluada
                                  ? DColores.success
                                  : DColores.warning,
                            ),
                          ),
                          Text(
                            'pts',
                            style: TextStyle(
                              fontSize: 10,
                              color: evaluada
                                  ? DColores.success
                                  : DColores.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: DColores.divider),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 20),
                    if (rubrica != null) ...[
                      const Text(
                        'Criterios evaluados',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: DColores.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...rubrica.secciones.map(
                        (s) => SeccionDetalleWidget(
                          seccion: s,
                          notas: notas,
                        ),
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: DColores.warningLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: DColores.warning, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No se encontró la rúbrica asociada.',
                                style: TextStyle(
                                    color: DColores.warning,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard() {
    final sala = evaluacion['sala']?.toString() ?? '';
    final integrantes = evaluacion['integrantes']?.toString() ?? '';
    final clasificacion = evaluacion['clasificacion']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DColores.accentLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DColores.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información del proyecto',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: DColores.accent,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          if (integrantes.isNotEmpty)
            _infoRow(Icons.group_rounded, 'Integrantes', integrantes),
          if (sala.isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoRow(Icons.room_rounded, 'Sala', sala),
          ],
          if (clasificacion.isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoRow(Icons.category_rounded, 'Categoría', clasificacion),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: DColores.accent),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DColores.textPrimary,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                      fontSize: 12, color: DColores.textSecondary),
                ),
              ],
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class SeccionDetalleWidget extends StatelessWidget {
  final SeccionRubrica seccion;
  final Map<String, dynamic> notas;

  const SeccionDetalleWidget({
    super.key,
    required this.seccion,
    required this.notas,
  });

  @override
  Widget build(BuildContext context) {
    double puntaje = 0;
    int evaluados = 0;
    for (var c in seccion.criterios) {
      if (notas.containsKey(c.id)) {
        puntaje += (notas[c.id] as num).toDouble();
        evaluados++;
      }
    }
    final completo = evaluados == seccion.criterios.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: DColores.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DColores.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: completo ? DColores.successLight : DColores.warningLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              completo
                  ? Icons.folder_special_rounded
                  : Icons.folder_open_rounded,
              color: completo ? DColores.success : DColores.warning,
              size: 18,
            ),
          ),
          title: Text(
            seccion.nombre,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: DColores.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '$evaluados/${seccion.criterios.length} criterios  ·  ${puntaje.toStringAsFixed(1)} / ${seccion.pesoTotal.toStringAsFixed(0)} pts',
            style: const TextStyle(fontSize: 11, color: DColores.textTertiary),
          ),
          children: seccion.criterios.map((c) {
            final nota = notas[c.id];
            final tiene = nota != null;
            final notaVal = tiene ? (nota as num).toDouble() : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tiene
                    ? DColores.successLight.withValues(alpha: 0.5)
                    : DColores.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: tiene
                      ? DColores.success.withValues(alpha: 0.3)
                      : DColores.border,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.descripcion,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: DColores.textPrimary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Máx: ${c.peso.toStringAsFixed(1)} pts',
                          style: const TextStyle(
                            fontSize: 11,
                            color: DColores.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    constraints: const BoxConstraints(minWidth: 44),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: tiene ? DColores.success : DColores.textTertiary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tiene ? notaVal.toStringAsFixed(1) : '—',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
