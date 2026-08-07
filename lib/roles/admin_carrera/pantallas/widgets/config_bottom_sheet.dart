import 'package:flutter/material.dart';
import '../../datos/eval_final_config.dart';

class EColores {
  static const navy = Color(0xFF0F2342);
  static const accent = Color(0xFF3B82F6);
  static const green = Color(0xFF059669);
  static const orange = Color(0xFFD97706);
  static const orangeL = Color(0xFFFEF3C7);
  static const red = Color(0xFFDC2626);
  static const redL = Color(0xFFFEE2E2);
  static const purple = Color(0xFF7C3AED);
  static const purpleL = Color(0xFFEDE9FE);
  static const teal = Color(0xFF0F9D58);
  static const tealL = Color(0xFFD7F5E6);
  static const surface = Color(0xFFF8FAFC);
  static const card = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const txt1 = Color(0xFF0F172A);
  static const txt2 = Color(0xFF475569);
  static const txt3 = Color(0xFF94A3B8);
}

class ConfigBottomSheet extends StatefulWidget {
  final EvalFinalConfig config;
  final Future<void> Function(EvalFinalConfig) onGuardar;

  const ConfigBottomSheet({
    super.key,
    required this.config,
    required this.onGuardar,
  });

  @override
  State<ConfigBottomSheet> createState() => _ConfigBottomSheetState();
}

class _ConfigBottomSheetState extends State<ConfigBottomSheet> {
  late EvalFinalConfig _cfg;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cfg = widget.config;
  }

  String? _validar() {
    if (_cfg.incluirDocenteNoSel) {
      final s = _cfg.pctAsistNoSel + _cfg.pctDocenteNoSel;
      if ((s - 100).abs() > 0.5) {
        return 'Sin exponer: suma ${s.toStringAsFixed(1)}% (debe ser 100%)';
      }
    }
    if (_cfg.modalidad == 'jurado') {
      final s = _cfg.pctAsistSel + _cfg.pctJuradoSel;
      if ((s - 100).abs() > 0.5) {
        return 'Expone (jurado): suma ${s.toStringAsFixed(1)}% (debe ser 100%)';
      }
    } else {
      final s = _cfg.pctAsistSelMixta +
          _cfg.pctJuradoSelMixta +
          _cfg.pctDocenteSelMixta;
      if ((s - 100).abs() > 0.5) {
        return 'Expone (mixta): suma ${s.toStringAsFixed(1)}% (debe ser 100%)';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final error = _validar();

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: EColores.card,
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
                  color: EColores.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: EColores.purpleL,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.tune_rounded,
                        color: EColores.purple, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Configurar ponderación',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: EColores.navy)),
                  ),
                ],
              ),
            ),
            Container(
                height: 1,
                margin: const EdgeInsets.only(top: 14),
                color: EColores.border),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(20),
                children: [
                  _seccionLabel(
                      'Estudiantes sin exponer (no seleccionados)',
                      Icons.person_rounded,
                      EColores.orange),
                  const SizedBox(height: 10),
                  _infoChip(
                      'Tienen nota de asistencias (N1) siempre.'
                      ' Opcionalmente incluye nota docente (N3).'),
                  const SizedBox(height: 12),
                  _sliderRow(
                    label: 'Asistencias (N1)',
                    value: _cfg.pctAsistNoSel,
                    color: EColores.accent,
                    onChanged: (v) => setState(() {
                      _cfg.pctAsistNoSel = v;
                      if (_cfg.incluirDocenteNoSel) {
                        _cfg.pctDocenteNoSel = (100 - v).clamp(0, 100);
                      }
                    }),
                    enabled: true,
                  ),
                  _toggleRow(
                    label: 'Incluir nota docente (N3)',
                    value: _cfg.incluirDocenteNoSel,
                    onChanged: (v) => setState(() {
                      _cfg.incluirDocenteNoSel = v;
                      if (v) {
                        _cfg.pctAsistNoSel = 70;
                        _cfg.pctDocenteNoSel = 30;
                      } else {
                        _cfg.pctAsistNoSel = 100;
                        _cfg.pctDocenteNoSel = 0;
                      }
                    }),
                  ),
                  if (_cfg.incluirDocenteNoSel) ...[
                    const SizedBox(height: 4),
                    _sliderRow(
                      label: 'Docente (N3)',
                      value: _cfg.pctDocenteNoSel,
                      color: EColores.orange,
                      onChanged: (v) => setState(() {
                        _cfg.pctDocenteNoSel = v;
                        _cfg.pctAsistNoSel = (100 - v).clamp(0, 100);
                      }),
                      enabled: true,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(height: 1, color: EColores.border),
                  const SizedBox(height: 24),
                  _seccionLabel(
                      'Estudiantes que exponen (seleccionados)',
                      Icons.present_to_all_rounded,
                      EColores.teal),
                  const SizedBox(height: 10),
                  const Text('Modalidad de calificación',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: EColores.txt2)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _modeBtn('jurado', 'Solo jurado', Icons.gavel_rounded),
                      const SizedBox(width: 10),
                      _modeBtn(
                          'mixta', 'Mixta (+ docente)', Icons.merge_type_rounded),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_cfg.modalidad == 'jurado') ...[
                    _infoChip(
                        'Solo jurado: N1 (Asistencias) + N2 (Jurados). '
                        'No se usa nota docente.'),
                    const SizedBox(height: 12),
                    _sliderRow(
                      label: 'Asistencias (N1)',
                      value: _cfg.pctAsistSel,
                      color: EColores.accent,
                      onChanged: (v) => setState(() {
                        _cfg.pctAsistSel = v;
                        _cfg.pctJuradoSel = (100 - v).clamp(0, 100);
                      }),
                      enabled: true,
                    ),
                    const SizedBox(height: 4),
                    _sliderRow(
                      label: 'Jurado (N2)',
                      value: _cfg.pctJuradoSel,
                      color: EColores.purple,
                      onChanged: (v) => setState(() {
                        _cfg.pctJuradoSel = v;
                        _cfg.pctAsistSel = (100 - v).clamp(0, 100);
                      }),
                      enabled: true,
                    ),
                  ] else ...[
                    _infoChip(
                        'Mixta: N1 (Asistencias) + N2 (Jurados) + N3 (Docente). '
                        'La nota docente estará vacía hasta completarla en el Excel.'),
                    const SizedBox(height: 12),
                    _sliderRow(
                      label: 'Asistencias (N1)',
                      value: _cfg.pctAsistSelMixta,
                      color: EColores.accent,
                      onChanged: (v) => setState(() {
                        final resto = 100 - v;
                        _cfg.pctAsistSelMixta = v;
                        _cfg.pctJuradoSelMixta = (resto * 0.7).roundToDouble();
                        _cfg.pctDocenteSelMixta =
                            (resto * 0.3).roundToDouble();
                      }),
                      enabled: true,
                    ),
                    const SizedBox(height: 4),
                    _sliderRow(
                      label: 'Jurado (N2)',
                      value: _cfg.pctJuradoSelMixta,
                      color: EColores.purple,
                      onChanged: (v) => setState(() {
                        _cfg.pctJuradoSelMixta = v;
                        _cfg.pctDocenteSelMixta =
                            (100 - _cfg.pctAsistSelMixta - v).clamp(0, 100);
                      }),
                      enabled: true,
                    ),
                    const SizedBox(height: 4),
                    _sliderRow(
                      label: 'Docente (N3)',
                      value: _cfg.pctDocenteSelMixta,
                      color: EColores.orange,
                      onChanged: (v) => setState(() {
                        _cfg.pctDocenteSelMixta = v;
                        _cfg.pctJuradoSelMixta =
                            (100 - _cfg.pctAsistSelMixta - v).clamp(0, 100);
                      }),
                      enabled: true,
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: EColores.redL,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: EColores.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_rounded,
                              color: EColores.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(error,
                                style: const TextStyle(
                                    color: EColores.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (error != null || _guardando)
                          ? null
                          : () async {
                              setState(() => _guardando = true);
                              await widget.onGuardar(_cfg);
                              setState(() => _guardando = false);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EColores.purple,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Guardar configuración',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionLabel(String label, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: EColores.navy)),
        ),
      ],
    );
  }

  Widget _infoChip(String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: EColores.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EColores.border),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11, color: EColores.txt2, height: 1.4)),
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
    required bool enabled,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: EColores.txt2)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              overlayColor: color.withValues(alpha: 0.1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.clamp(0, 100),
              max: 100,
              divisions: 20,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${value.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  Widget _toggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: EColores.txt1)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: EColores.teal,
        ),
      ],
    );
  }

  Widget _modeBtn(String value, String label, IconData icon) {
    final sel = _cfg.modalidad == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _cfg.modalidad = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: sel ? EColores.teal : EColores.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? EColores.teal : EColores.border,
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: sel ? Colors.white : EColores.txt2),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : EColores.txt2)),
            ],
          ),
        ),
      ),
    );
  }
}
