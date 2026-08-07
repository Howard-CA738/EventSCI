import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../logica/asistencias_personales_service.dart';

const _primary = Color(0xFF1E3A5F);
const _success = Color(0xFF43A047);
const _muted = Color(0xFF64748B);

void mostrarQrAsistenciaPersonalDialog(
  BuildContext context,
  Map<String, dynamic> asistencia,
) {
  HapticFeedback.selectionClick();
  final data = construirQrPayload(asistencia);
  final nombre = (asistencia['nombre'] as String?) ?? 'Asistencia';
  final eventName = (asistencia['eventName'] as String?) ?? '';
  final codigo = (asistencia['codigo'] as String?) ?? '';

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.qr_code_2_rounded, color: _success, size: 16),
                SizedBox(width: 6),
                Text('Código QR',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _success)),
              ]),
            ),
            const SizedBox(height: 16),
            Text(
              nombre,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: _primary),
            ),
            if (eventName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                eventName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: _muted),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0E7ED), width: 2),
              ),
              child: QrImageView(
                data: data,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            if (codigo.isNotEmpty) ...[
              const SizedBox(height: 18),
              buildCodigoManualBox(codigo),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Cerrar',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget buildCodigoManualBox(String codigo) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _primary.withValues(alpha: 0.2)),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.dialpad_rounded, size: 16, color: _primary),
            SizedBox(width: 6),
            Text(
              'Código para ingreso manual',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          codigo,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
            color: _primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'El alumno puede escanear el QR o escribir este número.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    ),
  );
}
