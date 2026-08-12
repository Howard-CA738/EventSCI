import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef GuardarEstudianteCallback = Future<void> Function({
  required String name,
  required String email,
  required String codigoUniversitario,
  String? dni,
  required String celular,
  required String correoInstitucional,
  String? ciclo,
  String? grupo,
});

String? _safeOption(dynamic value, List<String> options) {
  if (value == null) return null;
  final v = value.toString();
  return options.contains(v) ? v : null;
}

Future<void> mostrarDialogoEditarEstudiante(
  BuildContext context, {
  required Map<String, dynamic> student,
  required String dniActual,
  required GuardarEstudianteCallback onGuardar,
  required void Function(String message) onMessage,
}) async {
  final editNombreController =
      TextEditingController(text: student['name'] ?? '');
  final editEmailController =
      TextEditingController(text: student['email'] ?? '');
  final editCodigoController =
      TextEditingController(text: student['codigoUniversitario'] ?? '');
  final editDniController =
      TextEditingController(text: dniActual == 'Sin DNI' ? '' : dniActual);
  final editCelularController =
      TextEditingController(text: student['celular'] ?? '');
  final editCorreoInstitucionalController =
      TextEditingController(text: student['correoInstitucional'] ?? '');

  final cicloOptions = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'];
  final grupoOptions = ['Único', '1', '2', '3', '4'];

  String? selectedCiclo = _safeOption(student['ciclo'], cicloOptions);
  String? selectedGrupo = _safeOption(student['grupo'], grupoOptions);

  bool obscureDni = true;
  final formKey = GlobalKey<FormState>();

  void copiarDni(String text) {
    Clipboard.setData(ClipboardData(text: text));
    onMessage('✅ DNI copiado al portapapeles');
  }

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxH = MediaQuery.of(context).size.height * 0.85;
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxH,
                  maxWidth: 560,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A5F)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.edit,
                                color: Color(0xFF1E3A5F)),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Editar Estudiante',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close, size: 20),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding:
                            const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _editField(
                                editNombreController,
                                'Nombre completo',
                                Icons.person,
                                maxLines: 1,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'El nombre es requerido'
                                        : null,
                              ),
                              const SizedBox(height: 14),
                              _editField(
                                editEmailController,
                                'Email',
                                Icons.email,
                                maxLines: 1,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 14),
                              _editField(
                                editCodigoController,
                                'Código universitario',
                                Icons.badge,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 14),
                              _buildDniField(
                                controller: editDniController,
                                obscure: obscureDni,
                                onCopiar: () {
                                  if (editDniController.text.isNotEmpty) {
                                    copiarDni(editDniController.text);
                                  }
                                },
                                onToggle: () => setDialogState(
                                    () => obscureDni = !obscureDni),
                              ),
                              const SizedBox(height: 14),
                              _editField(
                                editCelularController,
                                'Celular',
                                Icons.phone,
                                maxLines: 1,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 14),
                              _editField(
                                editCorreoInstitucionalController,
                                'Correo institucional',
                                Icons.email_outlined,
                                maxLines: 1,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _dropdownField(
                                      label: 'Ciclo',
                                      icon: Icons.layers,
                                      value: selectedCiclo,
                                      options: cicloOptions,
                                      itemLabel: (v) => 'Ciclo $v',
                                      onChanged: (v) => setDialogState(
                                          () => selectedCiclo = v),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _dropdownField(
                                      label: 'Grupo',
                                      icon: Icons.groups,
                                      value: selectedGrupo,
                                      options: grupoOptions,
                                      itemLabel: (v) => 'Grupo $v',
                                      onChanged: (v) => setDialogState(
                                          () => selectedGrupo = v),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      const Color(0xFF64748B),
                                  side: BorderSide(
                                      color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancelar'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (formKey.currentState!.validate()) {
                                    final nuevoDni =
                                        editDniController.text.trim();
                                    final dniParaActualizar = (nuevoDni
                                                .isNotEmpty &&
                                            nuevoDni != dniActual &&
                                            nuevoDni != 'Sin DNI')
                                        ? nuevoDni
                                        : null;

                                    Navigator.of(context).pop();

                                    await onGuardar(
                                      name: editNombreController.text
                                          .trim(),
                                      email: editEmailController.text
                                          .trim(),
                                      codigoUniversitario:
                                          editCodigoController.text
                                              .trim(),
                                      dni: dniParaActualizar,
                                      celular:
                                          editCelularController.text
                                              .trim(),
                                      correoInstitucional:
                                          editCorreoInstitucionalController
                                              .text
                                              .trim(),
                                      ciclo: selectedCiclo,
                                      grupo: selectedGrupo,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF1E3A5F),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                                child: const Text('Guardar'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ),
  );

  editNombreController.dispose();
  editEmailController.dispose();
  editCodigoController.dispose();
  editDniController.dispose();
  editCelularController.dispose();
  editCorreoInstitucionalController.dispose();
}

Widget _buildDniField({
  required TextEditingController controller,
  required bool obscure,
  required VoidCallback onCopiar,
  required VoidCallback onToggle,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.info_outline_rounded,
                  color: Color(0xFFD4863B), size: 15),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Este es el DNI actual del estudiante. '
                'Puedes copiarlo o escribir uno nuevo.',
                style: TextStyle(fontSize: 11, color: Color(0xFF7D5A00)),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'DNI actual',
          labelStyle:
              const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          prefixIcon: const Icon(Icons.credit_card,
              color: Color(0xFF1E3A5F), size: 20),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  icon: const Icon(Icons.copy_rounded,
                      color: Color(0xFF3B6FD4), size: 19),
                  tooltip: 'Copiar DNI',
                  onPressed: onCopiar,
                  padding: EdgeInsets.zero,
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  onPressed: onToggle,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          helperText: 'Dejar vacío para no cambiar el DNI',
          helperStyle:
              const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    ],
  );
}

Widget _editField(
  TextEditingController controller,
  String label,
  IconData icon, {
  TextInputType? keyboardType,
  String? Function(String?)? validator,
  int maxLines = 1,
}) {
  return TextFormField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    validator: validator,
  );
}

Widget _dropdownField({
  required String label,
  required IconData icon,
  required String? value,
  required List<String> options,
  required ValueChanged<String?> onChanged,
  String Function(String)? itemLabel,
}) {
  return DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    items: [
      const DropdownMenuItem<String>(
        value: null,
        child: Text('Sin seleccionar', overflow: TextOverflow.ellipsis),
      ),
      ...options.map((o) => DropdownMenuItem(
            value: o,
            child: Text(
              itemLabel != null ? itemLabel(o) : o,
              overflow: TextOverflow.ellipsis,
            ),
          )),
    ],
    onChanged: onChanged,
    dropdownColor: Colors.white,
    menuMaxHeight: 260,
    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1E3A5F)),
  );
}
