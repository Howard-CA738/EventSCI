import 'package:flutter/material.dart';
import '/shared/logica/gestion_criterios.dart';

class CriterioWidget extends StatefulWidget {
  final Criterio criterio;
  final VoidCallback onEliminar;
  final VoidCallback onActualizar;

  const CriterioWidget({
    super.key,
    required this.criterio,
    required this.onEliminar,
    required this.onActualizar,
  });

  @override
  State<CriterioWidget> createState() => _CriterioWidgetState();
}

class _CriterioWidgetState extends State<CriterioWidget> {
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _pesoCtrl;

  @override
  void initState() {
    super.initState();
    _descripcionCtrl =
        TextEditingController(text: widget.criterio.descripcion);
    _pesoCtrl =
        TextEditingController(text: widget.criterio.peso.toString());
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _pesoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextFormField(
              controller: _descripcionCtrl,
              style: const TextStyle(color: Color(0xFF1E293B)),
              decoration: const InputDecoration(
                  labelText: 'Criterio de Evaluacion',
                  labelStyle: TextStyle(color: Color(0xFF64748B)),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.all(12)),
              maxLines: 2,
              onChanged: (v) {
                widget.criterio.descripcion = v;
                widget.onActualizar();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _pesoCtrl,
                    style: const TextStyle(color: Color(0xFF1E293B)),
                    decoration: const InputDecoration(
                        labelText: 'Peso (pts)',
                        labelStyle: TextStyle(color: Color(0xFF64748B)),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.all(12)),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: (v) {
                      widget.criterio.peso = double.tryParse(v) ?? 0;
                      widget.onActualizar();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete,
                        color: Colors.red, size: 18),
                    tooltip: 'Eliminar criterio',
                    onPressed: widget.onEliminar,
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
