import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/logica/generar_qr.dart';
import 'proyectos_categoria_screen.dart';

class GenerarQRScreen extends StatefulWidget {
  final VoidCallback? logoutCallback;

  const GenerarQRScreen({super.key, this.logoutCallback});

  @override
  State<GenerarQRScreen> createState() => _GenerarQRScreenState();
}

class _GenerarQRScreenState extends State<GenerarQRScreen>
    with TickerProviderStateMixin {
  final GenerarQRController _controller = GenerarQRController();

  String? _selectedFacultad;
  String? _selectedCarrera;
  String? _selectedEventId;
  String? _selectedEventName;
  bool _isLoadingEvents = false;
  bool _isLoadingCategorias = false;

  List<QueryDocumentSnapshot> _eventos = [];
  List<String> _categorias = [];

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _buscarEventos() async {
    if (_selectedFacultad == null) {
      _showSnackBar('Selecciona una facultad primero', isError: true);
      return;
    }

    if (_controller.requiereCarrera(_selectedFacultad) &&
        _selectedCarrera == null) {
      _showSnackBar('Selecciona una carrera primero', isError: true);
      return;
    }

    setState(() {
      _isLoadingEvents = true;
      _selectedEventId = null;
      _selectedEventName = null;
      _categorias.clear();
    });

    try {
      final eventos = await _controller.buscarEventos(
        facultad: _selectedFacultad!,
        carrera: _selectedCarrera,
      );

      if (!mounted) return;

      setState(() {
        _eventos = eventos;
      });

      if (_eventos.isEmpty) {
        _showSnackBar('No se encontraron eventos para esta selección');
      } else {
        _showSnackBar('Se encontraron ${_eventos.length} evento(s)');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error al buscar eventos: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingEvents = false;
        });
      }
    }
  }

  Future<void> _cargarCategorias() async {
    if (_selectedEventId == null) return;

    setState(() {
      _isLoadingCategorias = true;
      _categorias.clear();
    });

    try {
      final categorias =
          await _controller.cargarCategorias(_selectedEventId!);

      if (!mounted) return;

      setState(() {
        _categorias = categorias;
      });

      if (_categorias.isEmpty) {
        _showSnackBar(
          'No se encontraron categorías en este evento. Asegúrate de haber importado proyectos primero.',
          isError: true,
        );
      } else {
        _showSnackBar('Se encontraron ${_categorias.length} categoría(s)');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error al cargar categorías: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategorias = false;
        });
      }
    }
  }

  void _navegarAProyectosCategoria(String categoria) {
    if (_selectedEventId == null) {
      _showSnackBar('Selecciona un evento primero', isError: true);
      return;
    }

    final eventName = _selectedEventName ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProyectosCategoriaScreen(
          eventId: _selectedEventId!,
          eventName: eventName,
          facultad: _selectedFacultad!,
          carrera: _selectedCarrera ?? 'General',
          categoria: categoria,
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red.shade600 : Colors.green.shade600,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _mostrarDialogoCerrarSesion() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: Colors.red.shade600,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '¿Cerrar Sesión?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '¿Estás seguro de que deseas cerrar tu sesión?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.logoutCallback?.call();
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cerrar Sesión',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EFF5),
      appBar: AppBar(
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_scanner, size: 24),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'Panel de Asistente',
                style: TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        actions: [
          if (widget.logoutCallback != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                label: 'Cerrar Sesión',
                button: true,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.logout_rounded, size: 20),
                  ),
                  onPressed: _mostrarDialogoCerrarSesion,
                  tooltip: 'Cerrar Sesión',
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStepCard(
                  step: '1',
                  title: 'Seleccionar Facultad y Carrera',
                  icon: Icons.school_rounded,
                  color: const Color(0xFF1E3A5F),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCustomDropdown(
                        value: _selectedFacultad,
                        label: 'Facultad',
                        icon: Icons.apartment_rounded,
                        items: _controller.facultadesCarreras.keys.toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedFacultad = newValue;
                            _selectedCarrera = null;
                            _selectedEventId = null;
                            _selectedEventName = null;
                            _eventos.clear();
                            _categorias.clear();
                          });
                        },
                      ),
                      if (_controller
                          .requiereCarrera(_selectedFacultad)) ...[
                        const SizedBox(height: 16),
                        _buildCustomDropdown(
                          value: _selectedCarrera,
                          label: 'Escuela Profesional',
                          icon: Icons.menu_book_rounded,
                          items: _selectedFacultad != null
                              ? _controller.obtenerCarrerasPorFacultad(
                                  _selectedFacultad!,
                                )
                              : [],
                          onChanged: _selectedFacultad != null
                              ? (String? newValue) {
                                  setState(() {
                                    _selectedCarrera = newValue;
                                    _selectedEventId = null;
                                    _selectedEventName = null;
                                    _eventos.clear();
                                    _categorias.clear();
                                  });
                                }
                              : null,
                        ),
                      ],
                      if (_selectedFacultad ==
                          'Universidad Peruana Unión')
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF2196F3)),
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Eventos generales de la universidad',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      _buildAnimatedButton(
                        onPressed: _selectedFacultad != null &&
                                (_selectedCarrera != null ||
                                    !_controller.requiereCarrera(
                                      _selectedFacultad,
                                    ))
                            ? _buscarEventos
                            : null,
                        isLoading: _isLoadingEvents,
                        label: 'Buscar Eventos',
                        icon: Icons.search_rounded,
                        color: const Color(0xFF1E3A5F),
                      ),
                    ],
                  ),
                ),
                if (_eventos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildStepCard(
                    step: '2',
                    title: 'Seleccionar Evento',
                    icon: Icons.event_rounded,
                    color: const Color(0xFF2A4A6F),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildEventDropdown(),
                        if (_selectedEventName != null) ...[
                          const SizedBox(height: 16),
                          _buildInfoCard(
                            title: 'Evento seleccionado',
                            content: _selectedEventName!,
                            color: Colors.blue,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (_selectedEventId != null) ...[
                  const SizedBox(height: 16),
                  _buildStepCard(
                    step: '3',
                    title: 'Seleccionar Categoría',
                    icon: Icons.category_rounded,
                    color: const Color(0xFF365A7F),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isLoadingCategorias) ...[
                          const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF1E3A5F),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Cargando categorías...',
                            textAlign: TextAlign.center,
                          ),
                        ] else if (_categorias.isNotEmpty) ...[
                          _buildInfoCard(
                            title: 'Categorías encontradas',
                            content:
                                'Se encontraron ${_categorias.length} categorías. Selecciona una para ver sus proyectos.',
                            color: Colors.green,
                            icon: Icons.info_outline_rounded,
                          ),
                          const SizedBox(height: 16),
                          ..._categorias.asMap().entries.map((entry) {
                            final index = entry.key;
                            final categoria = entry.value;
                            return TweenAnimationBuilder<double>(
                              duration: Duration(
                                milliseconds: 300 + (index * 50),
                              ),
                              tween: Tween<double>(begin: 0, end: 1),
                              builder:
                                  (context, double value, child) {
                                return Transform.translate(
                                  offset:
                                      Offset(0, 20 * (1 - value)),
                                  child: Opacity(
                                    opacity: value,
                                    child: child,
                                  ),
                                );
                              },
                              child: _buildCategoriaCard(categoria),
                            );
                          }),
                        ] else ...[
                          _buildEmptyState(
                            icon: Icons.warning_amber_rounded,
                            title: 'No se encontraron categorías',
                            subtitle:
                                'Asegúrate de haber importado proyectos para este evento',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String step,
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paso $step',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: color.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildCustomDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required void Function(String?)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E7ED)),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        menuMaxHeight: 300,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF1E3A5F)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          );
        }).toList(),
        onChanged: onChanged,
        dropdownColor: Colors.white,
      ),
    );
  }

 Widget _buildEventDropdown() {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF5F8FA),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE0E7ED)),
    ),
    child: DropdownButtonFormField<String>(
      initialValue: _selectedEventId,
      isExpanded: true,
      menuMaxHeight: 300,
      decoration: const InputDecoration(
        labelText: 'Evento',
        labelStyle: TextStyle(color: Color(0xFF1E3A5F)),
        border: InputBorder.none,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        prefixIcon: Icon(
          Icons.event_note_rounded,
          color: Color(0xFF1E3A5F),
        ),
      ),
      items: _eventos.map((evento) {

        final data = evento.data() as Map<String, dynamic>? ?? {};
        return DropdownMenuItem<String>(
          value: evento.id,
          child: Text(
            data['name'] as String? ?? 'Sin nombre',
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedEventId = newValue;
          if (newValue != null) {
            final match = _eventos.where((e) => e.id == newValue);
            if (match.isNotEmpty) {

              final eventoData =
                  match.first.data() as Map<String, dynamic>? ?? {};
              _selectedEventName =
                  eventoData['name'] as String? ?? 'Sin nombre';
            }
          }
          _categorias.clear();
        });
        if (newValue != null) {
          _cargarCategorias();
        }
      },
      dropdownColor: Colors.white,
    ),
  );
}

  Widget _buildAnimatedButton({
    required VoidCallback? onPressed,
    required String label,
    required IconData icon,
    required Color color,
    bool isLoading = false,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          isLoading ? 'Cargando...' : label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required MaterialColor color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color[700], size: 24),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(fontSize: 13, color: color[900]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriaCard(String categoria) {
    return Semantics(
      label: 'Categoría: $categoria. Toca para ver proyectos.',
      button: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE0E7ED),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navegarAProyectosCategoria(categoria),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.folder_rounded,
                      color: Color(0xFF1E3A5F),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      categoria,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF1E3A5F),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.orange.shade600, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A5F),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}