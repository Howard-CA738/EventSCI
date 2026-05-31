import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';

class NotasPorSellosScreen extends StatefulWidget {
  final String filialId;
  final String filialNombre;
  final String facultad;
  final String carrera;

  const NotasPorSellosScreen({
    super.key,
    required this.filialId,
    required this.filialNombre,
    required this.facultad,
    required this.carrera,
  });

  @override
  State<NotasPorSellosScreen> createState() => _NotasPorSellosScreenState();
}

class _NotasPorSellosScreenState extends State<NotasPorSellosScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // ── Sesión ─────────────────────────────────────────────────────
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

  // ── Meta y notas ───────────────────────────────────────────────
  int _metaSellos = 0;
  bool _tieneConfig = false;
  List<Map<String, dynamic>> _notasEstudiantes = [];
  bool _isLoadingNotas = false;

  // ── Búsqueda ───────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ── Orden ──────────────────────────────────────────────────────
  bool _ordenDesc = true; // true = mayor nota primero

  String _docIdConfig(String eventoId) =>
      '${_filialId}_${_facultad}_${_carreraId}_$eventoId'
          .replaceAll(' ', '_');

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadSession();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // SESIÓN
  // ═══════════════════════════════════════════════════════════════
  Future<void> _loadSession() async {
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
  // EVENTOS
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

      setState(() {
        _eventos = snap.docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': d['name'] ?? 'Sin nombre',
            'date': d['fecha'],
          };
        }).toList();
      });
      _animCtrl.forward();
    } catch (e) {
      _showSnack('Error al cargar eventos: $e', isError: true);
    } finally {
      setState(() => _isLoadingEventos = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CARGAR NOTAS DEL EVENTO
  // ═══════════════════════════════════════════════════════════════
  Future<void> _cargarNotasDeEvento(String eventoId) async {
    setState(() {
      _isLoadingNotas = true;
      _notasEstudiantes = [];
      _metaSellos = 0;
      _tieneConfig = false;
    });

    try {
      // 1. Leer la meta configurada
      final docIdConfig = _docIdConfig(eventoId);
      debugPrint('📋 Buscando config en: sellos_asistencia/$docIdConfig');

      final configDoc = await _firestore
          .collection('sellos_asistencia')
          .doc(docIdConfig)
          .get();

      debugPrint('📋 Config existe: ${configDoc.exists}');
      if (configDoc.exists) {
        debugPrint('📋 Config data: ${configDoc.data()}');
      }

      if (!configDoc.exists) {
        // Intentar búsqueda alternativa: listar docs del evento
        // para depurar si el docId no coincide
        debugPrint('⚠️ Config no encontrada. filialId=$_filialId facultad=$_facultad carreraId=$_carreraId eventoId=$eventoId');
        setState(() {
          _tieneConfig = false;
          _isLoadingNotas = false;
        });
        return;
      }

      final meta = configDoc.data()!['meta'];
      debugPrint('📋 Meta leída: $meta (tipo: ${meta.runtimeType})');

      // Aceptar tanto int como double (Firestore a veces los guarda como double)
      final int metaInt;
      if (meta is int && meta > 0) {
        metaInt = meta;
      } else if (meta is double && meta > 0) {
        metaInt = meta.toInt();
      } else {
        debugPrint('⚠️ Meta inválida: $meta');
        setState(() {
          _tieneConfig = false;
          _isLoadingNotas = false;
        });
        return;
      }

      _metaSellos = metaInt;
      _tieneConfig = true;
      debugPrint('✅ Meta configurada: $_metaSellos sellos');

      // 2. Cargar todos los estudiantes de la carrera
      // El log revela que los docs en Firestore usan filialNombre + carreraNombre
      // ej: "Campus Juliaca_Psicología" — NO el filialId ni el carreraId (UUID)
      // Probamos 4 combinaciones en orden de mayor a menor probabilidad
      final candidatos = [
        '${widget.filialNombre}_$_carreraNombre',   // "Campus Juliaca_Psicología"  ← más probable
        '${widget.filialNombre}_$_carreraId',        // "Campus Juliaca_qRD2t..."
        '${_filialId}_$_carreraNombre',              // "juliaca_Psicología"
        '${_filialId}_$_carreraId',                  // "juliaca_qRD2t..."
      ];

      List<QueryDocumentSnapshot<Map<String, dynamic>>> estudiantesDocs = [];

      for (final path in candidatos) {
        debugPrint('👥 Intentando: users/$path/students');
        final snap = await _firestore
            .collection('users')
            .doc(path)
            .collection('students')
            .get();
        debugPrint('   → ${snap.docs.length} estudiantes');
        if (snap.docs.isNotEmpty) {
          estudiantesDocs = snap.docs;
          debugPrint('✅ Estudiantes encontrados en: $path');
          break;
        }
      }

      if (estudiantesDocs.isEmpty) {
        debugPrint('❌ No se encontraron estudiantes. filialNombre=${widget.filialNombre} filialId=$_filialId carreraNombre=$_carreraNombre carreraId=$_carreraId');
        setState(() {
          _notasEstudiantes = [];
          _tieneConfig = true;
          _isLoadingNotas = false;
        });
        return;
      }

      // 3. Para cada estudiante, contar sus scans en el evento
      final List<Map<String, dynamic>> notas = [];

      await Future.wait(estudiantesDocs.map((studentDoc) async {
        final studentData = studentDoc.data();
        final studentId = studentDoc.id;

        int totalSellos = 0;
        try {
          final scansSnap = await _firestore
              .collection('events')
              .doc(eventoId)
              .collection('asistencias')
              .doc(studentId)
              .collection('scans')
              .get();
          totalSellos = scansSnap.docs.length;
        } catch (e) {
          debugPrint('⚠️ Error contando scans de $studentId: $e');
          totalSellos = 0;
        }

        final nota = _metaSellos > 0
            ? (totalSellos / _metaSellos * 20).clamp(0.0, 20.0)
            : 0.0;

        notas.add({
          'studentId':   studentId,
          'name':        studentData['name'] ?? 'Sin nombre',
          'username':    studentData['username'] ?? '',
          'codigo':      studentData['codigoUniversitario'] ?? '',
          'ciclo':       studentData['ciclo']?.toString() ?? '',
          'grupo':       studentData['grupo']?.toString() ?? '',
          'totalSellos': totalSellos,
          'nota':        nota,
        });
      }));

      debugPrint('✅ Notas calculadas para ${notas.length} estudiantes');

      // Ordenar por nota descendente por defecto
      notas.sort((a, b) =>
          (b['nota'] as double).compareTo(a['nota'] as double));

      setState(() {
        _notasEstudiantes = notas;
        _ordenDesc = true;
      });

      _animCtrl
        ..reset()
        ..forward();
    } catch (e, stack) {
      debugPrint('❌ Error en _cargarNotasDeEvento: $e\n$stack');
      _showSnack('Error al cargar notas: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingNotas = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════
  List<Map<String, dynamic>> get _notasFiltradas {
    var lista = _notasEstudiantes.where((e) {
      final q = _searchQuery.toLowerCase();
      if (q.isEmpty) return true;
      return (e['name'] as String).toLowerCase().contains(q) ||
          (e['username'] as String).toLowerCase().contains(q) ||
          (e['codigo'] as String).toLowerCase().contains(q);
    }).toList();

    lista.sort((a, b) {
      final cmp =
          (a['nota'] as double).compareTo(b['nota'] as double);
      return _ordenDesc ? -cmp : cmp;
    });

    return lista;
  }

  Color _colorNota(double nota) {
    if (nota >= 17) return const Color(0xFF059669);
    if (nota >= 14) return const Color(0xFF2563EB);
    if (nota >= 11) return const Color(0xFFD97706);
    if (nota >= 7)  return const Color(0xFFEA580C);
    return const Color(0xFFDC2626);
  }

  String _etiquetaNota(double nota) {
    if (nota >= 17) return 'Excelente';
    if (nota >= 14) return 'Bueno';
    if (nota >= 11) return 'Regular';
    if (nota >= 7)  return 'Bajo';
    return 'Deficiente';
  }

  void _toggleOrden() {
    setState(() => _ordenDesc = !_ordenDesc);
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      appBar: AppBar(
        title: const Text('Notas por Sellos',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_eventoSeleccionadoId != null && !_isLoadingNotas)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => _cargarNotasDeEvento(_eventoSeleccionadoId!),
              tooltip: 'Actualizar',
            ),
        ],
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
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: (_isLoadingSession || _isLoadingEventos)
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
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
                    child: Column(
                      children: [
                        // ── Selector de evento ─────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: _buildSelectorEvento(),
                        ),

                        // ── Contenido ──────────────────────────────
                        Expanded(
                          child: _isLoadingNotas
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                          color: Color(0xFF1E3A5F)),
                                      SizedBox(height: 14),
                                      Text('Calculando notas...',
                                          style: TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 13)),
                                    ],
                                  ),
                                )
                              : _eventoSeleccionadoId == null
                                  ? _buildEstadoSinEvento()
                                  : !_tieneConfig
                                      ? _buildEstadoSinConfig()
                                      : _buildContenidoNotas(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
              color: Colors.black.withValues(alpha: 0.05),
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
                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event, color: Color(0xFF16A34A), size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Seleccionar evento',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F))),
            ],
          ),
          const SizedBox(height: 12),
          if (_eventos.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
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
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _eventoSeleccionadoId != null
                      ? const Color(0xFF16A34A)
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
                    child: Text('Elige un evento...',
                        style:
                            TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ),
                  icon: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child:
                        Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.event,
                                size: 18, color: Color(0xFF16A34A)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(evento['name'],
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF1E3A5F),
                                          fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis),
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
                    final nombre = _eventos
                        .firstWhere((e) => e['id'] == value)['name'] as String;
                    setState(() {
                      _eventoSeleccionadoId = value;
                      _eventoSeleccionadoNombre = nombre;
                      _searchQuery = '';
                      _searchCtrl.clear();
                    });
                    await _cargarNotasDeEvento(value);
                  },
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Estado sin evento ──────────────────────────────────────────
  Widget _buildEstadoSinEvento() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const Text('Selecciona un evento',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F))),
            const SizedBox(height: 8),
            Text(
              'Elige un evento para ver las notas de los estudiantes según sus sellos',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Estado sin config ──────────────────────────────────────────
  Widget _buildEstadoSinConfig() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orange.shade200, width: 2),
              ),
              child:
                  Icon(Icons.settings_outlined, size: 48, color: Colors.orange.shade600),
            ),
            const SizedBox(height: 20),
            const Text('Sin configuración de sellos',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F))),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                'Este evento no tiene una meta de sellos configurada. Ve a "Configurar sellos" para definirla.',
                style:
                    TextStyle(fontSize: 13, color: Colors.orange.shade800, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Contenido principal de notas ───────────────────────────────
  Widget _buildContenidoNotas() {
    final filtrados = _notasFiltradas;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        children: [
          // ── Resumen + búsqueda ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                _buildResumenCard(filtrados),
                const SizedBox(height: 12),
                _buildBarraBusquedaYOrden(filtrados),
              ],
            ),
          ),

          // ── Lista de estudiantes ─────────────────────────────────
          Expanded(
            child: filtrados.isEmpty
                ? Center(
                    child: Text(
                      'No se encontraron estudiantes',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    itemCount: filtrados.length,
                    itemBuilder: (context, index) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration:
                            Duration(milliseconds: 200 + (index * 40)),
                        curve: Curves.easeOut,
                        builder: (ctx, val, _) => Transform.translate(
                          offset: Offset(0, 16 * (1 - val)),
                          child: Opacity(
                            opacity: val,
                            child: _buildEstudianteCard(
                                filtrados[index], index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Card resumen estadístico ───────────────────────────────────
  Widget _buildResumenCard(List<Map<String, dynamic>> lista) {
    if (lista.isEmpty) return const SizedBox.shrink();

    final totalConSellos =
        lista.where((e) => (e['totalSellos'] as int) > 0).length;
    final promedio =
        lista.map((e) => e['nota'] as double).reduce((a, b) => a + b) /
            lista.length;
    final aprobados =
        lista.where((e) => (e['nota'] as double) >= 11).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1E3A5F).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _eventoSeleccionadoNombre ?? '',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Meta: $_metaSellos sellos',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatItem(
                  label: 'Total',
                  value: '${lista.length}',
                  icon: Icons.people_alt_rounded,
                  color: Colors.white),
              _buildStatDivider(),
              _buildStatItem(
                  label: 'Con sellos',
                  value: '$totalConSellos',
                  icon: Icons.workspace_premium,
                  color: Colors.amber),
              _buildStatDivider(),
              _buildStatItem(
                  label: 'Aprobados',
                  value: '$aprobados',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF86EFAC)),
              _buildStatDivider(),
              _buildStatItem(
                  label: 'Promedio',
                  value: promedio.toStringAsFixed(1),
                  icon: Icons.bar_chart_rounded,
                  color: const Color(0xFF93C5FD)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withValues(alpha: 0.2),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  // ── Barra búsqueda y orden ─────────────────────────────────────
  Widget _buildBarraBusquedaYOrden(List<Map<String, dynamic>> lista) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style:
                  const TextStyle(fontSize: 13, color: Color(0xFF1E3A5F)),
              decoration: InputDecoration(
                hintText: 'Buscar estudiante...',
                hintStyle:
                    TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: Icon(Icons.search,
                    color: Colors.grey.shade400, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close,
                            color: Colors.grey.shade400, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _toggleOrden,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _ordenDesc
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _ordenDesc ? 'Mayor' : 'Menor',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Card de estudiante ─────────────────────────────────────────
  Widget _buildEstudianteCard(Map<String, dynamic> datos, int index) {
    final nota = datos['nota'] as double;
    final totalSellos = datos['totalSellos'] as int;
    final progreso = (totalSellos / _metaSellos).clamp(0.0, 1.0);
    final color = _colorNota(nota);
    final etiqueta = _etiquetaNota(nota);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila superior: posición + nombre + nota
            Row(
              children: [
                // Número de posición
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: index < 3
                        ? [
                            const Color(0xFFFFD700),
                            const Color(0xFFC0C0C0),
                            const Color(0xFFCD7F32),
                          ][index]
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: index < 3
                              ? Colors.white
                              : Colors.grey.shade600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Nombre y datos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        datos['name'] as String,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if ((datos['username'] as String).isNotEmpty) ...[
                            Text(
                              '@${datos['username']}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if ((datos['ciclo'] as String).isNotEmpty)
                            _buildMiniTag('Ciclo ${datos['ciclo']}',
                                Colors.blue.shade600),
                          if ((datos['grupo'] as String).isNotEmpty) ...[
                            const SizedBox(width: 4),
                            _buildMiniTag(
                                'Grupo ${datos['grupo']}',
                                Colors.purple.shade600),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Nota
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: color.withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: Text(
                        nota.toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(etiqueta,
                        style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Barra de progreso
            Row(
              children: [
                Icon(Icons.workspace_premium,
                    size: 14, color: Colors.amber.shade600),
                const SizedBox(width: 6),
                Text(
                  '$totalSellos / $_metaSellos sellos',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  '${(progreso * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 7,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}