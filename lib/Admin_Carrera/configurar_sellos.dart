import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';

class ConfigurarSellosScreen extends StatefulWidget {
  final String filialId;
  final String filialNombre;
  final String facultad;
  final String carrera;

  const ConfigurarSellosScreen({
    super.key,
    required this.filialId,
    required this.filialNombre,
    required this.facultad,
    required this.carrera,
  });

  @override
  State<ConfigurarSellosScreen> createState() =>
      _ConfigurarSellosScreenState();
}

class _ConfigurarSellosScreenState extends State<ConfigurarSellosScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // ── Datos de sesión ────────────────────────────────────────────
  String? _filialId;
  String? _facultad;
  String? _carreraId;
  String? _carreraNombre;
  bool _isLoadingSession = true;

  // ── Eventos ────────────────────────────────────────────────────
  List<Map<String, dynamic>> _eventos = [];
  String? _eventoSeleccionadoId;
  String? _eventoSeleccionadoNombre;
  bool _isLoadingEventos = false;

  // ── Config de sellos ───────────────────────────────────────────
  bool _modoNumero = true;
  int _metaSellos = 10;
  final TextEditingController _metaCtrl = TextEditingController(text: '10');
  bool _isLoadingConfig = false;
  bool _isSaving = false;

  String _docId(String eventoId) =>
      '${_filialId}_${_facultad}_${_carreraId}_$eventoId'
          .replaceAll(' ', '_');

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _loadSessionData();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _metaCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // CARGAR SESIÓN
  // ═══════════════════════════════════════════════════════════════
  Future<void> _loadSessionData() async {
    setState(() => _isLoadingSession = true);
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData != null) {
        setState(() {
          _filialId      = adminData['filial'];
          _facultad      = adminData['facultad'];
          _carreraId     = adminData['carreraId'] ?? adminData['carrera'];
          _carreraNombre = adminData['carrera'];
        });
        await _cargarEventos();
      }
    } catch (e) {
      _showSnack('Error al cargar sesión: $e', isError: true);
    } finally {
      setState(() => _isLoadingSession = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CARGAR EVENTOS
  // ═══════════════════════════════════════════════════════════════
  Future<void> _cargarEventos() async {
    setState(() => _isLoadingEventos = true);
    try {
      final snap = await _firestore
          .collection('events')
          .where('filialId', isEqualTo: _filialId)
          .where('facultad', isEqualTo: _facultad)
          .where('carreraId', isEqualTo: _carreraId)
          .orderBy('createdAt', descending: true)
          .get();

      final lista = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Sin nombre',
          'date': data['fecha'],
        };
      }).toList();

      setState(() => _eventos = lista);
      _animCtrl.forward();
    } catch (e) {
      _showSnack('Error al cargar eventos: $e', isError: true);
    } finally {
      setState(() => _isLoadingEventos = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CARGAR CONFIG DEL EVENTO
  // ═══════════════════════════════════════════════════════════════
  Future<void> _cargarConfigEvento(String eventoId) async {
    setState(() => _isLoadingConfig = true);
    try {
      final doc = await _firestore
          .collection('sellos_asistencia')
          .doc(_docId(eventoId))
          .get();

      if (doc.exists) {
        final meta = doc.data()!['meta'];
        if (meta == 'libre') {
          setState(() {
            _modoNumero = false;
            _metaSellos = 10;
            _metaCtrl.text = '10';
          });
        } else if (meta is int && meta > 0) {
          setState(() {
            _modoNumero = true;
            _metaSellos = meta;
            _metaCtrl.text = meta.toString();
          });
        } else {
          _resetConfig();
        }
      } else {
        _resetConfig();
      }
    } catch (e) {
      _resetConfig();
    } finally {
      setState(() => _isLoadingConfig = false);
    }
  }

  void _resetConfig() => setState(() {
        _modoNumero = true;
        _metaSellos = 10;
        _metaCtrl.text = '10';
      });

  // ═══════════════════════════════════════════════════════════════
  // GUARDAR
  // ═══════════════════════════════════════════════════════════════
  Future<void> _guardar() async {
    if (_eventoSeleccionadoId == null) return;

    if (_modoNumero) {
      final parsed = int.tryParse(_metaCtrl.text.trim());
      if (parsed == null || parsed < 1 || parsed > 200) {
        _showSnack('Ingresa un número entre 1 y 200', isError: true);
        return;
      }
      _metaSellos = parsed;
    }

    setState(() => _isSaving = true);
    try {
      await _firestore
          .collection('sellos_asistencia')
          .doc(_docId(_eventoSeleccionadoId!))
          .set({
        'filialId':       _filialId,
        'facultad':       _facultad,
        'carreraId':      _carreraId,
        'carreraNombre':  _carreraNombre,
        'eventoId':       _eventoSeleccionadoId,
        'eventoNombre':   _eventoSeleccionadoNombre,
        'meta':           _modoNumero ? _metaSellos : 'libre',
        'updatedAt':      FieldValue.serverTimestamp(),
      });
      _showSnack('Configuración guardada para "$_eventoSeleccionadoNombre"');
    } catch (e) {
      _showSnack('Error al guardar: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      appBar: AppBar(
        title: const Text('Configurar Sellos',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.school, color: Colors.white60, size: 13),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    _carreraNombre ?? '',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: (_isLoadingSession || _isLoadingEventos)
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 4),
                            _buildSelectorEvento(),
                            const SizedBox(height: 20),
                            AnimatedOpacity(
                              opacity: _eventoSeleccionadoId != null
                                  ? 1.0
                                  : 0.35,
                              duration: const Duration(milliseconds: 300),
                              child: IgnorePointer(
                                ignoring: _eventoSeleccionadoId == null,
                                child: _isLoadingConfig
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(32),
                                          child: CircularProgressIndicator(
                                              color: Color(0xFF1E3A5F)),
                                        ),
                                      )
                                    : Column(
                                        children: [
                                          _buildInfoCard(),
                                          const SizedBox(height: 20),
                                          _buildModoSelector(),
                                          const SizedBox(height: 20),
                                          if (_modoNumero)
                                            _buildNumeroInput(),
                                          if (!_modoNumero)
                                            _buildModoLibreInfo(),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildBottomBar(),
                ],
              ),
            ),
    );
  }

  // ── Selector de evento ─────────────────────────────────────────
  Widget _buildSelectorEvento() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event,
                    color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Seleccionar evento',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'Requerido',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_eventos.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_busy, color: Colors.grey.shade400),
                  const SizedBox(width: 10),
                  Text('No hay eventos disponibles',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _eventoSeleccionadoId != null
                      ? const Color(0xFF2563EB)
                      : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _eventoSeleccionadoId,
                  isExpanded: true,
                  hint: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.event_outlined,
                            size: 18, color: Colors.grey.shade500),
                        const SizedBox(width: 8),
                        Text('Elige un evento...',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  icon: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(Icons.arrow_drop_down,
                        color: Colors.grey.shade600),
                  ),
                  items: _eventos.map((evento) {
                    final date = evento['date'] != null
                        ? (evento['date'] as dynamic)?.toDate()
                        : null;
                    final dateStr = date != null
                        ? '${date.day}/${date.month}/${date.year}'
                        : '';
                    return DropdownMenuItem<String?>(
                      value: evento['id'] as String,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.event,
                                size: 18, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(
                                    evento['name'],
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1E3A5F),
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (dateStr.isNotEmpty)
                                    Text(dateStr,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? value) async {
                    if (value == null) return;
                    final nombre = _eventos.firstWhere(
                        (e) => e['id'] == value)['name'] as String;
                    setState(() {
                      _eventoSeleccionadoId = value;
                      _eventoSeleccionadoNombre = nombre;
                    });
                    await _cargarConfigEvento(value);
                  },
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ),
          if (_eventoSeleccionadoId != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF2563EB).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF2563EB), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _eventoSeleccionadoNombre ?? '',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E3A5F),
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Info card ──────────────────────────────────────────────────
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF7B61FF).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFF7B61FF).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7B61FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_outline,
                color: Color(0xFF7B61FF), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Define cuántos sellos deben completar los estudiantes para este evento.',
              style: TextStyle(
                  fontSize: 12, color: Color(0xFF4A3F8C), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Modo selector ──────────────────────────────────────────────
  Widget _buildModoSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tipo de meta',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F))),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildModoOpcion(
                  titulo: 'Número fijo',
                  descripcion: 'Los estudiantes completan N sellos',
                  icono: Icons.pin_outlined,
                  seleccionado: _modoNumero,
                  onTap: () => setState(() => _modoNumero = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModoOpcion(
                  titulo: 'Libre',
                  descripcion: 'Sin límite de sellos',
                  icono: Icons.all_inclusive,
                  seleccionado: !_modoNumero,
                  onTap: () => setState(() => _modoNumero = false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModoOpcion({
    required String titulo,
    required String descripcion,
    required IconData icono,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: seleccionado
              ? const Color(0xFF1E3A5F).withOpacity(0.07)
              : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionado
                ? const Color(0xFF1E3A5F)
                : Colors.grey.shade300,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icono,
                color: seleccionado
                    ? const Color(0xFF1E3A5F)
                    : Colors.grey.shade500,
                size: 28),
            const SizedBox(height: 8),
            Text(titulo,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: seleccionado
                        ? const Color(0xFF1E3A5F)
                        : Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(descripcion,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    color: seleccionado
                        ? const Color(0xFF1E3A5F).withOpacity(0.7)
                        : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  // ── Input número ───────────────────────────────────────────────
  Widget _buildNumeroInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cantidad de sellos',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F))),
          const SizedBox(height: 4),
          Text('Los estudiantes verán esta cantidad de sellos vacíos',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStepButton(
                icono: Icons.remove,
                onTap: () {
                  final val =
                      int.tryParse(_metaCtrl.text) ?? _metaSellos;
                  if (val > 1) {
                    setState(() {
                      _metaSellos = val - 1;
                      _metaCtrl.text = _metaSellos.toString();
                    });
                  }
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _metaCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F)),
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF1E3A5F), width: 2)),
                  ),
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null) {
                      setState(() => _metaSellos = parsed);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              _buildStepButton(
                icono: Icons.add,
                onTap: () {
                  final val =
                      int.tryParse(_metaCtrl.text) ?? _metaSellos;
                  if (val < 200) {
                    setState(() {
                      _metaSellos = val + 1;
                      _metaCtrl.text = _metaSellos.toString();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [5, 10, 15, 20, 30, 50].map((n) {
              final sel = (int.tryParse(_metaCtrl.text) ?? 0) == n;
              return GestureDetector(
                onTap: () => setState(() {
                  _metaSellos = n;
                  _metaCtrl.text = n.toString();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF1E3A5F)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel
                            ? const Color(0xFF1E3A5F)
                            : Colors.grey.shade300),
                  ),
                  child: Text('$n',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel
                              ? Colors.white
                              : Colors.grey.shade700)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton(
      {required IconData icono, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF1E3A5F).withOpacity(0.2)),
        ),
        child: Icon(icono, color: const Color(0xFF1E3A5F)),
      ),
    );
  }

  Widget _buildModoLibreInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.all_inclusive,
                color: Colors.green.shade700, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modo libre activado',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800)),
                const SizedBox(height: 4),
                Text(
                  'Los estudiantes podrán acumular sellos sin límite. Solo se mostrarán los sellos ganados.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Barra inferior ─────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed:
              (_isSaving || _eventoSeleccionadoId == null) ? null : _guardar,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded, size: 20),
          label: Text(
            _eventoSeleccionadoId == null
                ? 'Selecciona un evento primero'
                : (_isSaving ? 'Guardando...' : 'Guardar configuración'),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _eventoSeleccionadoId == null
                ? Colors.grey.shade400
                : const Color(0xFF1E3A5F),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}