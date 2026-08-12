import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/shared/logica/grupos_service.dart';
import '/roles/admin/logica/agregar_proyecto_service.dart';

class _C {
  static const navy    = Color(0xFF0F2342);
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
  final AgregarProyectoService _agregarProyectoService =
      AgregarProyectoService();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _codigoController = TextEditingController();
  final _tituloController = TextEditingController();
  final _clasificacionController = TextEditingController();
  final _salaController = TextEditingController();

  bool _isLoading = false;
  bool _mostrarErrorIntegrantes = false;

  List<String> _clasificacionesExistentes = [];
  bool _cargandoClasificaciones = true;

  List<Map<String, dynamic>> _estudiantesSeleccionados = [];
  List<Map<String, dynamic>> _estudiantesDisponibles = [];
  bool _cargandoEstudiantes = true;

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
    _cargarEstudiantes();
  }

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

  Future<void> _cargarEstudiantes() async {
    try {
      final filialNombre =
          (widget.eventData['filialNombre'] ?? '').toString().trim();
      final carrera =
          (widget.eventData['carreraNombre'] ?? '').toString().trim();

      if (filialNombre.isEmpty || carrera.isEmpty) {
        if (mounted) setState(() => _cargandoEstudiantes = false);
        return;
      }

      final estudiantes = await _agregarProyectoService.cargarEstudiantes(
        filialNombre: filialNombre,
        carrera: carrera,
      );

      if (!mounted) return;
      setState(() {
        _estudiantesDisponibles = estudiantes;
        _cargandoEstudiantes = false;
      });
    } catch (e) {
      if (mounted) setState(() => _cargandoEstudiantes = false);
      debugPrint('Error cargando estudiantes: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _codigoController.dispose();
    _tituloController.dispose();
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
            _buildIntegrantesField(),
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

  Widget _buildIntegrantesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Integrantes',
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
        if (_estudiantesSeleccionados.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _estudiantesSeleccionados.map((est) {
              final nombre = est['name']?.toString() ?? 'Sin nombre';
              final codigo =
                  est['codigoUniversitario']?.toString() ?? '';
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _C.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _C.teal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: _C.teal,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          nombre.isNotEmpty
                              ? nombre[0].toUpperCase()
                              : 'E',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 140),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            nombre,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _C.teal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (codigo.isNotEmpty)
                            Text(
                              codigo,
                              style: TextStyle(
                                fontSize: 10,
                                color: _C.teal.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(
                          () => _estudiantesSeleccionados.remove(est)),
                      child: const Icon(Icons.close,
                          size: 14, color: _C.teal),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _cargandoEstudiantes
                ? null
                : _mostrarSelectorEstudiantes,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _mostrarErrorIntegrantes &&
                          _estudiantesSeleccionados.isEmpty
                      ? _C.red
                      : _estudiantesSeleccionados.isEmpty
                          ? _C.border
                          : _C.teal.withValues(alpha: 0.4),
                  width: _mostrarErrorIntegrantes &&
                          _estudiantesSeleccionados.isEmpty
                      ? 1.5
                      : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _cargandoEstudiantes
                        ? Icons.hourglass_empty
                        : Icons.person_add,
                    color: _mostrarErrorIntegrantes &&
                            _estudiantesSeleccionados.isEmpty
                        ? _C.red
                        : _C.teal,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _cargandoEstudiantes
                        ? const Text(
                            'Cargando estudiantes...',
                            style: TextStyle(
                                color: _C.txt3, fontSize: 13),
                          )
                        : _estudiantesDisponibles.isEmpty
                            ? const Text(
                                'Sin estudiantes importados en esta carrera',
                                style: TextStyle(
                                    color: _C.txt3, fontSize: 13),
                              )
                            : Text(
                                _estudiantesSeleccionados.isEmpty
                                    ? 'Toca para seleccionar integrantes'
                                    : '${_estudiantesSeleccionados.length} integrante${_estudiantesSeleccionados.length != 1 ? 's' : ''} seleccionado${_estudiantesSeleccionados.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _estudiantesSeleccionados
                                          .isEmpty
                                      ? _mostrarErrorIntegrantes
                                          ? _C.red
                                          : _C.txt3
                                      : _C.teal,
                                  fontWeight:
                                      _estudiantesSeleccionados.isEmpty
                                          ? FontWeight.normal
                                          : FontWeight.w600,
                                ),
                              ),
                  ),
                  if (_cargandoEstudiantes)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_C.teal),
                      ),
                    )
                  else
                    Icon(
                      Icons.arrow_forward_ios,
                      color: _mostrarErrorIntegrantes &&
                              _estudiantesSeleccionados.isEmpty
                          ? _C.red
                          : _C.teal,
                      size: 14,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_mostrarErrorIntegrantes && _estudiantesSeleccionados.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              'Selecciona al menos un integrante',
              style: TextStyle(color: _C.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  void _mostrarSelectorEstudiantes() {
    final TextEditingController busquedaCtrl = TextEditingController();
    List<Map<String, dynamic>> filtrados =
        List.from(_estudiantesDisponibles);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void filtrar(String term) {
            final t = term.toLowerCase().trim();
            setSheet(() {
              filtrados = t.isEmpty
                  ? List.from(_estudiantesDisponibles)
                  : _estudiantesDisponibles.where((e) {
                      final nombre =
                          (e['name'] ?? '').toString().toLowerCase();
                      final codigo =
                          (e['codigoUniversitario'] ?? '')
                              .toString()
                              .toLowerCase();
                      return nombre.contains(t) || codigo.contains(t);
                    }).toList();
            });
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _C.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.people,
                            color: _C.teal, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Seleccionar Integrantes',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _C.navy,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Listo',
                          style: TextStyle(
                            color: _C.teal,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_estudiantesSeleccionados.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _C.teal.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _C.teal.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: _C.teal, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_estudiantesSeleccionados.length} seleccionado${_estudiantesSeleccionados.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _C.teal,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setSheet(() =>
                                  _estudiantesSeleccionados.clear());
                              setState(() {});
                            },
                            child: const Text(
                              'Quitar todos',
                              style: TextStyle(
                                fontSize: 12,
                                color: _C.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: busquedaCtrl,
                    onChanged: filtrar,
                    style: const TextStyle(fontSize: 14, color: _C.txt1),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o código',
                      hintStyle: const TextStyle(
                          color: _C.txt3, fontSize: 13),
                      prefixIcon: const Icon(Icons.search,
                          color: _C.teal, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _C.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _C.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: _C.teal, width: 2)),
                      filled: true,
                      fillColor: _C.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      suffixIcon: busquedaCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: _C.txt3, size: 18),
                              onPressed: () {
                                busquedaCtrl.clear();
                                filtrar('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (filtrados.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off,
                              size: 48,
                              color: _C.txt3.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'Sin resultados',
                            style: TextStyle(
                                color: _C.txt3, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: filtrados.length,
                      itemBuilder: (ctx, i) {
                        final est = filtrados[i];
                        final codigo =
                            est['codigoUniversitario']?.toString() ??
                                '';
                        final nombre =
                            est['name']?.toString() ?? 'Sin nombre';
                        final ciclo =
                            est['ciclo']?.toString() ?? '';
                        final isSelected =
                            _estudiantesSeleccionados.any((s) =>
                                s['codigoUniversitario'] == codigo);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(12),
                              onTap: () {
                                setSheet(() {
                                  if (isSelected) {
                                    _estudiantesSeleccionados
                                        .removeWhere((s) =>
                                            s['codigoUniversitario'] ==
                                            codigo);
                                  } else {
                                    _estudiantesSeleccionados
                                        .add(est);
                                  }
                                });
                                setState(() {});
                              },
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _C.teal.withValues(alpha: 0.07)
                                      : _C.surface,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? _C.teal
                                        : _C.border,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 180),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _C.teal
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected
                                              ? _C.teal
                                              : _C.txt3,
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check,
                                              color: Colors.white,
                                              size: 14)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _C.teal
                                            : _C.navy,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          nombre.isNotEmpty
                                              ? nombre[0].toUpperCase()
                                              : 'E',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 15,
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
                                            nombre,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color: isSelected
                                                  ? _C.teal
                                                  : _C.txt1,
                                            ),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              if (codigo.isNotEmpty) ...[
                                                Icon(
                                                  Icons.badge,
                                                  size: 11,
                                                  color: isSelected
                                                      ? _C.teal.withValues(
                                                          alpha: 0.7)
                                                      : _C.txt3,
                                                ),
                                                const SizedBox(
                                                    width: 3),
                                                Text(
                                                  codigo,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isSelected
                                                        ? _C.teal.withValues(
                                                            alpha: 0.8)
                                                        : _C.txt3,
                                                  ),
                                                ),
                                              ],
                                              if (ciclo.isNotEmpty) ...[
                                                const SizedBox(
                                                    width: 8),
                                                Text(
                                                  'Ciclo $ciclo',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isSelected
                                                        ? _C.teal.withValues(
                                                            alpha: 0.7)
                                                        : _C.txt3,
                                                  ),
                                                ),
                                              ],
                                            ],
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
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() => setState(() {}));
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
            prefixIcon:
                const Icon(Icons.category, color: _C.teal, size: 20),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
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
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.save, size: 20),
      label: Text(
        _isLoading ? 'Guardando...' : 'Guardar Proyecto',
        style:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
    _clasificacionController.clear();
    _salaController.clear();
    setState(() {
      _estudiantesSeleccionados = [];
      _mostrarErrorIntegrantes = false;
    });
  }

  Future<void> _guardarProyecto() async {
    setState(() => _mostrarErrorIntegrantes = true);

    if (!_formKey.currentState!.validate()) {
      _mostrarError('Por favor complete todos los campos obligatorios');
      return;
    }
    if (_estudiantesSeleccionados.isEmpty) {
      _mostrarError('Selecciona al menos un integrante');
      return;
    }

    final codigoSnapshot = _codigoController.text.trim();
    final tituloSnapshot = _tituloController.text.trim();
    final clasificacionSnapshot = _clasificacionController.text.trim();
    final salaSnapshot = _salaController.text.trim();

    final codigos = _estudiantesSeleccionados
        .map((e) => e['codigoUniversitario']?.toString() ?? '')
        .where((c) => c.isNotEmpty)
        .toList();

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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Deseas guardar este proyecto?',
              style: TextStyle(fontSize: 15, color: _C.txt2),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.teal.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _C.teal.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    codigoSnapshot,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _C.navy,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${codigos.length} integrante${codigos.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: _C.txt2),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancelar', style: TextStyle(color: _C.txt2)),
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

    setState(() => _isLoading = true);

    try {
      final proyectoData = {
        'Código': codigoSnapshot,
        'Título': tituloSnapshot,
        'Integrantes': codigos,
        'totalIntegrantes': codigos.length,
        'Clasificación': clasificacionSnapshot,
        'Sala': salaSnapshot,
      };

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
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _mostrarError('Error al guardar el proyecto: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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