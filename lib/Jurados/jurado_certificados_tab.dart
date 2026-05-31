import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '/admin_Carrera/certificado_builder.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO
// ─────────────────────────────────────────────────────────────────────────────
class _CertItem {
  final String id;
  final DatosCertificado datos;
  final DateTime? creadoEn;
  final String nombreJurado;

  const _CertItem({
    required this.id,
    required this.datos,
    this.creadoEn,
    this.nombreJurado = '',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET PRINCIPAL
// Úsalo así dentro de JuradosScreen:
//   JuradoCertificadosTab(juradoId: _userId, juradoNombre: _userName)
// ─────────────────────────────────────────────────────────────────────────────
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

  bool _isLoading = true;
  String? _error;
  List<_CertItem> _certificados = [];

  /// IDs de certificados que están siendo procesados (ver/descargar)
  final Set<String> _procesando = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // ─────────────────────────────────────────────────────────────────────────
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
      // Los certificados de jurados se guardan en:
      // users/{juradoId}/certificados
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.juradoId)
          .collection('certificados')
          .orderBy('creadoEn', descending: true)
          .get();

      final lista = snap.docs.map((doc) {
        final d = doc.data();
        return _CertItem(
          id:           doc.id,
          datos:        DatosCertificado.fromMap(d),
          creadoEn:     (d['creadoEn'] as Timestamp?)?.toDate(),
          nombreJurado: d['nombreEstudiante'] as String? ??
              widget.juradoNombre,
        );
      }).toList();

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

  // ─────────────────────────────────────────────────────────────────────────
  // GENERACIÓN DE PDF
  // ─────────────────────────────────────────────────────────────────────────
  Future<Uint8List?> _generarPdf(_CertItem cert) async {
    try {
      final bytes1 = await _descargarPorUrl(cert.datos.urlFirma1);
      final bytes2 = await _descargarPorUrl(cert.datos.urlFirma2);
      final bytes3 = await _descargarPorUrl(cert.datos.urlFirma3);

      final datosConFirmas = DatosCertificado(
        evento:      cert.datos.evento,
        rol:         cert.datos.rol,
        fecha:       cert.datos.fecha,
        horas:       cert.datos.horas,
        carrera:     cert.datos.carrera,
        facultad:    cert.datos.facultad,
        campus:      cert.datos.campus,
        motivo:      cert.datos.motivo,
        director1:   cert.datos.director1, cargo1: cert.datos.cargo1,
        director2:   cert.datos.director2, cargo2: cert.datos.cargo2,
        director3:   cert.datos.director3, cargo3: cert.datos.cargo3,
        urlFirma1:   cert.datos.urlFirma1,
        urlFirma2:   cert.datos.urlFirma2,
        urlFirma3:   cert.datos.urlFirma3,
        bytesFirma1: bytes1,
        bytesFirma2: bytes2,
        bytesFirma3: bytes3,
      );

      final nombre = cert.nombreJurado.isNotEmpty
          ? cert.nombreJurado
          : widget.juradoNombre;

      if (nombre.isEmpty) return null;

      final builder = CertificadoBuilder(datosConFirmas);
      final persona = Estudiante(
        id: widget.juradoId, nombre: nombre, dni: '', codigo: '',
      );
      return await builder.buildPdf([persona]);
    } catch (e) {
      debugPrint('Error generando PDF certificado jurado: $e');
      return null;
    }
  }

  Future<Uint8List?> _descargarPorUrl(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      // Intento 1: refrescar desde Storage SDK
      final storagePath = _extraerStoragePath(url);
      if (storagePath != null) {
        final freshUrl = await FirebaseStorage.instance
            .ref(storagePath)
            .getDownloadURL();
        final r = await http
            .get(Uri.parse(freshUrl))
            .timeout(const Duration(seconds: 30));
        if (r.statusCode == 200) return r.bodyBytes;
      }
      // Intento 2: URL directa
      if (url.startsWith('https://')) {
        final r = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30));
        if (r.statusCode == 200) return r.bodyBytes;
      }
      return null;
    } on FirebaseException catch (e) {
      debugPrint('Firebase Storage error: ${e.code}');
      return null;
    } on TimeoutException {
      debugPrint('Timeout descargando firma');
      return null;
    } catch (e) {
      debugPrint('Error descargando firma: $e');
      return null;
    }
  }

  String? _extraerStoragePath(String url) {
    try {
      final uri = Uri.parse(url);
      final oIndex = uri.path.indexOf('/o/');
      if (oIndex == -1) return null;
      final encoded = uri.path.substring(oIndex + 3).split('?').first;
      return Uri.decodeComponent(encoded);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACCIONES
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _verCertificado(_CertItem cert) async {
    if (_procesando.contains(cert.id)) return;
    setState(() => _procesando.add(cert.id));
    _snack('Generando certificado...');

    try {
      final bytes = await _generarPdf(cert);
      if (bytes == null) {
        _snack('Error al generar el certificado');
        return;
      }
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } finally {
      if (mounted) setState(() => _procesando.remove(cert.id));
    }
  }

  Future<void> _descargarCertificado(_CertItem cert) async {
    if (_procesando.contains(cert.id)) return;
    setState(() => _procesando.add(cert.id));
    _snack('Preparando descarga...');

    try {
      final bytes = await _generarPdf(cert);
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

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS VISUALES
  // ─────────────────────────────────────────────────────────────────────────
  Color _colorPorRol(String rol) {
    switch (rol) {
      case 'JURADO':      return const Color(0xFF0F6E56);
      case 'PONENTE':     return const Color(0xFF7C3AED);
      case 'ORGANIZADOR': return const Color(0xFFB45309);
      default:            return _primario;
    }
  }

  IconData _iconPorRol(String rol) {
    switch (rol) {
      case 'JURADO':      return Icons.gavel_rounded;
      case 'PONENTE':     return Icons.mic_rounded;
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

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
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
          // Resumen
          _buildResumen(),
          const SizedBox(height: 16),
          // Lista de certificados
          ..._certificados.map(_buildCertCard),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
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
            color: const Color(0xFF1E3A5F).withOpacity(0.25),
            blurRadius: 12, offset: const Offset(0, 4),
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
              spacing: 8, runSpacing: 6,
              children: porRol.entries.map((e) {
                final color = _colorPorRol(e.key);
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.5)),
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
                fontSize: 10, color: Colors.white.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCertCard(_CertItem cert) {
    final color      = _colorPorRol(cert.datos.rol);
    final icon       = _iconPorRol(cert.datos.rol);
    final procesando = _procesando.contains(cert.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cabecera de la tarjeta
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
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
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                ]),
              ),
            ]),
          ),

          // Cuerpo con detalles
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.calendar_today_outlined,
                    'Fecha evento: ${cert.datos.fecha}'),
                const SizedBox(height: 6),
                _infoRow(Icons.school_outlined,
                    cert.datos.carrera.isNotEmpty
                        ? cert.datos.carrera
                        : 'Sin carrera'),
                if (cert.creadoEn != null) ...[
                  const SizedBox(height: 6),
                  _infoRow(Icons.send_rounded,
                      'Emitido el ${_formatFecha(cert.creadoEn!)}',
                      color: Colors.grey[500]),
                ],
                const SizedBox(height: 12),

                // Botones de acción
                if (procesando)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 18, height: 18,
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
                        icon: const Icon(Icons.visibility_outlined,
                            size: 16),
                        label: const Text('Ver',
                            style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color,
                          side: BorderSide(color: color.withOpacity(0.5)),
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
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Descargar',
                            style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
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