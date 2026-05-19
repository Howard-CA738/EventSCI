import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/admin/logica/seleccionar_ganadores.dart';

class SeleccionarGanadorScreen extends StatefulWidget {
  const SeleccionarGanadorScreen({super.key});

  @override
  State<SeleccionarGanadorScreen> createState() =>
      _SeleccionarGanadorScreenState();
}

class _SeleccionarGanadorScreenState extends State<SeleccionarGanadorScreen>
    with SingleTickerProviderStateMixin {
  final SeleccionarGanadoresLogic _logic = SeleccionarGanadoresLogic();
  String? _selectedFacultad;
  String? _selectedCarrera;
  String? _selectedEventId;
  Map<String, dynamic>? _selectedEventData;
  List<Map<String, dynamic>> _grupos = [];
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF2),
      appBar: AppBar(
        title: const Text(
          'Seleccionar Ganadores',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: const Color(0xFF34495E),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado con icono
              _buildHeader(),
              const SizedBox(height: 24),

              // Sección de filtros
              _buildFilterCard(),
              const SizedBox(height: 20),

              // Lista de eventos filtrados
              if (_selectedFacultad != null && _selectedCarrera != null) ...[
                _buildEventsCard(),
                if (_selectedEventId != null) ...[
                  const SizedBox(height: 20),
                  _buildGruposCard(),
                ],
              ] else ...[
                _buildEmptyState(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF34495E), Color(0xFF4A6278)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF34495E).withValues(alpha:0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 40,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Elegir grupos ganadores',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Selecciona el evento y marca los ganadores',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.08),
            blurRadius: 20,
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34495E).withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.filter_list,
                    color: Color(0xFF34495E),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Filtros de Búsqueda',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF34495E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Selector de Facultad
            _buildDropdownField(
              value: _selectedFacultad,
              label: 'Facultad',
              icon: Icons.school,
              items: _logic.facultadesCarreras.keys.toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedFacultad = newValue;
                  _selectedCarrera = null;
                  _selectedEventId = null;
                  _selectedEventData = null;
                  _grupos.clear();
                });
              },
            ),
            const SizedBox(height: 16),

            // Selector de Carrera
            _buildDropdownField(
              value: _selectedCarrera,
              label: 'Carrera/Escuela Profesional',
              icon: Icons.book,
              items: _selectedFacultad != null
                  ? _logic.facultadesCarreras[_selectedFacultad]!
                  : null,
              onChanged: _selectedFacultad != null
                  ? (String? newValue) {
                      setState(() {
                        _selectedCarrera = newValue;
                        _selectedEventId = null;
                        _selectedEventData = null;
                        _grupos.clear();
                      });
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required IconData icon,
    required List<String>? items,
    required void Function(String?)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: value != null ? const Color(0xFF34495E) : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: const Color(0xFF34495E),
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF34495E)),
        ),
        dropdownColor: Colors.white,
        items: items?.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildEventsCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.08),
            blurRadius: 20,
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Eventos Disponibles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF34495E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecciona un evento para ver sus grupos participantes',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: StreamBuilder<QuerySnapshot>(
                stream: _logic.getEventsStream(
                  _selectedFacultad!,
                  _selectedCarrera!,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2C5F7C),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    );
                  }

                  final events = snapshot.data?.docs ?? [];

                  if (events.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 60,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay eventos para $_selectedCarrera',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final eventData = event.data() as Map<String, dynamic>;
                      final eventName = eventData['name'] ?? 'Sin nombre';
                      final eventId = event.id;
                      final isSelected = _selectedEventId == eventId;

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 300 + (index * 100)),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Opacity(opacity: value, child: child),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF34495E).withValues(alpha:0.1)
                                : const Color(0xFFE8EEF2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF34495E)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _selectEvent(eventId, eventData),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF2C5F7C)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        isSelected
                                            ? Icons.check_circle
                                            : Icons.event,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF2C5F7C),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            eventName,
                                            style: TextStyle(
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              fontSize: 16,
                                              color: const Color(0xFF2C5F7C),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _selectedCarrera!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: isSelected
                                          ? const Color(0xFF2C5F7C)
                                          : Colors.grey,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGruposCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.08),
            blurRadius: 20,
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha:0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.groups,
                    color: Colors.amber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Grupos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF34495E),
                  ),
                ),
                const Spacer(),
                if (_grupos.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_grupos.length} grupos',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ),
              ],
            ),
            if (_selectedEventData != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEF2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_note,
                      size: 18,
                      color: Color(0xFF34495E),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Evento: ${_selectedEventData!['name']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF34495E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 450,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF34495E),
                      ),
                    )
                  : _grupos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_off,
                            size: 60,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay grupos en este evento',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Los grupos se crean cuando los\nestudiantes se registran en proyectos',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _grupos.length,
                      itemBuilder: (context, index) {
                        final grupo = _grupos[index];
                        final isWinner = grupo['isWinner'] ?? false;
                        final projectName =
                            grupo['projectName'] ?? 'Proyecto sin nombre';
                        final integrantes = List<String>.from(
                          grupo['integrantes'] ?? [],
                        );

                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 300 + (index * 80)),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              gradient: isWinner
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFFFD700),
                                        Color(0xFFFFE55C),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isWinner ? null : const Color(0xFFE8EEF2),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: isWinner
                                  ? [
                                      BoxShadow(
                                        color: Colors.amber.withValues(alpha:0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showGrupoDetails(grupo),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isWinner
                                              ? Colors.white
                                              : const Color(0xFF2C5F7C),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          isWinner
                                              ? Icons.emoji_events
                                              : Icons.group,
                                          color: isWinner
                                              ? Colors.amber
                                              : Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              projectName,
                                              style: TextStyle(
                                                fontWeight: isWinner
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                                fontSize: 16,
                                                color: isWinner
                                                    ? const Color(0xFF2C5F7C)
                                                    : const Color(0xFF2C5F7C),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Integrantes: ${integrantes.length}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isWinner
                                                    ? const Color(0xFF2C5F7C)
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                            if (integrantes.isNotEmpty)
                                              Text(
                                                integrantes.take(2).join(', ') +
                                                    (integrantes.length > 2
                                                        ? '...'
                                                        : ''),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isWinner
                                                      ? Colors.grey[700]
                                                      : Colors.grey,
                                                ),
                                              ),
                                            if (isWinner)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.star,
                                                      size: 14,
                                                      color: Colors.amber,
                                                    ),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'GANADOR',
                                                      style: TextStyle(
                                                        color: Colors.amber,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: isWinner
                                              ? Colors.white
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            isWinner
                                                ? Icons.remove_circle
                                                : Icons.emoji_events,
                                            color: isWinner
                                                ? Colors.red
                                                : Colors.amber,
                                          ),
                                          onPressed: isWinner
                                              ? () => _toggleWinner(
                                                  grupo['id'],
                                                  false,
                                                )
                                              : () => _showWinnerConfirmDialog(
                                                  grupo,
                                                ),
                                          tooltip: isWinner
                                              ? 'Remover ganador'
                                              : 'Seleccionar ganador',
                                        ),
                                      ),
                                    ],
                                  ),
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha:0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events,
                size: 80,
                color: Colors.amber.shade600,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Selecciona Facultad y Carrera',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF34495E),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Primero elige la facultad y carrera para ver los eventos y sus grupos',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectEvent(String eventId, Map<String, dynamic> eventData) {
    setState(() {
      _selectedEventId = eventId;
      _selectedEventData = eventData;
    });
    _loadGrupos();
  }

  Future<void> _loadGrupos() async {
    if (_selectedEventId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final grupos = await _logic.loadGrupos(_selectedEventId!);
      setState(() {
        _grupos = grupos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error al cargar proyectos: $e');
    }
  }

  Future<void> _toggleWinner(String grupoId, bool isWinner) async {
    try {
      await _logic.toggleWinner(_selectedEventId!, grupoId, isWinner);

      setState(() {
        final index = _grupos.indexWhere((g) => g['id'] == grupoId);
        if (index != -1) {
          _grupos[index]['isWinner'] = isWinner;
          if (isWinner) {
            _grupos[index]['winnerDate'] = Timestamp.now();
          } else {
            _grupos[index].remove('winnerDate');
          }
        }
      });

      _showSuccessSnackBar(
        isWinner
            ? 'Proyecto seleccionado como ganador'
            : 'Proyecto removido de ganadores',
      );
    } catch (e) {
      _showErrorSnackBar('Error al actualizar ganador: $e');
    }
  }

  void _showWinnerConfirmDialog(Map<String, dynamic> grupo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events, color: Colors.amber),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Confirmar Ganador',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF34495E),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Confirmas que este grupo es ganador?',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade50, Colors.amber.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade300, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.workspace_premium,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            grupo['projectName'] ?? 'Sin nombre',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF2C5F7C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.group, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Integrantes: ${List<String>.from(grupo['integrantes'] ?? []).length}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _toggleWinner(grupo['id'], true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Confirmar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGrupoDetails(Map<String, dynamic> grupo) {
    final integrantes = List<String>.from(grupo['integrantes'] ?? []);
    final projectName = grupo['projectName'] ?? 'Proyecto sin nombre';
    final isWinner = grupo['isWinner'] ?? false;
    final codigo = grupo['codigo'] ?? 'Sin código';
    final clasificacion = grupo['clasificacion'] ?? 'Sin clasificación';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C5F7C).withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline, color: Color(0xFF2C5F7C)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  projectName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF34495E),
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isWinner)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFE55C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha:0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.emoji_events, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'PROYECTO GANADOR',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Información del proyecto
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EEF2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.code,
                            size: 18,
                            color: Color(0xFF34495E),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Código: $codigo',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.category,
                            size: 18,
                            color: Color(0xFF34495E),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Clasificación: $clasificacion',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Text(
                  'Integrantes:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF34495E),
                  ),
                ),
                const SizedBox(height: 12),
                ...integrantes.map(
                  (integrante) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFE8EEF2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C5F7C).withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 18,
                            color: Color(0xFF2C5F7C),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            integrante,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (integrantes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'No hay integrantes registrados',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34495E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cerrar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
