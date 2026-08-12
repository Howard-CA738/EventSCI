import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '/shared/logica/periodos_helper.dart';

class PeriodosScreen extends StatefulWidget {
  const PeriodosScreen({super.key});

  @override
  State<PeriodosScreen> createState() => _PeriodosScreenState();
}

class _PeriodosScreenState extends State<PeriodosScreen> {
  List<Map<String, dynamic>> _periodos = [];
  List<Map<String, dynamic>> _filteredPeriodos = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPeriodos();
  }

  Future<void> _loadPeriodos() async {
    setState(() => _isLoading = true);
    final periodos = await PeriodosHelper.getPeriodos();
    if (!mounted) return;
    setState(() {
      _periodos = periodos;
      _filteredPeriodos = periodos;
      _isLoading = false;
    });
  }

  void _filterPeriodos(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPeriodos = _periodos;
      } else {
        _filteredPeriodos = _periodos.where((periodo) {
          final nombre = periodo['nombre'].toString().toLowerCase();
          return nombre.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _showCreateDialog() {
    final nombreController = TextEditingController();
    DateTime? fechaInicio;
    DateTime? fechaFin;
    bool activo = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Crear Período',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nombreController,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del Período',
                            hintText: 'Ej: 2025-I',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DatePickerTile(
                          title: 'Fecha de Inicio',
                          date: fechaInicio,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setDialogState(() => fechaInicio = picked);
                            }
                          },
                        ),
                        _DatePickerTile(
                          title: 'Fecha de Fin',
                          date: fechaFin,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: fechaInicio ?? DateTime.now(),
                              firstDate: fechaInicio ?? DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setDialogState(() => fechaFin = picked);
                            }
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Período Activo',
                            style: TextStyle(fontSize: 14),
                          ),
                          subtitle: const Text(
                            'Solo puede haber un período activo',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: activo,
                          onChanged: (value) {
                            setDialogState(() => activo = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (nombreController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ingrese el nombre del período'),
                              ),
                            );
                            return;
                          }
                          if (fechaInicio == null || fechaFin == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Seleccione las fechas'),
                              ),
                            );
                            return;
                          }
                          if (fechaFin!.isBefore(fechaInicio!)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('La fecha de fin debe ser posterior'),
                              ),
                            );
                            return;
                          }

                          final success = await PeriodosHelper.createPeriodo(
                            nombre: nombreController.text,
                            fechaInicio: fechaInicio!,
                            fechaFin: fechaFin!,
                            activo: activo,
                          );

                          if (!context.mounted) return;

                          if (success) {
                            Navigator.pop(context);
                            _loadPeriodos();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Período creado exitosamente'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error al crear el período'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text('Crear'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> periodo) {
    final nombreController = TextEditingController(text: periodo['nombre']);
    DateTime? fechaInicio = (periodo['fechaInicio'] as Timestamp).toDate();
    DateTime? fechaFin = (periodo['fechaFin'] as Timestamp).toDate();
    bool activo = periodo['activo'] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Editar Período',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nombreController,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del Período',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DatePickerTile(
                          title: 'Fecha de Inicio',
                          date: fechaInicio,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: fechaInicio!,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setDialogState(() => fechaInicio = picked);
                            }
                          },
                        ),
                        _DatePickerTile(
                          title: 'Fecha de Fin',
                          date: fechaFin,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: fechaFin!,
                              firstDate: fechaInicio ?? DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setDialogState(() => fechaFin = picked);
                            }
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Período Activo',
                            style: TextStyle(fontSize: 14),
                          ),
                          subtitle: const Text(
                            'Solo puede haber un período activo',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: activo,
                          onChanged: (value) {
                            setDialogState(() => activo = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (nombreController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ingrese el nombre del período'),
                              ),
                            );
                            return;
                          }
                          if (fechaFin!.isBefore(fechaInicio!)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('La fecha de fin debe ser posterior'),
                              ),
                            );
                            return;
                          }

                          final success = await PeriodosHelper.updatePeriodo(
                            periodoId: periodo['id'],
                            nombre: nombreController.text,
                            fechaInicio: fechaInicio,
                            fechaFin: fechaFin,
                            activo: activo,
                          );

                          if (!context.mounted) return;

                          if (success) {
                            Navigator.pop(context);
                            _loadPeriodos();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Período actualizado exitosamente'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error al actualizar el período'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text('Guardar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> periodo) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Eliminar Período',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Está seguro que desea eliminar el período "${periodo['nombre']}"?',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final success = await PeriodosHelper.deletePeriodo(
                          periodo['id'],
                        );
                        if (!context.mounted) return;
                        if (success) {
                          Navigator.pop(context);
                          _loadPeriodos();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Período eliminado exitosamente'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error al eliminar el período'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Gestión de Períodos',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFE8EDF2),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _filterPeriodos,
                decoration: InputDecoration(
                  hintText: 'Buscar período...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterPeriodos('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredPeriodos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay períodos registrados',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: _filteredPeriodos.length,
                          itemBuilder: (context, index) {
                            final periodo = _filteredPeriodos[index];
                            final fechaInicio =
                                (periodo['fechaInicio'] as Timestamp).toDate();
                            final fechaFin =
                                (periodo['fechaFin'] as Timestamp).toDate();
                            final activo = periodo['activo'] ?? false;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: activo
                                    ? const BorderSide(
                                        color: Colors.green,
                                        width: 2,
                                      )
                                    : BorderSide.none,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                minVerticalPadding: 0,
                                leading: CircleAvatar(
                                  backgroundColor: activo
                                      ? Colors.green
                                      : const Color(0xFF1E3A5F),
                                  child: Icon(
                                    activo
                                        ? Icons.check_circle
                                        : Icons.calendar_month,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  periodo['nombre'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Inicio: ${DateFormat('dd/MM/yyyy').format(fechaInicio)}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    Text(
                                      'Fin: ${DateFormat('dd/MM/yyyy').format(fechaFin)}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    if (activo)
                                      Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'PERÍODO ACTIVO',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: _PeriodoMenuButton(
                                  activo: activo,
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      _showEditDialog(periodo);
                                    } else if (value == 'delete') {
                                      _showDeleteDialog(periodo);
                                    } else if (value == 'activate') {
                                      final success =
                                          await PeriodosHelper.activarPeriodo(
                                        periodo['id'],
                                      );
                                      if (!mounted) return;
                                      if (success) {
                                        _loadPeriodos();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Período activado exitosamente',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } else if (value == 'deactivate') {
                                      final success =
                                          await PeriodosHelper.desactivarPeriodo(
                                        periodo['id'],
                                      );
                                      if (!mounted) return;
                                      if (success) {
                                        _loadPeriodos();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Período desactivado exitosamente',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: const Color(0xFF1E3A5F),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Período'),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _DatePickerTile extends StatelessWidget {
  final String title;
  final DateTime? date;
  final VoidCallback onTap;

  const _DatePickerTile({
    required this.title,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date != null
                        ? DateFormat('dd/MM/yyyy').format(date!)
                        : 'Seleccionar fecha',
                    style: TextStyle(
                      fontSize: 14,
                      color: date != null ? Colors.black87 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.calendar_today, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PeriodoMenuButton extends StatelessWidget {
  final bool activo;
  final Future<void> Function(String) onSelected;

  const _PeriodoMenuButton({
    required this.activo,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 20),
              SizedBox(width: 8),
              Text('Editar'),
            ],
          ),
        ),
        if (!activo)
          const PopupMenuItem(
            value: 'activate',
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 20),
                SizedBox(width: 8),
                Text('Activar'),
              ],
            ),
          ),
        if (activo)
          const PopupMenuItem(
            value: 'deactivate',
            child: Row(
              children: [
                Icon(Icons.cancel, size: 20),
                SizedBox(width: 8),
                Text('Desactivar'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 20, color: Colors.red),
              SizedBox(width: 8),
              Text('Eliminar', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }
}
