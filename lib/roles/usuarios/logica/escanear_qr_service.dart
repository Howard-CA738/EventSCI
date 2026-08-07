import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/prefs_helper.dart';
import '/admin/logica/escaner_config_service.dart';

class QRScanResult {
  final bool success;
  final String message;
  final String? eventName;
  final String? categoria;
  final String? codigoProyecto;
  final String? filial;
  final bool esPersonal;
  final bool resetScanner;

  const QRScanResult({
    required this.success,
    required this.message,
    this.eventName,
    this.categoria,
    this.codigoProyecto,
    this.filial,
    this.esPersonal = false,
    this.resetScanner = false,
  });
}

class EscanearQRService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? currentUserId;
  String? currentUserName;
  String? currentUsername;
  Map<String, dynamic>? cachedUserData;
  String? studentFilial;
  int cooldownSegundos = EscanerConfigService.defaultCooldown;
  bool usuarioCargado = false;

  static const String keyCooldown = 'ultimo_escaneo_global';

  Future<void> cargarUsuario() async {
    await PrefsHelper.ensureAuthActiva();
    cooldownSegundos = await EscanerConfigService.getCooldownSegundos();
    final userId = await PrefsHelper.getCurrentUserId();
    final userName = await PrefsHelper.getUserName();
    final userData = await PrefsHelper.getCurrentUserData();

    currentUserId = userId;
    currentUserName = userName;
    currentUsername = userData?['username'];
    cachedUserData = userData;
    if (userData != null) {
      studentFilial = userData['filial']?.toString();
    }
    usuarioCargado = true;
  }

  Future<T> conReintento<T>(
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
        debugPrint(
            '🔁 Reintento $intento tras "${e.code}", espera ${espera.inMilliseconds}ms');
        await Future.delayed(espera);
      }
    }
  }

  Future<String?> puedeEscanear() async {
    if (cooldownSegundos <= 0) return null;
    final prefs = await SharedPreferences.getInstance();
    final ultimoMs = prefs.getInt('${keyCooldown}_$currentUserId');
    if (ultimoMs != null) {
      final diferencia = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(ultimoMs));
      if (diferencia.inSeconds < cooldownSegundos) {
        final restante = cooldownSegundos - diferencia.inSeconds;
        final minutos = restante ~/ 60;
        final segundos = restante % 60;
        final texto =
            minutos > 0 ? '${minutos}m ${segundos}s' : '${segundos}s';
        return '⏳ Debes esperar $texto para escanear de nuevo';
      }
    }
    return null;
  }

  Future<void> guardarCooldown() async {
    if (cooldownSegundos <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '${keyCooldown}_$currentUserId',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  String normalizar(String? valor) {
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

  String normalizarCarrera(String? valor) {
    return normalizar(valor).replaceAll(RegExp(r'^ep\s*'), '');
  }

  bool esEventoUniversitario(Map<String, dynamic> qrInfo) {
    final f = normalizar(qrInfo['facultad']);
    final c = normalizar(qrInfo['carrera']);
    return f == 'universidad peruana union' ||
        f == 'universidad peruana unión' ||
        c == 'general';
  }

  bool esEventoDeSede(Map<String, dynamic> qrInfo) {
    final c = normalizar(qrInfo['carrera']);
    return c == 'general';
  }

  bool filialCoincide(Map<String, dynamic> qrInfo) {
    final qrFilial = normalizar(qrInfo['filialNombre']);
    if (qrFilial.isEmpty) return true;
    final sFilial = normalizar(studentFilial);
    return sFilial.isEmpty || sFilial == qrFilial;
  }

  bool esBlancoONulo(String? valor) {
    if (valor == null || valor.trim().isEmpty) return true;
    final v = valor.trim().toLowerCase();
    return v == 'null' ||
        v == 'sin código' ||
        v == 'sin codigo' ||
        v == 'sin título' ||
        v == 'sin titulo' ||
        v == 'sin grupo';
  }

  Future<QRScanResult> procesarQR(String qrData) async {
    try {
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
        return QRScanResult(
          success: false,
          message: 'QR inválido: No contiene datos válidos\nError: $e',
        );
      }

      final qrId = qrInfo['qrId'];
      if (qrId == null || qrId.toString().isEmpty) {
        return const QRScanResult(
          success: false,
          message: '⚠️ QR sin ID válido. Regenera el código QR.',
        );
      }

      final eventId = qrInfo['eventId']?.toString();
      if (eventId == null || eventId.isEmpty) {
        return const QRScanResult(
          success: false,
          message: 'QR incompleto: Falta el campo "eventId"',
        );
      }

      final qrDoc = await conReintento(() => _firestore
          .collection('events')
          .doc(eventId)
          .collection('qr_codes')
          .doc(qrId)
          .get());

      if (!qrDoc.exists) {
        return const QRScanResult(
          success: false,
          message: '⚠️ Este código QR no existe o fue eliminado',
        );
      }

      final qrDocData = qrDoc.data()!;
      final isActive = qrDocData['activo'] ?? false;
      if (!isActive) {
        return const QRScanResult(
          success: false,
          message: '🔒 Este código QR ya fue FINALIZADO',
        );
      }

      if (currentUserId == null) {
        currentUserId = await PrefsHelper.getCurrentUserId();
        if (currentUserId == null) {
          return const QRScanResult(
            success: false,
            message: '📶 No se pudo verificar tu sesión.\n\n'
                'Revisa tu conexión e intenta de nuevo.',
          );
        }
      }

      if (cachedUserData == null) {
        cachedUserData =
            await PrefsHelper.getCurrentUserData(forceRefresh: true);
        cachedUserData ??= await PrefsHelper.getPersistedStudentData();
        if (cachedUserData != null) {
          studentFilial = cachedUserData!['filial']?.toString();
        }
      }

      if (cachedUserData == null) {
        return const QRScanResult(
          success: false,
          message: '📶 No se pudieron cargar tus datos.\n\n'
              'Revisa tu conexión a internet e intenta de nuevo.',
        );
      }

      final qrType = (qrDocData['type'] ?? qrInfo['type'] ?? '').toString();
      if (qrType == 'asistencia_personal') {
        return await procesarQRAsistenciaPersonal(qrInfo, qrDocData);
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
          return QRScanResult(
            success: false,
            message: 'QR incompleto: Falta el campo "$field"',
          );
        }
      }

      final esUniversitario = esEventoUniversitario(qrInfo);
      if (!esUniversitario) {
        if (!filialCoincide(qrInfo)) {
          final qrFilial =
              qrInfo['filialNombre']?.toString() ?? 'Sin filial';
          return QRScanResult(
            success: false,
            message: '🏛️ Este evento es de otra filial.\n\n'
                '📌 EVENTO:\n'
                'Filial: "$qrFilial"\n\n'
                '👤 TU FILIAL:\n'
                '"${studentFilial ?? 'No registrada'}"',
          );
        }

        final userFacultad = normalizar(cachedUserData!['facultad']);
        final userCarrera = normalizarCarrera(cachedUserData!['carrera']);
        final eventFacultad = normalizar(qrInfo['facultad']);
        final eventCarrera = normalizarCarrera(qrInfo['carrera']);
        final esDeSede = esEventoDeSede(qrInfo);

        if (!esDeSede) {
          if (userFacultad != eventFacultad || userCarrera != eventCarrera) {
            return QRScanResult(
              success: false,
              message:
                  '🚫 Este evento no corresponde a tu facultad/carrera.\n\n'
                  '📌 EVENTO:\n'
                  'Facultad: "${qrInfo['facultad']}"\n'
                  'Carrera: "${qrInfo['carrera']}"\n\n'
                  '👤 TU PERFIL:\n'
                  'Facultad: "${cachedUserData!['facultad']}"\n'
                  'Carrera: "${cachedUserData!['carrera']}"',
            );
          }
        }
      }

      final codigoProyecto = qrInfo['codigoProyecto']?.toString().trim();
      final tituloProyecto = qrInfo['tituloProyecto']?.toString().trim();
      final grupo = qrInfo['grupo']?.toString().trim();

      final parts = currentUserId!.split('/');
      final studentId = parts[1];
      final scanId = '${qrInfo['eventId']}_${studentId}_$codigoProyecto';

      final existingDoc = await conReintento(() => _firestore
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
        return QRScanResult(
          success: false,
          message: '⚠️ Ya escaneaste este código anteriormente\n\n'
              '📅 Registrado: $registeredDate',
        );
      }

      final cooldownMsg = await puedeEscanear();
      if (cooldownMsg != null) {
        return QRScanResult(
          success: false,
          message: cooldownMsg,
          resetScanner: true,
        );
      }

      final codigoFinal =
          esBlancoONulo(codigoProyecto) ? 'Sin código' : codigoProyecto!;
      final tituloFinal =
          esBlancoONulo(tituloProyecto) ? 'Sin título' : tituloProyecto!;
      final grupoFinal = esBlancoONulo(grupo) ? null : grupo;

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

      batch.set(
          resumenRef,
          {
            'studentName': currentUserName,
            'studentUsername': cachedUserData!['username'],
            'studentDNI': cachedUserData!['dni'],
            'studentCodigo': cachedUserData!['codigoUniversitario'],
            'facultad': cachedUserData!['facultad'],
            'carrera': cachedUserData!['carrera'],
            'filial': studentFilial ?? '',
            'ciclo': cachedUserData!['ciclo'],
            'grupo': cachedUserData!['grupo'],
            'eventId': qrInfo['eventId'],
            'eventName': qrInfo['eventName'],
            'lastScan': FieldValue.serverTimestamp(),
            'totalScans': FieldValue.increment(1),
          },
          SetOptions(merge: true));

      await conReintento(() => batch.commit());
      await guardarCooldown();

      return QRScanResult(
        success: true,
        message: 'Asistencia registrada exitosamente',
        eventName: qrInfo['eventName'],
        categoria: qrInfo['categoria'],
        codigoProyecto: codigoFinal,
        filial: qrInfo['filialNombre']?.toString(),
      );
    } on FirebaseException catch (e) {
      debugPrint('Error en procesarQR: ${e.code} - ${e.message}');
      final esRed =
          e.code == 'unavailable' || e.code == 'deadline-exceeded';
      return QRScanResult(
        success: false,
        message: esRed
            ? '📶 Problema de conexión.\n\n'
                'No se pudo registrar tu asistencia. Revisa tu internet '
                'e intenta de nuevo.'
            : 'Error al registrar asistencia: ${e.message}',
      );
    } catch (e) {
      debugPrint('Error en procesarQR: $e');
      final msg = e.toString().toLowerCase();
      final esRed = msg.contains('unavailable') ||
          msg.contains('deadline') ||
          msg.contains('network') ||
          msg.contains('unreachable');
      return QRScanResult(
        success: false,
        message: esRed
            ? '📶 Sin conexión o señal débil.\n\n'
                'No se pudo registrar tu asistencia.\n'
                'Revisa tu internet e intenta de nuevo.'
            : 'Error al registrar asistencia: $e',
      );
    }
  }

  Future<QRScanResult> procesarQRAsistenciaPersonal(
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
          return QRScanResult(
            success: false,
            message:
                'QR de asistencia personal incompleto: falta "$field"',
          );
        }
      }

      if (!filialCoincide(qrInfo)) {
        final qrFilial =
            qrInfo['filialNombre']?.toString() ?? 'Sin filial';
        return QRScanResult(
          success: false,
          message: '🏛️ Este evento es de otra filial.\n\n'
              '📌 EVENTO:\nFilial: "$qrFilial"\n\n'
              '👤 TU FILIAL:\n"${studentFilial ?? 'No registrada'}"',
        );
      }

      final userFacultad = normalizar(cachedUserData!['facultad']);
      final userCarrera = normalizarCarrera(cachedUserData!['carrera']);
      final eventFacultad = normalizar(qrInfo['facultad']);
      final eventCarrera = normalizarCarrera(qrInfo['carrera']);

      final esUniversitarioPersonal = esEventoUniversitario(qrInfo);
      final esDeSedePersonal = esEventoDeSede(qrInfo);

      if (!esUniversitarioPersonal && !esDeSedePersonal) {
        if (userFacultad != eventFacultad || userCarrera != eventCarrera) {
          return QRScanResult(
            success: false,
            message:
                '🚫 Este evento no corresponde a tu facultad/carrera.\n\n'
                '📌 EVENTO:\nFacultad: "${qrInfo['facultad']}"\nCarrera: "${qrInfo['carrera']}"\n\n'
                '👤 TU PERFIL:\nFacultad: "${cachedUserData!['facultad']}"\nCarrera: "${cachedUserData!['carrera']}"',
          );
        }
      }

      final eventId = qrInfo['eventId'] as String;
      final asistenciaId = qrInfo['asistenciaId'] as String;
      final qrId = qrInfo['qrId'] as String;

      final asistenciaDoc = await conReintento(() => _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias_personales')
          .doc(asistenciaId)
          .get());

      if (!asistenciaDoc.exists) {
        return const QRScanResult(
          success: false,
          message: '⚠️ Esta asistencia ya no existe.',
        );
      }

      final aData = asistenciaDoc.data()!;
      final ahora = DateTime.now();

      final activoBase = aData['activo'] as bool? ?? false;
      if (!activoBase) {
        return const QRScanResult(
          success: false,
          message:
              '🔒 Este código QR ha sido DESACTIVADO por el administrador.',
        );
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
            return QRScanResult(
              success: false,
              message: '⏳ Este QR aún no está disponible.\n\n'
                  '🕐 Disponible a partir de las '
                  '${inicio.hour.toString().padLeft(2, '0')}:'
                  '${inicio.minute.toString().padLeft(2, '0')}\n'
                  'Faltan: ${horas > 0 ? '${horas}h ' : ''}${minutos}min',
            );
          }

          if (ahora.isAfter(fin)) {
            return QRScanResult(
              success: false,
              message: '⌛ La ventana horaria de este QR ha cerrado.\n\n'
                  '🕐 Estuvo disponible de '
                  '${inicio.hour.toString().padLeft(2, '0')}:'
                  '${inicio.minute.toString().padLeft(2, '0')} '
                  'a '
                  '${fin.hour.toString().padLeft(2, '0')}:'
                  '${fin.minute.toString().padLeft(2, '0')}',
            );
          }
        }
      }

      final tiempoLimiteActivo =
          aData['tiempoLimiteActivo'] as bool? ?? false;
      if (tiempoLimiteActivo) {
        final activadoTs = aData['activadoEn'] as Timestamp?;
        final minutos =
            (aData['tiempoLimiteMinutos'] as num?)?.toInt() ?? 30;

        if (activadoTs != null) {
          final expira =
              activadoTs.toDate().add(Duration(minutes: minutos));
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

            return QRScanResult(
              success: false,
              message: '⏱️ El tiempo de este QR ha expirado.\n\n'
                  'El código estuvo activo durante $minutos minuto${minutos != 1 ? 's' : ''}.\n'
                  'El administrador puede reactivarlo si es necesario.',
            );
          }
        }
      }

      final parts = currentUserId!.split('/');
      final studentId = parts.length > 1 ? parts[1] : currentUserId!;

      final existingDoc = await conReintento(() => _firestore
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
        return QRScanResult(
          success: false,
          message: '⚠️ Ya registraste esta asistencia anteriormente\n\n'
              '📋 ${qrInfo['nombre'] ?? 'Asistencia personal'}\n'
              '📅 Registrado: $registeredDate',
        );
      }

      final cooldownMsg = await puedeEscanear();
      if (cooldownMsg != null) {
        return QRScanResult(
          success: false,
          message: cooldownMsg,
          resetScanner: true,
        );
      }

      final registroRef = _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias_personales')
          .doc(asistenciaId)
          .collection('registros')
          .doc(studentId);

      await conReintento(() => registroRef.set({
            'studentId': studentId,
            'studentName': currentUserName,
            'studentUsername': cachedUserData!['username'],
            'studentDNI': cachedUserData!['dni'],
            'studentCodigo': cachedUserData!['codigoUniversitario'],
            'facultad': cachedUserData!['facultad'],
            'carrera': cachedUserData!['carrera'],
            'filial': studentFilial ?? '',
            'ciclo': cachedUserData!['ciclo'],
            'grupo': cachedUserData!['grupo'],
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
      await guardarCooldown();

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
          debugPrint(
              'totalRegistros no actualizado (contención esperada): $e');
        }),
      );

      return QRScanResult(
        success: true,
        message: '¡Asistencia personal registrada!',
        eventName: qrInfo['eventName'],
        categoria:
            qrInfo['tipo'] ?? qrInfo['nombre'] ?? 'Asistencia Personal',
        filial: qrInfo['filialNombre']?.toString(),
        esPersonal: true,
      );
    } on FirebaseException catch (e) {
      debugPrint(
          'Error en asistencia personal: ${e.code} - ${e.message}');
      final esRed =
          e.code == 'unavailable' || e.code == 'deadline-exceeded';
      return QRScanResult(
        success: false,
        message: esRed
            ? '📶 Problema de conexión.\n\nRevisa tu internet e intenta de nuevo.'
            : 'Error al procesar asistencia personal: ${e.message}',
      );
    } catch (e) {
      debugPrint('Error en asistencia personal: $e');
      return QRScanResult(
        success: false,
        message: 'Error al procesar asistencia personal: $e',
      );
    }
  }
}
