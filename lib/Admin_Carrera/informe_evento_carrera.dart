import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import 'informe_word.dart';

class InformeEventoCarreraScreen extends StatefulWidget {
  const InformeEventoCarreraScreen({super.key});

  @override
  State<InformeEventoCarreraScreen> createState() =>
      _InformeEventoCarreraScreenState();
}

class _InformeEventoCarreraScreenState
    extends State<InformeEventoCarreraScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _filialId;
  String? _filialNombre;
  String? _facultad;
  String? _carrera;
  String? _carreraId;

  List<Map<String, dynamic>> _eventos = [];
  Map<String, dynamic>? _eventoSeleccionado;

  bool _isLoadingInit = true;
  bool _isLoadingEventos = false;
  bool _isGenerando = false;
  String? _mensajeEstado;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isLoadingInit = true);
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontró información de sesión'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoadingInit = false);
        return;
      }
      _filialId = adminData['filial'] as String?;
      _filialNombre = adminData['filialNombre'] as String?;
      _facultad = adminData['facultad'] as String?;
      _carrera = adminData['carrera'] as String?;
      _carreraId = adminData['carreraId'] ?? adminData['carrera'];
      await _cargarEventos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isLoadingInit = false);
  }

  Future<void> _cargarEventos() async {
    setState(() => _isLoadingEventos = true);
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('filialId', isEqualTo: _filialId)
          .where('facultad', isEqualTo: _facultad)
          .where('carreraId', isEqualTo: _carreraId)
          .orderBy('createdAt', descending: true)
          .get();

      final eventos = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Sin nombre',
          'facultad': data['facultad'] ?? '',
          'carrera': data['carrera'] ?? '',
          'fecha': data['fecha'] ?? '',
          'createdAt': data['createdAt'],
        };
      }).toList();

      if (mounted) {
        setState(() {
          _eventos = eventos;
          _isLoadingEventos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEventos = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar eventos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generarInforme() async {
    if (_eventoSeleccionado == null) return;

    setState(() {
      _isGenerando = true;
      _mensajeEstado = 'Generando informe...';
    });

    try {
      await InformeWordGenerator.generarYCompartir(
        evento: _eventoSeleccionado!,
        adminData: {
          'facultad': _facultad,
          'carrera': _carrera,
          'filialNombre': _filialNombre,
          'filial': _filialId,
        },
      );

      if (mounted) {
        setState(() {
          _isGenerando = false;
          _mensajeEstado = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Informe generado exitosamente',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF009688),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerando = false;
          _mensajeEstado = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al generar informe: $e',
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            backgroundColor: Colors.red,
          ),
        );
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
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 28),
                    onPressed:
                        _isGenerando ? null : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informe Completo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Generación de informe por evento',
                          style: TextStyle(fontSize: 12, color: Colors.white60),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Colors.white, size: 24),
                    onPressed: (_isLoadingEventos || _isGenerando)
                        ? null
                        : _cargarEventos,
                    tooltip: 'Actualizar eventos',
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
                child: _isLoadingInit
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                                color: Color(0xFF1E3A5F)),
                            SizedBox(height: 16),
                            Text(
                              'Cargando datos...',
                              style: TextStyle(
                                color: Color(0xFF1E3A5F),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoAdminCard(),
                            const SizedBox(height: 20),
                            _buildSelectorEvento(),
                            const SizedBox(height: 20),
                            _buildBotonGenerarInforme(),
                            if (_mensajeEstado != null) ...[
                              const SizedBox(height: 14),
                              _buildEstadoMessage(),
                            ],
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoAdminCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _carrera ?? '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _facultad ?? '—',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _filialNombre ?? '—',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30),
            ),
            child: const Text(
              'Tu carrera',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorEvento() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.event_note_rounded,
                color: Color(0xFF1E3A5F), size: 20),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Selecciona un evento',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (!_isLoadingEventos)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_eventos.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1E3A5F),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.teal[700]),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Los eventos mostrados corresponden únicamente a tu carrera asignada.',
                  style: TextStyle(fontSize: 12, color: Colors.teal[700]),
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
        ),
        if (_isLoadingEventos)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Color(0xFF1E3A5F)),
            ),
          )
        else if (_eventos.isEmpty)
          _buildEmptyEventos()
        else
          ...(_eventos.map((e) => _buildEventoItem(e)).toList()),
      ],
    );
  }

  Widget _buildEventoItem(Map<String, dynamic> evento) {
    final isSelected = _eventoSeleccionado?['id'] == evento['id'];
    final nombre = (evento['name'] as String?) ?? '';
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: _isGenerando
          ? null
          : () => setState(() => _eventoSeleccionado = evento),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A5F) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1E3A5F)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF1E3A5F).withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSelected
                      ? [
                          Colors.white.withValues(alpha: 0.3),
                          Colors.white.withValues(alpha: 0.1),
                        ]
                      : [
                          const Color(0xFF009688),
                          const Color(0xFF00796B),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  inicial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre.isNotEmpty ? nombre : 'Sin nombre',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF1E3A5F),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.summarize_rounded,
                        size: 13,
                        color: isSelected ? Colors.white60 : Colors.teal[400],
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isSelected
                              ? 'Evento seleccionado'
                              : 'Tap para seleccionar',
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white60
                                : Colors.teal[400],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Container(
                      key: const ValueKey('check'),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16),
                    )
                  : Container(
                      key: const ValueKey('arrow'),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.teal[600],
                        size: 14,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyEventos() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFE0F2F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_busy_rounded,
                size: 48, color: Color(0xFF009688)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay eventos disponibles',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            'No se encontraron eventos para tu carrera.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBotonGenerarInforme() {
    final listo = _eventoSeleccionado != null && !_isGenerando;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: listo ? _generarInforme : null,
        icon: _isGenerando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.download_rounded),
        label: Text(
          _isGenerando ? 'Generando...' : 'Generar Informe Word',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF009688),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: listo ? 4 : 0,
        ),
      ),
    );
  }

  Widget _buildEstadoMessage() {
    final esError = _mensajeEstado!.startsWith('Error');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: esError
            ? Colors.red.withValues(alpha: 0.1)
            : const Color(0xFF009688).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esError
              ? Colors.red.withValues(alpha: 0.3)
              : const Color(0xFF009688).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              esError ? Icons.error_outline : Icons.info_outline,
              size: 16,
              color: esError ? Colors.red : const Color(0xFF009688),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _mensajeEstado!,
              style: TextStyle(
                fontSize: 13,
                color:
                    esError ? Colors.red[700] : const Color(0xFF00695C),
              ),
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }
}