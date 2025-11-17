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

  // ✅ AGREGAR ESTAS LÍNEAS:
  DateTime? _ultimoEscaneo;
  static const int _cooldownSegundos = 3;

  // ✅ CACHE DE DATOS DEL USUARIO (evita leer cada vez)
  Map<String, dynamic>? _cachedUserData;
  int _escaneosDeSesion = 0;
  static const int _intervaloActualizacionResumen = 3;
  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _setupAnimations();
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

  // ═══════════════════════════════════════════════════════════════
  // ✅ OPTIMIZADO: Cargar datos del usuario UNA VEZ con caché
  // ═══════════════════════════════════════════════════════════════
  Future<void> _getCurrentUser() async {
    try {
      final userId = await PrefsHelper.getCurrentUserId();
      final userName = await PrefsHelper.getUserName();

      // ✅ USAR CACHÉ del PrefsHelper
      final userData = await PrefsHelper.getCurrentUserData();

      setState(() {
        _currentUserId = userId;
        _currentUserName = userName;
        _currentUsername = userData?['username'];
        _cachedUserData = userData;
      });

      print('✅ Usuario cargado desde caché');
    } catch (e) {
      _showSnackBar('Error al obtener usuario: $e', isError: true);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ OPTIMIZADO: Reducido de 3 lecturas a 2 lecturas
  // ANTES: qrDoc + existingDoc + allScans = 3 lecturas
  // AHORA: qrDoc + existingDoc = 2 lecturas (conteo eliminado)
  // ═══════════════════════════════════════════════════════════════
  Future<void> _procesarQR(String qrData) async {
    // ✅ PRIMERO: Validar que no esté procesando
    if (_isProcessing || _hasScanned) return;

    // ✅ SEGUNDO: Validar cooldown
    if (_ultimoEscaneo != null) {
      final diferencia = DateTime.now().difference(_ultimoEscaneo!);
      if (diferencia.inSeconds < _cooldownSegundos) {
        _showSnackBar(
          'Espera ${_cooldownSegundos - diferencia.inSeconds}s antes de escanear',
          isError: true,
        );
        return; // No reiniciar cámara, solo esperar
      }
    }

    // ✅ TERCERO: Registrar timestamp DESPUÉS de validaciones
    _ultimoEscaneo = DateTime.now();

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
            final decodedData = Uri.decodeComponent(encodedData);
            qrInfo = jsonDecode(decodedData);
          } else {
            throw Exception('No data parameter found in deep link');
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

      // ═══════════════════════════════════════════════════════════
      // PASO 2: VALIDAR QUE EL QR ESTÉ ACTIVO (1 LECTURA)
      // ═══════════════════════════════════════════════════════════
      final qrId = qrInfo['qrId'];
      if (qrId == null || qrId.toString().isEmpty) {
        _showResult(
          success: false,
          message: '⚠️ QR sin ID válido. Regenera el código QR.',
        );
        return;
      }

      print('🔍 Verificando QR: $qrId');

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

      final qrDataMap = qrDoc.data()!;
      final isActive = qrDataMap['activo'] ?? false;

      if (!isActive) {
        final finalizadoAt = qrDataMap['finalizadoAt'] as Timestamp?;
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

      // ═══════════════════════════════════════════════════════════
      // PASO 3: VALIDAR CAMPOS REQUERIDOS
      // ═══════════════════════════════════════════════════════════
      final requiredFields = [
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
            message: 'QR incompleto: Falta el campo $field',
          );
          return;
        }
      }

      if (_currentUserId == null || _cachedUserData == null) {
        _showResult(
          success: false,
          message: 'Debes iniciar sesión para registrar asistencia',
        );
        return;
      }

      // ═══════════════════════════════════════════════════════════
      // PASO 4: VALIDAR FACULTAD Y CARRERA (sin lectura adicional)
      // ═══════════════════════════════════════════════════════════
      String userFacultad = (_cachedUserData!['facultad'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      String userCarrera = (_cachedUserData!['carrera'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      String eventFacultad = (qrInfo['facultad'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      String eventCarrera = (qrInfo['carrera'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      // Normalizar carreras
      userCarrera = userCarrera.replaceAll(RegExp(r'^ep\s*'), '');
      eventCarrera = eventCarrera.replaceAll(RegExp(r'^ep\s*'), '');

      // Evento general de UPeU
      bool esEventoUPeU =
          eventFacultad == 'universidad peruana unión' ||
          eventFacultad == 'universidad peruana union';
      bool esCarreraGeneral = eventCarrera == 'general';

      if (!esEventoUPeU || !esCarreraGeneral) {
        if (userFacultad != eventFacultad || userCarrera != eventCarrera) {
          _showResult(
            success: false,
            message:
                'Este evento no corresponde a tu facultad/carrera.\n\n'
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

      // ═══════════════════════════════════════════════════════════
      // PASO 5: VERIFICAR DUPLICADOS CON ID COMPUESTO (1 LECTURA)
      // ═══════════════════════════════════════════════════════════
      final codigoProyecto = qrInfo['codigoProyecto']?.toString().trim();
      final tituloProyecto = qrInfo['tituloProyecto']?.toString().trim();
      final grupo = qrInfo['grupo']?.toString().trim();

      final parts = _currentUserId!.split('/');
      final studentId = parts[1];

      // ✅ ID COMPUESTO: eventId + studentId + codigoProyecto
      final scanId = '${qrInfo['eventId']}_${studentId}_$codigoProyecto';

      print('🔍 Verificando duplicado con ID: $scanId');

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

        // ✅ OPTIMIZACIÓN: Eliminado el conteo extra de scans
        // Antes hacía una query adicional para contar
        // Ahora simplemente informa que ya existe

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

      // ═══════════════════════════════════════════════════════════
      // PASO 6: GUARDAR ASISTENCIA CON BATCH (1 ESCRITURA BATCH)
      // ═══════════════════════════════════════════════════════════
      final codigoFinal =
          (codigoProyecto != null &&
              codigoProyecto.isNotEmpty &&
              codigoProyecto.toLowerCase() != 'sin código' &&
              codigoProyecto.toLowerCase() != 'sin codigo' &&
              codigoProyecto != 'null')
          ? codigoProyecto
          : 'Sin código';

      final tituloFinal =
          (tituloProyecto != null &&
              tituloProyecto.isNotEmpty &&
              tituloProyecto.toLowerCase() != 'sin título' &&
              tituloProyecto.toLowerCase() != 'sin titulo' &&
              tituloProyecto != 'null')
          ? tituloProyecto
          : 'Sin título';

      final grupoFinal =
          (grupo != null &&
              grupo.isNotEmpty &&
              grupo.toLowerCase() != 'sin grupo' &&
              grupo != 'null')
          ? grupo
          : null;

      final scanData = {
        'codigoProyecto': codigoFinal,
        'tituloProyecto': tituloFinal,
        'categoria': qrInfo['categoria'],
        'grupo': grupoFinal,
        'qrId': qrId,
        'timestamp': FieldValue.serverTimestamp(),
        'qrTimestamp': qrInfo['timestamp'],
        'registrationMethod': 'qr_scan',
      };

      // ✅ OPTIMIZACIÓN: Incrementar contador de escaneos
      _escaneosDeSesion++;

      // ✅ Decidir si actualizar resumen (solo cada N escaneos)
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

      // ✅ SIEMPRE guardar el scan individual
      batch.set(scanRef, scanData);

      // ✅ CONDICIONAL: Solo actualizar resumen cada N escaneos
      if (debeActualizarResumen) {
        batch.set(resumenRef, {
          'studentName': _currentUserName,
          'studentUsername': _cachedUserData!['username'],
          'studentDNI': _cachedUserData!['dni'],
          'studentCodigo': _cachedUserData!['codigoUniversitario'],
          'facultad': _cachedUserData!['facultad'],
          'carrera': _cachedUserData!['carrera'],
          'eventId': qrInfo['eventId'],
          'eventName': qrInfo['eventName'],
          'lastScan': FieldValue.serverTimestamp(),
          'totalScans': FieldValue.increment(1),
        }, SetOptions(merge: true));

        print(
          '✅ Asistencia con resumen: $scanId (Escaneo #$_escaneosDeSesion)',
        );
      } else {
        print(
          '✅ Asistencia SIN resumen: $scanId (Escaneo #$_escaneosDeSesion)',
        );
      }

      await batch.commit();

      print('✅ Asistencia guardada con batch: $scanId');

      _showResult(
        success: true,
        message: 'Asistencia registrada exitosamente',
        eventName: qrInfo['eventName'],
        categoria: qrInfo['categoria'],
        codigoProyecto: codigoFinal,
      );
    } catch (e) {
      print('❌ Error procesando asistencia: $e');
      _showResult(success: false, message: 'Error al procesar asistencia: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showResult({
    required bool success,
    required String message,
    String? eventName,
    String? categoria,
    String? codigoProyecto,
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
                  TweenAnimationBuilder(
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
                                    .withOpacity(0.3),
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
                    success ? '¡Éxito!' : 'Error',
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
                      overflow: TextOverflow.visible,
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
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                          if (categoria != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.category,
                                  color: Colors.blue.shade600,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Categoría: $categoria',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (codigoProyecto != null &&
                              codigoProyecto != 'Sin código') ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.qr_code,
                                  color: Colors.purple.shade600,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Código: $codigoProyecto',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E3A5F),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
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
                                      maxLines: 1,
                                    ),
                                    if (_currentUsername != null)
                                      Text(
                                        '@$_currentUsername',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
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
                    mainAxisAlignment: MainAxisAlignment.center,
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
                                  builder: (context) =>
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

  void _resetScanner() async {
    setState(() {
      _hasScanned = false;
      _isProcessing = false;
    });
    await cameraController.start();
  }

  Future<void> _toggleFlash() async {
    await cameraController.toggleTorch();
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
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
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
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
                                  color: Colors.white.withOpacity(0.2),
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
                          Container(
                            margin: const EdgeInsets.all(20),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
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
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentUserName ?? 'Cargando...',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E3A5F),
                                        ),
                                      ),
                                      if (_currentUsername != null)
                                        Text(
                                          '@$_currentUsername',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                children: [
                                  MobileScanner(
                                    controller: cameraController,
                                    onDetect: (capture) {
                                      final List<Barcode> barcodes =
                                          capture.barcodes;
                                      for (final barcode in barcodes) {
                                        if (barcode.rawValue != null &&
                                            !_hasScanned &&
                                            !_isProcessing) {
                                          _procesarQR(barcode.rawValue!);
                                          break;
                                        }
                                      }
                                    },
                                  ),
                                  Center(
                                    child: SizedBox(
                                      width: 250,
                                      height: 250,
                                      child: Stack(
                                        children: [
                                          ...List.generate(4, (index) {
                                            return Positioned(
                                              top: index < 2 ? 0 : null,
                                              bottom: index >= 2 ? 0 : null,
                                              left: index % 2 == 0 ? 0 : null,
                                              right: index % 2 == 1 ? 0 : null,
                                              child: TweenAnimationBuilder(
                                                duration: const Duration(
                                                  milliseconds: 800,
                                                ),
                                                tween: Tween<double>(
                                                  begin: 0,
                                                  end: 1,
                                                ),
                                                builder: (context, double value, child) {
                                                  return Opacity(
                                                    opacity: value,
                                                    child: Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        border: Border(
                                                          top: index < 2
                                                              ? const BorderSide(
                                                                  color: Colors
                                                                      .white,
                                                                  width: 4,
                                                                )
                                                              : BorderSide.none,
                                                          bottom: index >= 2
                                                              ? const BorderSide(
                                                                  color: Colors
                                                                      .white,
                                                                  width: 4,
                                                                )
                                                              : BorderSide.none,
                                                          left: index % 2 == 0
                                                              ? const BorderSide(
                                                                  color: Colors
                                                                      .white,
                                                                  width: 4,
                                                                )
                                                              : BorderSide.none,
                                                          right: index % 2 == 1
                                                              ? const BorderSide(
                                                                  color: Colors
                                                                      .white,
                                                                  width: 4,
                                                                )
                                                              : BorderSide.none,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                          }),
                                          AnimatedBuilder(
                                            animation: _scanLineAnimation,
                                            builder: (context, child) {
                                              return Positioned(
                                                top:
                                                    250 *
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
                                                            .green
                                                            .shade400
                                                            .withOpacity(0.5),
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
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            TweenAnimationBuilder(
                                              duration: const Duration(
                                                milliseconds: 600,
                                              ),
                                              tween: Tween<double>(
                                                begin: 0,
                                                end: 1,
                                              ),
                                              builder:
                                                  (
                                                    context,
                                                    double value,
                                                    child,
                                                  ) {
                                                    return Transform.scale(
                                                      scale: value,
                                                      child: Container(
                                                        width: 80,
                                                        height: 80,
                                                        decoration:
                                                            BoxDecoration(
                                                              color: Colors
                                                                  .white
                                                                  .withOpacity(
                                                                    0.1,
                                                                  ),
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                        child:
                                                            const CircularProgressIndicator(
                                                              color:
                                                                  Colors.white,
                                                              strokeWidth: 3,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                            ),
                                            const SizedBox(height: 24),
                                            const Text(
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
                          Container(
                            margin: const EdgeInsets.all(20),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
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
                                    ).withOpacity(0.1),
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
                                        'Coloca el código QR',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E3A5F),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Escanea todos los códigos diferentes de la categoría',
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

  @override
  void dispose() {
    _animationController.dispose();
    cameraController.dispose();
    _escaneosDeSesion = 0;
    super.dispose();
  }
}
