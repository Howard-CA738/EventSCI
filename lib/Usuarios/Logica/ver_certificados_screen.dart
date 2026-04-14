import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import '/prefs_helper.dart';
import '/admin_Carrera/certificado_builder.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTES DE COLOR — evita crear objetos Color en cada build()
// ─────────────────────────────────────────────────────────────────────────────
const _kPrimario       = Color(0xFF1E3A5F);
const _kPrimario08     = Color(0x141E3A5F);
const _kTextoGris      = Color(0xFF64748B);
const _kTextoGrisClaro = Color(0xFF94A3B8);
const _kFondo          = Color(0xFFE8EDF2);

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA VER CERTIFICADOS (estudiante)
// ─────────────────────────────────────────────────────────────────────────────
class VerCertificadosScreen extends StatefulWidget {
  const VerCertificadosScreen({super.key});

  @override
  State<VerCertificadosScreen> createState() => _VerCertificadosScreenState();
}

class _VerCertificadosScreenState extends State<VerCertificadosScreen> {
  bool _isLoading = true;
  List<_CertificadoItem> _certificados = [];
  String? _error;

  String _nombreEstudiante = '';

  // flags para evitar doble tap en Ver / Descargar
  final Set<String> _procesando = {};

  @override
  void initState() {
    super.initState();
    _cargarCertificados();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CARGA
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _cargarCertificados() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error     = null;
    });

    try {
      final userData = await PrefsHelper.getCurrentUserData();
      if (userData == null) {
        _setError('No se pudo obtener los datos del usuario.');
        return;
      }

      _nombreEstudiante = userData['name']?.toString() ?? '';

      final ids = await _resolverIds(userData);
      if (ids == null) {
        _setError('No se encontró la información académica del estudiante.');
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(ids.$1)
          .collection('students')
          .doc(ids.$2)
          .collection('certificados')
          .orderBy('creadoEn', descending: true)
          .get();

      final lista = snap.docs.map((doc) {
        final d = doc.data();
        return _CertificadoItem(
          id:       doc.id,
          datos:    DatosCertificado.fromMap(d),
          creadoEn: (d['creadoEn'] as Timestamp?)?.toDate(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _certificados = lista;
          _isLoading    = false;
        });
      }
    } catch (e) {
      _setError('Error al cargar certificados: $e');
    }
  }

  /// Resuelve (carreraPath, studentId) desde los datos del usuario.
  /// Retorna null si no se pueden determinar ambos valores.
  Future<(String, String)?> _resolverIds(Map<String, dynamic> userData) async {
    String carreraPath = userData['carreraPath']?.toString() ?? '';
    String studentId   = userData['id']?.toString()          ?? '';

    if (carreraPath.isEmpty || studentId.isEmpty) {
      final filial  = userData['filial']?.toString().trim()  ?? '';
      final carrera = userData['carrera']?.toString().trim() ?? '';
      if (filial.isNotEmpty && carrera.isNotEmpty) {
        carreraPath = '${filial}_$carrera';
      }
      studentId = userData['uid']?.toString() ??
          userData['docId']?.toString() ?? '';
    }

    if (carreraPath.isEmpty || studentId.isEmpty) return null;
    return (carreraPath, studentId);
  }

  void _setError(String msg) {
    if (mounted) {
      setState(() {
        _error     = msg;
        _isLoading = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GENERACIÓN DE PDF (on-demand, sin guardar en Firestore)
  // ─────────────────────────────────────────────────────────────────────────
  Future<Uint8List?> _generarPdf(_CertificadoItem cert) async {
    try {
      final builder        = CertificadoBuilder(cert.datos);
      final estudianteTemp = Estudiante(
        id:     '',
        nombre: _nombreEstudiante,
        dni:    '',
        codigo: '',
      );
      return await builder.buildPdf([estudianteTemp]);
    } catch (e) {
      _snack('Error al generar el certificado: $e');
      return null;
    }
  }

  Future<void> _abrirCertificado(_CertificadoItem cert) async {
    if (_procesando.contains(cert.id)) return;
    _procesando.add(cert.id);
    _snack('Generando certificado...');

    final bytes = await _generarPdf(cert);
    _procesando.remove(cert.id);

    if (bytes == null || !mounted) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _descargarCertificado(_CertificadoItem cert) async {
    if (_procesando.contains(cert.id)) return;
    _procesando.add(cert.id);
    _snack('Preparando descarga...');

    final bytes = await _generarPdf(cert);
    _procesando.remove(cert.id);

    if (bytes == null || !mounted) return;
    final nombre =
        'certificado_${cert.datos.rol.toLowerCase()}_'
        '${cert.datos.evento.replaceAll(' ', '_').toLowerCase()}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: nombre);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _kPrimario,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
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
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _kPrimario));
    }
    if (_error != null) return _buildError();
    return _buildBody();
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.workspace_premium,
                  color: _kPrimario,
                  size: 28),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mis Certificados',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text('Visualiza y descarga tus certificados',
                    style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white, size: 24),
            onPressed: _cargarCertificados,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 26),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _kTextoGris)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _cargarCertificados,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimario,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_certificados.isEmpty) return _buildVacio();

    return RefreshIndicator(
      onRefresh: _cargarCertificados,
      color: _kPrimario,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        // +2 para el resumen (índice 0) y el spacer final (índice N+1)
        itemCount: _certificados.length + 2,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildResumen(),
            );
          }
          if (i == _certificados.length + 1) {
            return const SizedBox(height: 8);
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildCertificadoCard(_certificados[i - 1]),
          );
        },
      ),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: _kPrimario08,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium_outlined,
                  size: 52, color: _kPrimario),
            ),
            const SizedBox(height: 20),
            const Text('Sin certificados aún',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kPrimario)),
            const SizedBox(height: 8),
            Text(
              'Cuando el administrador envíe tus certificados, aparecerán aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _cargarCertificados,
              icon: const Icon(Icons.refresh_rounded, color: _kPrimario),
              label: const Text('Actualizar',
                  style: TextStyle(color: _kPrimario)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kPrimario),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumen() {
    // Cálculo de roles solo cuando se construye el resumen
    final roles = <String, int>{};
    for (final c in _certificados) {
      roles[c.datos.rol] = (roles[c.datos.rol] ?? 0) + 1;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kPrimario,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_certificados.length} certificado'
                  '${_certificados.length != 1 ? 's' : ''} recibido'
                  '${_certificados.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                if (roles.isNotEmpty)
                  Text(
                    roles.entries
                        .map((e) =>
                            '${e.value} ${e.key.toLowerCase()}'
                            '${e.value != 1 ? 's' : ''}')
                        .join(' · '),
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificadoCard(_CertificadoItem cert) {
    final rolColor = _colorPorRol(cert.datos.rol);
    final rolIcon  = _iconPorRol(cert.datos.rol);

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
      _CertificadoItem cert, Color rolColor, IconData rolIcon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Color.fromRGBO(
                rolColor.red, rolColor.green, rolColor.blue, 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(rolIcon, color: rolColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRolBadge(cert.datos.rol, rolColor),
              const SizedBox(height: 4),
              Text(
                cert.datos.evento,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kPrimario),
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
        color: Color.fromRGBO(rolColor.red, rolColor.green, rolColor.blue, 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        rol,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: rolColor),
      ),
    );
  }

  Widget _buildCardDetalles(_CertificadoItem cert) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cert.datos.fecha.isNotEmpty)
          _detalle(Icons.calendar_today_outlined, cert.datos.fecha),
        if (cert.datos.carrera.isNotEmpty) ...[
          const SizedBox(height: 4),
          _detalle(Icons.school_outlined, cert.datos.carrera),
        ],
        if (cert.datos.rol == 'ASISTENTE' && cert.datos.horas.isNotEmpty) ...[
          const SizedBox(height: 4),
          _detalle(Icons.timer_outlined,
              '${cert.datos.horas} horas académicas'),
        ],
        if (cert.creadoEn != null) ...[
          const SizedBox(height: 4),
          _detalle(
            Icons.access_time_outlined,
            'Recibido el ${_formatFecha(cert.creadoEn!)}',
            fontSize: 11,
            color: _kTextoGrisClaro,
          ),
        ],
      ],
    );
  }

  Widget _buildCardBotones(_CertificadoItem cert) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _abrirCertificado(cert),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Ver', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kPrimario,
              side: const BorderSide(color: _kPrimario),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _descargarCertificado(cert),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Descargar', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimario,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              elevation: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _detalle(IconData icon, String texto,
      {double fontSize = 12, Color color = _kTextoGris}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(texto,
              style: TextStyle(fontSize: fontSize, color: color)),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Color _colorPorRol(String rol) {
    switch (rol) {
      case 'PONENTE':     return const Color(0xFF7C3AED);
      case 'JURADO':      return const Color(0xFF0F6E56);
      case 'ORGANIZADOR': return const Color(0xFFB45309);
      default:            return _kPrimario;
    }
  }

  IconData _iconPorRol(String rol) {
    switch (rol) {
      case 'PONENTE':     return Icons.mic_rounded;
      case 'JURADO':      return Icons.gavel_rounded;
      case 'ORGANIZADOR': return Icons.manage_accounts_rounded;
      default:            return Icons.workspace_premium;
    }
  }

  String _formatFecha(DateTime dt) {
    const meses = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${dt.day} ${meses[dt.month]} ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO LOCAL
// ─────────────────────────────────────────────────────────────────────────────
class _CertificadoItem {
  final String id;
  final DatosCertificado datos;
  final DateTime? creadoEn;

  const _CertificadoItem({
    required this.id,
    required this.datos,
    this.creadoEn,
  });
}