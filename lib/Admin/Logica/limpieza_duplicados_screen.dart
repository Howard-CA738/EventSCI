import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'limpieza_duplicados_service.dart';

/// Pantalla TEMPORAL de un solo uso para revisar y corregir carreras
/// duplicadas. Bórrala (y borra su entrada del menú de AdminScreen)
/// una vez que confirmes que los datos quedaron limpios.
class LimpiezaDuplicadosScreen extends StatefulWidget {
  const LimpiezaDuplicadosScreen({super.key});

  @override
  State<LimpiezaDuplicadosScreen> createState() =>
      _LimpiezaDuplicadosScreenState();
}

class _LimpiezaDuplicadosScreenState extends State<LimpiezaDuplicadosScreen> {
  static const Color _primaryColor = Color(0xFF1E3A5F);

  final LimpiezaDuplicadosService _service = LimpiezaDuplicadosService();

  String _filialId = 'juliaca';
  final List<String> _filialesConocidas = ['lima', 'juliaca', 'tarapoto'];

  bool _isRunning = false;
  Map<String, dynamic>? _ultimoReporte;

  Future<void> _ejecutar({required bool dryRun}) async {
    setState(() {
      _isRunning = true;
      _ultimoReporte = null;
    });

    try {
      final reporte =
          await _service.limpiarDuplicados(_filialId, dryRun: dryRun);
      if (!mounted) return;
      setState(() => _ultimoReporte = reporte);

      // Resumen final bien delimitado, fácil de copiar del log de consola.
      debugPrint('');
      debugPrint('════════════════ RESUMEN FINAL ($_filialId) ════════════════');
      debugPrint('dryRun: $dryRun');
      debugPrint('facultadesRevisadas: ${reporte['facultadesRevisadas']}');
      debugPrint('gruposDuplicados: ${reporte['gruposDuplicados']}');
      debugPrint('gruposAmbiguos: ${reporte['gruposAmbiguos'] ?? 0}');
      debugPrint('carrerasEliminadas: ${reporte['carrerasEliminadas']}');
      debugPrint('eventosReasignados: ${reporte['eventosReasignados']}');
      debugPrint('══════════════════════════════════════════════════════════');
      debugPrint('');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<void> _confirmarYAplicar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red),
            SizedBox(width: 8),
            Flexible(child: Text('Confirmar cambios reales')),
          ],
        ),
        content: const Text(
          'Esto va a modificar y BORRAR documentos en Firestore de forma '
          'permanente (no hay deshacer). Asegúrate de haber revisado el '
          'reporte en modo "Solo revisar" primero.\n\n'
          '¿Confirmas que quieres aplicar los cambios ahora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, aplicar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _ejecutar(dryRun: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reporte = _ultimoReporte;

    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF2),
      appBar: AppBar(
        title: const Text('Limpieza de Carreras Duplicadas'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[800]),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Herramienta temporal. Corre primero "Solo revisar" '
                        'y lee el detalle antes de tocar "Aplicar cambios".',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _filialId,
                decoration: InputDecoration(
                  labelText: 'Filial a revisar',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _filialesConocidas
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: _isRunning
                    ? null
                    : (v) {
                        if (v != null) setState(() => _filialId = v);
                      },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isRunning ? null : () => _ejecutar(dryRun: true),
                      icon: const Icon(Icons.search),
                      label: const Text('Solo revisar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isRunning ? null : _confirmarYAplicar,
                      icon: const Icon(Icons.warning_amber),
                      label: const Text('Aplicar cambios'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isRunning)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_isRunning && reporte != null)
                Expanded(child: _buildReporte(reporte)),
              if (!_isRunning && reporte == null)
                Expanded(
                  child: Center(
                    child: Text(
                      'Sin resultados todavía.\nElige una filial y presiona '
                      '"Solo revisar".',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReporte(Map<String, dynamic> reporte) {
    final dryRun = reporte['dryRun'] as bool? ?? true;
    final detalle = (reporte['detalle'] as List?)?.cast<String>() ?? [];
    final gruposAmbiguos = reporte['gruposAmbiguos'] as int? ?? 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: dryRun ? Colors.blue[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: dryRun ? Colors.blue.shade200 : Colors.green.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dryRun
                      ? '🔍 Modo revisión (nada se modificó)'
                      : '✅ Cambios aplicados',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text('Facultades revisadas: ${reporte['facultadesRevisadas']}'),
                Text('Grupos duplicados encontrados: ${reporte['gruposDuplicados']}'),
                if (gruposAmbiguos > 0)
                  Text(
                    '⚠️ Grupos ambiguos (no tocados): $gruposAmbiguos',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  'Carreras ${dryRun ? "a eliminar" : "eliminadas"}: '
                  '${reporte['carrerasEliminadas']}',
                ),
                Text(
                  'Eventos ${dryRun ? "a reasignar" : "reasignados"}: '
                  '${reporte['eventosReasignados']}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Detalle',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          if (detalle.isEmpty)
            const Text('No se encontraron duplicados en esta filial. 🎉')
          else
            ...detalle.map((linea) {
              final esAmbiguo = linea.contains('AMBIGUO');
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: esAmbiguo ? Colors.red[50] : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: esAmbiguo ? Colors.red.shade200 : Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  linea,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: esAmbiguo ? Colors.red[900] : Colors.black87,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}