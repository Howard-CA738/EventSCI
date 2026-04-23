import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/logica/gestion_criterios.dart';

// Archivo: lib/admin/interfaz/detalle_evaluaciones_carrera.dart

class DetalleEvaluacionesCarreraScreen extends StatefulWidget {
  final String eventoId;
  final String eventoNombre;
  final List<Map<String, dynamic>> evaluaciones;

  const DetalleEvaluacionesCarreraScreen({
    super.key,
    required this.eventoId,
    required this.eventoNombre,
    required this.evaluaciones,
  });

  @override
  State<DetalleEvaluacionesCarreraScreen> createState() =>
      _DetalleEvaluacionesCarreraScreenState();
}

class _DetalleEvaluacionesCarreraScreenState
    extends State<DetalleEvaluacionesCarreraScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  late List<Map<String, dynamic>> _evaluaciones;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Copia local para poder actualizar el estado sin recargar todo
    _evaluaciones = List<Map<String, dynamic>>.from(widget.evaluaciones);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // LISTAS FILTRADAS
  // ═══════════════════════════════════════════════════════════════
  List<Map<String, dynamic>> get _pendientes =>
      _evaluaciones.where((e) => !(e['evaluada'] as bool)).toList();

  List<Map<String, dynamic>> get _evaluadas =>
      _evaluaciones.where((e) => e['evaluada'] as bool).toList();

  // ═══════════════════════════════════════════════════════════════
  // BLOQUEAR / DESBLOQUEAR
  // ═══════════════════════════════════════════════════════════════
  Future<void> _toggleBloqueo(Map<String, dynamic> evaluacion) async {
    final bloqueada = evaluacion['bloqueada'] as bool;
    final nuevoEstado = !bloqueada;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
            nuevoEstado ? 'Bloquear Evaluación' : 'Desbloquear Evaluación'),
        content: Text(
          nuevoEstado
              ? '¿Deseas bloquear esta evaluación? El jurado no podrá modificarla.'
              : '¿Deseas desbloquear esta evaluación? El jurado podrá volver a calificar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: nuevoEstado ? Colors.red : Colors.green,
            ),
            child: Text(nuevoEstado ? 'Bloquear' : 'Desbloquear'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _firestore
          .collection('events')
          .doc(widget.eventoId)
          .collection('proyectos')
          .doc(evaluacion['proyectoId'])
          .collection('evaluaciones')
          .doc(evaluacion['juradoId'])
          .update({
        'bloqueada': nuevoEstado,
        // Si se desbloquea, resetear evaluada para que el jurado pueda volver a calificar
        if (!nuevoEstado) 'evaluada': false,
      });

      setState(() {
        final idx = _evaluaciones.indexWhere(
          (e) =>
              e['proyectoId'] == evaluacion['proyectoId'] &&
              e['juradoId'] == evaluacion['juradoId'],
        );
        if (idx != -1) {
          _evaluaciones[idx]['bloqueada'] = nuevoEstado;
          // Actualizar también localmente el estado evaluada
          if (!nuevoEstado) _evaluaciones[idx]['evaluada'] = false;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nuevoEstado
                ? '🔒 Evaluación bloqueada'
                : '🔓 Evaluación desbloqueada - el jurado puede volver a calificar'),
            backgroundColor: nuevoEstado ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
void _verDetalle(Map<String, dynamic> evaluacion) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DetalleBottomSheet(evaluacion: evaluacion),
  );
}
  // ═══════════════════════════════════════════════════════════════
  // EDITAR NOTAS (navegar a pantalla de edición)
  // ═══════════════════════════════════════════════════════════════
  Future<void> _editarNotas(Map<String, dynamic> evaluacion) async {
    final rubrica = evaluacion['rubrica'] as Rubrica?;
    if (rubrica == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró la rúbrica para editar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _EditarNotasScreen(
          eventoId: widget.eventoId,
          evaluacion: evaluacion,
          rubrica: rubrica,
        ),
      ),
    );

    // Si se guardaron cambios, actualizar localmente
    if (resultado != null) {
      setState(() {
        final idx = _evaluaciones.indexWhere(
          (e) =>
              e['proyectoId'] == evaluacion['proyectoId'] &&
              e['juradoId'] == evaluacion['juradoId'],
        );
        if (idx != -1) {
          _evaluaciones[idx]['notas'] = resultado['notas'];
          _evaluaciones[idx]['notaTotal'] = resultado['notaTotal'];
        }
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Evaluaciones del Evento',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Text(
                          widget.eventoNombre,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.75)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Resumen rápido ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildResumenChip(
                      'Total', _evaluaciones.length, Colors.white),
                  const SizedBox(width: 10),
                  _buildResumenChip(
                      'Pendientes', _pendientes.length, Colors.orange),
                  const SizedBox(width: 10),
                  _buildResumenChip(
                      'Evaluadas', _evaluadas.length, Colors.green),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── TabBar ───────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: const Color(0xFF1E3A5F),
                unselectedLabelColor: Colors.white,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.pending_actions, size: 18),
                        const SizedBox(width: 6),
                        Text('Pendientes (${_pendientes.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, size: 18),
                        const SizedBox(width: 6),
                        Text('Evaluadas (${_evaluadas.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── TabView ──────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLista(_pendientes, esPendiente: true),
                    _buildLista(_evaluadas, esPendiente: false),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenChip(String label, int valor, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Text(
              valor.toString(),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color == Colors.white ? Colors.white : color),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  color: color == Colors.white
                      ? Colors.white70
                      : color.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // LISTA DE EVALUACIONES
  // ═══════════════════════════════════════════════════════════════
  Widget _buildLista(List<Map<String, dynamic>> lista,
      {required bool esPendiente}) {
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              esPendiente ? Icons.pending_actions : Icons.assignment_turned_in,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              esPendiente
                  ? 'No hay evaluaciones pendientes'
                  : 'No hay evaluaciones completadas',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: lista.length,
      itemBuilder: (context, index) =>
          _buildEvaluacionCard(lista[index], esPendiente: esPendiente),
    );
  }

  Widget _buildEvaluacionCard(Map<String, dynamic> evaluacion,
      {required bool esPendiente}) {
    final bloqueada = evaluacion['bloqueada'] as bool;
    final notaTotal = evaluacion['notaTotal'] as double;

    final Color borderColor =
        esPendiente ? Colors.orange : Colors.green;
    final Color estadoColor = bloqueada
        ? Colors.red
        : esPendiente
            ? Colors.orange
            : Colors.green;
    final IconData estadoIcon = bloqueada
        ? Icons.lock
        : esPendiente
            ? Icons.pending
            : Icons.check_circle;
    final String estadoTexto = bloqueada
        ? 'Bloqueada'
        : esPendiente
            ? 'Pendiente'
            : 'Evaluada';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor.withOpacity(0.3), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Fila superior: código + estado ──────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    evaluacion['codigo'],
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(estadoIcon, size: 13, color: estadoColor),
                      const SizedBox(width: 4),
                      Text(
                        estadoTexto,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: estadoColor),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Nota total (solo si evaluada)
                if (!esPendiente)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${notaTotal.toStringAsFixed(1)} pts',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Título del proyecto ──────────────────────────────
            Text(
              evaluacion['titulo'],
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6),

            _buildInfoRowSmall(
                Icons.person, 'Jurado: ${evaluacion['juradoNombre']}'),
            _buildInfoRowSmall(
                Icons.checklist, evaluacion['rubricaNombre']),
            if (evaluacion['integrantes'].toString().isNotEmpty)
              _buildInfoRowSmall(
                  Icons.people, evaluacion['integrantes']),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── Acciones ─────────────────────────────────────────
            Row(
              children: [
                // Ver detalle
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _verDetalle(evaluacion),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Ver detalle',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E3A5F),
                      side: const BorderSide(color: Color(0xFF1E3A5F)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),

                // Editar (solo si evaluada)
                if (!esPendiente) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _editarNotas(evaluacion),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Editar nota',
                          style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9C27B0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],

                const SizedBox(width: 8),

                // Bloquear / desbloquear
                IconButton(
                  onPressed: () => _toggleBloqueo(evaluacion),
                  icon: Icon(
                    bloqueada ? Icons.lock : Icons.lock_open,
                    color: bloqueada ? Colors.red : Colors.grey,
                  ),
                  tooltip: bloqueada
                      ? 'Desbloquear evaluación'
                      : 'Bloquear evaluación',
                  style: IconButton.styleFrom(
                    backgroundColor: bloqueada
                        ? Colors.red.shade100
                        : Colors.grey.shade200,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRowSmall(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// BOTTOM SHEET: Detalle de evaluación (solo lectura)
// ═══════════════════════════════════════════════════════════════════════
class _DetalleBottomSheet extends StatelessWidget {
  final Map<String, dynamic> evaluacion;

  const _DetalleBottomSheet({required this.evaluacion});

  @override
  Widget build(BuildContext context) {
    final rubrica = evaluacion['rubrica'] as Rubrica?;
    final notas = evaluacion['notas'] as Map<String, dynamic>;
    final evaluada = evaluacion['evaluada'] as bool;
    final notaTotal = evaluacion['notaTotal'] as double;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Evaluación de ${evaluacion['codigo']}',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F)),
                          ),
                          Text(
                            'Jurado: ${evaluacion['juradoNombre']}',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                    // Nota total badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: evaluada ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            notaTotal.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          const Text('pts',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 24),

              // Contenido
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Info proyecto
                    _buildInfoCard(),

                    const SizedBox(height: 16),

                    // Criterios
                    if (rubrica != null) ...[
                      const Text(
                        'Criterios Evaluados',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F)),
                      ),
                      const SizedBox(height: 12),
                      ...rubrica.secciones
                          .map((s) => _SeccionDetalleWidget(
                                seccion: s,
                                notas: notas,
                              ))
                          .toList(),
                    ] else
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No se encontró la rúbrica asociada',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),

                    const SizedBox(height: 20),
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
    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              evaluacion['titulo'],
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F)),
            ),
            if (evaluacion['integrantes'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.people, evaluacion['integrantes']),
            ],
            if (evaluacion['sala'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              _infoRow(Icons.room, evaluacion['sala']),
            ],
            const SizedBox(height: 6),
            _infoRow(Icons.category,
                'Categoría: ${evaluacion['clasificacion']}'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]))),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WIDGET: Sección de rúbrica en detalle (solo lectura)
// ═══════════════════════════════════════════════════════════════════════
class _SeccionDetalleWidget extends StatelessWidget {
  final SeccionRubrica seccion;
  final Map<String, dynamic> notas;

  const _SeccionDetalleWidget(
      {required this.seccion, required this.notas});

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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context)
            .copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.folder_open,
                color: Color(0xFF1E3A5F), size: 20),
          ),
          title: Text(seccion.nombre,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F))),
          subtitle: Text(
            '$evaluados/${seccion.criterios.length} criterios • ${puntaje.toStringAsFixed(1)}/${seccion.pesoTotal.toStringAsFixed(0)} pts',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          children: seccion.criterios.map((c) {
            final nota = notas[c.id];
            final tieneNota = nota != null;
            final notaDouble =
                tieneNota ? (nota as num).toDouble() : 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tieneNota
                    ? Colors.green.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: tieneNota
                      ? Colors.green.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.descripcion,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155))),
                        const SizedBox(height: 4),
                        Text(
                            'Máximo: ${c.peso.toStringAsFixed(1)} pts',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: tieneNota ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tieneNota
                          ? notaDouble.toStringAsFixed(1)
                          : '-',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
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

// ═══════════════════════════════════════════════════════════════════════
// PANTALLA: Editar notas por criterio
// ═══════════════════════════════════════════════════════════════════════
class _EditarNotasScreen extends StatefulWidget {
  final String eventoId;
  final Map<String, dynamic> evaluacion;
  final Rubrica rubrica;

  const _EditarNotasScreen({
    required this.eventoId,
    required this.evaluacion,
    required this.rubrica,
  });

  @override
  State<_EditarNotasScreen> createState() => _EditarNotasScreenState();
}

class _EditarNotasScreenState extends State<_EditarNotasScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Map<String, double?> _notasEditadas;
  bool _isGuardando = false;

  @override
  void initState() {
    super.initState();
    // Precargar con las notas actuales
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

  Future<void> _guardarCambios() async {
    // Verificar que todos los criterios tengan nota
    for (var seccion in widget.rubrica.secciones) {
      for (var criterio in seccion.criterios) {
        if (_notasEditadas[criterio.id] == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Faltan criterios en "${seccion.nombre}" sin calificar'),
            backgroundColor: Colors.orange,
          ));
          return;
        }
      }
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar cambios'),
        content: Text(
          'La nota total será ${_notaTotalActual.toStringAsFixed(1)} pts.\n¿Deseas guardar los cambios?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isGuardando = true);

    try {
      final Map<String, dynamic> notasGuardar = {};
      for (var entry in _notasEditadas.entries) {
        notasGuardar[entry.key] = entry.value!;
      }

      await _firestore
          .collection('events')
          .doc(widget.eventoId)
          .collection('proyectos')
          .doc(widget.evaluacion['proyectoId'])
          .collection('evaluaciones')
          .doc(widget.evaluacion['juradoId'])
          .update({
        'notas': notasGuardar,
        'notaTotal': _notaTotalActual,
        'editadoPorAdmin': true,
        'fechaEdicionAdmin': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Notas actualizadas correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        // Devolver los nuevos datos al padre
        Navigator.pop(context, {
          'notas': notasGuardar,
          'notaTotal': _notaTotalActual,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al guardar: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGuardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editar Notas - ${widget.evaluacion['codigo']}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Text(
                          widget.rubrica.nombre,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.75)),
                        ),
                      ],
                    ),
                  ),
                  if (!_isGuardando)
                    IconButton(
                      icon: const Icon(Icons.save,
                          color: Colors.white, size: 28),
                      onPressed: _guardarCambios,
                      tooltip: 'Guardar cambios',
                    ),
                ],
              ),
            ),

            // ── Contenido ────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _isGuardando
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          // Progreso y nota actual
                          _buildResumenProgreso(),
                          const SizedBox(height: 20),

                          // Secciones y criterios
                          ...widget.rubrica.secciones
                              .map((s) => _buildSeccionEditable(s)),

                          const SizedBox(height: 80),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isGuardando
          ? null
          : FloatingActionButton.extended(
              onPressed: _guardarCambios,
              backgroundColor: const Color(0xFF9C27B0),
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('Guardar cambios',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
    );
  }

  Widget _buildResumenProgreso() {
    final progreso = _totalCriterios > 0
        ? _criteriosCompletos / _totalCriterios
        : 0.0;

    return Card(
      elevation: 2,
      color: Colors.purple.shade50,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note,
                    color: Colors.purple.shade700, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Editando evaluación',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade900),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Criterios',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                      Text(
                          '$_criteriosCompletos / $_totalCriterios',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade800)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nota total',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                      Text(
                        '${_notaTotalActual.toStringAsFixed(1)} / ${widget.rubrica.puntajeMaximo.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                    progreso == 1.0 ? Colors.green : Colors.purple),
              ),
            ),
          ],
        ),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context)
            .copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.folder_open,
                color: Color(0xFF1E3A5F), size: 22),
          ),
          title: Text(seccion.nombre,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F))),
          subtitle: Text(
            '$evaluados/${seccion.criterios.length} criterios • ${puntajeSeccion.toStringAsFixed(1)}/${seccion.pesoTotal.toStringAsFixed(0)} pts',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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

    // Generar opciones de 0 a pesoMaximo en pasos de 0.5
    final List<double> opciones = [];
    double valor = 0;
    while (valor <= pesoMaximo) {
      opciones.add(valor);
      valor += 0.5;
    }
    if (opciones.isEmpty || opciones.last != pesoMaximo) {
      opciones.add(pesoMaximo);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: notaSeleccionada != null
            ? Colors.green.withOpacity(0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notaSeleccionada != null
              ? Colors.green.withOpacity(0.4)
              : Colors.grey.withOpacity(0.3),
          width: notaSeleccionada != null ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Descripción y peso máximo
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(criterio.descripcion,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                    'Máx: ${pesoMaximo.toStringAsFixed(1)} pts',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A5F))),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Nota actual
          if (notaSeleccionada != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.stars, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                    'Seleccionado: ${notaSeleccionada.toStringAsFixed(1)} pts',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.pending, size: 14, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text('Sin calificar',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700])),
              ]),
            ),

          // Selector: chips si pocas opciones, dropdown si muchas
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
      spacing: 8,
      runSpacing: 8,
      children: opciones.map((nota) {
        final isSelected = notaSeleccionada == nota;
        return InkWell(
          onTap: () =>
              setState(() => _notasEditadas[criterio.id] = nota),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF9C27B0)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF9C27B0)
                    : const Color(0xFF9C27B0).withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: const Color(0xFF9C27B0)
                              .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.check_circle,
                        color: Colors.white, size: 14),
                  ),
                Text(
                  nota.toStringAsFixed(
                      nota.truncateToDouble() == nota ? 0 : 1),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF9C27B0)),
                ),
              ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notaSeleccionada != null
              ? const Color(0xFF9C27B0)
              : const Color(0xFF9C27B0).withOpacity(0.3),
          width: notaSeleccionada != null ? 2 : 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          value: notaSeleccionada,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Selecciona una nota',
                style:
                    TextStyle(fontSize: 14, color: Colors.grey[600])),
          ),
          icon: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.arrow_drop_down,
                color: Color(0xFF9C27B0)),
          ),
          items: opciones.map((nota) {
            return DropdownMenuItem<double>(
              value: nota,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Text(
                  nota.toStringAsFixed(
                      nota.truncateToDouble() == nota ? 0 : 1),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3A5F)),
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _notasEditadas[criterio.id] = value);
            }
          },
        ),
      ),
    );
  }
}