import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/logica/filiales_service.dart';
import '/encryption_helper.dart';

class ControlPagosScreen extends StatefulWidget {
  const ControlPagosScreen({super.key});

  @override
  State<ControlPagosScreen> createState() => _ControlPagosScreenState();
}

class _ControlPagosScreenState extends State<ControlPagosScreen>
    with TickerProviderStateMixin {

  // ── Servicios ──────────────────────────────────────────────────────
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FilialesService   _filialesService = FilialesService();

  // ── Estructura de filiales ─────────────────────────────────────────
  Map<String, dynamic> _estructuraFiliales = {};
  bool _estructuraCargada = false;

  // ── Selección de filtros ───────────────────────────────────────────
  String? _selectedFilialId;
  String? _selectedFilialNombre;
  String? _selectedFacultad;
  String? _selectedCarrera;
  String? _selectedCarreraId;
  String? _selectedEventoId;
  String? _selectedEventoNombre;

  // ── Eventos disponibles ────────────────────────────────────────────
  List<Map<String, dynamic>> _eventos = [];
  bool _loadingEventos = false;

  // ── Estudiantes ────────────────────────────────────────────────────
  List<Map<String, dynamic>> _estudiantes = [];
  bool _loadingEstudiantes = false;

  // ── Estudiantes con pago en proceso de actualización ───────────────
  final Set<String> _updatingPayment = {};

  // ── Tab controller ─────────────────────────────────────────────────
  late TabController _tabController;

  // ── Búsqueda ───────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Animaciones ────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double>   _fadeAnimation;

  // ── Cache de ruta ──────────────────────────────────────────────────
  String _carreraPath = '';

  // ── Constante de color principal ───────────────────────────────────
  static const Color _primary = Color(0xFF1E3A5F);

  @override
  void initState() {
    super.initState();
    _tabController  = TabController(length: 3, vsync: this);
    _animController = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnimation  = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeIn));
    _animController.forward();
    _initEstructura();
    _searchController.addListener(
        () => setState(() => _searchQuery = _searchController.text.toLowerCase()));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Inicializar estructura ─────────────────────────────────────────
  Future<void> _initEstructura() async {
    try {
      await _filialesService.inicializarSiEsNecesario();
      final estructura = await _filialesService.getEstructuraCompleta();
      setState(() {
        _estructuraFiliales = estructura;
        _estructuraCargada  = true;
      });
    } catch (e) {
      _showMessage('Error cargando estructura: $e');
    }
  }

  // ── Helpers de estructura ──────────────────────────────────────────
  List<String> get _filialesDisponibles => _estructuraFiliales.keys.toList();

  List<String> _getFacultades(String filialId) {
    final filial = _estructuraFiliales[filialId];
    if (filial == null) return [];
    return (filial['facultades'] as Map<String, dynamic>).keys.toList();
  }

  List<Map<String, dynamic>> _getCarreras(String filialId, String facultad) {
    final filial = _estructuraFiliales[filialId];
    if (filial == null) return [];
    final facs    = filial['facultades'] as Map<String, dynamic>;
    final facData = facs[facultad];
    if (facData == null) return [];
    return List<Map<String, dynamic>>.from(facData['carreras'] ?? []);
  }

  String _getNombreFilial(String filialId) =>
      _estructuraFiliales[filialId]?['nombre'] ?? filialId;

  // ── Cambios de selección ───────────────────────────────────────────
  void _onFilialChanged(String? filialId) {
    setState(() {
      _selectedFilialId     = filialId;
      _selectedFilialNombre = filialId != null ? _getNombreFilial(filialId) : null;
      _selectedFacultad     = null;
      _selectedCarrera      = null;
      _selectedCarreraId    = null;
      _carreraPath          = '';
      _eventos              = [];
      _selectedEventoId     = null;
      _selectedEventoNombre = null;
      _estudiantes          = [];
    });
  }

  void _onFacultadChanged(String? facultad) {
    setState(() {
      _selectedFacultad     = facultad;
      _selectedCarrera      = null;
      _selectedCarreraId    = null;
      _carreraPath          = '';
      _eventos              = [];
      _selectedEventoId     = null;
      _selectedEventoNombre = null;
      _estudiantes          = [];
    });
  }

  void _onCarreraChanged(String? carrera, String? carreraId) {
    setState(() {
      _selectedCarrera   = carrera;
      _selectedCarreraId = carreraId;
      _carreraPath       = (carrera != null && _selectedFilialNombre != null)
          ? '${_selectedFilialNombre}_$carrera'
          : '';
      _eventos           = [];
      _selectedEventoId  = null;
      _selectedEventoNombre = null;
      _estudiantes       = [];
    });
    if (carreraId != null) _cargarEventos();
  }

  void _onEventoChanged(String? eventoId) {
    if (eventoId == null) return;
    final evento = _eventos.firstWhere((e) => e['id'] == eventoId, orElse: () => {});
    setState(() {
      _selectedEventoId     = eventoId;
      _selectedEventoNombre = evento['nombre'] ?? '';
      _estudiantes          = [];
    });
    _cargarEstudiantes();
  }

  // ── Cargar eventos de la carrera ───────────────────────────────────
  Future<void> _cargarEventos() async {
    if (_selectedFilialId == null || _selectedFacultad == null ||
        _selectedCarreraId == null) return;
    setState(() { _loadingEventos = true; _eventos = []; });
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('filialId',  isEqualTo: _selectedFilialId)
          .where('facultad',  isEqualTo: _selectedFacultad)
          .where('carreraId', isEqualTo: _selectedCarreraId)
          .orderBy('createdAt', descending: true)
          .get();
      setState(() {
        _eventos = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id'     : doc.id,
            'nombre' : data['name']         ?? 'Sin nombre',
            'periodo': data['periodoNombre'] ?? '',
          };
        }).toList();
      });
      if (_eventos.isEmpty) _showMessage('⚠️ No hay eventos para esta carrera');
    } catch (e) {
      _showMessage('Error cargando eventos: $e');
    }
    setState(() => _loadingEventos = false);
  }

  // ── Cargar estudiantes de la carrera ───────────────────────────────
  Future<void> _cargarEstudiantes() async {
    if (_selectedCarrera == null || _selectedFilialNombre == null ||
        _selectedEventoId == null) return;
    setState(() { _loadingEstudiantes = true; _estudiantes = []; });
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_carreraPath)
          .collection('students')
          .orderBy('name')
          .get();

      final eventoId = _selectedEventoId!;
      final lista = snapshot.docs.map((doc) {
        final data = doc.data();

        final dniEncrypted = data['dniEncrypted'] as String? ?? '';
        final dni = dniEncrypted.isNotEmpty
            ? EncryptionHelper.decryptDni(dniEncrypted)
            : '—';

        final pagos  = data['pagos'] as Map<String, dynamic>? ?? {};
        final pagado = pagos[eventoId] == true;

        return {
          'id'                 : doc.id,
          'name'               : data['name']                ?? 'Sin nombre',
          'codigoUniversitario': data['codigoUniversitario'] ?? '—',
          'dni'                : dni,
          'ciclo'              : data['ciclo']               ?? '—',
          'grupo'              : data['grupo']               ?? '—',
          'email'              : data['email']               ?? '—',
          'pagado'             : pagado,
        };
      }).toList();

      setState(() => _estudiantes = lista);
      _animController
        ..reset()
        ..forward();
    } catch (e) {
      _showMessage('Error cargando estudiantes: $e');
    }
    setState(() => _loadingEstudiantes = false);
  }

 Future<void> _togglePago(Map<String, dynamic> student) async {
  if (_selectedEventoId == null) return;
 
  final studentId    = student['id'] as String;
  final pagadoActual = student['pagado'] as bool;
  final nuevoEstado  = !pagadoActual;
  final nombre       = student['name'] as String;
 
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: nuevoEstado
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              nuevoEstado ? Icons.check_circle : Icons.cancel,
              color: nuevoEstado ? Colors.green.shade700 : Colors.red.shade500,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Flexible(
            child: Text('Cambiar pago',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
          children: [
            const TextSpan(text: '¿Marcar a '),
            TextSpan(
              text: nombre,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: nuevoEstado
                  ? ' como PAGADO?'
                  : ' como PENDIENTE (sin pago)?',
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor:
                nuevoEstado ? Colors.green.shade700 : Colors.red.shade500,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(nuevoEstado ? 'Marcar pagado' : 'Marcar pendiente'),
        ),
      ],
    ),
  );
 
  if (confirmado != true) return;
 
  setState(() => _updatingPayment.add(studentId));
 
  try {
    await _firestore
        .collection('users')
        .doc(_carreraPath)
        .collection('students')
        .doc(studentId)
        .update({
      // Campo original de pago por evento — sin cambios
      'pagos.$_selectedEventoId': nuevoEstado,
      // Campo nuevo: bloquea el login si el pago está pendiente.
      // true  = bloqueado (pendiente)
      // false = libre     (pagó)
      'bloqueadoPorPago': !nuevoEstado,
    });
 
    setState(() {
      final idx = _estudiantes.indexWhere((e) => e['id'] == studentId);
      if (idx != -1) {
        _estudiantes[idx] = {..._estudiantes[idx], 'pagado': nuevoEstado};
      }
    });
 
    _showMessage(nuevoEstado
        ? '✅ $nombre marcado como PAGADO'
        : '⚠️ $nombre marcado como PENDIENTE');
  } catch (e) {
    _showMessage('Error actualizando pago: $e');
  } finally {
    setState(() => _updatingPayment.remove(studentId));
  }
}

  // ── Filtrar lista según tab y búsqueda ─────────────────────────────
  List<Map<String, dynamic>> _filteredList(int tabIndex) {
    List<Map<String, dynamic>> base;
    switch (tabIndex) {
      case 1:
        base = _estudiantes.where((e) => e['pagado'] == true).toList();
        break;
      case 2:
        base = _estudiantes.where((e) => e['pagado'] == false).toList();
        break;
      default:
        base = _estudiantes;
    }
    if (_searchQuery.isEmpty) return base;
    return base.where((e) {
      final name   = (e['name']                ?? '').toString().toLowerCase();
      final codigo = (e['codigoUniversitario'] ?? '').toString().toLowerCase();
      final dni    = (e['dni']                 ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) ||
             codigo.contains(_searchQuery) ||
             dni.contains(_searchQuery);
    }).toList();
  }

  // ── Estadísticas ───────────────────────────────────────────────────
  int get _totalEstudiantes => _estudiantes.length;
  int get _totalPagaron     => _estudiantes.where((e) => e['pagado'] == true).length;
  int get _totalNoPagaron   => _estudiantes.where((e) => e['pagado'] == false).length;

  // ── Bottom sheets ──────────────────────────────────────────────────
  void _showFilialSelector() => _showSelectorSheet(
    title: 'Seleccionar Sede',
    icon: Icons.location_city,
    items: _filialesDisponibles.map((id) => _SheetItem(
      value: id,
      label: _getNombreFilial(id),
      subtitle: _estructuraFiliales[id]?['ubicacion'] ?? '',
      isSelected: _selectedFilialId == id,
    )).toList(),
    onSelected: (v, [_]) { _onFilialChanged(v); Navigator.pop(context); },
  );

  void _showFacultadSelector() {
    if (_selectedFilialId == null) { _showMessage('Selecciona una sede'); return; }
    _showSelectorSheet(
      title: 'Seleccionar Facultad',
      icon: Icons.business,
      items: _getFacultades(_selectedFilialId!).map((f) => _SheetItem(
        value: f,
        label: f,
        subtitle: '${_getCarreras(_selectedFilialId!, f).length} carreras',
        isSelected: _selectedFacultad == f,
      )).toList(),
      onSelected: (v, [_]) { _onFacultadChanged(v); Navigator.pop(context); },
    );
  }

  void _showCarreraSelector() {
    if (_selectedFilialId == null || _selectedFacultad == null) {
      _showMessage('Selecciona una facultad'); return;
    }
    final carreras = _getCarreras(_selectedFilialId!, _selectedFacultad!);
    _showSelectorSheet(
      title: 'Seleccionar Carrera',
      icon: Icons.school,
      items: carreras.map((c) => _SheetItem(
        value: c['nombre'] as String,
        label: c['nombre'] as String,
        subtitle: '',
        isSelected: _selectedCarrera == c['nombre'],
        extra: c['id'] as String?,
      )).toList(),
      onSelected: (v, [extra]) { _onCarreraChanged(v, extra); Navigator.pop(context); },
    );
  }

  void _showEventoSelector() {
    if (_eventos.isEmpty) { _showMessage('No hay eventos disponibles'); return; }
    _showSelectorSheet(
      title: 'Seleccionar Evento',
      icon: Icons.event,
      items: _eventos.map((e) => _SheetItem(
        value: e['id'] as String,
        label: e['nombre'] as String,
        subtitle: e['periodo'] as String? ?? '',
        isSelected: _selectedEventoId == e['id'],
      )).toList(),
      onSelected: (v, [_]) { _onEventoChanged(v); Navigator.pop(context); },
    );
  }

  void _showSelectorSheet({
    required String title,
    required IconData icon,
    required List<_SheetItem> items,
    required void Function(String, [String?]) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) => Padding(
            padding: EdgeInsets.fromLTRB(
              20, 20, 20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50, height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: _primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _primary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('Sin opciones',
                                  style: TextStyle(color: Colors.grey[500])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: item.isSelected
                                    ? _primary.withOpacity(0.08)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: item.isSelected
                                      ? _primary
                                      : Colors.grey.shade300,
                                  width: item.isSelected ? 2 : 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                title: Text(
                                  item.label,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: item.isSelected
                                          ? _primary
                                          : Colors.black87,
                                      fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                subtitle: item.subtitle.isNotEmpty
                                    ? Text(item.subtitle,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: item.isSelected
                                                ? _primary.withOpacity(0.7)
                                                : Colors.grey),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1)
                                    : null,
                                trailing: item.isSelected
                                    ? const Icon(Icons.check_circle,
                                        color: _primary)
                                    : const Icon(Icons.arrow_forward_ios,
                                        size: 14, color: Colors.grey),
                                onTap: () => onSelected(item.value, item.extra),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: _primary,
    ));
  }

  // ── BUILD ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primary,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44, minHeight: 44,
                      maxWidth: 56, maxHeight: 56,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.monetization_on,
                            color: _primary, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Control de Pagos',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1),
                        Text('Seguimiento de pagos por evento',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: !_estructuraCargada
                    ? const Center(child: CircularProgressIndicator(
                        color: _primary))
                    : Column(
                        children: [
                          _buildFiltrosPanel(),
                          Expanded(child: _buildBody()),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Panel de filtros ───────────────────────────────────────────────
  Widget _buildFiltrosPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _filterChip(
                    label: 'Sede',
                    value: _selectedFilialNombre,
                    icon: Icons.location_city,
                    onTap: _estructuraCargada ? _showFilialSelector : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _filterChip(
                    label: 'Facultad',
                    value: _selectedFacultad != null
                        ? (_selectedFacultad!.startsWith('Facultad de ')
                            ? _selectedFacultad!
                                .substring('Facultad de '.length)
                            : _selectedFacultad)
                        : null,
                    icon: Icons.business,
                    onTap: _selectedFilialId != null ? _showFacultadSelector : null,
                    enabled: _selectedFilialId != null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _filterChip(
                    label: 'Carrera',
                    value: _selectedCarrera,
                    icon: Icons.school,
                    onTap: _selectedFacultad != null ? _showCarreraSelector : null,
                    enabled: _selectedFacultad != null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _loadingEventos
                      ? Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.green.shade600),
                              ),
                              const SizedBox(width: 8),
                              const Text('Eventos...',
                                  style: TextStyle(fontSize: 11,
                                      color: Color(0xFF64748B))),
                            ],
                          ),
                        )
                      : _filterChip(
                          label: 'Evento',
                          value: _selectedEventoNombre,
                          icon: Icons.event,
                          onTap: (_destinoCarreraListo && _eventos.isNotEmpty)
                              ? _showEventoSelector
                              : null,
                          enabled: _destinoCarreraListo && _eventos.isNotEmpty,
                          activeColor: Colors.green.shade700,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Buscador
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _estudiantes.isNotEmpty
                ? Column(
                    key: const ValueKey('search-visible'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _searchController,
                        scrollPadding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre, código o DNI...',
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.search,
                              color: _primary, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TabBar(
                        controller: _tabController,
                        labelColor: _primary,
                        unselectedLabelColor: const Color(0xFF94A3B8),
                        indicatorColor: _primary,
                        indicatorWeight: 3,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11),
                        tabs: [
                          Tab(text: 'Todos ($_totalEstudiantes)'),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle,
                                    size: 13, color: Colors.green.shade600),
                                const SizedBox(width: 3),
                                Text('Pagaron ($_totalPagaron)',
                                    style: const TextStyle(fontSize: 11),
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cancel,
                                    size: 13, color: Colors.red.shade400),
                                const SizedBox(width: 3),
                                Text('Pendientes ($_totalNoPagaron)',
                                    style: const TextStyle(fontSize: 11),
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 1, color: Colors.grey.shade200),
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('search-hidden')),
          ),
        ],
      ),
    );
  }

  bool get _destinoCarreraListo =>
      _selectedFilialNombre != null &&
      _selectedFacultad != null &&
      _selectedCarrera != null;

  // ── Cuerpo principal ───────────────────────────────────────────────
  Widget _buildBody() {
    if (_loadingEstudiantes) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primary),
            SizedBox(height: 16),
            Text('Cargando estudiantes...',
                style: TextStyle(color: _primary)),
          ],
        ),
      );
    }

    if (_selectedEventoId == null) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.filter_list,
                      size: 48, color: _primary),
                ),
                const SizedBox(height: 20),
                const Text('Selecciona los filtros',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primary)),
                const SizedBox(height: 8),
                Text(
                  'Elige sede, facultad, carrera y evento\npara ver el estado de pagos',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_estudiantes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No hay estudiantes en esta carrera',
                style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          _buildStatsBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStudentList(_filteredList(0)),
                _buildStudentList(_filteredList(1)),
                _buildStudentList(_filteredList(2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Barra de estadísticas ──────────────────────────────────────────
  Widget _buildStatsBar() {
    final porcentaje = _totalEstudiantes > 0
        ? (_totalPagaron / _totalEstudiantes * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: _statBadge('$_totalEstudiantes', 'Total',
                    _primary, const Color(0xFFEFF6FF)),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: _statBadge('$_totalPagaron', 'Pagaron',
                    Colors.green.shade700, Colors.green.shade50),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: _statBadge('$_totalNoPagaron', 'Pendientes',
                    Colors.red.shade600, Colors.red.shade50),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$porcentaje% pagó',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: '$porcentaje% de estudiantes han pagado',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _totalEstudiantes > 0
                    ? _totalPagaron / _totalEstudiantes
                    : 0,
                minHeight: 6,
                backgroundColor: Colors.red.shade100,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.green.shade600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String value, String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: 10, color: textColor.withOpacity(0.8)),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
        ],
      ),
    );
  }

  // ── Lista de estudiantes ───────────────────────────────────────────
  Widget _buildStudentList(List<Map<String, dynamic>> lista) {
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 44, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'Sin resultados para "$_searchQuery"'
                    : 'No hay estudiantes en esta categoría',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: lista.length,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      itemBuilder: (context, index) =>
          _buildStudentCard(lista[index], index),
    );
  }

  // ── Card de estudiante ─────────────────────────────────────────────
  Widget _buildStudentCard(Map<String, dynamic> student, int index) {
    final pagado      = student['pagado'] as bool;
    final studentId   = student['id'] as String;
    final isUpdating  = _updatingPayment.contains(studentId);
    final pagoColor   = pagado ? Colors.green.shade700 : Colors.red.shade500;
    final pagoBg      = pagado ? Colors.green.shade50   : Colors.red.shade50;
    final pagoLabel   = pagado ? 'Pagó' : 'Pendiente';
    final pagoIcon    = pagado ? Icons.check_circle : Icons.cancel;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pagado ? Colors.green.shade200 : Colors.red.shade100,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar con número
            SizedBox(
              width: 40, height: 40,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: pagado ? Colors.green.shade700 : _primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(student['name'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _primary,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.badge,
                          size: 11, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(student['codigoUniversitario'],
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.credit_card,
                          size: 11, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(student['dni'],
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1),
                      ),
                    ],
                  ),
                  if (student['ciclo'] != '—' || student['grupo'] != '—') ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (student['ciclo'] != '—') ...[
                          Icon(Icons.layers,
                              size: 11, color: Colors.grey.shade400),
                          const SizedBox(width: 3),
                          Text('Ciclo ${student['ciclo']}',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(width: 8),
                        ],
                        if (student['grupo'] != '—') ...[
                          Icon(Icons.groups,
                              size: 11, color: Colors.grey.shade400),
                          const SizedBox(width: 3),
                          Text('Grupo ${student['grupo']}',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Badge de pago TAPPABLE ─────────────────────────────
            // Al tocar el badge se abre el diálogo de confirmación
            // y se actualiza el estado en Firestore + estado local.
            GestureDetector(
              onTap: isUpdating ? null : () => _togglePago(student),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isUpdating ? Colors.grey.shade100 : pagoBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isUpdating
                        ? Colors.grey.shade300
                        : pagoColor.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: isUpdating
                    // Spinner mientras se guarda en Firestore
                    ? SizedBox(
                        width: 52, height: 18,
                        child: Center(
                          child: SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(pagoIcon, size: 14, color: pagoColor),
                          const SizedBox(width: 4),
                          Text(pagoLabel,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: pagoColor)),
                          const SizedBox(width: 4),
                          // Ícono pequeño de lápiz que indica que es editable
                          Icon(Icons.edit,
                              size: 10,
                              color: pagoColor.withOpacity(0.6)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter chip ────────────────────────────────────────────────────
  Widget _filterChip({
    required String   label,
    required String?  value,
    required IconData icon,
    required VoidCallback? onTap,
    bool   enabled = true,
    Color? activeColor,
  }) {
    final color      = activeColor ?? _primary;
    final isSelected = value != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected && enabled
                ? color.withOpacity(0.06)
                : enabled ? Colors.grey.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected && enabled ? color : Colors.grey.shade300,
              width: isSelected && enabled ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 14,
                  color: enabled ? color : Colors.grey.shade400),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                    Text(
                      value ?? 'Seleccionar',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected && enabled
                              ? color
                              : Colors.grey.shade400),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_drop_down,
                  size: 16,
                  color: enabled ? color : Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper ─────────────────────────────────────────────────────────────
class _SheetItem {
  final String  value;
  final String  label;
  final String  subtitle;
  final bool    isSelected;
  final String? extra;

  const _SheetItem({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    this.extra,
  });
}