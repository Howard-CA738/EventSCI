import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

/// Servicio compartido para los códigos numéricos de asistencia.
///
/// Cada QR (de proyecto o personal) puede tener además un código de 6 dígitos.
/// El "puente" se guarda en `codigos/{codigo}` con el MISMO `qrData` (JSON) que
/// lleva el QR, de modo que escribir el código termina en EXACTAMENTE la misma
/// lógica de registro que escanear el QR. No duplica validaciones: solo lleva
/// al alumno al mismo punto de entrada (`_procesarQR`).
///
/// Esquema del documento `codigos/{codigo}`:
///   codigo        -> el propio código de 6 dígitos (también es el ID del doc)
///   eventId       -> evento al que pertenece
///   qrId          -> id del qr_code asociado
///   type          -> 'proyecto' | 'asistencia_personal'
///   asistenciaId  -> solo para asistencias personales (null en proyectos)
///   qrData        -> el JSON idéntico al que codifica el QR
///   createdAt     -> marca de tiempo del servidor
class CodigoAsistenciaService {
  CodigoAsistenciaService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Random _random = Random.secure();

  /// Genera un código único de 6 dígitos, registra el puente en
  /// `codigos/{codigo}` y devuelve el código generado.
  ///
  /// Usa una transacción con reintentos para garantizar unicidad: si el número
  /// ya existe (colisión), prueba con otro. Con cientos de QR la probabilidad
  /// de colisión es mínima, pero igual queda cubierta.
  static Future<String> generarYRegistrar({
    required String eventId,
    required String qrId,
    required String type, // 'proyecto' | 'asistencia_personal'
    required String qrData, // el mismo JSON que codifica el QR
    String? asistenciaId,
  }) async {
    const maxIntentos = 10;

    for (var intento = 0; intento < maxIntentos; intento++) {
      // Rango 100000–999999: siempre 6 dígitos, nunca empieza en 0.
      final codigo = (100000 + _random.nextInt(900000)).toString();
      final ref = _firestore.collection('codigos').doc(codigo);

      try {
        final asignado = await _firestore.runTransaction<bool>((tx) async {
          final snap = await tx.get(ref);
          if (snap.exists) return false; // colisión → reintentar
          tx.set(ref, {
            'codigo': codigo,
            'eventId': eventId,
            'qrId': qrId,
            'type': type,
            'asistenciaId': asistenciaId,
            'qrData': qrData,
            'createdAt': FieldValue.serverTimestamp(),
          });
          return true;
        });

        if (asignado) return codigo;
      } catch (_) {
        // Falla puntual de la transacción → reintenta con otro número.
      }
    }

    throw Exception('No se pudo generar un código único. Intenta de nuevo.');
  }

  /// Busca el código que escribió el alumno y devuelve el `qrData` (JSON)
  /// listo para pasar a la misma lógica de escaneo. Devuelve null si no existe.
  ///
  /// Importante: NO valida aquí si el QR está activo, dentro de su ventana, etc.
  /// Esa validación la hace la MISMA función `_procesarQR`, que lee el qr_code /
  /// asistencia real. Así hay una sola fuente de verdad y el código respeta
  /// automáticamente las desactivaciones y ventanas horarias.
  static Future<String?> buscarQrData(String codigo) async {
    final c = codigo.trim();
    if (c.isEmpty) return null;

    final snap = await _firestore.collection('codigos').doc(c).get();
    if (!snap.exists) return null;

    return snap.data()?['qrData'] as String?;
  }

  /// Elimina el código. Llámalo cuando borres el QR/asistencia asociado
  /// (por ejemplo en `_eliminarAsistencia`), para no dejar códigos huérfanos.
  static Future<void> eliminar(String codigo) async {
    final c = codigo.trim();
    if (c.isEmpty) return;
    try {
      await _firestore.collection('codigos').doc(c).delete();
    } catch (_) {
      // Silencioso: si falla la limpieza no es crítico.
    }
  }
}