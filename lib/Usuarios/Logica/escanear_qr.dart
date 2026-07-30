import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import '/prefs_helper.dart';
import '/usuarios/logica/asistencias.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '/admin_carrera/codigo_asistencia_service.dart';
import '/admin/logica/escaner_config_service.dart';

class EscanearQRScreen extends StatefulWidget {
  const EscanearQRScreen({super.key});

  @override
  State<EscanearQRScreen> createState() => _EscanearQRScreenState();
}

class _EscanearQRScreenState extends State<EscanearQRScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  MobileScannerController cameraController = MobileScannerController();
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUsername;
  bool _isProcessing = false;
  bool _hasScanned = false;
  bool _isFlashOn = false;
  bool _usuarioCargado = false;

  double _currentZoom = 0.0;

int _cooldownSegundos = EscanerConfigService.defaultCooldown;
static const String _keyCooldown = 'ultimo_escaneo_global';

  Map<String, dynamic>? _cachedUserData;

  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _pulseAnimation;

  String? _studentFilial;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getCurrentUser();
    _setupAnimations();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(cameraController.start());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        unawaited(cameraController.stop());
        break;
      default:
        break;
    }
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

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }
/// Reintenta una operación de Firestore ante errores transitorios de red.
Future<T> _conReintento<T>(
  Future<T> Function() operacion, {
  int maxIntentos = 4,
}) async {
  int intento = 0;
  while (true) {
    try {
      return await operacion();
    } on FirebaseException catch (e) {
      intento++;
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        if (intento >= maxIntentos) rethrow;
        debugPrint('🔁 Auth perdida ("${e.code}") → recreando sesión');
        await PrefsHelper.reautenticarAnonimo();
        await Future.delayed(const Duration(milliseconds: 300));
        continue;
      }
      const transitorios = {
        'unavailable',
        'deadline-exceeded',
        'aborted',
        'internal',
        'resource-exhausted',
      };
      if (!transitorios.contains(e.code) || intento >= maxIntentos) {
        rethrow;
      }
      final espera = Duration(milliseconds: 400 * (1 << (intento - 1)));
      debugPrint('🔁 Reintento $intento tras "${e.code}", espera ${espera.inMilliseconds}ms');
      await Future.delayed(espera);
    }
  }
}

/// Solo VERIFICA el cooldown. No guarda nada.
/// Devuelve true si PUEDE escanear, false si debe esperar.
Future<bool> _puedeEscanear() async {
  if (_cooldownSegundos <= 0) return true;
  final prefs = await SharedPreferences.getInstance();
  final ultimoMs = prefs.getInt('${_keyCooldown}_$_currentUserId');
  if (ultimoMs != null) {
    final diferencia = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ultimoMs));
    if (diferencia.inSeconds < _cooldownSegundos) {
      final restante = _cooldownSegundos - diferencia.inSeconds;
      final minutos = restante ~/ 60;
      final segundos = restante % 60;
      final texto =
          minutos > 0 ? '${minutos}m ${segundos}s' : '${segundos}s';
      _showSnackBar('⏳ Debes esperar $texto para escanear de nuevo',
          isError: true);
      return false;
    }
  }
  return true;
}

/// Guarda el timestamp del cooldown. Llamar SOLO tras un registro exitoso.
Future<void> _guardarCooldown() async {
  if (_cooldownSegundos <= 0) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(
    '${_keyCooldown}_$_currentUserId',
    DateTime.now().millisecondsSinceEpoch,
  );
}

Future<void> _getCurrentUser() async {
    try {
      await PrefsHelper.ensureAuthActiva();   // ← reestablece sesión al abrir el escáner
      _cooldownSegundos = await EscanerConfigService.getCooldownSegundos();
      final userId = await PrefsHelper.getCurrentUserId();
      final userName = await PrefsHelper.getUserName();
      final userData = await PrefsHelper.getCurrentUserData();
 
   setState(() {
  _currentUserId = userId;
  _currentUserName = userName;
  _currentUsername = userData?['username'];
  _cachedUserData = userData;

  if (userData != null) {
    _studentFilial = userData['filial']?.toString();
  }
  _usuarioCargado = true; // ← SOLO AGREGAR ESTA LÍNEA
});
 
    } catch (e) {
      _showSnackBar('Error al obtener usuario: $e', isError: true);
    }
  }
  
  String _normalizar(String? valor) {
    if (valor == null) return '';
    const Map<String, String> tildes = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n', 'ç': 'c',
    };
    String result = valor.trim().toLowerCase();
    tildes.forEach((tilde, reemplazo) {
      result = result.replaceAll(tilde, reemplazo);
    });
    return result;
  }

  String _normalizarCarrera(String? valor) {
    return _normalizar(valor).replaceAll(RegExp(r'^ep\s*'), '');
  }

  bool _esEventoUniversitario(Map<String, dynamic> qrInfo) {
    final f = _normalizar(qrInfo['facultad']);
    final c = _normalizar(qrInfo['carrera']);
    return f == 'universidad peruana union' ||
        f == 'universidad peruana unión' ||
        c == 'general';
  }

  bool _esEventoDeSede(Map<String, dynamic> qrInfo) {
    final c = _normalizar(qrInfo['carrera']);
    return c == 'general';
  }

  bool _filialCoincide(Map<String, dynamic> qrInfo) {
    final qrFilial = _normalizar(qrInfo['filialNombre']);
    if (qrFilial.isEmpty) return true;
    final studentFilial = _normalizar(_studentFilial);
    return studentFilial.isEmpty || studentFilial == qrFilial;
  }
void _mostrarDialogoCodigo() async {
  if (!_usuarioCargado) { // ← AGREGAR ESTAS 3 LÍNEAS
    _showSnackBar('Cargando datos, espera un momento...', isError: false);
    return;
  }
  await cameraController.stop();

    final codigoCtrl = TextEditingController();
    bool buscando = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 40,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.dialpad_rounded,
                          color: Color(0xFF1E3A5F), size: 32),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ingresar código',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E3A5F),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Escribe el código de 6 dígitos\nque te proporcionó el asistente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: codigoCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      autofocus: true,
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 10,
                        color: Color(0xFF1E3A5F),
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '······',
                        hintStyle: TextStyle(
                          fontSize: 32,
                          letterSpacing: 10,
                          color: Colors.grey.shade300,
                          fontWeight: FontWeight.w800,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFF1E3A5F), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                      ),
                      onSubmitted: (_) async {
                        if (codigoCtrl.text.trim().length == 6 && !buscando) {
                          await _procesarCodigoManual(
                            codigoCtrl.text.trim(),
                            ctx,
                            setDialogState,
                            () => buscando = true,
                            () => buscando = false,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 22),
                    Row(children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: buscando
                                ? null
                                : () {
                                    Navigator.pop(ctx);
                                  },
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              side: const BorderSide(
                                  color: Color(0xFF1E3A5F)),
                              foregroundColor: const Color(0xFF1E3A5F),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancelar',
                                style:
                                    TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: buscando
                                ? null
                                : () async {
                                    final c = codigoCtrl.text.trim();
                                    if (c.length != 6) {
                                      _showSnackBar(
                                          'El código debe tener 6 dígitos',
                                          isError: true);
                                      return;
                                    }
                                    await _procesarCodigoManual(
                                      c,
                                      ctx,
                                      setDialogState,
                                      () => setDialogState(
                                          () => buscando = true),
                                      () => setDialogState(
                                          () => buscando = false),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A5F),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: buscando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Confirmar',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (mounted && !_isProcessing && !_hasScanned) {
      await cameraController.start();
    }
  }

  Future<void> _procesarCodigoManual(
    String codigo,
    BuildContext dialogCtx,
    StateSetter setDialogState,
    VoidCallback onStart,
    VoidCallback onEnd,
  ) async {
    onStart();
    try {
      final qrData = await CodigoAsistenciaService.buscarQrData(codigo);
      if (qrData == null || qrData.isEmpty) {
        onEnd();
        _showSnackBar('⚠️ Código no encontrado o inválido', isError: true);
        return;
      }
      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
      setState(() {
        _hasScanned = true;
        _isProcessing = true;
      });
      await _procesarQR(qrData);
    } catch (e) {
      onEnd();
      _showSnackBar('Error al buscar el código: $e', isError: true);
    }
  }

  Future<void> _procesarQR(String qrData) async {
  if (_isProcessing && !_hasScanned) return;
  if (!_hasScanned) {
    setState(() {
      _isProcessing = true;
      _hasScanned = true;
    });
  }

  try {
    await cameraController.stop();

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

    final qrId = qrInfo['qrId'];
    if (qrId == null || qrId.toString().isEmpty) {
      _showResult(
        success: false,
        message: '⚠️ QR sin ID válido. Regenera el código QR.',
      );
      return;
    }

    final eventId = qrInfo['eventId']?.toString();
    if (eventId == null || eventId.isEmpty) {
      _showResult(
        success: false,
        message: 'QR incompleto: Falta el campo "eventId"',
      );
      return;
    }

    final qrDoc = await _conReintento(() => _firestore
        .collection('events')
        .doc(eventId)
        .collection('qr_codes')
        .doc(qrId)
        .get());

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
      _showResult(
        success: false,
        message: '🔒 Este código QR ya fue FINALIZADO',
      );
      return;
    }

    // ── Sesión / datos del usuario ──────────────────────────────────
    // Si no hay sesión, sí es un login faltante.
    if (_currentUserId == null) {
  _currentUserId = await PrefsHelper.getCurrentUserId(); // reintento
  if (_currentUserId == null) {
    _showResult(
      success: false,
      message: '📶 No se pudo verificar tu sesión.\n\n'
          'Revisa tu conexión e intenta de nuevo.',
    );
    return;
  }
}

    // Hay sesión pero faltan los datos (suele ser una carga fallida por
    // red): reintenta cargarlos antes de bloquear.
    if (_cachedUserData == null) {
      _cachedUserData =
          await PrefsHelper.getCurrentUserData(forceRefresh: true);
      _cachedUserData ??= await PrefsHelper.getPersistedStudentData();   // ← último recurso
      if (_cachedUserData != null) {
        _studentFilial = _cachedUserData!['filial']?.toString();
      }
    }

    // Si aún así no hay datos, es conexión: mensaje honesto.
    if (_cachedUserData == null) {
      _showResult(
        success: false,
        message: '📶 No se pudieron cargar tus datos.\n\n'
            'Revisa tu conexión a internet e intenta de nuevo.',
      );
      return;
    }

    final qrType = (qrDocData['type'] ?? qrInfo['type'] ?? '').toString();

    if (qrType == 'asistencia_personal') {
      await _procesarQRAsistenciaPersonal(qrInfo, qrDocData);
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

    final esUniversitario = _esEventoUniversitario(qrInfo);

    if (!esUniversitario) {
      if (!_filialCoincide(qrInfo)) {
        final qrFilial = qrInfo['filialNombre']?.toString() ?? 'Sin filial';
        _showResult(
          success: false,
          message: '🏛️ Este evento es de otra filial.\n\n'
              '📌 EVENTO:\n'
              'Filial: "$qrFilial"\n\n'
              '👤 TU FILIAL:\n'
              '"${_studentFilial ?? 'No registrada'}"',
        );
        return;
      }

      final userFacultad = _normalizar(_cachedUserData!['facultad']);
      final userCarrera = _normalizarCarrera(_cachedUserData!['carrera']);
      final eventFacultad = _normalizar(qrInfo['facultad']);
      final eventCarrera = _normalizarCarrera(qrInfo['carrera']);
      final esDeSede = _esEventoDeSede(qrInfo);

      if (!esDeSede) {
        if (userFacultad != eventFacultad || userCarrera != eventCarrera) {
          _showResult(
            success: false,
            message: '🚫 Este evento no corresponde a tu facultad/carrera.\n\n'
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

    final codigoProyecto = qrInfo['codigoProyecto']?.toString().trim();
    final tituloProyecto = qrInfo['tituloProyecto']?.toString().trim();
    final grupo = qrInfo['grupo']?.toString().trim();

    final parts = _currentUserId!.split('/');
    final studentId = parts[1];

    final scanId = '${qrInfo['eventId']}_${studentId}_$codigoProyecto';

    final existingDoc = await _conReintento(() => _firestore
        .collection('events')
        .doc(qrInfo['eventId'])
        .collection('asistencias')
        .doc(studentId)
        .collection('scans')
        .doc(scanId)
        .get());

    if (existingDoc.exists) {
      final existingData = existingDoc.data()!;
      final registeredDate = (existingData['timestamp'] as Timestamp?)
              ?.toDate()
              .toString()
              .substring(0, 16) ??
          'Fecha desconocida';
      _showResult(
        success: false,
        message: '⚠️ Ya escaneaste este código anteriormente\n\n'
            '📅 Registrado: $registeredDate',
      );
      return;
    }

    final codigoFinal =
        _esBlancoONulo(codigoProyecto) ? 'Sin código' : codigoProyecto!;
    final tituloFinal =
        _esBlancoONulo(tituloProyecto) ? 'Sin título' : tituloProyecto!;
    final grupoFinal = _esBlancoONulo(grupo) ? null : grupo;

    final cooldownOk = await _puedeEscanear();
    if (!cooldownOk) {
      _resetScanner();
      return;
    }

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

    batch.set(resumenRef, {
      'studentName': _currentUserName,
      'studentUsername': _cachedUserData!['username'],
      'studentDNI': _cachedUserData!['dni'],
      'studentCodigo': _cachedUserData!['codigoUniversitario'],
      'facultad': _cachedUserData!['facultad'],
      'carrera': _cachedUserData!['carrera'],
      'filial': _studentFilial ?? '',
      'ciclo': _cachedUserData!['ciclo'],
      'grupo': _cachedUserData!['grupo'],
      'eventId': qrInfo['eventId'],
      'eventName': qrInfo['eventName'],
      'lastScan': FieldValue.serverTimestamp(),
      'totalScans': FieldValue.increment(1),
    }, SetOptions(merge: true));

    await _conReintento(() => batch.commit());
    await _guardarCooldown();

    _showResult(
      success: true,
      message: 'Asistencia registrada exitosamente',
      eventName: qrInfo['eventName'],
      categoria: qrInfo['categoria'],
      codigoProyecto: codigoFinal,
      filial: qrInfo['filialNombre']?.toString(),
    );
  } on FirebaseException catch (e) {
    debugPrint('Error en _procesarQR: ${e.code} - ${e.message}');
    final esRed = e.code == 'unavailable' || e.code == 'deadline-exceeded';
    _showResult(
      success: false,
      message: esRed
          ? '📶 Problema de conexión.\n\n'
              'No se pudo registrar tu asistencia. Revisa tu internet '
              'e intenta de nuevo.'
          : 'Error al registrar asistencia: ${e.message}',
    );
  } catch (e) {
  debugPrint('Error en _procesarQR: $e');
  final msg = e.toString().toLowerCase();
  final esRed = msg.contains('unavailable') ||
      msg.contains('deadline') ||
      msg.contains('network') ||
      msg.contains('unreachable');
  _showResult(
    success: false,
    message: esRed
        ? '📶 Sin conexión o señal débil.\n\n'
            'No se pudo registrar tu asistencia.\n'
            'Revisa tu internet e intenta de nuevo.'
        : 'Error al registrar asistencia: $e',
  );
} finally {
    if (mounted) setState(() => _isProcessing = false);
  }
}

  Future<void> _procesarQRAsistenciaPersonal(
  Map<String, dynamic> qrInfo,
  Map<String, dynamic> qrDocData,
) async {
  try {
    for (final field in [
      'eventId',
      'eventName',
      'facultad',
      'carrera',
      'asistenciaId',
      'qrId',
    ]) {
      if (qrInfo[field] == null || qrInfo[field].toString().trim().isEmpty) {
        _showResult(
          success: false,
          message: 'QR de asistencia personal incompleto: falta "$field"',
        );
        return;
      }
    }

    if (!_filialCoincide(qrInfo)) {
      final qrFilial = qrInfo['filialNombre']?.toString() ?? 'Sin filial';
      _showResult(
        success: false,
        message: '🏛️ Este evento es de otra filial.\n\n'
            '📌 EVENTO:\nFilial: "$qrFilial"\n\n'
            '👤 TU FILIAL:\n"${_studentFilial ?? 'No registrada'}"',
      );
      return;
    }

    final userFacultad = _normalizar(_cachedUserData!['facultad']);
    final userCarrera = _normalizarCarrera(_cachedUserData!['carrera']);
    final eventFacultad = _normalizar(qrInfo['facultad']);
    final eventCarrera = _normalizarCarrera(qrInfo['carrera']);

    final esUniversitarioPersonal = _esEventoUniversitario(qrInfo);
    final esDeSedePersonal = _esEventoDeSede(qrInfo);

    if (!esUniversitarioPersonal && !esDeSedePersonal) {
      if (userFacultad != eventFacultad || userCarrera != eventCarrera) {
        _showResult(
          success: false,
          message: '🚫 Este evento no corresponde a tu facultad/carrera.\n\n'
              '📌 EVENTO:\nFacultad: "${qrInfo['facultad']}"\nCarrera: "${qrInfo['carrera']}"\n\n'
              '👤 TU PERFIL:\nFacultad: "${_cachedUserData!['facultad']}"\nCarrera: "${_cachedUserData!['carrera']}"',
        );
        return;
      }
    }

    final eventId = qrInfo['eventId'] as String;
    final asistenciaId = qrInfo['asistenciaId'] as String;
    final qrId = qrInfo['qrId'] as String;

    final asistenciaDoc = await _conReintento(() => _firestore
        .collection('events')
        .doc(eventId)
        .collection('asistencias_personales')
        .doc(asistenciaId)
        .get());

    if (!asistenciaDoc.exists) {
      _showResult(
        success: false,
        message: '⚠️ Esta asistencia ya no existe.',
      );
      return;
    }

    final aData = asistenciaDoc.data()!;
    final ahora = DateTime.now();

    final activoBase = aData['activo'] as bool? ?? false;
    if (!activoBase) {
      _showResult(
        success: false,
        message: '🔒 Este código QR ha sido DESACTIVADO por el administrador.',
      );
      return;
    }

    final ventanaActiva = aData['ventanaHorariaActiva'] as bool? ?? false;
    if (ventanaActiva) {
      final inicioTs = aData['ventanaInicio'] as Timestamp?;
      final finTs = aData['ventanaFin'] as Timestamp?;

      if (inicioTs != null && finTs != null) {
        final inicio = inicioTs.toDate();
        final fin = finTs.toDate();

        if (ahora.isBefore(inicio)) {
          final diff = inicio.difference(ahora);
          final horas = diff.inHours;
          final minutos = diff.inMinutes.remainder(60);
          _showResult(
            success: false,
            message: '⏳ Este QR aún no está disponible.\n\n'
                '🕐 Disponible a partir de las '
                '${inicio.hour.toString().padLeft(2, '0')}:'
                '${inicio.minute.toString().padLeft(2, '0')}\n'
                'Faltan: ${horas > 0 ? '${horas}h ' : ''}${minutos}min',
          );
          return;
        }

        if (ahora.isAfter(fin)) {
          _showResult(
            success: false,
            message: '⌛ La ventana horaria de este QR ha cerrado.\n\n'
                '🕐 Estuvo disponible de '
                '${inicio.hour.toString().padLeft(2, '0')}:'
                '${inicio.minute.toString().padLeft(2, '0')} '
                'a '
                '${fin.hour.toString().padLeft(2, '0')}:'
                '${fin.minute.toString().padLeft(2, '0')}',
          );
          return;
        }
      }
    }

    final tiempoLimiteActivo = aData['tiempoLimiteActivo'] as bool? ?? false;
    if (tiempoLimiteActivo) {
      final activadoTs = aData['activadoEn'] as Timestamp?;
      final minutos = (aData['tiempoLimiteMinutos'] as num?)?.toInt() ?? 30;

      if (activadoTs != null) {
        final expira = activadoTs.toDate().add(Duration(minutes: minutos));
        if (ahora.isAfter(expira)) {
          _firestore
              .collection('events')
              .doc(eventId)
              .collection('asistencias_personales')
              .doc(asistenciaId)
              .update({
            'activo': false,
            'finalizadoAt': FieldValue.serverTimestamp(),
          }).catchError((_) {});

          final qrIdDoc = aData['qrId']?.toString();
          if (qrIdDoc != null && qrIdDoc.isNotEmpty) {
            _firestore
                .collection('events')
                .doc(eventId)
                .collection('qr_codes')
                .doc(qrIdDoc)
                .update({
              'activo': false,
              'finalizadoAt': FieldValue.serverTimestamp(),
            }).catchError((_) {});
          }

          _showResult(
            success: false,
            message: '⏱️ El tiempo de este QR ha expirado.\n\n'
                'El código estuvo activo durante $minutos minuto${minutos != 1 ? 's' : ''}.\n'
                'El administrador puede reactivarlo si es necesario.',
          );
          return;
        }
      }
    }

    final parts = _currentUserId!.split('/');
    final studentId = parts.length > 1 ? parts[1] : _currentUserId!;

    final existingDoc = await _conReintento(() => _firestore
        .collection('events')
        .doc(eventId)
        .collection('asistencias_personales')
        .doc(asistenciaId)
        .collection('registros')
        .doc(studentId)
        .get());

    if (existingDoc.exists) {
      final existingData = existingDoc.data()!;
      final registeredDate = (existingData['timestamp'] as Timestamp?)
              ?.toDate()
              .toString()
              .substring(0, 16) ??
          'Fecha desconocida';
      _showResult(
        success: false,
        message: '⚠️ Ya registraste esta asistencia anteriormente\n\n'
            '📋 ${qrInfo['nombre'] ?? 'Asistencia personal'}\n'
            '📅 Registrado: $registeredDate',
      );
      return;
    }

    final cooldownOk = await _puedeEscanear();
    if (!cooldownOk) {
      _resetScanner();
      return;
    }

    final registroRef = _firestore
        .collection('events')
        .doc(eventId)
        .collection('asistencias_personales')
        .doc(asistenciaId)
        .collection('registros')
        .doc(studentId);

    await _conReintento(() => registroRef.set({
          'studentId': studentId,
          'studentName': _currentUserName,
          'studentUsername': _cachedUserData!['username'],
          'studentDNI': _cachedUserData!['dni'],
          'studentCodigo': _cachedUserData!['codigoUniversitario'],
          'facultad': _cachedUserData!['facultad'],
          'carrera': _cachedUserData!['carrera'],
          'filial': _studentFilial ?? '',
          'ciclo': _cachedUserData!['ciclo'],
          'grupo': _cachedUserData!['grupo'],
          'eventId': eventId,
          'eventName': qrInfo['eventName'],
          'asistenciaId': asistenciaId,
          'asistenciaNombre': qrInfo['nombre'] ?? '',
          'asistenciaTipo': qrInfo['tipo'] ?? 'Asistencia Personal',
          'qrId': qrId,
          'type': 'asistencia_personal',
          'timestamp': FieldValue.serverTimestamp(),
          'registrationMethod': 'codigo_manual',
          
        }));
        await _guardarCooldown();

    unawaited(
      _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias_personales')
          .doc(asistenciaId)
          .set({
        'totalRegistros': FieldValue.increment(1),
        'lastScan': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((Object e) {
        debugPrint('totalRegistros no actualizado (contención esperada): $e');
      }),
    );

    _showResult(
      success: true,
      message: '¡Asistencia personal registrada!',
      eventName: qrInfo['eventName'],
      categoria: qrInfo['tipo'] ?? qrInfo['nombre'] ?? 'Asistencia Personal',
      filial: qrInfo['filialNombre']?.toString(),
      esPersonal: true,
    );
  } on FirebaseException catch (e) {
    debugPrint('Error en asistencia personal: ${e.code} - ${e.message}');
    final esRed = e.code == 'unavailable' || e.code == 'deadline-exceeded';
    _showResult(
      success: false,
      message: esRed
          ? '📶 Problema de conexión.\n\nRevisa tu internet e intenta de nuevo.'
          : 'Error al procesar asistencia personal: ${e.message}',
    );
  } catch (e) {
    debugPrint('Error en asistencia personal: $e');
    _showResult(
      success: false,
      message: 'Error al procesar asistencia personal: $e',
    );
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

  void _showResult({
    required bool success,
    required String message,
    String? eventName,
    String? categoria,
    String? codigoProyecto,
    String? filial,
    bool esPersonal = false,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 32,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 5,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.82,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
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
                      Text(
                        message,
                        style: const TextStyle(
                            fontSize: 15, color: Color(0xFF64748B)),
                        textAlign: TextAlign.center,
                        softWrap: true,
                      ),
                      if (success && eventName != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.event_available,
                                        color: Colors.green.shade600, size: 20),
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
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (esPersonal) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade600,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.how_to_reg_rounded,
                                          color: Colors.white, size: 14),
                                      SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'ASISTENCIA PERSONAL',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (filial != null && filial.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _buildResultRow(
                                  icon: Icons.location_city,
                                  iconColor: Colors.blue.shade600,
                                  label: 'Filial: $filial',
                                ),
                              ],
                              if (categoria != null) ...[
                                const SizedBox(height: 10),
                                _buildResultRow(
                                  icon: esPersonal
                                      ? Icons.how_to_reg_rounded
                                      : Icons.category,
                                  iconColor: esPersonal
                                      ? Colors.deepPurple.shade600
                                      : Colors.blue.shade600,
                                  label: esPersonal
                                      ? 'Tipo: $categoria'
                                      : 'Categoría: $categoria',
                                ),
                              ],
                              if (!esPersonal &&
                                  codigoProyecto != null &&
                                  codigoProyecto != 'Sin código') ...[
                                const SizedBox(height: 10),
                                _buildResultRow(
                                  icon: Icons.qr_code,
                                  iconColor: Colors.purple.shade600,
                                  label: 'Código: $codigoProyecto',
                                  bold: true,
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.person,
                                      color: Colors.grey.shade600, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _currentUserName ?? '',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E3A5F),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
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
                                        if (_studentFilial != null)
                                          Text(
                                            '🏛️ $_studentFilial',
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
                      Row(
                        children: [
                          if (!success)
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop();
                                    Navigator.of(context).pop();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    side: const BorderSide(
                                        color: Color(0xFF64748B)),
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
                            ),
                          if (!success) const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                  if (success) {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const AsistenciasScreen(),
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
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
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
                          ),
                        ],
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
  }

  Widget _buildResultRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    bool bold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: bold
                  ? const Color(0xFF1E3A5F)
                  : const Color(0xFF64748B),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
        ),
      ],
    );
  }

  void _resetScanner() async {
    if (!mounted) return;
    setState(() {
      _hasScanned = false;
      _isProcessing = false;
    });
    await cameraController.start();
  }

  Future<void> _toggleFlash() async {
    await cameraController.toggleTorch();
    if (mounted) setState(() => _isFlashOn = !_isFlashOn);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
  child: !_usuarioCargado
      ? const Center(
          child: CircularProgressIndicator(color: Colors.white))
      : Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12.0 : 20.0,
                      vertical: isSmallScreen ? 12.0 : 20.0,
                    ),
                    child: Row(
                      children: [
                        Semantics(
                          label: 'Regresar',
                          button: true,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.arrow_back_ios_new,
                                  color: Colors.white, size: 22),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: 'Regresar',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.qr_code_scanner,
                              color: Color(0xFF1E3A5F), size: 26),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Registrar Asistencia',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          label: 'Activar o desactivar flash',
                          button: true,
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      _isFlashOn
                                          ? Icons.flash_on
                                          : Icons.flash_off,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                    onPressed: _toggleFlash,
                                    tooltip: 'Flash',
                                  ),
                                ),
                              );
                            },
                          ),
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
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              margin: EdgeInsets.fromLTRB(
                                isSmallScreen ? 12 : 20,
                                isSmallScreen ? 12 : 20,
                                isSmallScreen ? 12 : 20,
                                8,
                              ),
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
                                    behavior: HitTestBehavior.opaque,
                                    onScaleStart: _handleScaleStart,
                                    onScaleUpdate: _handleScaleUpdate,
                                    child: MobileScanner(
                                      controller: cameraController,
                                     onDetect: (capture) {
  for (final barcode in capture.barcodes) {
    if (barcode.rawValue != null &&
        !_hasScanned &&
        !_isProcessing &&
        _usuarioCargado) { // ← SOLO AGREGAR ESTA CONDICIÓN
      _procesarQR(barcode.rawValue!);
      break;
    }
  }
},
                                    ),
                                  ),
                                  if (_currentZoom > 0.0)
                                    Positioned(
                                      top: 16,
                                      right: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.6),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.zoom_in,
                                                color: Colors.white, size: 18),
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
                                  Center(
                                    child: SizedBox(
                                      width: isSmallScreen ? 200 : 250,
                                      height: isSmallScreen ? 200 : 250,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          ...List.generate(4, (index) {
                                            return Positioned(
                                              top: index < 2 ? 0 : null,
                                              bottom: index >= 2 ? 0 : null,
                                              left: index % 2 == 0 ? 0 : null,
                                              right: index % 2 == 1 ? 0 : null,
                                              child: Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    top: index < 2
                                                        ? const BorderSide(
                                                            color: Colors.white,
                                                            width: 4)
                                                        : BorderSide.none,
                                                    bottom: index >= 2
                                                        ? const BorderSide(
                                                            color: Colors.white,
                                                            width: 4)
                                                        : BorderSide.none,
                                                    left: index % 2 == 0
                                                        ? const BorderSide(
                                                            color: Colors.white,
                                                            width: 4)
                                                        : BorderSide.none,
                                                    right: index % 2 == 1
                                                        ? const BorderSide(
                                                            color: Colors.white,
                                                            width: 4)
                                                        : BorderSide.none,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                          AnimatedBuilder(
                                            animation: _scanLineAnimation,
                                            builder: (context, child) {
                                              final boxSize =
                                                  isSmallScreen ? 200.0 : 250.0;
                                              return Positioned(
                                                top: boxSize *
                                                    _scanLineAnimation.value,
                                                left: 0,
                                                right: 0,
                                                child: Container(
                                                  height: 2,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors.transparent,
                                                        Colors.green.shade400,
                                                        Colors.transparent,
                                                      ],
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors
                                                            .green.shade400
                                                            .withValues(
                                                                alpha: 0.5),
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
                                            Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 24),
                                              child: Text(
                                                'Registrando asistencia...',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.center,
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
                          Container(
                            margin: EdgeInsets.fromLTRB(
                              isSmallScreen ? 12 : 20,
                              0,
                              isSmallScreen ? 12 : 20,
                              isSmallScreen ? 12 : 20,
                            ),
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 14, 16, 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E3A5F),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Flexible(
                                        child: Text(
                                          'Elige cómo registrar tu asistencia',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E3A5F),
                                            letterSpacing: -0.2,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Colors.grey.shade100,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      12, 10, 12, 14),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Semantics(
                                          label:
                                              'Escanear QR, apunta la cámara al código QR',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12, horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E3A5F)
                                                  .withValues(alpha: 0.05),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: const Color(0xFF1E3A5F)
                                                    .withValues(alpha: 0.15),
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF1E3A5F)
                                                            .withValues(
                                                                alpha: 0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.qr_code_2,
                                                    color: Color(0xFF1E3A5F),
                                                    size: 26,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                const Text(
                                                  'Escanear QR',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1E3A5F),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  'Apunta la cámara\nal código QR',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        Colors.grey.shade500,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 1,
                                              height: 20,
                                              color: Colors.grey.shade300,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'ó',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade400,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              width: 1,
                                              height: 20,
                                              color: Colors.grey.shade300,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Semantics(
                                          label:
                                              'Ingresar código manual de 6 dígitos',
                                          button: true,
                                          child: GestureDetector(
                                            onTap: _isProcessing
                                                ? null
                                                : _mostrarDialogoCodigo,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                      horizontal: 10),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF0D7377),
                                                    Color(0xFF14919B),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                            0xFF0D7377)
                                                        .withValues(alpha: 0.3),
                                                    blurRadius: 8,
                                                    offset:
                                                        const Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            10),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.2),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.dialpad_rounded,
                                                      color: Colors.white,
                                                      size: 26,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                    'Código manual',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    'Ingresa el código\nde 6 dígitos',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.8),
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    cameraController.dispose();
    super.dispose();
  }
}