import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import '/prefs_helper.dart';
import '/usuarios/logica/asistencias.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class EscanearQRScreen extends StatefulWidget {
  const EscanearQRScreen({super.key});

  @override
  State<EscanearQRScreen> createState() => _EscanearQRScreenState();
}

class _EscanearQRScreenState extends State<EscanearQRScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Object?>? _barcodeSub;
  MobileScannerController cameraController = MobileScannerController();
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUsername;
  bool _isProcessing = false;
  bool _hasScanned = false;
  bool _isFlashOn = false;

  double _currentZoom = 0.0;

  static const int _cooldownMinutos = 5;
  static const String _keyCooldown = 'ultimo_escaneo_global';

  Map<String, dynamic>? _cachedUserData;
  int _escaneosDeSesion = 0;
  static const int _intervaloActualizacionResumen = 3;

  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _pulseAnimation;

  String? _studentFilial;
  String? _studentFacultad;
  String? _studentCarrera;

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
  _barcodeSub?.cancel();
  _barcodeSub = cameraController.barcodes.listen((capture) {
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue != null && !_hasScanned && !_isProcessing) {
        _procesarQR(barcode.rawValue!);
        break;
      }
    }
  });
  unawaited(cameraController.start());
      case AppLifecycleState.inactive:
        unawaited(_barcodeSub?.cancel());
        _barcodeSub = null;
        unawaited(cameraController.stop());
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

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<bool> _verificarYGuardarCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final ultimoMs = prefs.getInt('${_keyCooldown}_${_currentUserId}');

    if (ultimoMs != null) {
      final ultimo = DateTime.fromMillisecondsSinceEpoch(ultimoMs);
      final diferencia = DateTime.now().difference(ultimo);

      if (diferencia.inMinutes < _cooldownMinutos) {
        final restanteTotal =
            (_cooldownMinutos * 60) - diferencia.inSeconds;
        final minutos = restanteTotal ~/ 60;
        final segundos = restanteTotal % 60;
        _showSnackBar(
          '⏳ Debes esperar ${minutos}m ${segundos}s para escanear de nuevo',
          isError: true,
        );
        return false;
      }
    }

    await prefs.setInt(
      '${_keyCooldown}_${_currentUserId}',
      DateTime.now().millisecondsSinceEpoch,
    );
    return true;
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

        if (userData != null) {
          _studentFilial = userData['filial']?.toString();
          _studentFacultad = userData['facultad']?.toString();
          _studentCarrera = userData['carrera']?.toString();
        }
      });
    } catch (e) {
      _showSnackBar('Error al obtener usuario: $e', isError: true);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS DE NORMALIZACIÓN
  // ═══════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════
  // PROCESAR QR PRINCIPAL
  // ═══════════════════════════════════════════════════════════════

  Future<void> _procesarQR(String qrData) async {
    if (_isProcessing || _hasScanned) return;

    setState(() {
      _isProcessing = true;
      _hasScanned = true;
    });

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

      final qrDoc = await _firestore
          .collection('events')
          .doc(eventId)
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
        _showResult(
          success: false,
          message: '🔒 Este código QR ya fue FINALIZADO',
        );
        return;
      }

      if (_currentUserId == null || _cachedUserData == null) {
        _showResult(
          success: false,
          message: 'Debes iniciar sesión para registrar asistencia',
        );
        return;
      }

      final qrType = (qrDocData['type'] ?? qrInfo['type'] ?? '').toString();

      if (qrType == 'asistencia_personal') {
        // Delegamos completamente — este método maneja su propio ciclo de vida
        await _procesarQRAsistenciaPersonal(qrInfo, qrDocData);
        return;
      }

      // ── Flujo normal de proyectos ────────────────────────────────

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
      message:
          '🏛️ Este evento es de otra filial.\n\n'
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

      final codigoProyecto = qrInfo['codigoProyecto']?.toString().trim();
      final tituloProyecto = qrInfo['tituloProyecto']?.toString().trim();
      final grupo = qrInfo['grupo']?.toString().trim();

      final parts = _currentUserId!.split('/');
      final studentId = parts[1];

      final scanId = '${qrInfo['eventId']}_${studentId}_$codigoProyecto';

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
              '📅 Registrado: $registeredDate',
        );
        return;
      }

      final codigoFinal =
          _esBlancoONulo(codigoProyecto) ? 'Sin código' : codigoProyecto!;
      final tituloFinal =
          _esBlancoONulo(tituloProyecto) ? 'Sin título' : tituloProyecto!;
      final grupoFinal = _esBlancoONulo(grupo) ? null : grupo;

      final cooldownOk = await _verificarYGuardarCooldown();
      if (!cooldownOk) return;

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
          'filial': _studentFilial ?? '',
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
        filial: qrInfo['filialNombre']?.toString(),
      );
    } catch (e) {
      debugPrint('Error en _procesarQR: $e');
      _showResult(
        success: false,
        message: 'Error al registrar asistencia: $e',
      );
    } finally {
      // Solo reseteamos _isProcessing aquí.
      // _hasScanned se maneja en _showResult / _resetScanner para
      // evitar que el escáner se reactive antes de que el usuario
      // cierre el diálogo.
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // PROCESAR QR ASISTENCIA PERSONAL
  // ═══════════════════════════════════════════════════════════════

  Future<void> _procesarQRAsistenciaPersonal(
    Map<String, dynamic> qrInfo,
    Map<String, dynamic> qrDocData,
  ) async {
    // NOTA: _isProcessing y _hasScanned ya están en true (set por _procesarQR).
    // Este método NO tiene su propio finally — el finally de _procesarQR
    // es el único punto de reset de _isProcessing.
    // _hasScanned se resetea solo cuando el usuario toca "Reintentar" o cierra.

    try {
      // ── 1. Campos obligatorios ──────────────────────────────────────────
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

      // ── 2. Validación de filial ─────────────────────────────────────────
      if (!_filialCoincide(qrInfo)) {
        final qrFilial = qrInfo['filialNombre']?.toString() ?? 'Sin filial';
        _showResult(
          success: false,
          message:
              '🏛️ Este evento es de otra filial.\n\n'
              '📌 EVENTO:\nFilial: "$qrFilial"\n\n'
              '👤 TU FILIAL:\n"${_studentFilial ?? 'No registrada'}"',
        );
        return;
      }

      // ── 3. Validación de facultad/carrera ───────────────────────────────
      // ── 3. Validación de facultad/carrera ───────────────────────────────────────
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
      message:
          '🚫 Este evento no corresponde a tu facultad/carrera.\n\n'
          '📌 EVENTO:\nFacultad: "${qrInfo['facultad']}"\nCarrera: "${qrInfo['carrera']}"\n\n'
          '👤 TU PERFIL:\nFacultad: "${_cachedUserData!['facultad']}"\nCarrera: "${_cachedUserData!['carrera']}"',
    );
    return;
  }
}

      final eventId = qrInfo['eventId'] as String;
      final asistenciaId = qrInfo['asistenciaId'] as String;
      final qrId = qrInfo['qrId'] as String;

      // ── 4. Leer documento live de asistencia_personal ───────────────────
      final asistenciaDoc = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias_personales')
          .doc(asistenciaId)
          .get();

      if (!asistenciaDoc.exists) {
        _showResult(
          success: false,
          message: '⚠️ Esta asistencia ya no existe.',
        );
        return;
      }

      final aData = asistenciaDoc.data()!;
      final ahora = DateTime.now();

      // ── 4a. ¿Está activo el QR? ─────────────────────────────────────────
      final activoBase = aData['activo'] as bool? ?? false;
      if (!activoBase) {
        _showResult(
          success: false,
          message: '🔒 Este código QR ha sido DESACTIVADO por el administrador.',
        );
        return;
      }

      // ── 4b. Ventana horaria ─────────────────────────────────────────────
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
              message:
                  '⏳ Este QR aún no está disponible.\n\n'
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
              message:
                  '⌛ La ventana horaria de este QR ha cerrado.\n\n'
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

      // ── 4c. Tiempo límite ───────────────────────────────────────────────
      final tiempoLimiteActivo = aData['tiempoLimiteActivo'] as bool? ?? false;
      if (tiempoLimiteActivo) {
        final activadoTs = aData['activadoEn'] as Timestamp?;
        final minutos = (aData['tiempoLimiteMinutos'] as num?)?.toInt() ?? 30;

        if (activadoTs != null) {
          final expira = activadoTs.toDate().add(Duration(minutes: minutos));
          if (ahora.isAfter(expira)) {
            // Auto-desactivar en Firestore (best-effort, no bloqueante)
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
              message:
                  '⏱️ El tiempo de este QR ha expirado.\n\n'
                  'El código estuvo activo durante $minutos minuto${minutos != 1 ? 's' : ''}.\n'
                  'El administrador puede reactivarlo si es necesario.',
            );
            return;
          }
        }
      }

      // ── 5. Verificar si ya registró esta asistencia ─────────────────────
      final parts = _currentUserId!.split('/');
      final studentId = parts.length > 1 ? parts[1] : _currentUserId!;

      final existingDoc = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias_personales')
          .doc(asistenciaId)
          .collection('registros')
          .doc(studentId)
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
              '⚠️ Ya registraste esta asistencia anteriormente\n\n'
              '📋 ${qrInfo['nombre'] ?? 'Asistencia personal'}\n'
              '📅 Registrado: $registeredDate',
        );
        return;
      }

      // ── 6. Verificar cooldown ───────────────────────────────────────────
      final cooldownOk = await _verificarYGuardarCooldown();
      if (!cooldownOk) {
        // Reseteamos _hasScanned para que el usuario pueda reintentar
        // después de que expire el cooldown sin salir de la pantalla.
        if (mounted) setState(() => _hasScanned = false);
        return;
      }

      // ── 7. Guardar registro ─────────────────────────────────────────────
      final batch = _firestore.batch();

      final registroRef = _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias_personales')
          .doc(asistenciaId)
          .collection('registros')
          .doc(studentId);

      batch.set(registroRef, {
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
        'registrationMethod': 'qr_scan',
      });

      final resumenRef = _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias_personales')
          .doc(asistenciaId);

      batch.set(resumenRef, {
        'totalRegistros': FieldValue.increment(1),
        'lastScan': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      _showResult(
        success: true,
        message: '¡Asistencia personal registrada!',
        eventName: qrInfo['eventName'],
        categoria: qrInfo['tipo'] ?? qrInfo['nombre'] ?? 'Asistencia Personal',
        filial: qrInfo['filialNombre']?.toString(),
        esPersonal: true,
      );
    } catch (e) {
      debugPrint('Error en asistencia personal: $e');
      _showResult(
        success: false,
        message: 'Error al procesar asistencia personal: $e',
      );
    }
    // SIN finally aquí — el finally de _procesarQR maneja _isProcessing.
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
  // DIÁLOGO DE RESULTADO
  // ═══════════════════════════════════════════════════════════════

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
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                          fontSize: 15, color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                      softWrap: true,
                    ),
                  ),

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
                          Row(
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
                                  maxLines: 2,
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
                                  Text(
                                    'ASISTENCIA PERSONAL',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
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
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
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
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
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
              color: bold
                  ? const Color(0xFF1E3A5F)
                  : const Color(0xFF64748B),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
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
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: _currentUserId == null
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  // ── Header ─────────────────────────────────────
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
                            icon: const Icon(Icons.arrow_back_ios_new,
                                color: Colors.white, size: 22),
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
                          child: const Icon(Icons.qr_code_scanner,
                              color: Color(0xFF1E3A5F), size: 28),
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
                                  color:
                                      Colors.white.withValues(alpha: 0.2),
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

                  // ── Content ─────────────────────────────────────
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
                          // Tarjeta del estudiante
                          Container(
                            margin:
                                const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.05),
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
                                  child: const Icon(Icons.person,
                                      color: Colors.white, size: 28),
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
                                      if (_studentFilial != null ||
                                          _studentCarrera != null)
                                        const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (_studentFilial != null)
                                            _buildMiniChip(
                                              icon: Icons.location_city,
                                              label: _studentFilial!,
                                              color:
                                                  const Color(0xFF1565C0),
                                            ),
                                          if (_studentCarrera != null)
                                            _buildMiniChip(
                                              icon: Icons.menu_book,
                                              label: _studentCarrera!,
                                              color:
                                                  const Color(0xFF00897B),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Cámara
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.3),
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
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8),
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
                                                color: Colors.white,
                                                size: 18),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${(_currentZoom * 100).toInt()}%',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight:
                                                    FontWeight.bold,
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
                                          ...List.generate(4, (index) {
                                            return Positioned(
                                              top: index < 2 ? 0 : null,
                                              bottom:
                                                  index >= 2 ? 0 : null,
                                              left: index % 2 == 0
                                                  ? 0
                                                  : null,
                                              right: index % 2 == 1
                                                  ? 0
                                                  : null,
                                              child: Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    top: index < 2
                                                        ? const BorderSide(
                                                            color:
                                                                Colors.white,
                                                            width: 4)
                                                        : BorderSide.none,
                                                    bottom: index >= 2
                                                        ? const BorderSide(
                                                            color:
                                                                Colors.white,
                                                            width: 4)
                                                        : BorderSide.none,
                                                    left: index % 2 == 0
                                                        ? const BorderSide(
                                                            color:
                                                                Colors.white,
                                                            width: 4)
                                                        : BorderSide.none,
                                                    right: index % 2 == 1
                                                        ? const BorderSide(
                                                            color:
                                                                Colors.white,
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
                                              return Positioned(
                                                top: 250 *
                                                    _scanLineAnimation.value,
                                                left: 0,
                                                right: 0,
                                                child: Container(
                                                  height: 2,
                                                  decoration:
                                                      BoxDecoration(
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

                                  // Overlay de procesamiento
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
                                              child:
                                                  CircularProgressIndicator(
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

                          // Pie
                          Container(
                            margin:
                                const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.05),
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
                                    color: const Color(0xFF1E3A5F)
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.qr_code_2,
                                      color: Color(0xFF1E3A5F), size: 32),
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
    WidgetsBinding.instance.removeObserver(this);
    _barcodeSub?.cancel();
    _animationController.dispose();
    cameraController.dispose();
    super.dispose();
  }
}