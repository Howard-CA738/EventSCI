import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import 'proyectos_categoria_asistente_screen.dart';
import '/admin_carrera/asistencias_personales.dart';

class AsistenteQRScreen extends StatefulWidget {
  final VoidCallback? logoutCallback;

  const AsistenteQRScreen({super.key, this.logoutCallback});

  @override
  State<AsistenteQRScreen> createState() => _AsistenteQRScreenState();
}

class _AsistenteQRScreenState extends State<AsistenteQRScreen>
    with TickerProviderStateMixin {
  String? _estudianteNombre;
  String? _filialId;
  String? _filialNombre;
  String? _facultad;
  String? _carreraId;
  String? _carreraNombre;

  bool _isLoadingSession = true;
  bool _isLoadingCategorias = false;

  String? _selectedEventId;
  String? _selectedEventName;
  List<String> _categorias = [];

  late AnimationController _fadeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadEstudianteData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadEstudianteData() async {
    setState(() => _isLoadingSession = true);

    try {
      final name = await PrefsHelper.getUserName();
      final userIdPath = await PrefsHelper.getCurrentUserId();

      if (userIdPath == null || !userIdPath.contains('/')) {
        setState(() {
          _estudianteNombre = name ?? 'Asistente';
          _isLoadingSession = false;
        });
        return;
      }

      final parts = userIdPath.split('/');
      final carreraPath = parts[0];
      final studentId = parts[1];

      final studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(carreraPath)
          .collection('students')
          .doc(studentId)
          .get();

      final carreraDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(carreraPath)
          .get();

      final sd = studentDoc.data() ?? {};
      final cd = carreraDoc.data() ?? {};

      final facultad = sd['facultad']?.toString().trim() ?? '';
      final carreraNombre = sd['carrera']?.toString().trim() ?? '';

      final filialId = cd['filial']?.toString().trim() ?? '';
      final filialNombre = cd['filialNombre']?.toString().trim() ??
          cd['filial']?.toString().trim() ??
          '';
      final carreraId = cd['carreraId']?.toString().trim() ?? carreraPath;

      debugPrint('🎓 Asistente QR:'
          '\n  filialId=$filialId'
          '\n  facultad=$facultad'
          '\n  carreraId=$carreraId'
          '\n  carreraNombre=$carreraNombre');

      setState(() {
        _estudianteNombre = name ?? 'Asistente';
        _filialId = filialId.isNotEmpty ? filialId : null;
        _filialNombre = filialNombre.isNotEmpty ? filialNombre : null;
        _facultad = facultad.isNotEmpty ? facultad : null;
        _carreraId = carreraId.isNotEmpty ? carreraId : null;
        _carreraNombre = carreraNombre.isNotEmpty ? carreraNombre : null;
        _isLoadingSession = false;
      });

      if (_facultad != null) {
        _fadeController.forward();
        _slideController.forward();
      }
    } catch (e) {
      debugPrint('Error cargando datos del asistente: $e');
      setState(() => _isLoadingSession = false);
    }
  }

  Stream<List<QueryDocumentSnapshot>> _getEventosStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {
        final data = doc.data();

        if (_filialNombre != null && _filialNombre!.isNotEmpty) {
          final eventoFilial = data['filialNombre']?.toString() ??
              data['filialId']?.toString() ??
              '';
          if (eventoFilial != _filialNombre) return false;
        }

        if (_facultad != null && _facultad!.isNotEmpty) {
          if (data['facultad'] != _facultad) return false;
        }

        if (_carreraNombre != null && _carreraNombre!.isNotEmpty) {
          if (data['carreraNombre'] != _carreraNombre) return false;
        }

        return true;
      }).toList();
    });
  }

  Future<void> _cargarCategorias(String eventId) async {
    setState(() {
      _isLoadingCategorias = true;
      _categorias.clear();
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .get();

      final Set<String> categoriasSet = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final clasificacion = data['Clasificación']?.toString().trim();
        if (clasificacion != null && clasificacion.isNotEmpty) {
          categoriasSet.add(clasificacion);
        }
      }

      setState(() {
        _categorias = categoriasSet.toList()..sort();
        _isLoadingCategorias = false;
      });

      if (_categorias.isEmpty) {
        _showSnackBar(
          'Este evento aún no tiene proyectos importados.',
          isError: true,
        );
      }
    } catch (e) {
      setState(() => _isLoadingCategorias = false);
      _showSnackBar('Error al cargar categorías: $e', isError: true);
    }
  }

  void _seleccionarEvento(String eventId, String eventName) {
    setState(() {
      _selectedEventId = eventId;
      _selectedEventName = eventName;
      _categorias.clear();
    });
    _cargarCategorias(eventId);
  }

  void _deseleccionarEvento() {
    setState(() {
      _selectedEventId = null;
      _selectedEventName = null;
      _categorias.clear();
    });
  }

  void _navegarAProyectosCategoria(String categoria) {
    if (_selectedEventId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProyectosCategoriaAsistenteScreen(
          eventId: _selectedEventId!,
          eventName: _selectedEventName!,
          filialId: _filialId ?? '',
          filialNombre: _filialNombre ?? '',
          facultad: _facultad ?? '',
          carrera: _carreraNombre ?? 'General',
          categoria: categoria,
        ),
      ),
    );
  }
void _abrirCrearAsistenciaPersonal() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AsistenciasPersonalesScreen(
        filialId: _filialId,
        filialNombre: _filialNombre,
        facultad: _facultad,
        carreraId: _carreraId,
        carreraNombre: _carreraNombre,
      ),
    ),
  );
}
Widget _buildCrearAsistenciaButton() {
  return GestureDetector(
    onTap: _abrirCrearAsistenciaPersonal,
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D7377), Color(0xFF14919B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D7377).withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add_circle_outline,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crear asistencia personal',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 3),
                Text(
                  'Genera un QR de asistencia con nombre propio',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white70, size: 14),
        ],
      ),
    ),
  );
}
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFE53935) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF2),
      appBar: _buildAppBar(),
      body: _isLoadingSession
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E3A5F)),
            )
          : FadeTransition(
              opacity: _fadeController,
              child: _buildBody(),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E3A5F),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.qr_code_scanner, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Asistente QR',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Generación de códigos de asistencia',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (widget.logoutCallback != null)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.logout_rounded, size: 18),
            ),
            onPressed: widget.logoutCallback,
            tooltip: 'Cerrar Sesión',
          ),
      ],
    );
  }

  Widget _buildBody() {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildIdentityCard(),
            const SizedBox(height: 16),
            if (_facultad == null && _carreraNombre == null)
              _buildSinDatosCard()
            else ...[
              _buildCrearAsistenciaButton(), 
              if (_selectedEventId != null) ...[
                _buildEventoSeleccionadoCard(),
                const SizedBox(height: 16),
                _buildCategoriasSection(),
              ] else ...[
                _buildEventosSection(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2A4E7F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.badge_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _estudianteNombre ?? 'Asistente',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Asistente de QR',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D7377).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: Colors.white, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'Autorizado',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (_filialNombre != null)
                _buildChip(Icons.location_city, _filialNombre!),
              if (_facultad != null)
                _buildChip(Icons.account_balance, _facultad!),
              if (_carreraNombre != null)
                _buildChip(Icons.menu_book, _carreraNombre!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 12),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSinDatosCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 52, color: Colors.amber[400]),
          const SizedBox(height: 12),
          const Text(
            'No se detectaron datos de carrera',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A5F),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Cierra sesión e inicia nuevamente para cargar correctamente tu información.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEventosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.event_note,
                  color: Color(0xFF1E3A5F), size: 18),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Eventos de tu carrera',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF90CAF9)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Solo se muestran los eventos creados para tu carrera. Toca uno para ver sus categorías.',
                  style:
                      TextStyle(color: Colors.blue[900], fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        StreamBuilder<List<QueryDocumentSnapshot>>(
          stream: _getEventosStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF1E3A5F)),
                ),
              );
            }

            if (snapshot.hasError) {
              return _buildErrorCard('Error: ${snapshot.error}');
            }

            final docs = snapshot.data ?? [];

            if (docs.isEmpty) {
              return _buildEmptyEventosCard();
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildEventoCard(doc.id, data);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEventoCard(String eventId, Map<String, dynamic> data) {
    final name = (data['name'] ?? 'Sin nombre').toString();
    final periodo =
        (data['periodoNombre'] ?? data['periodo'] ?? '').toString();
    final initial =
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'E';

    return GestureDetector(
      onTap: () => _seleccionarEvento(eventId, name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  initial,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  if (periodo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 11, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            periodo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.qr_code_rounded,
                  color: Color(0xFF1E3A5F), size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventoSeleccionadoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D7377),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_available,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Evento activo',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Text(
                  _selectedEventName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _deseleccionarEvento,
            icon: const Icon(Icons.swap_horiz,
                color: Colors.white70, size: 16),
            label: const Text(
              'Cambiar',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.category_rounded,
                  color: Color(0xFF1E3A5F), size: 18),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Selecciona una categoría',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ),
              if (_categorias.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_categorias.length}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1E3A5F),
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_isLoadingCategorias)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF1E3A5F)),
                  SizedBox(height: 12),
                  Text('Cargando categorías...',
                      style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            ),
          )
        else if (_categorias.isEmpty)
          _buildEmptyCategoriasCard()
        else
          ..._categorias.asMap().entries.map((entry) {
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + entry.key * 60),
              tween: Tween(begin: 0, end: 1),
              builder: (context, value, child) => Transform.translate(
                offset: Offset(0, 18 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              ),
              child: _buildCategoriaCard(entry.value),
            );
          }),
      ],
    );
  }

  Widget _buildCategoriaCard(String categoria) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E7ED), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navegarAProyectosCategoria(categoria),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF1E3A5F).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder_rounded,
                      color: Color(0xFF1E3A5F), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    categoria,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D7377).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded,
                      color: Color(0xFF0D7377), size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyEventosCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy, size: 52, color: Colors.grey[300]),
          const SizedBox(height: 14),
          const Text(
            'No hay eventos para tu carrera',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A5F),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'El administrador de tu carrera debe crear un evento primero.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCategoriasCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded,
                size: 40, color: Colors.orange.shade600),
          ),
          const SizedBox(height: 14),
          const Text(
            'Sin categorías disponibles',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A5F),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Asegúrate de que se hayan importado proyectos en este evento.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style:
                  TextStyle(color: Colors.red.shade800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}