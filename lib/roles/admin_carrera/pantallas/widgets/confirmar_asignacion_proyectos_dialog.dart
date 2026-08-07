import 'package:flutter/material.dart';

Future<bool?> mostrarConfirmarAsignacionProyectosDialog(
  BuildContext context, {
  required bool modoEdicion,
  required int proyectosSeleccionados,
  required int proyectosAEliminar,
  required String nombreRubrica,
  required String nombreJurado,
}) {
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (modoEdicion
                            ? const Color(0xFF2E9E6E)
                            : const Color(0xFF1E3A5F))
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    modoEdicion ? Icons.edit_note : Icons.assignment_turned_in,
                    color: modoEdicion
                        ? const Color(0xFF2E9E6E)
                        : const Color(0xFF1E3A5F),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    modoEdicion ? 'Confirmar cambios' : 'Confirmar asignación',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              modoEdicion
                  ? proyectosSeleccionados == 0
                      ? '¿Quitar TODOS los proyectos asignados a $nombreJurado?'
                      : '¿Guardar los cambios de proyectos para $nombreJurado?'
                  : '¿Asignar $proyectosSeleccionados proyecto(s) a $nombreJurado?',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD9F5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.checklist_rounded,
                      color: Color(0xFF3B6FD4), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      nombreRubrica,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (proyectosAEliminar > 0) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFEC5C5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep_rounded,
                        color: Color(0xFFD4453B), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$proyectosAEliminar asignación(es) se eliminarán',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFD4453B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
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
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: modoEdicion
                          ? const Color(0xFF2E9E6E)
                          : const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      modoEdicion ? 'Guardar' : 'Asignar',
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
}
