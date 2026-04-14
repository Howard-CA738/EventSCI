import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import '/prefs_helper.dart';
import '/usuarios/logica/asistencias.dart';

class EscanearQRScreen extends StatefulWidget {
  const EscanearQRScreen({super.key});

  @override
  State<EscanearQRScreen> createState() => _EscanearQRScreenState();
}

class _EscanearQRScreenState extends State<EscanearQRScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  MobileScannerController cameraController = MobileScannerController();
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUsername;
  bool _isProcessing = false;
  bool _hasScanned = false;
  bool _isFlashOn = false;

  // ── ZOOM ─────────────────────────────────────────────────────────
  double _currentZoom = 0.0;

  DateTime? _ultimoEscaneo;
  static const int _cooldownSegundos = 3;

  Map<String, dynamic>? _cachedUserData;
  int _escaneosDeSesion = 0;
  static const int _intervaloActualizacionResumen = 3;

  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _pulseAnimation;

  // ── Info académica del estudiante para mostrar en UI ─────────────
  String? _studentSede;
  String? _studentFacultad;
  String? _studentCarrera;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _setupAnimations();
    _initializeZoom();
  }

  void _initializeZoom() async {
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint('Zoom inicializado');
  }

  void _handleScaleStart(ScaleStartDetails details) {}

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.scale == 1.0) return;
    final double zoomDelta = (details.scale - 1.0) * 0.05;
    final double newZoom = (_currentZoom + zoomDelta).clamp(0.0, 1.0);
    if ((newZoom - _currentZoom).abs() > 0.01) {
      setState(() => _currentZoom = newZoom);
      try {
        cameraController.setZoomScale(_currentZoom);
      } catch (e) {
        debugPrint('Error al ajustar zoom: $e');
      }
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _getCurrentUser() async {
    try {
      final userId = await PrefsHelper.getCurrentUserId();
      final userName = await PrefsHelper.getUserName();
      final userData = await PrefsHelper.getCurrentUserData();

      setState(() {
        _currentUserId = userId;
        _currentUserName = userName;
        _currentUsername = userData?['username'];
        _cachedUserData = userData;

        // ── Extraer datos académicos para UI y validación ──────────
        if (userData != null) {
          final sede = userData['sede']?.toString() ?? '';
          final filial = userData['filial']?.toString() ?? '';
          _studentSede = sede.isNotEmpty
              ? sede
              : filial.isNotEmpty
              ? filial
              : null;
          _studentFacultad = userData['facultad']?.toString();
          _studentCarrera = userData['carrera']?.toString();
        }
      });
    } catch (e) {
      _showSnackBar('Error al obtener usuario: $e', isError: true);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ HELPERS DE NORMALIZACIÓN
  // ═══════════════════════════════════════════════════════════════

  /// Normaliza un string: minúsculas, sin tildes, sin espacios extremos.
  String _normalizar(String? valor) {
    if (valor == null) return '';
    const Map<String, String> tildes = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
      'ç': 'c',
    };
    String result = valor.trim().toLowerCase();
    tildes.forEach((tilde, reemplazo) {
      result = result.replaceAll(tilde, reemplazo);
    });
    return result;
  }

  /// Quita prefijos comunes de carrera antes de comparar.
  String _normalizarCarrera(String? valor) {
    return _normalizar(valor).replaceAll(RegExp(r'^ep\s*'), '');
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ VALIDACIÓN DE FILIAL / SEDE
  // ═══════════════════════════════════════════════════════════════

  /// Retorna true si el evento es para TODA la UPeU (sin restricción de sede).
  bool _esEventoUniversitario(Map<String, dynamic> qrInfo) {
    final f = _normalizar(qrInfo['facultad']);
    final c = _normalizar(qrInfo['carrera']);
    return f == 'universidad peruana union' ||
        f == 'universidad peruana unión' ||
        c == 'general';
  }

  /// Retorna true si el evento es para TODA una sede (sin restricción de carrera).
  bool _esEventoDeSede(Map<String, dynamic> qrInfo) {
    final c = _normalizar(qrInfo['carrera']);
    return c == 'general';
  }

  /// Compara la sede del QR con la sede del estudiante.
  /// Si el QR no trae sede, se omite la validación de sede.
  bool _sedeCoincide(Map<String, dynamic> qrInfo) {
    final qrSede = _normalizar(qrInfo['sede']);
    if (qrSede.isEmpty) return true; // QRs sin sede = sin restricción de sede
    final studentSede = _normalizar(_studentSede);
    return studentSede.isEmpty || studentSede == qrSede;
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ PROCESAR QR
  // ═══════════════════════════════════════════════════════════════
  Future<void> _procesarQR(String qrData) async {
    if (_isProcessing || _hasScanned) return;

    if (_ultimoEscaneo != null) {
      final diferencia = DateTime.now().difference(_ultimoEscaneo!);
      if (diferencia.inSeconds < _cooldownSegundos) {
        _showSnackBar(
          'Espera ${_cooldownSegundos - diferencia.inSeconds}s antes de escanear',
          isError: true,
        );
        return;
      }
    }

    _ultimoEscaneo = DateTime.now();
    setState(() {
      _isProcessing = true;
      _hasScanned = true;
    });

    try {
      await cameraController.stop();

      // ── Parsear QR ───────────────────────────────────────────────
      Map<String, dynamic> qrInfo;
      try {
        if (qrData.startsWith('myapp://')) {
          final uri = Uri.parse(qrData);
          final encodedData = uri.queryParameters['data'];
          if (encodedData != null) {
            qrInfo = jsonDecode(Uri.decodeComponent(encodedData));
          } else {
            throw Exception('No data parameter in deep link');
          }
        } else {
          qrInfo = jsonDecode(qrData);
        }
      } catch (e) {
        _showResult(
          success: false,
          message: 'QR inválido: No contiene datos válidos\nError: $e',
        );
        return;
      }

      // ── Validar campos obligatorios ──────────────────────────────
      final qrId = qrInfo['qrId'];
      if (qrId == null || qrId.toString().isEmpty) {
        _showResult(
          success: false,
          message: '⚠️ QR sin ID válido. Regenera el código QR.',
        );
        return;
      }

      const requiredFields = [
        'eventId',
        'eventName',
        'facultad',
        'carrera',
        'categoria',
      ];
      for (final field in requiredFields) {
        if (qrInfo[field] == null || qrInfo[field].toString().trim().isEmpty) {
          _showResult(
            success: false,
            message: 'QR incompleto: Falta el campo "$field"',
          );
          return;
        }
      }

      // ── Verificar estado del QR en Firestore ─────────────────────
      final qrDoc = await _firestore
          .collection('events')
          .doc(qrInfo['eventId'])
          .collection('qr_codes')
          .doc(qrId)
          .get();

      if (!qrDoc.exists) {
        _showResult(
          success: false,
          message: '⚠️ Este código QR no existe o fue eliminado',
        );
        return;
      }

      final qrDocData = qrDoc.data()!;
      final isActive = qrDocData['activo'] ?? false;

      if (!isActive) {
        final finalizadoAt = qrDocData['finalizadoAt'] as Timestamp?;
        final fechaFinalizado =
            finalizadoAt?.toDate().toString().substring(0, 16) ??
            'Fecha desconocida';
        _showResult(
          success: false,
          message:
              '🔒 Este código QR ya fue FINALIZADO\n\n'
              '❌ No se pueden registrar más asistencias\n\n'
              '📅 Finalizado: $fechaFinalizado',
        );
        return;
      }

      // ── Verificar usuario logueado ───────────────────────────────
      if (_currentUserId == null || _cachedUserData == null) {
        _showResult(
          success: false,
          message: 'Debes iniciar sesión para registrar asistencia',
        );
        return;
      }

      // ══════════════════════════════════════════════════════════════
      // ✅ VALIDACIÓN DE FILIAL / SEDE
      // ══════════════════════════════════════════════════════════════
      final esUniversitario = _esEventoUniversitario(qrInfo);

      if (!esUniversitario) {
        // ── Validar sede ──────────────────────────────────────────
        if (!_sedeCoincide(qrInfo)) {
          final qrSede = qrInfo['sede']?.toString() ?? 'Sin sede';
          _showResult(
            success: false,
            message:
                '🏛️ Este evento es de otra filial/sede.\n\n'
                '📌 EVENTO:\n'
                'Sede: "$qrSede"\n\n'
                '👤 TU SEDE:\n'
                '"${_studentSede ?? 'No registrada'}"',
          );
          return;
        }

        // ── Validar facultad y carrera ────────────────────────────
        final userFacultad = _normalizar(_cachedUserData!['facultad']);
        final userCarrera = _normalizarCarrera(_cachedUserData!['carrera']);
        final eventFacultad = _normalizar(qrInfo['facultad']);
        final eventCarrera = _normalizarCarrera(qrInfo['carrera']);
        final esDeSede = _esEventoDeSede(qrInfo);

        if (!esDeSede) {
          if (userFacultad != eventFacultad || userCarrera != eventCarrera) {
            _showResult(
              success: false,
              message:
                  '🚫 Este evento no corresponde a tu facultad/carrera.\n\n'
                  '📌 EVENTO:\n'
                  'Facultad: "${qrInfo['facultad']}"\n'
                  'Carrera: "${qrInfo['carrera']}"\n\n'
                  '👤 TU PERFIL:\n'
                  'Facultad: "${_cachedUserData!['facultad']}"\n'
                  'Carrera: "${_cachedUserData!['carrera']}"',
            );
            return;
          }
        }
      }

      // ── Extraer datos del proyecto ───────────────────────────────
      final codigoProyecto = qrInfo['codigoProyecto']?.toString().trim();
      final tituloProyecto = qrInfo['tituloProyecto']?.toString().trim();
      final grupo = qrInfo['grupo']?.toString().trim();

      final parts = _currentUserId!.split('/');
      final studentId = parts[1];

      final scanId = '${qrInfo['eventId']}_${studentId}_$codigoProyecto';

      // ── Verificar duplicado ──────────────────────────────────────
      final existingDoc = await _firestore
          .collection('events')
          .doc(qrInfo['eventId'])
          .collection('asistencias')
          .doc(studentId)
          .collection('scans')
          .doc(scanId)
          .get();

      if (existingDoc.exists) {
        final existingData = existingDoc.data()!;
        final registeredDate =
            (existingData['timestamp'] as Timestamp?)
                ?.toDate()
                .toString()
                .substring(0, 16) ??
            'Fecha desconocida';

        _showResult(
          success: false,
          message:
              '⚠️ Ya escaneaste este código anteriormente\n\n'
              '📋 Proyecto: ${existingData['tituloProyecto']}\n'
              '🔢 Código: $codigoProyecto\n'
              '📂 Categoría: ${qrInfo['categoria']}\n'
              '📅 Registrado: $registeredDate',
        );
        return;
      }

      // ── Normalizar valores finales ───────────────────────────────
      final codigoFinal = _esBlancoONulo(codigoProyecto)
          ? 'Sin código'
          : codigoProyecto!;
      final tituloFinal = _esBlancoONulo(tituloProyecto)
          ? 'Sin título'
          : tituloProyecto!;
      final grupoFinal = _esBlancoONulo(grupo) ? null : grupo;

      // ── Guardar asistencia ───────────────────────────────────────
      _escaneosDeSesion++;
      final debeActualizarResumen =
          (_escaneosDeSesion % _intervaloActualizacionResumen == 0) ||
          (_escaneosDeSesion == 1);

      final batch = _firestore.batch();

      final scanRef = _firestore
          .collection('events')
          .doc(qrInfo['eventId'])
          .collection('asistencias')
          .doc(studentId)
          .collection('scans')
          .doc(scanId);

      final resumenRef = _firestore
          .collection('events')
          .doc(qrInfo['eventId'])
          .collection('asistencias')
          .doc(studentId);

      batch.set(scanRef, {
        'codigoProyecto': codigoFinal,
        'tituloProyecto': tituloFinal,
        'categoria': qrInfo['categoria'],
        'grupo': grupoFinal,
        'qrId': qrId,
        'timestamp': FieldValue.serverTimestamp(),
        'qrTimestamp': qrInfo['timestamp'],
        'registrationMethod': 'qr_scan',
      });

      if (debeActualizarResumen) {
        batch.set(resumenRef, {
          'studentName': _currentUserName,
          'studentUsername': _cachedUserData!['username'],
          'studentDNI': _cachedUserData!['dni'],
          'studentCodigo': _cachedUserData!['codigoUniversitario'],
          'facultad': _cachedUserData!['facultad'],
          'carrera': _cachedUserData!['carrera'],
          // ✅ incluir sede/filial en el resumen de asistencia
          'sede': _studentSede ?? '',
          'ciclo': _cachedUserData!['ciclo'],
          'grupo': _cachedUserData!['grupo'],
          'eventId': qrInfo['eventId'],
          'eventName': qrInfo['eventName'],
          'lastScan': FieldValue.serverTimestamp(),
          'totalScans': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      _showResult(
        success: true,
        message: 'Asistencia registrada exitosamente',
        eventName: qrInfo['eventName'],
        categoria: qrInfo['categoria'],
        codigoProyecto: codigoFinal,
        sede: qrInfo['sede']?.toString(),
      );
    } catch (e) {
      debugPrint('Error procesando asistencia: $e');
      _showResult(success: false, message: 'Error al procesar asistencia: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  bool _esBlancoONulo(String? valor) {
    if (valor == null || valor.trim().isEmpty) return true;
    final v = valor.trim().toLowerCase();
    return v == 'null' ||
        v == 'sin código' ||
        v == 'sin codigo' ||
        v == 'sin título' ||
        v == 'sin titulo' ||
        v == 'sin grupo';
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ DIÁLOGO DE RESULTADO
  // ═══════════════════════════════════════════════════════════════
  void _showResult({
    required bool success,
    required String message,
    String? eventName,
    String? categoria,
    String? codigoProyecto,
    String? sede,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 5,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: success
                    ? [Colors.green.shade50, Colors.white]
                    : [Colors.red.shade50, Colors.white],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Icono animado ──────────────────────────────
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, double value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: success ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (success ? Colors.green : Colors.red)
                                    .withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            success ? Icons.check_circle : Icons.error,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    success ? '¡Éxito!' : 'No permitido',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: success
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                      softWrap: true,
                    ),
                  ),

                  // ── Detalle del evento (solo en éxito) ─────────
                  if (success && eventName != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nombre del evento
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.event_available,
                                  color: Colors.green.shade600,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  eventName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF1E3A5F),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          // Sede del evento (si existe)
                          if (sede != null && sede.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _buildResultRow(
                              icon: Icons.location_city,
                              iconColor: Colors.blue.shade600,
                              label: 'Sede: $sede',
                            ),
                          ],

                          // Categoría
                          if (categoria != null) ...[
                            const SizedBox(height: 10),
                            _buildResultRow(
                              icon: Icons.category,
                              iconColor: Colors.blue.shade600,
                              label: 'Categoría: $categoria',
                            ),
                          ],

                          // Código proyecto
                          if (codigoProyecto != null &&
                              codigoProyecto != 'Sin código') ...[
                            const SizedBox(height: 10),
                            _buildResultRow(
                              icon: Icons.qr_code,
                              iconColor: Colors.purple.shade600,
                              label: 'Código: $codigoProyecto',
                              bold: true,
                            ),
                          ],

                          // Info del estudiante
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                color: Colors.grey.shade600,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentUserName ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E3A5F),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_currentUsername != null)
                                      Text(
                                        '@$_currentUsername',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    // ✅ Mostrar sede del estudiante en el resultado
                                    if (_studentSede != null)
                                      Text(
                                        '🏛️ $_studentSede',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Botones ────────────────────────────────────
                  Row(
                    children: [
                      if (!success)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFF64748B)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      if (!success) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            if (success) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const AsistenciasScreen(),
                                ),
                              );
                            } else {
                              _resetScanner();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: success
                                ? Colors.green
                                : const Color(0xFF1E3A5F),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            success ? 'Ver Asistencias' : 'Reintentar',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    bool bold = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: bold ? const Color(0xFF1E3A5F) : const Color(0xFF64748B),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  void _resetScanner() async {
    setState(() {
      _hasScanned = false;
      _isProcessing = false;
    });
    await cameraController.start();
  }

  Future<void> _toggleFlash() async {
    await cameraController.toggleTorch();
    setState(() => _isFlashOn = !_isFlashOn);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: _currentUserId == null
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Column(
                children: [
                  // ── Header ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Regresar',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner,
                            color: Color(0xFF1E3A5F),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Escanear QR',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    _isFlashOn
                                        ? Icons.flash_on
                                        : Icons.flash_off,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  onPressed: _toggleFlash,
                                  tooltip: 'Flash',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // ── Content ──────────────────────────────────────
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8EDF2),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          // ── Tarjeta de estudiante con sede ────────
                          Container(
                            margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF1E3A5F),
                                        Colors.blue.shade700,
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentUserName ?? 'Cargando...',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E3A5F),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (_currentUsername != null)
                                        Text(
                                          '@$_currentUsername',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      // ✅ Chips de sede + carrera
                                      if (_studentSede != null ||
                                          _studentCarrera != null)
                                        const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (_studentSede != null)
                                            _buildMiniChip(
                                              icon: Icons.location_city,
                                              label: _studentSede!,
                                              color: const Color(0xFF1565C0),
                                            ),
                                          if (_studentCarrera != null)
                                            _buildMiniChip(
                                              icon: Icons.menu_book,
                                              label: _studentCarrera!,
                                              color: const Color(0xFF00897B),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Cámara ────────────────────────────────
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                children: [
                                  GestureDetector(
                                    onScaleStart: _handleScaleStart,
                                    onScaleUpdate: _handleScaleUpdate,
                                    child: MobileScanner(
                                      controller: cameraController,
                                      onDetect: (capture) {
                                        for (final barcode
                                            in capture.barcodes) {
                                          if (barcode.rawValue != null &&
                                              !_hasScanned &&
                                              !_isProcessing) {
                                            _procesarQR(barcode.rawValue!);
                                            break;
                                          }
                                        }
                                      },
                                    ),
                                  ),

                                  // Indicador de zoom
                                  if (_currentZoom > 0.0)
                                    Positioned(
                                      top: 16,
                                      right: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.zoom_in,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${(_currentZoom * 100).toInt()}%',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Marco de escaneo
                                  Center(
                                    child: SizedBox(
                                      width: 250,
                                      height: 250,
                                      child: Stack(
                                        children: [
                                          // Esquinas del marco
                                          ...List.generate(4, (index) {
                                            return Positioned(
                                              top: index < 2 ? 0 : null,
                                              bottom: index >= 2 ? 0 : null,
                                              left: index % 2 == 0 ? 0 : null,
                                              right:
                                                  index % 2 == 1 ? 0 : null,
                                              child: Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    top: index < 2
                                                        ? const BorderSide(
                                                            color: Colors.white,
                                                            width: 4,
                                                          )
                                                        : BorderSide.none,
                                                    bottom: index >= 2
                                                        ? const BorderSide(
                                                            color: Colors.white,
                                                            width: 4,
                                                          )
                                                        : BorderSide.none,
                                                    left: index % 2 == 0
                                                        ? const BorderSide(
                                                            color: Colors.white,
                                                            width: 4,
                                                          )
                                                        : BorderSide.none,
                                                    right: index % 2 == 1
                                                        ? const BorderSide(
                                                            color: Colors.white,
                                                            width: 4,
                                                          )
                                                        : BorderSide.none,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),

                                          // Línea de escaneo
                                          AnimatedBuilder(
                                            animation: _scanLineAnimation,
                                            builder: (context, child) {
                                              return Positioned(
                                                top: 250 *
                                                    _scanLineAnimation.value,
                                                left: 0,
                                                right: 0,
                                                child: Container(
                                                  height: 2,
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        LinearGradient(
                                                      colors: [
                                                        Colors.transparent,
                                                        Colors.green.shade400,
                                                        Colors.transparent,
                                                      ],
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors
                                                            .green
                                                            .shade400
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                        blurRadius: 8,
                                                        spreadRadius: 2,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Overlay de procesando
                                  if (_isProcessing)
                                    Container(
                                      color: Colors.black87,
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 60,
                                              height: 60,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 3,
                                              ),
                                            ),
                                            SizedBox(height: 24),
                                            Text(
                                              'Registrando asistencia...',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // ── Pie de instrucciones ──────────────────
                          Container(
                            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1E3A5F,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.qr_code_2,
                                    color: Color(0xFF1E3A5F),
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Coloca el código QR dentro del marco',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E3A5F),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Usa dos dedos para hacer zoom',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMiniChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    cameraController.dispose();
    _escaneosDeSesion = 0;
    super.dispose();
  }
}