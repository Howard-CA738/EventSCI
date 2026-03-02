import 'package:flutter/material.dart';
import '/prefs_helper.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final userData = await PrefsHelper.getCurrentUserData();

      if (userData != null) {
        setState(() {
          _userData = userData;
          _isLoading = false;
        });
        _animationController.forward();
      } else {
        setState(() {
          _errorMessage = 'No se pudo cargar la información del usuario';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error cargando datos: $e';
        _isLoading = false;
      });
    }
  }

  /// Devuelve el nombre de la filial/sede del estudiante.
  /// Prioriza el campo 'sede', si no existe usa 'filial', y si no hay ninguno
  /// retorna null para que el widget no se muestre.
  String? _getSede() {
    final sede = _userData?['sede']?.toString() ?? '';
    final filial = _userData?['filial']?.toString() ?? '';
    if (sede.isNotEmpty) return sede;
    if (filial.isNotEmpty) return filial;
    return null;
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    Color? iconColor,
    int delay = 0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (delay * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, animValue, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animValue)),
          child: Opacity(opacity: animValue, child: child),
        );
      },
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade50],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (iconColor ?? const Color(0xFF1E3A5F)).withOpacity(
                      0.1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? const Color(0xFF1E3A5F),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A5F),
                        ),
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
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF1E3A5F)),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
        ],
      ),
    );
  }

  /// Badge compacto que muestra la filial/sede del estudiante en el header
  Widget _buildFilialBadge(String sede) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_city, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            sede,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Mi Perfil',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      _animationController.reset();
                      _loadUserData();
                    },
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
            ),

            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF1E3A5F)),
                            SizedBox(height: 16),
                            Text(
                              'Cargando información...',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.red,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadUserData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A5F),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _userData != null
                    ? FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Avatar + nombre + badges ─────────────
                                Center(
                                  child: Column(
                                    children: [
                                      Hero(
                                        tag: 'profile_avatar',
                                        child: Container(
                                          width: 110,
                                          height: 110,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFF1E3A5F),
                                                Color(0xFF2E4A6F),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF1E3A5F,
                                                ).withOpacity(0.3),
                                                blurRadius: 20,
                                                offset: const Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.person,
                                            size: 60,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _userData!['name'] ?? 'Sin nombre',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E3A5F),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),

                                      // Badge "Estudiante"
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF4CAF50),
                                              Color(0xFF45A049),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF4CAF50,
                                              ).withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Text(
                                          'Estudiante',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),

                                      // Badge filial/sede (solo si existe)
                                      if (_getSede() != null)
                                        _buildFilialBadge(_getSede()!),
                                    ],
                                  ),
                                ),

                                // ── Sección: Información Personal ─────────
                                _buildSectionTitle(
                                  'Información Personal',
                                  Icons.person_outline,
                                ),
                                _buildInfoCard(
                                  title: 'Nombre de Usuario',
                                  value:
                                      _userData!['username'] ?? 'No disponible',
                                  icon: Icons.account_circle,
                                  iconColor: const Color(0xFF1E3A5F),
                                  delay: 0,
                                ),
                                _buildInfoCard(
                                  title: 'Email Personal',
                                  value: _userData!['email'] ?? 'No disponible',
                                  icon: Icons.email,
                                  iconColor: const Color(0xFFFF9800),
                                  delay: 1,
                                ),
                                if ((_userData!['correoInstitucional'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  _buildInfoCard(
                                    title: 'Email Institucional',
                                    value: _userData!['correoInstitucional'],
                                    icon: Icons.email_outlined,
                                    iconColor: const Color(0xFFFF5722),
                                    delay: 2,
                                  ),
                                _buildInfoCard(
                                  title: 'DNI',
                                  value: _userData!['dni'] ?? 'No disponible',
                                  icon: Icons.credit_card,
                                  iconColor: const Color(0xFF9C27B0),
                                  delay: 3,
                                ),
                                if ((_userData!['celular'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  _buildInfoCard(
                                    title: 'Celular',
                                    value: _userData!['celular'],
                                    icon: Icons.phone,
                                    iconColor: const Color(0xFF4CAF50),
                                    delay: 4,
                                  ),

                                // ── Sección: Información Académica ────────
                                _buildSectionTitle(
                                  'Información Académica',
                                  Icons.school,
                                ),

                                // Filial / Sede
                                if (_getSede() != null)
                                  _buildInfoCard(
                                    title: 'Filial / Sede',
                                    value: _getSede()!,
                                    icon: Icons.location_city,
                                    iconColor: const Color(0xFF1565C0),
                                    delay: 0,
                                  ),

                                _buildInfoCard(
                                  title: 'Código Universitario',
                                  value:
                                      _userData!['codigoUniversitario'] ??
                                      'No disponible',
                                  icon: Icons.badge,
                                  iconColor: const Color(0xFF009688),
                                  delay: 1,
                                ),
                                _buildInfoCard(
                                  title: 'Facultad',
                                  value:
                                      _userData!['facultad'] ?? 'No disponible',
                                  icon: Icons.account_balance,
                                  iconColor: const Color(0xFF3F51B5),
                                  delay: 2,
                                ),
                                _buildInfoCard(
                                  title: 'Carrera',
                                  value:
                                      _userData!['carrera'] ?? 'No disponible',
                                  icon: Icons.menu_book,
                                  iconColor: const Color(0xFF795548),
                                  delay: 3,
                                ),
                                if ((_userData!['modalidadEstudio'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  _buildInfoCard(
                                    title: 'Modalidad de Estudio',
                                    value: _userData!['modalidadEstudio'],
                                    icon: Icons.laptop_mac,
                                    iconColor: const Color(0xFF00ACC1),
                                    delay: 4,
                                  ),
                                if ((_userData!['modoContrato'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  _buildInfoCard(
                                    title: 'Modo Contrato',
                                    value: _userData!['modoContrato'],
                                    icon: Icons.description_outlined,
                                    iconColor: const Color(0xFF8D6E63),
                                    delay: 5,
                                  ),
                                if ((_userData!['ciclo'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  _buildInfoCard(
                                    title: 'Ciclo',
                                    value: 'Ciclo ${_userData!['ciclo']}',
                                    icon: Icons.layers,
                                    iconColor: const Color(0xFF673AB7),
                                    delay: 6,
                                  ),
                                if ((_userData!['grupo'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  _buildInfoCard(
                                    title: 'Grupo',
                                    value: 'Grupo ${_userData!['grupo']}',
                                    icon: Icons.groups,
                                    iconColor: const Color(0xFF00BCD4),
                                    delay: 7,
                                  ),

                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      )
                    : const Center(
                        child: Text(
                          'No hay datos disponibles',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
