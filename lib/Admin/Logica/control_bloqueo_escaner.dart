import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'escaner_config_service.dart';

class ControlBloqueoEscanerScreen extends StatefulWidget {
  const ControlBloqueoEscanerScreen({super.key});

  @override
  State<ControlBloqueoEscanerScreen> createState() =>
      _ControlBloqueoEscanerScreenState();
}

class _ControlBloqueoEscanerScreenState
    extends State<ControlBloqueoEscanerScreen> {
  static const Color _primary = Color(0xFF1E3A5F);
  final _customCtrl = TextEditingController();
  bool _guardando = false;

  // Presets en segundos.
  final List<_Preset> _presets = const [
    _Preset('Desactivado', 0),
    _Preset('30 segundos', 30),
    _Preset('1 minuto', 60),
    _Preset('2 minutos', 120),
    _Preset('5 minutos', 300),
    _Preset('10 minutos', 600),
  ];

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  String _formato(int s) {
    if (s <= 0) return 'Desactivado';
    final m = s ~/ 60;
    final r = s % 60;
    if (m == 0) return '$r s';
    if (r == 0) return '$m min';
    return '$m min $r s';
  }

  Future<void> _guardar(int segundos) async {
    setState(() => _guardando = true);
    try {
      await EscanerConfigService.setCooldownSegundos(segundos);
      if (!mounted) return;
      _customCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bloqueo actualizado: ${_formato(segundos)}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _guardarCustom() {
    final txt = _customCtrl.text.trim();
    final val = int.tryParse(txt);
    if (val == null || val < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un número válido de segundos'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _guardar(val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Volver',
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.timer, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Bloqueo del Escáner',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Valor actual (en vivo)
                      StreamBuilder<int>(
                        stream: EscanerConfigService.watchCooldownSegundos(),
                        builder: (context, snap) {
                          final actual = snap.data;
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: _primary.withValues(alpha: 0.15)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'TIEMPO DE BLOQUEO ACTUAL',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  actual == null
                                      ? '...'
                                      : _formato(actual),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: _primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Aplica a TODAS las filiales, '
                                  'facultades y carreras',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Opciones rápidas',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _presets.map((p) {
                          return ActionChip(
                            label: Text(p.label),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                                color: _primary.withValues(alpha: 0.25)),
                            labelStyle: const TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w600,
                            ),
                            onPressed:
                                _guardando ? null : () => _guardar(p.segundos),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Valor personalizado (segundos)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                hintText: 'Ej: 180',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _guardando ? null : _guardarCustom,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _guardando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Guardar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.orange, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'El cambio se aplica al abrir el escáner. '
                                'Pon 0 (Desactivado) para quitar el bloqueo '
                                'por completo.',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ),
                          ],
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
    );
  }
}

class _Preset {
  final String label;
  final int segundos;
  const _Preset(this.label, this.segundos);
}