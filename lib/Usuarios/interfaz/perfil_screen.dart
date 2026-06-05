import 'package:flutter/material.dart';
import '/usuarios/logica/perfil.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen>
    with SingleTickerProviderStateMixin {
  late final PerfilController _controller;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = PerfilController()..addListener(_onControllerUpdate);

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

    _controller.loadUserData();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {});
    if (!_controller.isLoading && _controller.userData != null) {
      _animationController.forward();
    }
  }

  void _refresh() {
    _animationController.reset();
    _controller.loadUserData();
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
      child: Semantics(
        label: '$title: $value',
        child: Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildCardIcon(icon, iconColor),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E3A5F),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardIcon(IconData icon, Color? iconColor) {
    return SizedBox(
      width: 48,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: (iconColor ?? const Color(0xFF1E3A5F)).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: iconColor ?? const Color(0xFF1E3A5F),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF1E3A5F)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilialBadge(String sede) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.3),
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
          Flexible(
            child: Text(
              sede,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
            _buildAppBar(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _buildBodyContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Semantics(
            label: 'Volver',
            button: true,
            child: IconButton(
              icon:
                  const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Volver',
            ),
          ),
          const Expanded(
            child: Text(
              'Mi Perfil',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Semantics(
            label: 'Actualizar perfil',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
              onPressed: _refresh,
              tooltip: 'Actualizar',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_controller.isLoading) return _buildLoading();
    if (_controller.errorMessage != null) return _buildError();
    if (_controller.userData != null) return _buildProfile();
    return _buildNoData();
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF1E3A5F)),
          SizedBox(height: 16),
          Text(
            'Cargando información...',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _controller.errorMessage!,
              style: const TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _controller.loadUserData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                minimumSize: const Size(44, 44),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoData() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'No hay datos disponibles',
          style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildProfile() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatarSection(),
                  _buildSeccionPersonal(),
                  _buildSeccionAcademica(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    final sede = _controller.getSede();
    return Center(
      child: Column(
        children: [
          _buildAvatar(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _controller.userData!['name'] ?? 'Sin nombre',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          _buildEstudianteBadge(),
          if (sede != null) _buildFilialBadge(sede),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Hero(
      tag: 'profile_avatar',
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A5F), Color(0xFF2E4A6F)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A5F).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(Icons.person, size: 60, color: Colors.white),
      ),
    );
  }

  Widget _buildEstudianteBadge() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSeccionPersonal() {
    final userData = _controller.userData!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Información Personal', Icons.person_outline),
        _buildInfoCard(
          title: 'Nombre de Usuario',
          value: userData['username'] ?? 'No disponible',
          icon: Icons.account_circle,
          iconColor: const Color(0xFF1E3A5F),
          delay: 0,
        ),
        _buildInfoCard(
          title: 'Email Personal',
          value: userData['email'] ?? 'No disponible',
          icon: Icons.email,
          iconColor: const Color(0xFFFF9800),
          delay: 1,
        ),
        if (_controller.getCampo('correoInstitucional') != null)
          _buildInfoCard(
            title: 'Email Institucional',
            value: _controller.getCampo('correoInstitucional')!,
            icon: Icons.email_outlined,
            iconColor: const Color(0xFFFF5722),
            delay: 2,
          ),
        if (_controller.getCampo('celular') != null)
          _buildInfoCard(
            title: 'Celular',
            value: _controller.getCampo('celular')!,
            icon: Icons.phone,
            iconColor: const Color(0xFF4CAF50),
            delay: 4,
          ),
      ],
    );
  }

  Widget _buildSeccionAcademica() {
    final userData = _controller.userData!;
    final sede = _controller.getSede();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Información Académica', Icons.school),
        if (sede != null)
          _buildInfoCard(
            title: 'Filial / Sede',
            value: sede,
            icon: Icons.location_city,
            iconColor: const Color(0xFF1565C0),
            delay: 0,
          ),
        _buildInfoCard(
          title: 'Código Universitario',
          value: userData['codigoUniversitario'] ?? 'No disponible',
          icon: Icons.badge,
          iconColor: const Color(0xFF009688),
          delay: 1,
        ),
        _buildInfoCard(
          title: 'Facultad',
          value: userData['facultad'] ?? 'No disponible',
          icon: Icons.account_balance,
          iconColor: const Color(0xFF3F51B5),
          delay: 2,
        ),
        _buildInfoCard(
          title: 'Carrera',
          value: userData['carrera'] ?? 'No disponible',
          icon: Icons.menu_book,
          iconColor: const Color(0xFF795548),
          delay: 3,
        ),
        if (_controller.getCampo('modalidadEstudio') != null)
          _buildInfoCard(
            title: 'Modalidad de Estudio',
            value: _controller.getCampo('modalidadEstudio')!,
            icon: Icons.laptop_mac,
            iconColor: const Color(0xFF00ACC1),
            delay: 4,
          ),
        if (_controller.getCampo('modoContrato') != null)
          _buildInfoCard(
            title: 'Modo Contrato',
            value: _controller.getCampo('modoContrato')!,
            icon: Icons.description_outlined,
            iconColor: const Color(0xFF8D6E63),
            delay: 5,
          ),
        if (_controller.getCampo('ciclo') != null)
          _buildInfoCard(
            title: 'Ciclo',
            value: 'Ciclo ${_controller.getCampo('ciclo')}',
            icon: Icons.layers,
            iconColor: const Color(0xFF673AB7),
            delay: 6,
          ),
        if (_controller.getCampo('grupo') != null)
          _buildInfoCard(
            title: 'Grupo',
            value: 'Grupo ${_controller.getCampo('grupo')}',
            icon: Icons.groups,
            iconColor: const Color(0xFF00BCD4),
            delay: 7,
          ),
      ],
    );
  }
}