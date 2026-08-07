import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '/roles/jurados/datos/cert_item.dart';
import '/roles/jurados/logica/jurado_certificados_service.dart';

class JuradoCertificadosTab extends StatefulWidget {
  final String juradoId;
  final String juradoNombre;

  const JuradoCertificadosTab({
    super.key,
    required this.juradoId,
    required this.juradoNombre,
  });

  @override
  State<JuradoCertificadosTab> createState() => _JuradoCertificadosTabState();
}

class _JuradoCertificadosTabState extends State<JuradoCertificadosTab> {
  static const _primario = Color(0xFF1E3A5F);

  late final JuradoCertificadosService _service;
  bool _isLoading = true;
  String? _error;
  List<CertItem> _certificados = [];
  final Set<String> _procesando = {};

  @override
  void initState() {
    super.initState();
    _service = JuradoCertificadosService(
      juradoId: widget.juradoId,
      juradoNombre: widget.juradoNombre,
    );
    _cargar();
  }

  Future<void> _cargar() async {
    if (widget.juradoId.isEmpty) {
      setState(() {
        _error = 'No se pudo identificar al jurado.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final lista = await _service.cargar();
      if (mounted) {
        setState(() {
          _certificados = lista;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar certificados: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verCertificado(CertItem cert) async {
    if (_procesando.contains(cert.id)) return;
    setState(() => _procesando.add(cert.id));
    _snack('Generando certificado...');

    try {
      final bytes = await _service.generarPdf(cert);
      if (bytes == null) {
        _snack('Error al generar el certificado');
        return;
      }
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } finally {
      if (mounted) setState(() => _procesando.remove(cert.id));
    }
  }

  Future<void> _descargarCertificado(CertItem cert) async {
    if (_procesando.contains(cert.id)) return;
    setState(() => _procesando.add(cert.id));
    _snack('Preparando descarga...');

    try {
      final bytes = await _service.generarPdf(cert);
      if (bytes == null) {
        _snack('Error al generar el certificado');
        return;
      }
      final nombreArchivo =
          'certificado_jurado_${cert.datos.evento.replaceAll(' ', '_').toLowerCase()}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: nombreArchivo);
    } finally {
      if (mounted) setState(() => _procesando.remove(cert.id));
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _primario,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  Color _colorPorRol(String rol) {
    switch (rol) {
      case 'JURADO':
        return const Color(0xFF0F6E56);
      case 'PONENTE':
        return const Color(0xFF7C3AED);
      case 'ORGANIZADOR':
        return const Color(0xFFB45309);
      default:
        return _primario;
    }
  }

  IconData _iconPorRol(String rol) {
    switch (rol) {
      case 'JURADO':
        return Icons.gavel_rounded;
      case 'PONENTE':
        return Icons.mic_rounded;
      case 'ORGANIZADOR':
        return Icons.manage_accounts_rounded;
      default:
        return Icons.workspace_premium;
    }
  }

  String _formatFecha(DateTime dt) {
    const meses = [
      '',
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${dt.day} ${meses[dt.month]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primario)),
            SizedBox(height: 14),
            Text('Cargando certificados...',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF64748B))),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_certificados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.workspace_premium_outlined,
                  size: 72, color: Colors.grey[400]),
              const SizedBox(height: 20),
              Text('Sin certificados',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700])),
              const SizedBox(height: 10),
              Text(
                'Aún no tienes certificados emitidos.\n'
                'El administrador los enviará cuando corresponda.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      color: _primario,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildResumen(),
          const SizedBox(height: 16),
          ..._certificados.map(_buildCertCard),
        ],
      ),
    );
  }

  Widget _buildResumen() {
    final porRol = <String, int>{};
    for (final c in _certificados) {
      porRol[c.datos.rol] = (porRol[c.datos.rol] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2D5480)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.workspace_premium,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              '${_certificados.length} certificado${_certificados.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
          ]),
          if (porRol.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: porRol.entries.map((e) {
                final color = _colorPorRol(e.key);
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_iconPorRol(e.key), size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('${e.key}: ${e.value}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ]),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Desliza hacia abajo para actualizar',
            style: TextStyle(
                fontSize: 10, color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildCertCard(CertItem cert) {
    final color = _colorPorRol(cert.datos.rol);
    final icon = _iconPorRol(cert.datos.rol);
    final procesando = _procesando.contains(cert.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cert.datos.rol,
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cert.datos.evento,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F)),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.calendar_today_outlined,
                    'Fecha evento: ${cert.datos.fecha}'),
                const SizedBox(height: 6),
                _infoRow(
                    Icons.school_outlined,
                    cert.datos.carrera.isNotEmpty
                        ? cert.datos.carrera
                        : 'Sin carrera'),
                if (cert.creadoEn != null) ...[
                  const SizedBox(height: 6),
                  _infoRow(Icons.send_rounded,
                      'Emitido el ${_formatFecha(cert.creadoEn!)}',
                      color: Colors.grey[500]),
                ],
                if (cert.datos.codigoCertificado.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildCodigoBadge(cert.datos.codigoCertificado),
                ],
                const SizedBox(height: 12),
                if (procesando)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1E3A5F))),
                          SizedBox(width: 10),
                          Text('Procesando...',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  )
                else
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _verCertificado(cert),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('Ver',
                            style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color,
                          side:
                              BorderSide(color: color.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _descargarCertificado(cert),
                        icon:
                            const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Descargar',
                            style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ]),
              ],
            ),
          ),
        ],
      ),
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

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    return Row(children: [
      Icon(icon, size: 14, color: color ?? Colors.grey[500]),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12, color: color ?? const Color(0xFF475569))),
      ),
    ]);
  }
}
