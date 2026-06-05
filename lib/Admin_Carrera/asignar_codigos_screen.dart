import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';

const _kPrimario       = Color(0xFF1E3A5F);
const _kPrimario40     = Color(0x661E3A5F);
const _kTextoGris      = Color(0xFF64748B);
const _kTextoGrisClaro = Color(0xFF94A3B8);
const _kTextoOscuro    = Color(0xFF334155);
const _kFondo          = Color(0xFFE8EDF2);
const _kCampoFondo2    = Color(0xFFF1F5F9);
const _kVerde          = Color(0xFF16A34A);
const _kAmbar          = Color(0xFFF59E0B);

class _CertEntry {
  final String certId;
  final String personaId;
  final String personaNombre;
  final String rol;
  final String evento;
  final String fecha;
  final String carrera;
  final bool   esJurado;
  final String filialCarreraPath;

  String codigoCertificado;
  late final TextEditingController controller;

  _CertEntry({
    required this.certId,
    required this.personaId,
    required this.personaNombre,
    required this.rol,
    required this.evento,
    required this.fecha,
    required this.carrera,
    required this.esJurado,
    this.filialCarreraPath   = '',
    this.codigoCertificado   = '',
  }) {
    controller = TextEditingController(text: codigoCertificado);
  }

  void dispose() => controller.dispose();

  DocumentReference get docRef {
    if (esJurado) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(personaId)
          .collection('certificados')
          .doc(certId);
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(filialCarreraPath)
        .collection('students')
        .doc(personaId)
        .collection('certificados')
        .doc(certId);
  }
}

class AsignarCodigosScreen extends StatefulWidget {
  const AsignarCodigosScreen({super.key});

  @override
  State<AsignarCodigosScreen> createState() => _AsignarCodigosScreenState();
}

class _AsignarCodigosScreenState extends State<AsignarCodigosScreen>
    with SingleTickerProviderStateMixin {

  String _carrera           = '';
  String _facultad          = '';
  String _filial            = '';
  String _filialId          = '';
  String _filialCarreraPath = '';

  bool             _isLoading = true;
  bool             _huboError = false;
  List<_CertEntry> _entries   = [];

  String _searchQuery  = '';
  String _rolFiltro    = 'TODOS';
  String _estadoFiltro = 'TODOS';
  final _searchController = TextEditingController();
  Timer? _debounce;

  final Set<String> _guardando  = {};
  final Set<String> _guardados  = {};
  final Set<String> _eliminando = {};

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    for (final e in _entries) e.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (mounted) setState(() { _isLoading = true; _huboError = false; });
    final data = await PrefsHelper.getAdminCarreraData();
    if (data != null) {
      _carrera           = data['carrera']      ?? '';
      _facultad          = data['facultad']     ?? '';
      _filial            = data['filialNombre'] ?? '';
      _filialId          = data['filial']       ?? '';
      _filialCarreraPath = '${_filial}_$_carrera';
      await _cargarTodo();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _cargarTodo() async {
    try {
      final results = await Future.wait([
        _cargarCertsEstudiantes(),
        _cargarCertsJurados(),
      ]);
      final nuevas = [...results[0], ...results[1]];
      nuevas.sort((a, b) => a.personaNombre.compareTo(b.personaNombre));
      for (final e in _entries) e.dispose();
      if (mounted) setState(() { _entries = nuevas; _huboError = false; });
    } catch (_) {
      if (mounted) setState(() => _huboError = true);
    }
  }

  Future<List<_CertEntry>> _cargarCertsEstudiantes() async {
    try {
      final studentsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_filialCarreraPath)
          .collection('students')
          .get();

      final List<_CertEntry> lista = [];
      await Future.wait(studentsSnap.docs.map((studentDoc) async {
        final nombre = studentDoc.data()['name'] as String? ?? 'Sin nombre';
        final certsSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(_filialCarreraPath)
            .collection('students')
            .doc(studentDoc.id)
            .collection('certificados')
            .get();

        for (final certDoc in certsSnap.docs) {
          final d = certDoc.data();
          lista.add(_CertEntry(
            certId:            certDoc.id,
            personaId:         studentDoc.id,
            personaNombre:     d['nombreEstudiante'] as String? ?? nombre,
            rol:               d['rol']              as String? ?? 'ASISTENTE',
            evento:            d['evento']           as String? ?? '',
            fecha:             d['fecha']            as String? ?? '',
            carrera:           d['carrera']          as String? ?? _carrera,
            esJurado:          false,
            filialCarreraPath: _filialCarreraPath,
            codigoCertificado: d['codigoCertificado'] as String? ?? '',
          ));
        }
      }));
      return lista;
    } catch (e) {
      debugPrint('Error cargando certs estudiantes: $e');
      return [];
    }
  }

  Future<List<_CertEntry>> _cargarCertsJurados() async {
    try {
      final juradosSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'jurado')
          .where('filial',   isEqualTo: _filialId)
          .where('facultad', isEqualTo: _facultad)
          .where('carrera',  isEqualTo: _carrera)
          .get();

      final List<_CertEntry> lista = [];
      await Future.wait(juradosSnap.docs.map((juradoDoc) async {
        final nombre = juradoDoc.data()['name'] as String? ?? 'Sin nombre';
        final certsSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(juradoDoc.id)
            .collection('certificados')
            .get();

        for (final certDoc in certsSnap.docs) {
          final d = certDoc.data();
          lista.add(_CertEntry(
            certId:            certDoc.id,
            personaId:         juradoDoc.id,
            personaNombre:     d['nombreEstudiante'] as String? ?? nombre,
            rol:               d['rol']              as String? ?? 'JURADO',
            evento:            d['evento']           as String? ?? '',
            fecha:             d['fecha']            as String? ?? '',
            carrera:           d['carrera']          as String? ?? _carrera,
            esJurado:          true,
            codigoCertificado: d['codigoCertificado'] as String? ?? '',
          ));
        }
      }));
      return lista;
    } catch (e) {
      debugPrint('Error cargando certs jurados: $e');
      return [];
    }
  }

  Future<void> _guardarCodigo(_CertEntry entry) async {
    final codigo = entry.controller.text.trim();
    if (_guardando.contains(entry.certId)) return;
    if (mounted) setState(() => _guardando.add(entry.certId));
    try {
      await entry.docRef.update({'codigoCertificado': codigo});
      entry.codigoCertificado = codigo;
      if (mounted) {
        setState(() {
          _guardando.remove(entry.certId);
          _guardados.add(entry.certId);
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _guardados.remove(entry.certId));
        });
        _snack('✅ Código guardado para ${entry.personaNombre}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando.remove(entry.certId));
        _snack('❌ Error al guardar: $e');
      }
    }
  }

  Future<void> _eliminarCertificado(_CertEntry entry) async {
    final confirmar = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.delete_forever, color: Colors.red, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Eliminar certificado',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Estás seguro de eliminar este certificado?',
                style: TextStyle(fontSize: 14, color: _kTextoGris),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dialogoDetalle(Icons.person_outline, entry.personaNombre),
                    const SizedBox(height: 4),
                    _dialogoDetalle(Icons.badge_outlined, 'Rol: ${entry.rol}'),
                    const SizedBox(height: 4),
                    _dialogoDetalle(Icons.event_outlined, entry.evento, maxLines: 2),
                    if (entry.codigoCertificado.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _dialogoDetalle(
                        Icons.qr_code_2_rounded,
                        'Código: ${entry.codigoCertificado}',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Esta acción no se puede deshacer.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: _kTextoGris)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Eliminar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    if (mounted) setState(() => _eliminando.add(entry.certId));
    try {
      await entry.docRef.delete();
      if (mounted) {
        setState(() {
          _eliminando.remove(entry.certId);
          _entries.removeWhere((e) => e.certId == entry.certId);
        });
        entry.dispose();
        _snack('🗑️ Certificado eliminado de ${entry.personaNombre}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _eliminando.remove(entry.certId));
        _snack('❌ Error al eliminar: $e');
      }
    }
  }

  Widget _dialogoDetalle(IconData icon, String texto, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: Colors.red.shade400),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.red.shade700),
          ),
        ),
      ],
    );
  }

  List<_CertEntry> get _entriesFiltradas {
    return _entries.where((e) {
      final tab = _tabController.index;
      if (tab == 0 &&  e.esJurado) return false;
      if (tab == 1 && !e.esJurado) return false;
      if (_rolFiltro    != 'TODOS'      && e.rol != _rolFiltro)            return false;
      if (_estadoFiltro == 'CON_CODIGO' && e.codigoCertificado.isEmpty)    return false;
      if (_estadoFiltro == 'SIN_CODIGO' && e.codigoCertificado.isNotEmpty) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return e.personaNombre.toLowerCase().contains(q) ||
            e.evento.toLowerCase().contains(q) ||
            e.codigoCertificado.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  int get _totalEstudiantes => _entries.where((e) => !e.esJurado).length;
  int get _totalJurados     => _entries.where((e) =>  e.esJurado).length;
  int get _conCodigo        => _entries.where((e) => e.codigoCertificado.isNotEmpty).length;
  int get _sinCodigo        => _entries.length - _conCodigo;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _kPrimario,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPrimario,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _kFondo,
                borderRadius: BorderRadius.only(
                  topLeft:  Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _kPrimario))
                  : _buildBody(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Semantics(
              label: 'Logo de la aplicación',
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                  semanticLabel: 'Logo',
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.qr_code_2_rounded, color: _kPrimario, size: 26,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestionar Certificados',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Asigna códigos y administra certificados enviados',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Semantics(
              label: 'Recargar certificados',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 22),
                onPressed: () async {
                  setState(() => _isLoading = true);
                  await _cargarTodo();
                  if (mounted) setState(() => _isLoading = false);
                },
                tooltip: 'Recargar',
              ),
            ),
            Semantics(
              label: 'Cerrar pantalla',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _isLoading
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _buildEstadisticas(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadisticas() {
    return Row(children: [
      Expanded(child: _statChip(Icons.people_outlined, '$_totalEstudiantes', 'Estudiantes')),
      const SizedBox(width: 8),
      Expanded(child: _statChip(Icons.gavel_rounded, '$_totalJurados', 'Jurados')),
      const SizedBox(width: 8),
      Expanded(child: _statChip(Icons.check_circle_outline, '$_conCodigo', 'Con código', color: _kVerde)),
      const SizedBox(width: 8),
      Expanded(child: _statChip(Icons.radio_button_unchecked, '$_sinCodigo', 'Sin código', color: _kAmbar)),
    ]);
  }

  Widget _statChip(IconData icon, String valor, String label,
      {Color color = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 9),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(children: [
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _tabController,
          labelColor: _kPrimario,
          unselectedLabelColor: _kTextoGrisClaro,
          indicatorColor: _kPrimario,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          onTap: (_) => setState(() {}),
          tabs: [
            Tab(text: 'Estudiantes ($_totalEstudiantes)'),
            Tab(text: 'Jurados ($_totalJurados)'),
          ],
        ),
      ),
      _buildFiltros(),
      Expanded(child: _buildLista()),
    ]);
  }

  Widget _buildFiltros() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(children: [
        TextField(
          controller: _searchController,
          onChanged: (q) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 250), () {
              if (mounted) setState(() => _searchQuery = q);
            });
          },
          decoration: InputDecoration(
            hintText: 'Buscar por nombre, evento o código...',
            hintStyle: const TextStyle(fontSize: 12, color: _kTextoGrisClaro),
            prefixIcon: const Icon(Icons.search, color: _kTextoGrisClaro, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear,
                        size: 18, color: _kTextoGrisClaro),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    tooltip: 'Limpiar búsqueda',
                  )
                : null,
            filled: true,
            fillColor: _kCampoFondo2,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _filtroChip('Todos', _estadoFiltro == 'TODOS',
                    () => setState(() => _estadoFiltro = 'TODOS')),
                const SizedBox(width: 6),
                _filtroChip('Sin código', _estadoFiltro == 'SIN_CODIGO',
                    () => setState(() => _estadoFiltro = 'SIN_CODIGO'),
                    color: _kAmbar),
                const SizedBox(width: 6),
                _filtroChip('Con código', _estadoFiltro == 'CON_CODIGO',
                    () => setState(() => _estadoFiltro = 'CON_CODIGO'),
                    color: _kVerde),
                const SizedBox(width: 10),
                Container(width: 1, height: 20, color: Colors.grey.shade300),
                const SizedBox(width: 10),
                for (final rol in [
                  'TODOS', 'ASISTENTE', 'PONENTE', 'JURADO', 'ORGANIZADOR'
                ]) ...[
                  _filtroChip(
                    rol == 'TODOS' ? 'Todos los roles' : rol,
                    _rolFiltro == rol,
                    () => setState(() => _rolFiltro = rol),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _filtroChip(String label, bool selected, VoidCallback onTap,
      {Color? color}) {
    final c = color ?? _kPrimario;
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? c.withOpacity(0.12) : _kCampoFondo2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? c : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? c : _kTextoGris,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLista() {
    if (_huboError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                'No se pudieron cargar los certificados',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  setState(() => _isLoading = true);
                  await _cargarTodo();
                  if (mounted) setState(() => _isLoading = false);
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimario,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final lista = _entriesFiltradas;

    if (lista.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                _entries.isEmpty
                    ? 'No hay certificados enviados aún'
                    : 'Sin resultados para los filtros aplicados',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              if (_entries.isNotEmpty) ...[
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _searchQuery  = '';
                    _rolFiltro    = 'TODOS';
                    _estadoFiltro = 'TODOS';
                    _searchController.clear();
                  }),
                  icon: const Icon(Icons.filter_list_off_rounded,
                      size: 16, color: _kPrimario),
                  label: const Text('Limpiar filtros',
                      style: TextStyle(color: _kPrimario, fontSize: 13)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: lista.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final entry = lista[i];
        return _buildEntryCard(entry, key: ValueKey(entry.certId));
      },
    );
  }

  Widget _buildEntryCard(_CertEntry entry, {Key? key}) {
    final guardando   = _guardando.contains(entry.certId);
    final guardado    = _guardados.contains(entry.certId);
    final eliminando  = _eliminando.contains(entry.certId);
    final tieneCodigo = entry.codigoCertificado.isNotEmpty;
    final rolColor    = _colorPorRol(entry.rol);

    return Card(
      key: key,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: rolColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      entry.personaNombre.isNotEmpty
                          ? entry.personaNombre[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: rolColor,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.personaNombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _kTextoOscuro,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _rolBadge(entry.rol, rolColor),
                          if (entry.esJurado)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F6E56).withOpacity(0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Jurado',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF0F6E56),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _codigoIndicador(tieneCodigo, guardado),
              ],
            ),

            const SizedBox(height: 10),

            Row(children: [
              const Icon(Icons.event_outlined,
                  size: 12, color: _kTextoGrisClaro),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  entry.evento,
                  style: const TextStyle(fontSize: 11, color: _kTextoGris),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (entry.fecha.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  entry.fecha,
                  style: const TextStyle(
                      fontSize: 10, color: _kTextoGrisClaro),
                ),
              ],
            ]),

            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade100, height: 1),
            const SizedBox(height: 12),

            const Text(
              'Código del certificado',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kPrimario,
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: entry.controller,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _kTextoOscuro,
                    fontFamily: 'monospace',
                  ),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'Ej: CERT-2024-001',
                    hintStyle: const TextStyle(
                        fontSize: 12, color: _kTextoGrisClaro),
                    prefixIcon: const Icon(Icons.qr_code_2_rounded,
                        size: 18, color: _kTextoGrisClaro),
                    suffixText: tieneCodigo ? null : 'vacío',
                    suffixStyle: const TextStyle(
                        fontSize: 10, color: _kTextoGrisClaro),
                    filled: true,
                    fillColor: _kCampoFondo2,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: _kPrimario, width: 1.5)),
                  ),
                  onSubmitted: (_) => _guardarCodigo(entry),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                height: 48,
                child: Semantics(
                  label: 'Guardar código de ${entry.personaNombre}',
                  button: true,
                  child: ElevatedButton(
                    onPressed: (guardando || eliminando)
                        ? null
                        : () => _guardarCodigo(entry),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: guardado ? _kVerde : _kPrimario,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _kPrimario40,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Icon(
                            guardado
                                ? Icons.check_rounded
                                : Icons.save_rounded,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ]),

            if (tieneCodigo) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.info_outline, size: 12, color: _kVerde),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Código actual: ${entry.codigoCertificado}',
                    style: const TextStyle(fontSize: 10, color: _kVerde),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ],

            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade100, height: 1),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: eliminando
                  ? const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.red, strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Eliminando...',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.red)),
                        ],
                      ),
                    )
                  : Semantics(
                      label: 'Eliminar certificado de ${entry.personaNombre}',
                      button: true,
                      child: OutlinedButton.icon(
                        onPressed: (guardando || eliminando)
                            ? null
                            : () => _eliminarCertificado(entry),
                        icon: const Icon(Icons.delete_outline,
                            size: 16, color: Colors.red),
                        label: const Text(
                          'Eliminar este certificado',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(
                              color: Colors.red.shade200, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rolBadge(String rol, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        rol,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _codigoIndicador(bool tieneCodigo, bool recienGuardado) {
    if (recienGuardado) {
      return Container(
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _kVerde.withOpacity(0.10),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_circle_rounded,
            color: _kVerde, size: 18),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 90),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tieneCodigo
            ? _kVerde.withOpacity(0.10)
            : _kAmbar.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          tieneCodigo ? Icons.check_circle_outline : Icons.pending_outlined,
          size: 12,
          color: tieneCodigo ? _kVerde : _kAmbar,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            tieneCodigo ? 'Asignado' : 'Pendiente',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: tieneCodigo ? _kVerde : _kAmbar,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }

  Color _colorPorRol(String rol) {
    switch (rol) {
      case 'JURADO':      return const Color(0xFF0F6E56);
      case 'PONENTE':     return const Color(0xFF7C3AED);
      case 'ORGANIZADOR': return const Color(0xFFB45309);
      default:            return _kPrimario;
    }
  }
}