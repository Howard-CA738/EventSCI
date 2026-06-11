import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/admin/logica/grupos.dart';

// ═══════════════════════════════════════════════════════════════════
// PALETA — alineada con la pantalla de Evaluación Final
// ═══════════════════════════════════════════════════════════════════
class _C {
  static const navy    = Color(0xFF0F2342);
  static const accent  = Color(0xFF3B82F6);
  static const teal    = Color(0xFF0F9D58);
  static const tealL   = Color(0xFFD7F5E6);
  static const surface = Color(0xFFF8FAFC);
  static const card    = Colors.white;
  static const border  = Color(0xFFE2E8F0);
  static const txt1    = Color(0xFF0F172A);
  static const txt2    = Color(0xFF475569);
  static const txt3    = Color(0xFF94A3B8);
  static const red     = Color(0xFFDC2626);
}

class AgregarProyectoScreen extends StatefulWidget {
  final Map<String, dynamic> eventData;
  final GruposService gruposService;
  final VoidCallback onProyectoAgregado;

  const AgregarProyectoScreen({
    super.key,
    required this.eventData,
    required this.gruposService,
    required this.onProyectoAgregado,
  });

  @override
  State<AgregarProyectoScreen> createState() => _AgregarProyectoScreenState();
}

class _AgregarProyectoScreenState extends State<AgregarProyectoScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _codigoController = TextEditingController();
  final _tituloController = TextEditingController();
  final _integrantesController = TextEditingController();
  final _clasificacionController = TextEditingController();
  final _salaController = TextEditingController();

  bool _isLoading = false;

  // Clasificaciones reales tomadas de los proyectos ya importados del evento.
  List<String> _clasificacionesExistentes = [];
  bool _cargandoClasificaciones = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _categoriasSugeridas = [
    'INGENIERÍA Y TECNOLOGÍA',
    'CIENCIAS SOCIALES',
    'CIENCIAS DE LA SALUD',
    'CIENCIAS NATURALES',
    'CIENCIAS AGRÍCOLAS',
    'HUMANIDADES',
    'EDUCACIÓN',
    'ARQUITECTURA Y URBANISMO',
    'ECONOMÍA Y NEGOCIOS',
    'ARTE Y DISEÑO',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
    _cargarClasificaciones();
  }

  // ── Cargar clasificaciones reales del evento ────────────────────────
  Future<void> _cargarClasificaciones() async {
    try {
      final proyectos = await widget.gruposService
          .cargarProyectosExistentes(widget.eventData['id']);
      if (!mounted) return;

      final set = <String>{};
      for (final p in proyectos) {
        final c = p['Clasificación']?.toString().trim() ?? '';
        if (c.isNotEmpty) set.add(c);
      }

      setState(() {
        _clasificacionesExistentes = set.toList()..sort();
        _cargandoClasificaciones = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoClasificaciones = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _codigoController.dispose();
    _tituloController.dispose();
    _integrantesController.dispose();
    _clasificacionController.dispose();
    _salaController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _C.navy,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: KeyboardDismissOnScroll(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.only(
                            left: 20.0,
                            right: 20.0,
                            top: 22.0,
                            bottom:
                                MediaQuery.of(context).viewInsets.bottom + 32.0,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildEventCard(),
                                const SizedBox(height: 22),
                                _buildFormCard(),
                                const SizedBox(height: 22),
                                _buildActionButtons(),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header navy (estilo Evaluación Final) ───────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 14),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Regresar',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Agregar Proyecto',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta del evento (degradado navy→teal) ────────────────────────
  Widget _buildEventCard() {
    final eventName =
        (widget.eventData['name'] as String? ?? 'Evento').trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.navy, _C.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _C.navy.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.add_box_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Nuevo Proyecto',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  eventName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _C.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_document,
                      color: _C.teal, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Información del Proyecto',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _C.navy,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _buildTextField(
              controller: _codigoController,
              label: 'Código del Proyecto',
              icon: Icons.qr_code,
              hint: 'Ej: P001, INV-2024-001',
              isRequired: true,
            ),
            const SizedBox(height: 18),
            _buildTextField(
              controller: _tituloController,
              label: 'Título del Proyecto',
              icon: Icons.title,
              hint: 'Ingrese el título completo',
              maxLines: 3,
              isRequired: true,
              alignLabelWithHint: true,
            ),
            const SizedBox(height: 18),
            _buildTextField(
              controller: _integrantesController,
              label: 'Integrantes',
              icon: Icons.people,
              hint: 'Nombres separados por comas',
              maxLines: 3,
              isRequired: true,
              alignLabelWithHint: true,
            ),
            const SizedBox(height: 18),
            _buildClasificacionField(),
            const SizedBox(height: 18),
            _buildTextField(
              controller: _salaController,
              label: 'Sala (Opcional)',
              icon: Icons.meeting_room,
              hint: 'Ej: Sala A, Auditorio 1',
              isRequired: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    int maxLines = 1,
    bool isRequired = false,
    bool alignLabelWithHint = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _C.txt2,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(color: _C.red, fontSize: 14),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, color: _C.txt1),
          textInputAction:
              maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _C.txt3, fontSize: 13),
            alignLabelWithHint: alignLabelWithHint,
            prefixIcon: Padding(
              padding: maxLines > 1
                  ? const EdgeInsets.only(bottom: 0)
                  : EdgeInsets.zero,
              child: Icon(icon, color: _C.teal, size: 20),
            ),
            prefixIconConstraints: maxLines > 1
                ? const BoxConstraints(minWidth: 48, minHeight: 48)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.teal, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.red, width: 2),
            ),
            filled: true,
            fillColor: _C.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Este campo es obligatorio';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildClasificacionField() {
    // Si el evento ya tiene proyectos importados, mostramos SUS clasificaciones.
    // Si está vacío (sin importaciones aún), usamos las sugeridas como semilla.
    final List<String> opciones = _clasificacionesExistentes.isNotEmpty
        ? _clasificacionesExistentes
        : _categoriasSugeridas;
    final bool usandoExistentes = _clasificacionesExistentes.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Clasificación',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _C.txt2,
              ),
            ),
            SizedBox(width: 4),
            Text('*', style: TextStyle(color: _C.red, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _clasificacionController,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 14, color: _C.txt1),
          decoration: InputDecoration(
            hintText: 'Seleccione o escriba una categoría',
            hintStyle: const TextStyle(color: _C.txt3, fontSize: 13),
            prefixIcon: const Icon(Icons.category, color: _C.teal, size: 20),
            suffixIcon: _cargandoClasificaciones
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_C.teal),
                      ),
                    ),
                  )
                : opciones.isEmpty
                    ? null
                    : PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down,
                            color: _C.teal),
                        tooltip: 'Seleccionar categoría',
                        constraints: const BoxConstraints(
                            minWidth: 44, minHeight: 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        onSelected: (String value) {
                          setState(() {
                            _clasificacionController.text = value;
                          });
                        },
                        itemBuilder: (BuildContext context) {
                          return opciones.map((String categoria) {
                            return PopupMenuItem<String>(
                              value: categoria,
                              child: Text(
                                categoria,
                                style: const TextStyle(
                                    fontSize: 13, color: _C.txt1),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            );
                          }).toList();
                        },
                      ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.teal, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.red, width: 2),
            ),
            filled: true,
            fillColor: _C.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Este campo es obligatorio';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        // Etiqueta de contexto: deja claro de dónde salen las opciones.
        if (!_cargandoClasificaciones)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 4),
            child: Text(
              usandoExistentes
                  ? 'Clasificaciones del evento · también puedes escribir una nueva'
                  : 'Sin proyectos aún · escribe la clasificación o usa una sugerencia',
              style: const TextStyle(fontSize: 11, color: _C.txt3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (!_cargandoClasificaciones && opciones.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: opciones.take(6).map((categoria) {
              return InkWell(
                onTap: () {
                  setState(() {
                    _clasificacionController.text = categoria;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _C.tealL,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _C.teal.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    categoria,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _C.teal,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 320;

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSaveButton(),
              const SizedBox(height: 12),
              _buildClearButton(),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _buildClearButton()),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _buildSaveButton()),
          ],
        );
      },
    );
  }

  Widget _buildClearButton() {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : _limpiarFormulario,
      icon: const Icon(Icons.clear_all, size: 20),
      label: const Text(
        'Limpiar',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _C.txt2,
        side: const BorderSide(color: _C.border, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _guardarProyecto,
      icon: _isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.save, size: 20),
      label: Text(
        _isLoading ? 'Guardando...' : 'Guardar Proyecto',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _C.teal,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _C.teal.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    );
  }

  void _limpiarFormulario() {
    _formKey.currentState?.reset();
    _codigoController.clear();
    _tituloController.clear();
    _integrantesController.clear();
    _clasificacionController.clear();
    _salaController.clear();
  }

  Future<void> _guardarProyecto() async {
    if (!_formKey.currentState!.validate()) {
      _mostrarError('Por favor complete todos los campos obligatorios');
      return;
    }

    final codigoSnapshot = _codigoController.text.trim();
    final tituloSnapshot = _tituloController.text.trim();
    final integrantesSnapshot = _integrantesController.text.trim();
    final clasificacionSnapshot = _clasificacionController.text.trim();
    final salaSnapshot = _salaController.text.trim();

    bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, color: _C.teal),
            ),
            const SizedBox(width: 12),
            const Text('Confirmar', style: TextStyle(color: _C.navy)),
          ],
        ),
        content: const Text(
          '¿Deseas guardar este proyecto?',
          style: TextStyle(fontSize: 15, color: _C.txt2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: _C.txt2)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.teal,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final proyectoData = {
        'Código': codigoSnapshot,
        'Título': tituloSnapshot,
        'Integrantes': integrantesSnapshot,
        'Clasificación': clasificacionSnapshot,
        'Sala': salaSnapshot,
      };

      // FIX: se pasa eventData para que el proyecto manual guarde
      // filialId/facultad/carreraId igual que la importación de Excel,
      // y la resolución de nombres de integrantes funcione sin fallback.
      await widget.gruposService.guardarProyectosEnEvento(
        widget.eventData['id'],
        [proyectoData],
        eventData: widget.eventData,
      );

      widget.onProyectoAgregado();

      if (mounted) {
        _mostrarMensajeExito(codigoSnapshot);
        _limpiarFormulario();

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        _mostrarError('Error al guardar el proyecto: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _mostrarMensajeExito(String codigo) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Proyecto "$codigo" agregado exitosamente',
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        backgroundColor: _C.teal,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              ),
            ),
          ],
        ),
        backgroundColor: _C.red,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class KeyboardDismissOnScroll extends StatelessWidget {
  final Widget child;

  const KeyboardDismissOnScroll({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: child,
    );
  }
}