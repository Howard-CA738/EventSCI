import 'package:flutter/material.dart';
import '/shared/logica/gestion_criterios.dart';
import '../logica/detalle_evaluaciones_carrera_service.dart';
import 'widgets/detalle_evaluaciones_widgets.dart';

class EditarNotasScreen extends StatefulWidget {
  final String eventoId;
  final Map<String, dynamic> evaluacion;
  final Rubrica rubrica;

  const EditarNotasScreen({
    super.key,
    required this.eventoId,
    required this.evaluacion,
    required this.rubrica,
  });

  @override
  State<EditarNotasScreen> createState() => _EditarNotasScreenState();
}

class _EditarNotasScreenState extends State<EditarNotasScreen> {
  final _service = DetalleEvaluacionesCarreraService();

  late Map<String, double?> _notasEditadas;
  bool _isGuardando = false;

  @override
  void initState() {
    super.initState();
    final notasActuales =
        widget.evaluacion['notas'] as Map<String, dynamic>;
    _notasEditadas = {};
    for (var seccion in widget.rubrica.secciones) {
      for (var criterio in seccion.criterios) {
        final nota = notasActuales[criterio.id];
        _notasEditadas[criterio.id] =
            nota != null ? (nota as num).toDouble() : null;
      }
    }
  }

  double get _notaTotalActual {
    double total = 0;
    for (var nota in _notasEditadas.values) {
      if (nota != null) total += nota;
    }
    return total;
  }

  int get _criteriosCompletos =>
      _notasEditadas.values.where((n) => n != null).length;

  int get _totalCriterios => _notasEditadas.length;

  double get _progreso =>
      _totalCriterios > 0 ? _criteriosCompletos / _totalCriterios : 0.0;

  Future<void> _guardarCambios() async {
    for (var seccion in widget.rubrica.secciones) {
      for (var criterio in seccion.criterios) {
        if (_notasEditadas[criterio.id] == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Faltan criterios en "${seccion.nombre}"',
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: DColores.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ));
          return;
        }
      }
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Guardar cambios',
        message:
            'La nota total será ${_notaTotalActual.toStringAsFixed(1)} pts.\n¿Confirmas los cambios?',
        confirmLabel: 'Guardar',
        confirmColor: DColores.purple,
        icon: Icons.save_rounded,
      ),
    );

    if (confirmar != true) return;

    setState(() => _isGuardando = true);

    try {
      final Map<String, dynamic> notasGuardar = {
        for (var e in _notasEditadas.entries) e.key: e.value!,
      };

      await _service.guardarNotas(
        eventoId: widget.eventoId,
        proyectoId: widget.evaluacion['proyectoId'] as String,
        juradoId: widget.evaluacion['juradoId'] as String,
        notas: notasGuardar,
        notaTotal: _notaTotalActual,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Notas actualizadas correctamente',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            backgroundColor: DColores.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context, {
          'notas': notasGuardar,
          'notaTotal': _notaTotalActual,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error al guardar: $e',
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: DColores.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGuardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DColores.navy,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editar · ${widget.evaluacion['codigo'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.rubrica.nombre,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Colors.white.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_isGuardando)
                    Semantics(
                      button: true,
                      label: 'Guardar cambios',
                      child: GestureDetector(
                        onTap: _guardarCambios,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          constraints: const BoxConstraints(
                              minWidth: 44, minHeight: 44),
                          decoration: BoxDecoration(
                            color: DColores.purple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.save_rounded,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Guardar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: DColores.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: _isGuardando
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: DColores.purple),
                            SizedBox(height: 16),
                            Text('Guardando cambios...',
                                style: TextStyle(
                                    color: DColores.textSecondary,
                                    fontSize: 14)),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                        child: ListView(
                          padding:
                              const EdgeInsets.fromLTRB(16, 20, 16, 100),
                          children: [
                            _buildProgresoCard(),
                            const SizedBox(height: 16),
                            ...widget.rubrica.secciones
                                .map((s) => _buildSeccionEditable(s)),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgresoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DColores.purpleLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DColores.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DColores.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_note_rounded,
                    color: DColores.purple, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Progreso de edición',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DColores.purple,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _progresoStat(
                  'Criterios',
                  '$_criteriosCompletos / $_totalCriterios',
                  DColores.purple,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: DColores.purple.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _progresoStat(
                  'Nota total',
                  '${_notaTotalActual.toStringAsFixed(1)} / ${widget.rubrica.puntajeMaximo.toStringAsFixed(0)}',
                  DColores.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progreso,
              minHeight: 7,
              backgroundColor: DColores.purple.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                _progreso == 1.0 ? DColores.success : DColores.purple,
              ),
            ),
          ),
          if (_progreso == 1.0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: DColores.success, size: 14),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Todos los criterios completados',
                    style: TextStyle(
                      fontSize: 11,
                      color: DColores.success,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _progresoStat(String label, String valor, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: DColores.textTertiary)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionEditable(SeccionRubrica seccion) {
    double puntajeSeccion = 0;
    int evaluados = 0;
    for (var c in seccion.criterios) {
      final n = _notasEditadas[c.id];
      if (n != null) {
        puntajeSeccion += n;
        evaluados++;
      }
    }
    final completo = evaluados == seccion.criterios.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: DColores.card,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: completo ? DColores.successLight : DColores.border),
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
          initiallyExpanded: true,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: completo ? DColores.successLight : DColores.warningLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              completo
                  ? Icons.check_circle_rounded
                  : Icons.pending_rounded,
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
            '$evaluados/${seccion.criterios.length} criterios  ·  ${puntajeSeccion.toStringAsFixed(1)} / ${seccion.pesoTotal.toStringAsFixed(0)} pts',
            style: const TextStyle(fontSize: 11, color: DColores.textTertiary),
          ),
          children: seccion.criterios
              .map((c) => _buildCriterioEditable(c))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCriterioEditable(Criterio criterio) {
    final notaSeleccionada = _notasEditadas[criterio.id];
    final pesoMaximo = criterio.peso;

    final List<double> opciones = [];
    double valor = 0;
    while (valor <= pesoMaximo + 0.001) {
      opciones.add(double.parse(valor.toStringAsFixed(1)));
      valor += 0.5;
    }
    if (opciones.isEmpty ||
        (opciones.last - pesoMaximo).abs() > 0.001) {
      opciones.add(pesoMaximo);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: notaSeleccionada != null
            ? DColores.successLight.withValues(alpha: 0.4)
            : DColores.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notaSeleccionada != null
              ? DColores.success.withValues(alpha: 0.4)
              : DColores.border,
          width: notaSeleccionada != null ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  criterio.descripcion,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: DColores.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: DColores.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Máx ${pesoMaximo.toStringAsFixed(1)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: DColores.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: notaSeleccionada != null
                  ? DColores.success.withValues(alpha: 0.1)
                  : DColores.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  notaSeleccionada != null
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 13,
                  color: notaSeleccionada != null
                      ? DColores.success
                      : DColores.warning,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    notaSeleccionada != null
                        ? 'Nota: ${notaSeleccionada.toStringAsFixed(1)} pts'
                        : 'Sin calificar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: notaSeleccionada != null
                          ? DColores.success
                          : DColores.warning,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          opciones.length <= 10
              ? _buildChips(criterio, opciones, notaSeleccionada)
              : _buildDropdown(criterio, opciones, notaSeleccionada),
        ],
      ),
    );
  }

  Widget _buildChips(Criterio criterio, List<double> opciones,
      double? notaSeleccionada) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: opciones.map((nota) {
        final sel = notaSeleccionada == nota;
        return Semantics(
          button: true,
          selected: sel,
          label: 'Nota ${nota.toStringAsFixed(1)}',
          child: GestureDetector(
            onTap: () =>
                setState(() => _notasEditadas[criterio.id] = nota),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? DColores.purple : DColores.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: sel ? DColores.purple : DColores.borderMed,
                  width: sel ? 1.5 : 1,
                ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: DColores.purple.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Text(
                nota.toStringAsFixed(
                    nota.truncateToDouble() == nota ? 0 : 1),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : DColores.purple,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropdown(Criterio criterio, List<double> opciones,
      double? notaSeleccionada) {
    return Container(
      decoration: BoxDecoration(
        color: DColores.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: notaSeleccionada != null ? DColores.purple : DColores.borderMed,
          width: notaSeleccionada != null ? 1.5 : 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          value: notaSeleccionada,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          hint: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Selecciona una nota',
              style: TextStyle(fontSize: 13, color: DColores.textTertiary),
            ),
          ),
          icon: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.keyboard_arrow_down_rounded,
                color: DColores.purple, size: 22),
          ),
          items: opciones.map((nota) {
            return DropdownMenuItem<double>(
              value: nota,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  nota.toStringAsFixed(
                      nota.truncateToDouble() == nota ? 0 : 1),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: DColores.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _notasEditadas[criterio.id] = v);
            }
          },
        ),
      ),
    );
  }
}
