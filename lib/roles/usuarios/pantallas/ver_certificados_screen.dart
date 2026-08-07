import 'package:flutter/material.dart';
import '../logica/ver_certificados_controller.dart';
import '../datos/certificado_item.dart';

const _kPrimario       = Color(0xFF1E3A5F);
const _kTextoGris      = Color(0xFF64748B);
const _kTextoGrisClaro = Color(0xFF94A3B8);
const _kFondo          = Color(0xFFE8EDF2);

class VerCertificadosScreen extends StatefulWidget {
  const VerCertificadosScreen({super.key});

  @override
  State<VerCertificadosScreen> createState() => _VerCertificadosScreenState();
}

class _VerCertificadosScreenState extends State<VerCertificadosScreen> {
  late final VerCertificadosController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VerCertificadosController()..addListener(_onUpdate);
    _controller.cargarCertificados();
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _kPrimario,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPrimario,
      body: SafeArea(
        child: Column(
          children: [
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
                child: _buildBodyContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _kPrimario),
      );
    }
    if (_controller.error != null) return _buildError();
    return _buildBody();
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.workspace_premium,
                color: _kPrimario,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mis Certificados',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  'Visualiza y descarga tus certificados',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Actualizar',
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
              onPressed: _controller.cargarCertificados,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ),
          Tooltip(
            message: 'Cerrar',
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 24),
              onPressed: () => Navigator.pop(context),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _controller.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _kTextoGris),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _controller.cargarCertificados,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimario,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.certificados.isEmpty) return _buildVacio();

    return RefreshIndicator(
      onRefresh: _controller.cargarCertificados,
      color: _kPrimario,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _controller.certificados.length + 2,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildResumen(),
            );
          }
          if (i == _controller.certificados.length + 1) {
            return const SizedBox(height: 8);
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildCertificadoCard(_controller.certificados[i - 1]),
          );
        },
      ),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _kPrimario.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_outlined,
                size: 52,
                color: _kPrimario,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sin certificados aún',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kPrimario,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando el administrador envíe tus certificados, aparecerán aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _controller.cargarCertificados,
              icon: const Icon(Icons.refresh_rounded, color: _kPrimario),
              label: const Text('Actualizar', style: TextStyle(color: _kPrimario)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kPrimario),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumen() {
    final roles = _controller.contarPorRol();
    final String rolesTexto = roles.isEmpty
        ? ''
        : roles.entries
            .map((e) =>
                '${e.value} ${e.key.toLowerCase()}'
                '${e.value != 1 ? 's' : ''}')
            .join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kPrimario,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_controller.certificados.length} certificado'
                  '${_controller.certificados.length != 1 ? 's' : ''} recibido'
                  '${_controller.certificados.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                if (rolesTexto.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    rolesTexto,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificadoCard(CertificadoItem cert) {
    final rolColor = _controller.colorPorRol(cert.datos.rol);
    final rolIcon  = _controller.iconPorRol(cert.datos.rol);

    return Card(
      key: ValueKey(cert.id),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCardEncabezado(cert, rolColor, rolIcon),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade100),
            const SizedBox(height: 8),
            _buildCardDetalles(cert),
            const SizedBox(height: 14),
            _buildCardBotones(cert),
          ],
        ),
      ),
    );
  }

  Widget _buildCardEncabezado(
    CertificadoItem cert,
    Color rolColor,
    IconData rolIcon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: rolColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(rolIcon, color: rolColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRolBadge(cert.datos.rol, rolColor),
              const SizedBox(height: 4),
              Text(
                cert.datos.evento,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kPrimario,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRolBadge(String rol, Color rolColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: rolColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        rol,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: rolColor,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildCardDetalles(CertificadoItem cert) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (cert.datos.fecha.isNotEmpty)
        _detalle(Icons.calendar_today_outlined, cert.datos.fecha),
      if (cert.datos.carrera.isNotEmpty) ...[
        const SizedBox(height: 4),
        _detalle(Icons.school_outlined, cert.datos.carrera),
      ],
      if (cert.datos.rol == 'ASISTENTE' && cert.datos.horas.isNotEmpty) ...[
        const SizedBox(height: 4),
        _detalle(Icons.timer_outlined, '${cert.datos.horas} horas académicas'),
      ],
      if (cert.creadoEn != null) ...[
        const SizedBox(height: 4),
        _detalle(
          Icons.access_time_outlined,
          'Recibido el ${_controller.formatFecha(cert.creadoEn!)}',
          fontSize: 11,
          color: _kTextoGrisClaro,
        ),
      ],
      if (cert.datos.codigoCertificado.isNotEmpty) ...[
        const SizedBox(height: 10),
        _buildCodigoBadge(cert.datos.codigoCertificado),
      ],
    ],
  );
}
Widget _buildCodigoBadge(String codigo) {
  return Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xE61E3A5F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        codigo,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 1.5,
          fontFamily: 'monospace',
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}
  Widget _buildCardBotones(CertificadoItem cert) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                _controller.abrirCertificado(cert, onSnack: _snack),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text(
              'Ver',
              style: TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kPrimario,
              side: const BorderSide(color: _kPrimario),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              minimumSize: const Size(0, 44),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () =>
                _controller.descargarCertificado(cert, onSnack: _snack),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text(
              'Descargar',
              style: TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimario,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              elevation: 1,
              minimumSize: const Size(0, 44),
            ),
          ),
        ),
      ],
    );
  }

  Widget _detalle(
    IconData icon,
    String texto, {
    double fontSize = 12,
    Color color = _kTextoGris,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(fontSize: fontSize, color: color),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}