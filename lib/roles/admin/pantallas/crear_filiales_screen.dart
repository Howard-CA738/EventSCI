import 'package:flutter/material.dart';
import '/shared/logica/filiales_service.dart';
import 'widgets/crear_filiales_widgets.dart';

class CrearFilialesScreen extends StatefulWidget {
  const CrearFilialesScreen({super.key});

  @override
  State<CrearFilialesScreen> createState() => _CrearFilialesScreenState();
}

class _CrearFilialesScreenState extends State<CrearFilialesScreen> {
  final FilialesService _filialesService = FilialesService();

  Map<String, dynamic> _estructura = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

    try {
      await _filialesService.inicializarSiEsNecesario();
      final estructura = await _filialesService.getEstructuraCompleta();
      setState(() {
        _estructura = estructura;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      setState(() => _isLoading = false);
      _showMessage('Error al cargar datos', isError: true);
    }
  }

  Future<void> _refrescarDatos() async {
    try {
      final estructura = await _filialesService.getEstructuraCompleta(
        forceRefresh: true,
      );
      setState(() {
        _estructura = estructura;
      });
      _showMessage('Datos actualizados');
    } catch (e) {
      debugPrint('Error refrescando datos: $e');
      _showMessage('Error al actualizar', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getFilialInitial(String nombre) {
    if (nombre.trim().isEmpty) return '?';
    final words = nombre.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return words.last[0].toUpperCase();
    }
    return nombre.trim()[0].toUpperCase();
  }

  Future<void> _mostrarDialogoAgregarCarrera({
    required String filialId,
    required String facultadId,
    required String facultadNombre,
  }) async {
    final TextEditingController controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => DialogoNombre(
        titulo: 'Agregar Nueva Carrera',
        subtitulo: 'Facultad: $facultadNombre',
        labelField: 'Nombre de la carrera',
        hintField: 'Ej: Ingeniería de Software',
        iconField: Icons.school,
        labelBoton: 'Agregar',
        controller: controller,
        formKey: formKey,
      ),
    );

    if (resultado == true && controller.text.trim().isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const LoadingDialog(mensaje: 'Agregando carrera...'),
      );

      final exito = await _filialesService.agregarCarrera(
        filialId: filialId,
        facultadId: facultadId,
        nombreCarrera: controller.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (exito) {
        _showMessage('Carrera agregada exitosamente');
        await _refrescarDatos();
      } else {
        _showMessage(
          'Error: La carrera ya existe o hubo un problema',
          isError: true,
        );
      }
    }
  }

  Future<void> _mostrarDialogoAgregarFacultad({
    required String filialId,
    required String filialNombre,
  }) async {
    final TextEditingController controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => DialogoNombre(
        titulo: 'Agregar Nueva Facultad',
        subtitulo: 'Filial: $filialNombre',
        labelField: 'Nombre de la facultad',
        hintField: 'Ej: Facultad de Ciencias Jurídicas',
        iconField: Icons.business,
        labelBoton: 'Agregar',
        controller: controller,
        formKey: formKey,
      ),
    );

    if (resultado == true && controller.text.trim().isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const LoadingDialog(mensaje: 'Agregando facultad...'),
      );

      final exito = await _filialesService.agregarFacultad(
        filialId: filialId,
        nombreFacultad: controller.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (exito) {
        _showMessage('Facultad agregada exitosamente');
        await _refrescarDatos();
      } else {
        _showMessage(
          'Error: La facultad ya existe o hubo un problema',
          isError: true,
        );
      }
    }
  }

  Future<void> _mostrarDialogoEditarFilial({
    required String filialId,
    required String nombreActual,
    required String ubicacionActual,
  }) async {
    final nombreController = TextEditingController(text: nombreActual);
    final ubicacionController = TextEditingController(text: ubicacionActual);
    final formKey = GlobalKey<FormState>();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => DialogoEditarFilial(
        nombreController: nombreController,
        ubicacionController: ubicacionController,
        formKey: formKey,
      ),
    );

    if (resultado == true) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const LoadingDialog(mensaje: 'Actualizando filial...'),
      );

      final exito = await _filialesService.editarFilial(
        filialId: filialId,
        nuevoNombre: nombreController.text.trim(),
        nuevaUbicacion: ubicacionController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (exito) {
        _showMessage('Filial actualizada exitosamente');
        await _refrescarDatos();
      } else {
        _showMessage('Error al actualizar la filial', isError: true);
      }
    }
  }

  Future<void> _mostrarDialogoEditarFacultad({
    required String filialId,
    required String facultadId,
    required String nombreActual,
  }) async {
    final controller = TextEditingController(text: nombreActual);
    final formKey = GlobalKey<FormState>();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => DialogoNombre(
        titulo: 'Editar Facultad',
        subtitulo: null,
        labelField: 'Nombre de la facultad',
        hintField: null,
        iconField: Icons.business,
        labelBoton: 'Guardar',
        controller: controller,
        formKey: formKey,
        isEditing: true,
      ),
    );

    if (resultado == true && controller.text.trim().isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const LoadingDialog(mensaje: 'Actualizando facultad...'),
      );

      final exito = await _filialesService.editarFacultad(
        filialId: filialId,
        facultadId: facultadId,
        nuevoNombre: controller.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (exito) {
        _showMessage('Facultad actualizada exitosamente');
        await _refrescarDatos();
      } else {
        _showMessage(
          'Error: El nombre ya existe o hubo un problema',
          isError: true,
        );
      }
    }
  }

  Future<void> _mostrarDialogoEditarCarrera({
    required String filialId,
    required String facultadId,
    required String carreraId,
    required String nombreActual,
  }) async {
    final controller = TextEditingController(text: nombreActual);
    final formKey = GlobalKey<FormState>();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => DialogoNombre(
        titulo: 'Editar Carrera',
        subtitulo: null,
        labelField: 'Nombre de la carrera',
        hintField: null,
        iconField: Icons.school,
        labelBoton: 'Guardar',
        controller: controller,
        formKey: formKey,
        isEditing: true,
      ),
    );

    if (resultado == true && controller.text.trim().isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const LoadingDialog(mensaje: 'Actualizando carrera...'),
      );

      final exito = await _filialesService.editarCarrera(
        filialId: filialId,
        facultadId: facultadId,
        carreraId: carreraId,
        nuevoNombre: controller.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (exito) {
        _showMessage('Carrera actualizada exitosamente');
        await _refrescarDatos();
      } else {
        _showMessage(
          'Error: La carrera ya existe o hubo un problema',
          isError: true,
        );
      }
    }
  }

  Future<void> _confirmarEliminarCarrera({
    required String filialId,
    required String facultadId,
    required String carreraId,
    required String carreraNombre,
  }) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => DialogoConfirmarEliminar(
        carreraNombre: carreraNombre,
      ),
    );

    if (confirmar == true) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const LoadingDialog(mensaje: 'Eliminando carrera...'),
      );

      final exito = await _filialesService.eliminarCarrera(
        filialId: filialId,
        facultadId: facultadId,
        carreraId: carreraId,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (exito) {
        _showMessage('Carrera eliminada exitosamente');
        await _refrescarDatos();
      } else {
        _showMessage('Error al eliminar la carrera', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Volver',
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Gestión de Carreras',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _refrescarDatos,
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Cargando estructura...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _estructura.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No se pudo cargar la estructura',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _cargarDatos,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Reintentar'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _refrescarDatos,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Carreras por Filial',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E3A5F),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.green.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.green
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 14,
                                              color: Colors.green[700],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Datos cargados',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.green[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ..._estructura.entries.map((filialEntry) {
                                    return _buildFilialCard(
                                      filialEntry.key,
                                      filialEntry.value,
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilialCard(String filialId, Map<String, dynamic> filialData) {
    final facultades =
        filialData['facultades'] as Map<String, dynamic>? ?? {};
    final nombreFilial = filialData['nombre']?.toString() ?? '';
    final ubicacion = filialData['ubicacion']?.toString() ?? '';

    int totalCarreras = 0;
    for (var facultad in facultades.values) {
      final carreras = facultad['carreras'];
      if (carreras is List) {
        totalCarreras += carreras.length;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: filialId == 'lima',
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF1E3A5F),
            child: Text(
              _getFilialInitial(nombreFilial),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            nombreFilial,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.place, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        ubicacion,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${facultades.length} facultades',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$totalCarreras carreras',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          trailing: SizedBox(
            width: 88,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  color: Colors.blueGrey,
                  tooltip: 'Editar filial',
                  onPressed: () => _mostrarDialogoEditarFilial(
                    filialId: filialId,
                    nombreActual: nombreFilial,
                    ubicacionActual: ubicacion,
                  ),
                ),
                ActionIconButton(
                  icon: Icons.add_circle,
                  color: const Color(0xFF1E3A5F),
                  tooltip: 'Agregar facultad',
                  onPressed: () => _mostrarDialogoAgregarFacultad(
                    filialId: filialId,
                    filialNombre: nombreFilial,
                  ),
                ),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  ...facultades.entries.map((facultadEntry) {
                    return _buildFacultadCard(
                      filialId,
                      facultadEntry.key,
                      facultadEntry.value,
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacultadCard(
    String filialId,
    String facultadNombre,
    Map<String, dynamic> facultadData,
  ) {
    final carreras = List<Map<String, dynamic>>.from(
      facultadData['carreras'] ?? [],
    );
    final facultadId = facultadData['id']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.business, color: Colors.blue, size: 20),
          ),
          title: Text(
            facultadNombre,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF1E3A5F),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${carreras.length} ${carreras.length == 1 ? 'carrera' : 'carreras'}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          trailing: SizedBox(
            width: 88,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  color: Colors.blueGrey,
                  tooltip: 'Editar facultad',
                  onPressed: () => _mostrarDialogoEditarFacultad(
                    filialId: filialId,
                    facultadId: facultadId,
                    nombreActual: facultadNombre,
                  ),
                ),
                ActionIconButton(
                  icon: Icons.add_circle,
                  color: const Color(0xFF1E3A5F),
                  tooltip: 'Agregar carrera',
                  onPressed: () => _mostrarDialogoAgregarCarrera(
                    filialId: filialId,
                    facultadId: facultadId,
                    facultadNombre: facultadNombre,
                  ),
                ),
              ],
            ),
          ),
          children: [
            if (carreras.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[700],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'No hay carreras en esta facultad',
                        style: TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: carreras.map((carrera) {
                  final carreraId = carrera['id']?.toString() ?? '';
                  final carreraNombre =
                      carrera['nombre']?.toString() ?? 'Sin nombre';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.only(
                      left: 12,
                      top: 6,
                      bottom: 6,
                      right: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E3A5F),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            carreraNombre,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        SizedBox(
                          width: 88,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ActionIconButton(
                                icon: Icons.edit_outlined,
                                color: Colors.blueGrey,
                                tooltip: 'Editar carrera',
                                onPressed: () => _mostrarDialogoEditarCarrera(
                                  filialId: filialId,
                                  facultadId: facultadId,
                                  carreraId: carreraId,
                                  nombreActual: carreraNombre,
                                ),
                              ),
                              ActionIconButton(
                                icon: Icons.delete_outline,
                                color: Colors.red,
                                tooltip: 'Eliminar carrera',
                                onPressed: () => _confirmarEliminarCarrera(
                                  filialId: filialId,
                                  facultadId: facultadId,
                                  carreraId: carreraId,
                                  carreraNombre: carreraNombre,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
