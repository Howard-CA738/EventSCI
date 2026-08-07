import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/shared/logica/eventos_service.dart';
import '/shared/logica/periodos_helper.dart';
import 'dart:async';
import 'eventos_detalles_screen.dart';

class ListaEventosScreen extends StatefulWidget {
  const ListaEventosScreen({super.key});

  @override
  State<ListaEventosScreen> createState() => _ListaEventosScreenState();
}

class _ListaEventosScreenState extends State<ListaEventosScreen>
    with SingleTickerProviderStateMixin {
  final EventosService _eventosService = EventosService();

  String? _filtroFilialId;
  String? _filtroFacultad;
  String? _filtroCarreraId;
  String? _filtroPeriodo;

  List<Map<String, String>> _filiales = [];
  List<String> _facultades = [];
  List<Map<String, dynamic>> _carreras = [];
  final List<Map<String, dynamic>> _periodos = [];

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    unawaited(_animationController.forward());
    _startLoadFilterData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startLoadFilterData() {
    _loadFilterData().ignore();
  }

  Future<void> _loadFilterData() async {
    try {
      final results = await Future.wait([
        _eventosService.getFiliales(),
        PeriodosHelper.getPeriodosActivos(),
      ]);

      if (!mounted) return;

      setState(() {
        _filiales = results[0] as List<Map<String, String>>;
      });
    } catch (e) {
      debugPrint('Error cargando datos de filtros: $e');
    }
  }

  Future<void> _loadFacultadesForFilter(String filialId) async {
    try {
      final facultades = await _eventosService.getFacultadesByFilial(filialId);
      if (!mounted) return;
      setState(() {
        _facultades = facultades;
        _filtroFacultad = null;
        _filtroCarreraId = null;
        _carreras = [];
      });
    } catch (e) {
      debugPrint('Error cargando facultades: $e');
    }
  }

  Future<void> _loadCarrerasForFilter(
    String filialId,
    String facultadNombre,
  ) async {
    try {
      final carreras = await _eventosService.getCarrerasByFacultad(
        filialId,
        facultadNombre,
      );
      if (!mounted) return;
      setState(() {
        _carreras = carreras;
        _filtroCarreraId = null;
      });
    } catch (e) {
      debugPrint('Error cargando carreras: $e');
    }
  }

  void _navigateToEventDetails(
      String eventId, Map<String, dynamic> eventData) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            EventosDetallesScreen(eventId: eventId, eventData: eventData),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _editEvent(
    String eventId,
    Map<String, dynamic> eventData,
  ) async {
    final TextEditingController editNameController = TextEditingController(
      text: eventData['name'] as String? ?? '',
    );
    String? editFilialId = eventData['filialId'] as String?;
    String? editFilialNombre = eventData['filialNombre'] as String?;
    String? editFacultad = eventData['facultad'] as String?;
    String? editCarreraId = eventData['carreraId'] as String?;
    String? editCarreraNombre = eventData['carreraNombre'] as String?;

    List<String> editFacultades = [];
    List<Map<String, dynamic>> editCarreras = [];

    if (editFilialId != null) {
      editFacultades =
          await _eventosService.getFacultadesByFilial(editFilialId);
      if (editFacultad != null) {
        editCarreras = await _eventosService.getCarrerasByFacultad(
          editFilialId,
          editFacultad,
        );
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: Color(0xFF1E3A5F)),
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  'Editar Evento',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.55,
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: editNameController,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Nombre del evento',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.event),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: editFilialId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Filial',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.location_city),
                    ),
                    items: _filiales.map((filial) {
                      return DropdownMenuItem<String>(
                        value: filial['id'],
                        child: Text(
                          '${filial['nombre']} - ${filial['ubicacion']}',
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) async {
                      if (newValue != null) {
                        final filial = _filiales.firstWhere(
                          (f) => f['id'] == newValue,
                        );
                        final nuevasFacultades = await _eventosService
                            .getFacultadesByFilial(newValue);
                        setDialogState(() {
                          editFilialId = newValue;
                          editFilialNombre = filial['nombre'];
                          editFacultades = nuevasFacultades;
                          editFacultad = null;
                          editCarreraId = null;
                          editCarreraNombre = null;
                          editCarreras = [];
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: editFacultad,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Facultad',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.school),
                    ),
                    items: editFacultades.map((String facultad) {
                      return DropdownMenuItem<String>(
                        value: facultad,
                        child: Text(
                          facultad,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: editFilialId != null
                        ? (String? newValue) async {
                            if (newValue != null) {
                              final nuevasCarreras =
                                  await _eventosService.getCarrerasByFacultad(
                                editFilialId!,
                                newValue,
                              );
                              setDialogState(() {
                                editFacultad = newValue;
                                editCarreras = nuevasCarreras;
                                editCarreraId = null;
                                editCarreraNombre = null;
                              });
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: editCarreraId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Carrera',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.book),
                    ),
                    items: editCarreras.map((carrera) {
                      return DropdownMenuItem<String>(
                        value: carrera['id'] as String?,
                        child: Text(
                          (carrera['nombre'] as String?) ?? '',
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: editFacultad != null
                        ? (String? newValue) {
                            if (newValue != null) {
                              final carrera = editCarreras.firstWhere(
                                (c) => c['id'] == newValue,
                              );
                              setDialogState(() {
                                editCarreraId = newValue;
                                editCarreraNombre =
                                    carrera['nombre'] as String?;
                              });
                            }
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

onPressed: () async {
  final nameError = _eventosService.validateEventName(
    editNameController.text,
  );
  if (nameError != null) {
    if (mounted) _showSnackBar(nameError, isError: true);
    return;
  }

  final filialError = _eventosService.validateFilial(editFilialId);
  if (filialError != null) {
    if (mounted) _showSnackBar(filialError, isError: true);
    return;
  }

if ((editFilialNombre?.trim() ?? '').isEmpty) {
  if (mounted) _showSnackBar('Selecciona una filial válida', isError: true);
  return;
}

  final facultadError = _eventosService.validateFacultad(editFacultad);
  if (facultadError != null) {
    if (mounted) _showSnackBar(facultadError, isError: true);
    return;
  }

  final carreraError = _eventosService.validateCarrera(editCarreraId);
  if (carreraError != null) {
    if (mounted) _showSnackBar(carreraError, isError: true);
    return;
  }

 if ((editCarreraNombre?.trim() ?? '').isEmpty) {
  if (mounted) _showSnackBar('Selecciona una carrera válida', isError: true);
  return;
}

final filialNombreSeguro = editFilialNombre ?? '';
final carreraNombreSeguro = editCarreraNombre ?? '';
final filialIdSeguro = editFilialId ?? '';
final facultadSegura = editFacultad ?? '';
final carreraIdSegura = editCarreraId ?? '';

try {
  await _eventosService.updateEvent(
    eventId: eventId,
    name: editNameController.text.trim(),
    filialId: filialIdSeguro,
    filialNombre: filialNombreSeguro,
    facultad: facultadSegura,
    carreraId: carreraIdSegura,
    carreraNombre: carreraNombreSeguro,
  );

    if (!dialogContext.mounted) return;
    Navigator.pop(dialogContext);
    if (mounted) _showSnackBar('Evento actualizado exitosamente');
  } catch (e) {
    if (mounted) {
      _showSnackBar('Error al actualizar evento: $e', isError: true);
    }
  }
},
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEvent(String eventId, String eventName) async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'Eliminar Evento',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar "$eventName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              try {
                await _eventosService.deleteEvent(eventId);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (mounted) _showSnackBar('Evento eliminado exitosamente');
              } catch (e) {
                if (mounted) {
                  _showSnackBar(
                    'Error al eliminar evento: $e',
                    isError: true,
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFE53935)
            : const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EAF6),
      appBar: AppBar(
        title: const Text(
          'Todos los Eventos',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.white, Color(0xFFF5F7FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.filter_list,
                          color: Color(0xFF1E3A5F),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Filtros',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      const Spacer(),
                      if (_filtroFilialId != null ||
                          _filtroFacultad != null ||
                          _filtroCarreraId != null ||
                          _filtroPeriodo != null)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _filtroFilialId = null;
                              _filtroFacultad = null;
                              _filtroCarreraId = null;
                              _filtroPeriodo = null;
                              _facultades = [];
                              _carreras = [];
                            });
                          },
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Limpiar'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFE53935),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: _filtroFilialId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Filial',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      prefixIcon: const Icon(Icons.location_city),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Todas'),
                      ),
                      ..._filiales.map((filial) {
                        return DropdownMenuItem<String>(
                          value: filial['id'],
                          child: Text(
                            '${filial['nombre']} - ${filial['ubicacion']}',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }),
                    ],
                    onChanged: (String? newValue) {
                      setState(() {
                        _filtroFilialId = newValue;
                        _filtroFacultad = null;
                        _filtroCarreraId = null;
                        _facultades = [];
                        _carreras = [];
                      });
                      if (newValue != null) {
                        _loadFacultadesForFilter(newValue);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: _filtroFacultad,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Facultad',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      prefixIcon: const Icon(Icons.school),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Todas'),
                      ),
                      ..._facultades.map((String facultad) {
                        return DropdownMenuItem<String>(
                          value: facultad,
                          child: Text(
                            facultad,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }),
                    ],
                    onChanged: _filtroFilialId != null
                        ? (String? newValue) {
                            setState(() {
                              _filtroFacultad = newValue;
                              _filtroCarreraId = null;
                              _carreras = [];
                            });
                            if (newValue != null && _filtroFilialId != null) {
                              _loadCarrerasForFilter(
                                  _filtroFilialId!, newValue);
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: _filtroCarreraId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Carrera',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      prefixIcon: const Icon(Icons.book),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Todas'),
                      ),
                      ..._carreras.map((carrera) {
                        return DropdownMenuItem<String>(
                          value: carrera['id'] as String?,
                          child: Text(
                            (carrera['nombre'] as String?) ?? '',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }),
                    ],
                    onChanged: _filtroFacultad != null
                        ? (String? newValue) {
                            setState(() => _filtroCarreraId = newValue);
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: _filtroPeriodo,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Período Académico',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      prefixIcon: const Icon(Icons.calendar_month),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      ..._periodos.map((periodo) {
                        return DropdownMenuItem<String>(
                          value: periodo['id'] as String?,
                          child: Text(
                            (periodo['nombre'] as String?) ?? '',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }),
                    ],
                    onChanged: (String? newValue) {
                      setState(() => _filtroPeriodo = newValue);
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _eventosService.getEventsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF1E3A5F)),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  var events = snapshot.data?.docs ?? [];

                  events =
                      _eventosService.filterByFilial(events, _filtroFilialId);
                  events = _eventosService.filterByFacultad(
                      events, _filtroFacultad);
                  events = _eventosService.filterByCarrera(
                      events, _filtroCarreraId);
                  events =
                      _eventosService.filterByPeriodo(events, _filtroPeriodo);

                  if (events.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.event_busy,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _filtroFilialId != null ||
                                      _filtroFacultad != null ||
                                      _filtroCarreraId != null ||
                                      _filtroPeriodo != null
                                  ? 'No hay eventos con estos filtros'
                                  : 'No hay eventos creados',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final totalEvents = events.length;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: totalEvents,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final eventData =
                          event.data() as Map<String, dynamic>;
                      final eventName =
                          (eventData['name'] as String?) ?? 'Sin nombre';
                      final filialNombre =
                          (eventData['filialNombre'] as String?) ??
                              'Sin filial';
                      final carreraNombre =
                          (eventData['carreraNombre'] as String?) ??
                              'Sin carrera';
                      final eventId = event.id;

                      final double intervalStart =
                          totalEvents > 1 ? (index / totalEvents) * 0.5 : 0.0;
                      final double intervalEnd = totalEvents > 1
                          ? ((index + 1) / totalEvents) * 0.5 + 0.5
                          : 1.0;

                      return FadeTransition(
                        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(
                              intervalStart.clamp(0.0, 1.0),
                              intervalEnd.clamp(0.0, 1.0),
                              curve: Curves.easeOut,
                            ),
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.white, Color(0xFFFAFAFA)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E3A5F)
                                    .withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _navigateToEventDetails(
                                  eventId, eventData),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF1E3A5F),
                                            Color(0xFF2E5A8F),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF1E3A5F)
                                                .withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          eventName.isNotEmpty
                                              ? eventName
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            eventName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: Color(0xFF1E3A5F),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  const Color(0xFF43A047)
                                                      .withValues(alpha: 0.15),
                                                  const Color(0xFF66BB6A)
                                                      .withValues(alpha: 0.15),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: const Color(0xFF43A047)
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              carreraNombre,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF2E7D32),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              ExcludeSemantics(
                                                child: Icon(
                                                  Icons.location_city,
                                                  size: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  filialNombre,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[700],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (eventData['fecha'] != null ||
                                              (eventData['lugar'] != null &&
                                                  eventData['lugar'] != ''))
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  top: 6),
                                              child: Row(
                                                children: [
                                                  if (eventData['fecha'] !=
                                                      null) ...[
                                                    ExcludeSemantics(
                                                      child: Icon(
                                                        Icons.calendar_today,
                                                        size: 12,
                                                        color: Colors
                                                            .blue.shade600,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      _eventosService.formatDate(
                                                        (eventData['fecha']
                                                                as Timestamp)
                                                            .toDate(),
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors
                                                            .blue.shade700,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                  if (eventData['fecha'] !=
                                                          null &&
                                                      eventData['lugar'] !=
                                                          null &&
                                                      eventData['lugar'] != '')
                                                    const Text(
                                                      ' • ',
                                                      style: TextStyle(
                                                          fontSize: 10),
                                                    ),
                                                  if (eventData['lugar'] !=
                                                          null &&
                                                      eventData['lugar'] !=
                                                          '') ...[
                                                    ExcludeSemantics(
                                                      child: Icon(
                                                        Icons.location_on,
                                                        size: 12,
                                                        color: Colors
                                                            .orange.shade600,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        eventData['lugar']
                                                            as String,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors
                                                              .orange.shade700,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Semantics(
                                      label: 'Opciones para $eventName',
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: PopupMenuButton<String>(
                                          icon: const Icon(
                                            Icons.more_vert,
                                            color: Color(0xFF1E3A5F),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          onSelected: (value) {
                                            switch (value) {
                                              case 'details':
                                                _navigateToEventDetails(
                                                    eventId, eventData);
                                                break;
                                              case 'edit':
                                                _editEvent(eventId, eventData);
                                                break;
                                              case 'delete':
                                                _deleteEvent(
                                                    eventId, eventName);
                                                break;
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: 'details',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.visibility,
                                                    color: Color(0xFF43A047),
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 12),
                                                  Text('Ver Detalles'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.edit,
                                                    color: Color(0xFF1E88E5),
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 12),
                                                  Text('Editar'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.delete,
                                                    color: Color(0xFFE53935),
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 12),
                                                  Text('Eliminar'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
