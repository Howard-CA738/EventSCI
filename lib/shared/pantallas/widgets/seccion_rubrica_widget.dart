import 'package:flutter/material.dart';
import '/shared/logica/gestion_criterios.dart';
import 'criterio_widget.dart';

class SeccionRubricaWidget extends StatefulWidget {
  final SeccionRubrica seccion;
  final VoidCallback onEliminar;
  final VoidCallback onActualizar;

  const SeccionRubricaWidget({
    super.key,
    required this.seccion,
    required this.onEliminar,
    required this.onActualizar,
  });

  @override
  State<SeccionRubricaWidget> createState() => _SeccionRubricaWidgetState();
}

class _SeccionRubricaWidgetState extends State<SeccionRubricaWidget> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _pesoCtrl;

  @override
  void initState() {
    super.initState();
    _nombreCtrl =
        TextEditingController(text: widget.seccion.nombre);
    _pesoCtrl =
        TextEditingController(text: widget.seccion.pesoTotal.toString());
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _pesoCtrl.dispose();
    super.dispose();
  }

  void _agregarCriterio() {
    widget.seccion.criterios.add(Criterio(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      descripcion: 'Nuevo criterio',
      peso: 2.5,
    ));
    widget.onActualizar();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.blue.shade50,
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.all(12),
        title: Text(widget.seccion.nombre,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${widget.seccion.criterios.length} criterios · ${widget.seccion.pesoTotal} pts',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
          tooltip: 'Eliminar seccion',
          onPressed: widget.onEliminar,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
        children: [
          Column(
            children: [
              TextFormField(
                controller: _nombreCtrl,
                style: const TextStyle(color: Color(0xFF1E293B)),
                decoration: const InputDecoration(
                    labelText: 'Nombre de la seccion',
                    labelStyle: TextStyle(color: Color(0xFF64748B)),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.all(12)),
                onChanged: (v) {
                  widget.seccion.nombre = v;
                  widget.onActualizar();
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pesoCtrl,
                style: const TextStyle(color: Color(0xFF1E293B)),
                decoration: const InputDecoration(
                    labelText: 'Peso total (pts)',
                    labelStyle: TextStyle(color: Color(0xFF64748B)),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.all(12)),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                onChanged: (v) {
                  widget.seccion.pesoTotal = double.tryParse(v) ?? 10;
                  widget.onActualizar();
                },
              ),
              const SizedBox(height: 12),
              ...widget.seccion.criterios.asMap().entries.map((e) {
                return CriterioWidget(
                  key: ValueKey(e.value.id),
                  criterio: e.value,
                  onEliminar: () {
                    widget.seccion.criterios.removeAt(e.key);
                    widget.onActualizar();
                  },
                  onActualizar: widget.onActualizar,
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _agregarCriterio,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Agregar Criterio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
