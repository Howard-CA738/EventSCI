import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import '/shared/logica/gestion_criterios.dart';
import 'crear_rubrica_carrera_screen.dart';
import 'editar_rubrica_carrera_screen.dart';

class GestionRubricasCarreraScreen extends StatefulWidget {
  const GestionRubricasCarreraScreen({super.key});

  @override
  State<GestionRubricasCarreraScreen> createState() =>
      _GestionRubricasCarreraScreenState();
}

class _GestionRubricasCarreraScreenState
    extends State<GestionRubricasCarreraScreen> {
  final RubricasService _service = RubricasService();

  String? _filialId;
  String? _filialNombre;
  String? _facultad;
  String? _carreraNombre;

  List<Rubrica> _rubricas = [];
  bool _isLoadingSession = true;
  bool _isLoadingRubricas = false;

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    setState(() => _isLoadingSession = true);
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData != null) {
        _filialId = adminData['filial'];
        _filialNombre = adminData['filialNombre'];
        _facultad = adminData['facultad'];
        _carreraNombre = adminData['carrera'];
      }
    } catch (e) {
      debugPrint('Error cargando sesion: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSession = false);
    }
    await _cargarRubricas();
  }

  Future<void> _cargarRubricas() async {
    if (_filialId == null) return;
    if (mounted) setState(() => _isLoadingRubricas = true);
    try {
      final todas = await _service.obtenerRubricas();

      final filtradas = todas.where((r) {
        if (r.filial != _filialId) return false;
        if (r.facultad.trim().toLowerCase() !=
            (_facultad ?? '').trim().toLowerCase()) return false;
        if (_carreraNombre != null && _carreraNombre!.isNotEmpty) {
          if (r.carrera == null || r.carrera!.trim().isEmpty) return false;
          return r.carrera!.trim().toLowerCase() ==
              _carreraNombre!.trim().toLowerCase();
        }
        return true;
      }).toList();

      if (mounted) setState(() => _rubricas = filtradas);
    } catch (e) {
      debugPrint('Error cargando rubricas: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRubricas = false);
    }
  }

  Future<void> _eliminarRubrica(String rubricaId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminacion'),
        content: const Text('¿Eliminar esta rubrica?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final ok = await _service.eliminarRubrica(rubricaId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Rubrica eliminada' : 'Error al eliminar'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) _cargarRubricas();
    }
  }

  void _navegarACrearRubrica() {
    if (_filialId == null || _facultad == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CrearRubricaCarreraScreen(
          filial: _filialId!,
          filialNombre: _filialNombre ?? _filialId!,
          facultad: _facultad!,
          carrera: _carreraNombre,
        ),
      ),
    ).then((_) => _cargarRubricas());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF2),
      appBar: AppBar(
        title: const Text('Gestion de Rubricas',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarRubricas,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoadingSession ? null : _navegarACrearRubrica,
        backgroundColor: const Color(0xFF1E3A5F),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Rubrica'),
      ),
      body: SafeArea(
        child: _isLoadingSession
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF1E3A5F)))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildContextCard(),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoadingRubricas
                        ? const Center(child: CircularProgressIndicator())
                        : _rubricas.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 80),
                                itemCount: _rubricas.length,
                                itemBuilder: (context, index) =>
                                    _buildRubricaCard(_rubricas[index]),
                              ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildContextCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_carreraNombre ?? '—',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 3),
                Text(_facultad ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(_filialNombre ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30),
            ),
            child: Text(
              '${_rubricas.length} rubrica(s)',
              style:
                  const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRubricaCard(Rubrica rubrica) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditarRubricaCarreraScreen(
                rubrica: rubrica,
                filialNombre: _filialNombre ?? rubrica.filial,
              ),
            ),
          );
          _cargarRubricas();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment,
                        color: Color(0xFF1E3A5F), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rubrica.nombre,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A5F)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (rubrica.descripcion.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              rubrica.descripcion,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red),
                    tooltip: 'Eliminar rubrica',
                    onPressed: () => _eliminarRubrica(rubrica.id),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _infoChip(Icons.format_list_numbered,
                      '${rubrica.secciones.length} secc.', Colors.blue),
                  _infoChip(Icons.check_circle_outline,
                      '${rubrica.totalCriterios} crit.', Colors.green),
                  _infoChip(Icons.people_outline,
                      '${rubrica.juradosAsignados.length} jurados',
                      Colors.orange),
                  _infoChip(Icons.stars,
                      '${rubrica.puntajeMaximo.toStringAsFixed(rubrica.puntajeMaximo.truncateToDouble() == rubrica.puntajeMaximo ? 0 : 1)} pts',
                      Colors.purple),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                  color: Color(0xFFF0F4FF), shape: BoxShape.circle),
              child: const Icon(Icons.checklist,
                  size: 56, color: Color(0xFF1E3A5F)),
            ),
            const SizedBox(height: 20),
            const Text('No hay rubricas',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F))),
            const SizedBox(height: 8),
            Text('Crea la primera rubrica para esta carrera',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
