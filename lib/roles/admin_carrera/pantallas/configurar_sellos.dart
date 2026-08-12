import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/prefs_helper.dart';
import '../logica/configurar_sellos_service.dart';

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
  final ConfigurarSellosService _service = ConfigurarSellosService();

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  String? _filialId;
  String? _facultad;
  String? _carreraId;
  String? _carreraNombre;
  bool _isLoadingSession = true;

  List<Map<String, dynamic>> _eventos = [];
  String? _eventoSeleccionadoId;
  String? _eventoSeleccionadoNombre;
  bool _isLoadingEventos = false;

  int _metaSellos = 10;
  final TextEditingController _metaCtrl = TextEditingController(text: '10');
  bool _isLoadingConfig = false;
  bool _isSaving = false;

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

  Future<void> _loadSessionData() async {
    setState(() => _isLoadingSession = true);
    try {
      final adminData = await PrefsHelper.getAdminCarreraData();
      if (adminData != null) {
        setState(() {
          _filialId = adminData['filial'];
          _facultad = adminData['facultad'];
          _carreraId = adminData['carreraId'] ?? adminData['carrera'];
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

  Future<void> _cargarEventos() async {
    setState(() => _isLoadingEventos = true);
    try {
      final lista = await _service.cargarEventos(
        filialId: _filialId,
        facultad: _facultad,
        carreraId: _carreraId,
      );

      setState(() => _eventos = lista);
      _animCtrl.forward();
    } catch (e) {
      _showSnack('Error al cargar eventos: $e', isError: true);
    } finally {
      setState(() => _isLoadingEventos = false);
    }
  }

  Future<void> _cargarConfigEvento(String eventoId) async {
    setState(() => _isLoadingConfig = true);
    try {
      final meta = await _service.cargarConfigEvento(
        filialId: _filialId,
        facultad: _facultad,
        carreraId: _carreraId,
        eventoId: eventoId,
      );

      if (meta != null) {
        setState(() {
          _metaSellos = meta;
          _metaCtrl.text = meta.toString();
        });
      } else {
        _resetConfig();
      }
    } catch (_) {
      _resetConfig();
    } finally {
      setState(() => _isLoadingConfig = false);
    }
  }

  void _resetConfig() => setState(() {
        _metaSellos = 10;
        _metaCtrl.text = '10';
      });

  Future<void> _guardar() async {
    if (_eventoSeleccionadoId == null) return;

    final parsed = int.tryParse(_metaCtrl.text.trim());
    if (parsed == null || parsed < 1 || parsed > 200) {
      _showSnack('Ingresa un número entre 1 y 200', isError: true);
      return;
    }
    _metaSellos = parsed;

    setState(() => _isSaving = true);
    try {
      await _service.guardarMeta(
        filialId: _filialId,
        facultad: _facultad,
        carreraId: _carreraId,
        carreraNombre: _carreraNombre,
        eventoId: _eventoSeleccionadoId!,
        eventoNombre: _eventoSeleccionadoNombre,
        meta: _metaSellos,
      );
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

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      appBar: AppBar(
        title: const Text(
          'Configurar Sellos',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
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
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: (_isLoadingSession || _isLoadingEventos)
          ? const SafeArea(
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
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
                      child: SafeArea(
                        top: false,
                        child: GestureDetector(
                          onTap: () =>
                              FocusScope.of(context).unfocus(),
                          behavior: HitTestBehavior.opaque,
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 4),
                                _buildSelectorEvento(),
                                const SizedBox(height: 20),
                                AnimatedOpacity(
                                  opacity: _eventoSeleccionadoId != null
                                      ? 1.0
                                      : 0.35,
                                  duration:
                                      const Duration(milliseconds: 300),
                                  child: IgnorePointer(
                                    ignoring:
                                        _eventoSeleccionadoId == null,
                                    child: _isLoadingConfig
                                        ? const Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(32),
                                              child:
                                                  CircularProgressIndicator(
                                                color: Color(0xFF1E3A5F),
                                              ),
                                            ),
                                          )
                                        : Column(
                                            children: [
                                              _buildInfoCard(),
                                              const SizedBox(height: 20),
                                              _buildNumeroInput(),
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
                    ),
                  ),
                  _buildBottomBar(bottomPadding),
                ],
              ),
            ),
    );
  }

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
            offset: const Offset(0, 4),
          ),
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
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Seleccionar evento',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
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
                    fontWeight: FontWeight.w600,
                  ),
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
                  Expanded(
                    child: Text(
                      'No hay eventos disponibles',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),
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
                  menuMaxHeight: 300,
                  hint: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 18,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Elige un evento...',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  icon: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  items: _eventos.map((evento) {
                    final rawDate = evento['date'];
                    DateTime? date;
                    try {
                      date = rawDate?.toDate();
                    } catch (_) {
                      date = null;
                    }
                    final dateStr = date != null
                        ? '${date.day}/${date.month}/${date.year}'
                        : '';
                    return DropdownMenuItem<String?>(
                      value: evento['id'] as String,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event,
                              size: 18,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    evento['name'] as String,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF1E3A5F),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  if (dateStr.isNotEmpty)
                                    Text(
                                      dateStr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
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
                      (e) => e['id'] == value,
                    )['name'] as String;
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
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF2563EB),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _eventoSeleccionadoNombre ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E3A5F),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
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

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF7B61FF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF7B61FF).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7B61FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.info_outline,
              color: Color(0xFF7B61FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Define cuántos sellos equivalen al 100% (nota 20). La nota se calcula proporcional a los sellos obtenidos.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF4A3F8C),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumeroInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.workspace_premium,
                color: Color(0xFF1E3A5F),
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cantidad de sellos (meta)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Esta cantidad representa la nota máxima (20)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
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
                    color: Color(0xFF1E3A5F),
                  ),
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1E3A5F),
                        width: 2,
                      ),
                    ),
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
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF1E3A5F)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? const Color(0xFF1E3A5F)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    '$n',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? Colors.white
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calculate_outlined,
                  color: Color(0xFF1E3A5F),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ejemplo: 1 sello = ${(_metaSellos > 0 ? 20 / _metaSellos : 0).toStringAsFixed(2)} puntos',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E3A5F),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton({
    required IconData icono,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.2),
          ),
        ),
        child: Icon(icono, color: const Color(0xFF1E3A5F)),
      ),
    );
  }

  Widget _buildBottomBar(double bottomPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        bottomPadding > 0 ? bottomPadding : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: (_isSaving || _eventoSeleccionadoId == null)
              ? null
              : _guardar,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
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
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
