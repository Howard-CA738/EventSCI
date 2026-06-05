import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/admin/logica/grupos.dart';

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
        backgroundColor: const Color(0xFF2C5F7C),
        appBar: AppBar(
          title: const Text(
            'Agregar Proyecto',
            style: TextStyle(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: const Color(0xFF2C5F7C),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Regresar',
          ),
        ),
        body: SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF5F7FA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
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
                      top: 20.0,
                      bottom:
                          MediaQuery.of(context).viewInsets.bottom + 32.0,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeaderCard(),
                          const SizedBox(height: 24),
                          _buildFormCard(),
                          const SizedBox(height: 24),
                          _buildActionButtons(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final eventName =
        (widget.eventData['name'] as String? ?? 'Evento').trim();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.add_box,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nuevo Proyecto',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  eventName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_document, color: Color(0xFF2C5F7C), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Información del Proyecto',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _codigoController,
              label: 'Código del Proyecto',
              icon: Icons.qr_code,
              hint: 'Ej: P001, INV-2024-001',
              isRequired: true,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _tituloController,
              label: 'Título del Proyecto',
              icon: Icons.title,
              hint: 'Ingrese el título completo',
              maxLines: 3,
              isRequired: true,
              alignLabelWithHint: true,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _integrantesController,
              label: 'Integrantes',
              icon: Icons.people,
              hint: 'Nombres separados por comas',
              maxLines: 3,
              isRequired: true,
              alignLabelWithHint: true,
            ),
            const SizedBox(height: 20),
            _buildClasificacionField(),
            const SizedBox(height: 20),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          textInputAction:
              maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
          decoration: InputDecoration(
            hintText: hint,
            alignLabelWithHint: alignLabelWithHint,
            prefixIcon: Padding(
              padding: maxLines > 1
                  ? const EdgeInsets.only(bottom: 0)
                  : EdgeInsets.zero,
              child: Icon(icon, color: const Color(0xFF2C5F7C)),
            ),
            prefixIconConstraints: maxLines > 1
                ? const BoxConstraints(minWidth: 48, minHeight: 48)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2C5F7C), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Clasificación',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            SizedBox(width: 4),
            Text('*', style: TextStyle(color: Colors.red, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _clasificacionController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'Seleccione o escriba una categoría',
            prefixIcon:
                const Icon(Icons.category, color: Color(0xFF2C5F7C)),
            suffixIcon: PopupMenuButton<String>(
              icon: const Icon(Icons.arrow_drop_down,
                  color: Color(0xFF2C5F7C)),
              tooltip: 'Seleccionar categoría',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onSelected: (String value) {
                setState(() {
                  _clasificacionController.text = value;
                });
              },
              itemBuilder: (BuildContext context) {
                return _categoriasSugeridas.map((String categoria) {
                  return PopupMenuItem<String>(
                    value: categoria,
                    child: Text(
                      categoria,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  );
                }).toList();
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF2C5F7C), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
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
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categoriasSugeridas.take(5).map((categoria) {
            return InkWell(
              onTap: () {
                setState(() {
                  _clasificacionController.text = categoria;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Chip(
                label: Text(
                  categoria,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                backgroundColor:
                    const Color(0xFF2C5F7C).withValues(alpha: 0.1),
                labelStyle: const TextStyle(color: Color(0xFF2C5F7C)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
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
        foregroundColor: const Color(0xFF64748B),
        side: BorderSide(color: Colors.grey.shade300, width: 2),
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
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
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
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
            ),
            const SizedBox(width: 12),
            const Text('Confirmar'),
          ],
        ),
        content: const Text(
          '¿Deseas guardar este proyecto?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
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

      await widget.gruposService.guardarProyectosEnEvento(
        widget.eventData['id'],
        [proyectoData],
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
        backgroundColor: const Color(0xFF4CAF50),
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
        backgroundColor: const Color(0xFFF44336),
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