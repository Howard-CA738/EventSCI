import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import '/shared/certificado_builder.dart';
import '/roles/admin/datos/firmante_resumen.dart';
import '/shared/logica/facultad_id_helper.dart';
import '/shared/logica/firma_storage_helper.dart';
import '/roles/admin/logica/certificado_texto_helper.dart';
import 'agregar_jurados_bloque_screen.dart';

const _kPrimario       = Color(0xFF1E3A5F);
const _kTextoGris      = Color(0xFF64748B);
const _kTextoGrisClaro = Color(0xFF94A3B8);
const _kTextoOscuro    = Color(0xFF334155);
const _kFondo          = Color(0xFFE8EDF2);
const _kCampoFondo     = Color(0xFFF8FAFC);
const _kVerde          = Color(0xFF16A34A);
const _kAmbar          = Color(0xFFF59E0B);
const _kAzulInfo       = Color(0xFF2563EB);
const _kJurado         = Color(0xFF0F6E56);
class DetalleListaCertificadosScreen extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Future<void> Function() onEnviado;
  const DetalleListaCertificadosScreen({super.key, required this.doc, required this.onEnviado});

  @override
  State<DetalleListaCertificadosScreen> createState() => _DetalleListaScreenState();
}

class _DetalleListaScreenState extends State<DetalleListaCertificadosScreen> {
  bool _enviando = false;
  bool _procesando = false;
  bool _descargando = false;
  int  _descargados = 0;
  int  _totalDescargar = 0;
  late Map<String, dynamic> _data;





  final Set<String> _seleccionadosJurado = {};






  late TextEditingController _nombreEventoCtrl;






  late TextEditingController _nombreCarreraCtrl;

  String get _docKey => '${_data['filialNombre']}_${_data['carrera']}';


  bool get _esJurado => (_data['rol'] as String? ?? '') == 'JURADO';

  String _idDe(Map<String, dynamic> e) =>
      (e['estudianteId'] ?? e['manualId'] ?? '').toString();










  void _autoSeleccionarListos() {
    if (!_esJurado) return;
    final estudiantes = List<Map<String, dynamic>>.from(_data['estudiantes'] ?? []);
    for (final e in estudiantes) {
      final esManual      = e['esManual'] == true;
      final tieneCodigo   = (e['codigoCertificado'] ?? '').toString().trim().isNotEmpty;
      final yaFueEnviado  = e['generadoCompleto'] == true;
      if (!esManual && tieneCodigo && !yaFueEnviado) {
        _seleccionadosJurado.add(_idDe(e));
      }
    }
  }




  CollectionReference<Map<String, dynamic>> _certColeccion(String personId) {
    final db = FirebaseFirestore.instance;
    if (_esJurado) {
      return db.collection('users').doc(personId).collection('certificados');
    }
    return db.collection('users').doc(_docKey)
        .collection('students').doc(personId).collection('certificados');
  }

  void _snackLocal(String msg, {Color color = _kPrimario}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.doc.data());
    _nombreEventoCtrl = TextEditingController(
      text: (_data['evento'] ?? '').toString(),
    );
    _nombreCarreraCtrl = TextEditingController(
      text: (_data['carrera'] ?? '').toString(),
    );
    _autoSeleccionarListos();
  }

  @override
  void dispose() {
    _nombreEventoCtrl.dispose();
    _nombreCarreraCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final esJurado = _esJurado;
    final accentColor = esJurado ? _kJurado : _kPrimario;
    final estudiantes = List<Map<String, dynamic>>.from(d['estudiantes'] ?? []);




    final pendientes = estudiantes
        .where((e) => e['generadoCompleto'] != true && e['esManual'] != true)
        .toList();
    final seleccionadosJurado = estudiantes
        .where((e) => _seleccionadosJurado.contains(_idDe(e)))
        .toList();

    return Scaffold(
      backgroundColor: accentColor,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (esJurado) ...[
            FloatingActionButton.extended(
              heroTag: 'fab_bloque_jurados',
              onPressed: _procesando ? null : _abrirAgregarJuradosBloque,
              backgroundColor: _kJurado,
              icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
              label: const Text('Agregar en bloque', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton.extended(
            heroTag: 'fab_manual',
            onPressed: _procesando ? null : _agregarCertificadoManual,
            backgroundColor: _kAmbar,
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
            label: const Text('Certificado manual', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'fab_estudiante',
            onPressed: _procesando ? null : (esJurado ? _agregarJuradoExistente : _agregarEstudiante),
            backgroundColor: _kAzulInfo,
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
            label: Text(esJurado ? 'Agregar jurado' : 'Agregar estudiante',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${d['evento'] ?? ''}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                  Text('${d['filialNombre'] ?? ''} · ${d['carrera'] ?? ''} · ${d['rol'] ?? ''}',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _kFondo,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(children: [
                if (esJurado)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(children: [
                      SizedBox(
                        width: 36, height: 36,
                        child: Checkbox(
                          value: estudiantes.isNotEmpty &&
                              _seleccionadosJurado.length == estudiantes.length,
                          onChanged: _procesando ? null : (v) => setState(() {
                            if (v == true) {
                              _seleccionadosJurado
                                ..clear()
                                ..addAll(estudiantes.map(_idDe));
                            } else {
                              _seleccionadosJurado.clear();
                            }
                          }),
                          activeColor: _kJurado,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const Text('Seleccionar todos',
                          style: TextStyle(fontSize: 12, color: _kTextoGris, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text('${_seleccionadosJurado.length} seleccionado(s)',
                          style: const TextStyle(fontSize: 11, color: _kTextoGrisClaro)),
                    ]),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: estudiantes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _buildEstudianteTile(estudiantes[i]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(children: [
                    SizedBox(
                      width: double.infinity, height: 54,
                      child: OutlinedButton.icon(
                        onPressed: (_descargando || _procesando || estudiantes.isEmpty)
                            ? null
                            : _descargarTodos,
                        icon: _descargando
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(color: _kPrimario, strokeWidth: 2))
                            : const Icon(Icons.download_rounded, size: 20),
                        label: Text(_descargando
                            ? 'Generando... $_descargados / $_totalDescargar'
                            : 'Descargar todos (${estudiantes.length})'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accentColor,
                          disabledForegroundColor: _kTextoGrisClaro,
                          side: BorderSide(color: estudiantes.isEmpty ? _kTextoGrisClaro : accentColor, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (esJurado)
                      SizedBox(
                        width: double.infinity, height: 54,
                        child: ElevatedButton.icon(
                          onPressed: (_enviando || _procesando || seleccionadosJurado.isEmpty)
                              ? null
                              : () => _confirmarEnvioJurados(seleccionadosJurado, d),
                          icon: _enviando
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send_rounded, size: 20),
                          label: Text(_enviando
                              ? 'Enviando...'
                              : seleccionadosJurado.isEmpty
                                  ? 'Selecciona jurados para enviar'
                                  : 'Enviar certificados (${seleccionadosJurado.length})'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kJurado, foregroundColor: Colors.white,
                            disabledBackgroundColor: _kTextoGrisClaro,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity, height: 54,
                        child: ElevatedButton.icon(
                          onPressed: (_enviando || _procesando || pendientes.isEmpty)
                              ? null
                              : () => _confirmarEnvio(pendientes, d),
                          icon: _enviando
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send_rounded, size: 20),
                          label: Text(_enviando
                              ? 'Enviando...'
                              : pendientes.isEmpty
                                  ? 'Todos los certificados ya están completos'
                                  : 'Enviar certificados (${pendientes.length})'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPrimario, foregroundColor: Colors.white,
                            disabledBackgroundColor: _kTextoGrisClaro,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildEstudianteTile(Map<String, dynamic> e) {
    final esManual = e['esManual'] == true;
    final completo = e['generadoCompleto'] == true;
    final esJurado = _esJurado;
    final id = _idDe(e);
    final seleccionado = esJurado && _seleccionadosJurado.contains(id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: esManual ? _kAzulInfo.withValues(alpha: 0.4) : const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        if (esJurado)
          SizedBox(
            width: 36, height: 36,
            child: Checkbox(
              value: seleccionado,
              onChanged: _procesando ? null : (v) => setState(() {
                if (v == true) {
                  _seleccionadosJurado.add(id);
                } else {
                  _seleccionadosJurado.remove(id);
                }
              }),
              activeColor: _kJurado,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          )
        else
          Icon(
            esManual
                ? Icons.edit_note_rounded
                : (completo ? Icons.check_circle : Icons.hourglass_bottom_rounded),
            size: 18,
            color: esManual ? _kAzulInfo : (completo ? _kVerde : _kAmbar),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(e['nombre'] ?? '',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextoOscuro),
                    overflow: TextOverflow.ellipsis),
              ),
              if (esManual) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: _kAzulInfo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Manual',
                      style: TextStyle(fontSize: 9, color: _kAzulInfo, fontWeight: FontWeight.w600)),
                ),
              ],
              if (esJurado && completo) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: _kVerde.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Enviado',
                      style: TextStyle(fontSize: 9, color: _kVerde, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
            Text(
              esManual
                  ? 'Fuera del sistema · solo se descarga, no se envía'
                  : 'DNI: ${e['dni']?.toString().isNotEmpty == true ? e['dni'] : '—'}   ·   '
                    '${esJurado ? 'Cód. jurado' : 'Cód. estudiante'}: ${e['codigoEstudiante'] ?? ''}',
              style: const TextStyle(fontSize: 10.5, color: _kTextoGrisClaro),
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        GestureDetector(
          onTap: _procesando ? null : () => _editarCodigo(e),
          child: Text(e['codigoCertificado'] ?? '',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _kAzulInfo,
                  fontFamily: 'monospace', decoration: TextDecoration.underline)),
        ),
        SizedBox(
          width: 36, height: 36,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.edit_outlined, size: 16, color: _kTextoGris),
            tooltip: 'Editar código',
            onPressed: _procesando ? null : () => _editarCodigo(e),
          ),
        ),
        SizedBox(
          width: 36, height: 36,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
            tooltip: esJurado ? 'Quitar de la lista' : 'Quitar de la lista',
            onPressed: _procesando ? null : () => _eliminarEstudiante(e),
          ),
        ),
      ]),
    );
  }


  Future<void> _editarCodigo(Map<String, dynamic> entry) async {
    final ctrl = TextEditingController(text: entry['codigoCertificado'] ?? '');
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Editar código de certificado',
            style: TextStyle(color: _kPrimario, fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: InputDecoration(
            filled: true, fillColor: _kCampoFondo,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimario, foregroundColor: Colors.white),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nuevo == null || nuevo.isEmpty) return;

    final esManual     = entry['esManual'] == true;
    final estudianteId = entry['estudianteId'] as String?;
    final certId       = entry['certId'] as String?;
    final manualId     = entry['manualId'] as String?;






    if (!esManual && estudianteId == null) {
      _snackLocal('No se pudo actualizar: falta información del certificado', color: _kAmbar);
      return;
    }

    setState(() => _procesando = true);
    try {
      if (!esManual && estudianteId != null && certId != null) {
        await _certColeccion(estudianteId).doc(certId).update({'codigoCertificado': nuevo});
      }

      final lista = List<Map<String, dynamic>>.from(_data['estudiantes'] ?? []);
      for (final e in lista) {
        final match = esManual
            ? (e['manualId'] == manualId)
            : (e['estudianteId'] == estudianteId && e['certId'] == certId);
        if (match) {
          e['codigoCertificado'] = nuevo;
        }
      }
      await widget.doc.reference.update({'estudiantes': lista});
      if (mounted) {
        setState(() {
          _data = {..._data, 'estudiantes': lista};
          _autoSeleccionarListos();
        });
      }
      await widget.onEnviado();
      _snackLocal('Código actualizado', color: _kVerde);
    } catch (e) {
      _snackLocal('Error actualizando código: $e', color: const Color(0xFFDC2626));
    }
    if (mounted) setState(() => _procesando = false);
  }


  Future<void> _eliminarEstudiante(Map<String, dynamic> entry) async {
    final esManual = entry['esManual'] == true;
    final esJurado = _esJurado;
    bool tambienBorrarCert = false;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setStateDialog) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.person_remove_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Flexible(child: Text(esJurado ? 'Quitar jurado' : 'Quitar estudiante',
              style: const TextStyle(color: _kPrimario, fontWeight: FontWeight.bold))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('¿Quitar a "${entry['nombre']}" de esta lista?',
              style: const TextStyle(fontSize: 13, color: _kTextoGris)),



          if (!esManual) ...[
            const SizedBox(height: 6),
            CheckboxListTile(
              value: tambienBorrarCert,
              onChanged: (v) => setStateDialog(() => tambienBorrarCert = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('También eliminar el certificado (irreversible)',
                  style: TextStyle(fontSize: 12)),
            ),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Quitar'),
          ),
        ],
      )),
    );
    if (confirmar != true) return;

    setState(() => _procesando = true);
    try {
      if (!esManual && tambienBorrarCert) {
        final estudianteId = entry['estudianteId'] as String?;
        final certId = entry['certId'] as String?;
        if (estudianteId != null && certId != null) {
          await _certColeccion(estudianteId).doc(certId).delete();
        }
      }
      final lista = List<Map<String, dynamic>>.from(_data['estudiantes'] ?? []);
      lista.removeWhere((e) => esManual
          ? e['manualId'] == entry['manualId']
          : (e['estudianteId'] == entry['estudianteId'] && e['certId'] == entry['certId']));
      await widget.doc.reference.update({
        'estudiantes': lista,
        'totalEstudiantes': lista.length,
      });
      if (mounted) {
        setState(() {
          _data = {..._data, 'estudiantes': lista, 'totalEstudiantes': lista.length};
          _seleccionadosJurado.remove(_idDe(entry));
        });
      }
      await widget.onEnviado();
      _snackLocal(esJurado ? 'Jurado quitado de la lista' : 'Estudiante quitado de la lista', color: _kVerde);
    } catch (e) {
      _snackLocal('Error quitando de la lista: $e', color: const Color(0xFFDC2626));
    }
    if (mounted) setState(() => _procesando = false);
  }


  Future<void> _agregarEstudiante() async {
    final codEstCtrl  = TextEditingController();
    final codCertCtrl = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Agregar estudiante a la lista',
            style: TextStyle(color: _kPrimario, fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Se busca en ${_data['carrera']} · ${_data['filialNombre']}',
                style: const TextStyle(fontSize: 11, color: _kTextoGrisClaro)),
            const SizedBox(height: 10),
            TextField(
              controller: codEstCtrl,
              decoration: InputDecoration(
                labelText: 'Código de estudiante',
                filled: true, fillColor: _kCampoFondo,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: codCertCtrl,
              decoration: InputDecoration(
                labelText: 'Código de certificado',
                filled: true, fillColor: _kCampoFondo,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimario, foregroundColor: Colors.white),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final codEst  = codEstCtrl.text.trim();
    final codCert = codCertCtrl.text.trim();
    if (codEst.isEmpty || codCert.isEmpty) {
      _snackLocal('Completa ambos códigos', color: _kAmbar);
      return;
    }

    setState(() => _procesando = true);
    try {
      final db   = FirebaseFirestore.instance;
      final snap = await db.collection('users').doc(_docKey)
          .collection('students')
          .where('codigoUniversitario', isEqualTo: codEst)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        _snackLocal('Código de estudiante no encontrado en esta carrera', color: const Color(0xFFDC2626));
        return;
      }
      final doc          = snap.docs.first;
      final estudianteId = doc.id;
      final nombre       = doc.data()['name'] as String? ?? 'Sin nombre';
      final dni          = (doc.data()['dni'] ?? '').toString();

      final listaActual = List<Map<String, dynamic>>.from(_data['estudiantes'] ?? []);
      if (listaActual.any((e) => e['estudianteId'] == estudianteId)) {
        _snackLocal('Ese estudiante ya está en la lista', color: _kAmbar);
        return;
      }





      final evento = _data['evento'] as String? ?? '';
      final rol    = _data['rol'] as String? ?? '';

      final certsSnap = await db.collection('users').doc(_docKey)
          .collection('students').doc(estudianteId)
          .collection('certificados')
          .where('evento', isEqualTo: evento)
          .where('rol', isEqualTo: rol)
          .get();

      String certId;
      if (certsSnap.docs.isNotEmpty) {
        certId = certsSnap.docs.first.id;
        await certsSnap.docs.first.reference.update({'codigoCertificado': codCert});
      } else {
        certId = '${rol}_${DateTime.now().millisecondsSinceEpoch}';
        await db.collection('users').doc(_docKey)
            .collection('students').doc(estudianteId)
            .collection('certificados').doc(certId)
            .set({'evento': evento, 'rol': rol, 'codigoCertificado': codCert});
      }

      listaActual.add({
        'estudianteId': estudianteId,
        'nombre': nombre,
        'dni': dni,
        'codigoEstudiante': codEst,
        'codigoCertificado': codCert,
        'certId': certId,
        'generadoCompleto': false,
      });

      await widget.doc.reference.update({
        'estudiantes': listaActual,
        'totalEstudiantes': listaActual.length,
      });
      if (mounted) {
        setState(() => _data = {..._data, 'estudiantes': listaActual, 'totalEstudiantes': listaActual.length});
      }
      await widget.onEnviado();
      _snackLocal('Estudiante agregado a la lista', color: _kVerde);
    } catch (e) {
      _snackLocal('Error agregando estudiante: $e', color: const Color(0xFFDC2626));
    }
    if (mounted) setState(() => _procesando = false);
  }







  Future<void> _agregarJuradoExistente() async {
    final codigoCtrl = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Agregar jurado a la lista',
            style: TextStyle(color: _kPrimario, fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Se busca en ${_data['carrera']} · ${_data['filialNombre']} · ${_data['evento']}',
                style: const TextStyle(fontSize: 11, color: _kTextoGrisClaro)),
            const SizedBox(height: 10),
            TextField(
              controller: codigoCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Código (usuario) del jurado',
                filled: true, fillColor: _kCampoFondo,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kJurado, foregroundColor: Colors.white),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final codigo = codigoCtrl.text.trim();
    if (codigo.isEmpty) {
      _snackLocal('Escribe el código del jurado', color: _kAmbar);
      return;
    }

    setState(() => _procesando = true);
    try {
      final db = FirebaseFirestore.instance;
      final snap = await db.collection('users')
          .where('userType', isEqualTo: 'jurado')
          .where('filial', isEqualTo: _data['filialId'])
          .where('carreraId', isEqualTo: _data['carreraId'])
          .where('eventoId', isEqualTo: _data['eventoId'])
          .where('usuario', isEqualTo: codigo)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        _snackLocal('Jurado no encontrado en este evento/carrera', color: const Color(0xFFDC2626));
        return;
      }

      final doc      = snap.docs.first;
      final juradoId = doc.id;
      final dJurado  = doc.data();

      final listaActual = List<Map<String, dynamic>>.from(_data['estudiantes'] ?? []);
      if (listaActual.any((e) => e['estudianteId'] == juradoId)) {
        _snackLocal('Ese jurado ya está en la lista', color: _kAmbar);
        return;
      }

      listaActual.add({
        'estudianteId': juradoId,
        'nombre': dJurado['name'] ?? 'Sin nombre',
        'dni': (dJurado['dni'] ?? '').toString(),
        'codigoEstudiante': codigo,
        'codigoCertificado': '',
        'certId': null,
        'generadoCompleto': false,
      });

      await widget.doc.reference.update({
        'estudiantes': listaActual,
        'totalEstudiantes': listaActual.length,
      });
      if (mounted) {
        setState(() {
          _data = {..._data, 'estudiantes': listaActual, 'totalEstudiantes': listaActual.length};
          _autoSeleccionarListos();
        });
      }
      await widget.onEnviado();
      _snackLocal('Jurado agregado a la lista', color: _kVerde);
    } catch (e) {
      _snackLocal('Error agregando jurado: $e', color: const Color(0xFFDC2626));
    }
    if (mounted) setState(() => _procesando = false);
  }









  Future<void> _abrirAgregarJuradosBloque() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AgregarJuradosBloqueScreen(
        listaRef: widget.doc.reference,
        listaData: _data,
      ),
    ));
    try {
      final freshDoc = await widget.doc.reference.get();
      if (freshDoc.exists && mounted) {
        setState(() {
          _data = Map<String, dynamic>.from(freshDoc.data()!);
          _autoSeleccionarListos();
        });
      }
    } catch (e) {
      debugPrint('Error recargando lista tras agregar en bloque: $e');
    }
    await widget.onEnviado();
  }

Future<void> _agregarCertificadoManual() async {
  final nombreCtrl = TextEditingController();
  final codigoCtrl = TextEditingController();

  final confirmar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        Icon(Icons.edit_note_rounded, color: _kAzulInfo),
        SizedBox(width: 10),
        Flexible(child: Text('Certificado manual (fuera del sistema)',
            style: TextStyle(color: _kPrimario, fontWeight: FontWeight.bold, fontSize: 15))),
      ]),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _kAzulInfo.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Text(
              'Se agregará a la lista "${_data['evento'] ?? ''}". Como no está en '
              'el sistema, este certificado se podrá descargar junto con los '
              'demás (con el evento/fecha/carrera que definas al descargar), '
              'pero no se podrá "enviar".',
              style: const TextStyle(fontSize: 11, color: _kTextoGris),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: nombreCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nombre completo',
              filled: true, fillColor: _kCampoFondo,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: codigoCtrl,
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: InputDecoration(
              labelText: 'Código de certificado',
              filled: true, fillColor: _kCampoFondo,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: _kAzulInfo, foregroundColor: Colors.white),
          child: const Text('Agregar a la lista'),
        ),
      ],
    ),
  );
  if (confirmar != true) return;

  final nombre = nombreCtrl.text.trim();
  if (nombre.isEmpty) {
    _snackLocal('Escribe el nombre completo', color: _kAmbar);
    return;
  }

  setState(() => _procesando = true);
  try {
    final listaActual = List<Map<String, dynamic>>.from(_data['estudiantes'] ?? []);
    listaActual.add({
      'estudianteId': null,
      'certId': null,
      'manualId': 'manual_${DateTime.now().millisecondsSinceEpoch}',
      'esManual': true,
      'nombre': nombre,
      'dni': '',
      'codigoEstudiante': '',
      'codigoCertificado': codigoCtrl.text.trim(),
      'generadoCompleto': false,
    });

    await widget.doc.reference.update({
      'estudiantes': listaActual,
      'totalEstudiantes': listaActual.length,
    });
    if (mounted) {
      setState(() => _data = {..._data, 'estudiantes': listaActual, 'totalEstudiantes': listaActual.length});
    }
    await widget.onEnviado();
    _snackLocal('Certificado manual agregado a la lista', color: _kVerde);
  } catch (e) {
    _snackLocal('Error agregando certificado manual: $e', color: const Color(0xFFDC2626));
  }
  if (mounted) setState(() => _procesando = false);
}







  Widget _buildCampoNombreEventoCertificado(StateSetter setStateDialog) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nombreEventoCtrl,
          onChanged: (_) => setStateDialog(() {}),
          maxLines: 2,
          minLines: 1,
          decoration: InputDecoration(
            labelText: 'Nombre del evento en el certificado',
            filled: true, fillColor: _kCampoFondo,
            suffixIcon: IconButton(
              icon: const Icon(Icons.restart_alt_rounded, size: 18, color: _kTextoGris),
              tooltip: 'Restaurar nombre original de la lista',
              onPressed: () => setStateDialog(() {
                _nombreEventoCtrl.text = (_data['evento'] ?? '').toString();
              }),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Solo cambia el texto impreso en el PDF y el certificado del '
          'estudiante/jurado. No modifica el evento de esta lista.',
          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, height: 1.3),
        ),
      ],
    );
  }







  Widget _buildCampoNombreCarreraCertificado(StateSetter setStateDialog) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nombreCarreraCtrl,
          onChanged: (_) => setStateDialog(() {}),
          maxLines: 2,
          minLines: 1,
          decoration: InputDecoration(
            labelText: 'Nombre de la carrera/escuela en el certificado',
            filled: true, fillColor: _kCampoFondo,
            suffixIcon: IconButton(
              icon: const Icon(Icons.restart_alt_rounded, size: 18, color: _kTextoGris),
              tooltip: 'Restaurar nombre original de la carrera',
              onPressed: () => setStateDialog(() {
                _nombreCarreraCtrl.text = (_data['carrera'] ?? '').toString();
              }),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Solo cambia el texto impreso en el PDF y el certificado del '
          'estudiante/jurado. No modifica la carrera real de esta lista.',
          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, height: 1.3),
        ),
      ],
    );
  }

Widget _buildSelectorHoras(
    String seleccionado,
    StateSetter setStateDialog,
    TextEditingController horasCtrl,
  ) {
    Widget chip(String valor, String linea1, String linea2) {
      final activo = horasCtrl.text.trim() == valor;
      return Expanded(
        child: GestureDetector(
          onTap: () => setStateDialog(() => horasCtrl.text = valor),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: activo ? _kPrimario : _kCampoFondo,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: activo ? _kPrimario : const Color(0xFFE2E8F0)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(linea1,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                      color: activo ? Colors.white : _kTextoOscuro)),
              if (linea2.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(linea2,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9.5,
                        color: activo ? Colors.white70 : _kTextoGrisClaro)),
              ],
            ]),
          ),
        ),
      );
    }

    return Row(children: [
      chip('16', '16 horas', '(1 crédito)'),
      chip('9', '9 horas', ''),
      chip('7', '7 horas', ''),
    ]);
  }


  Future<void> _seleccionarFecha(
    BuildContext dialogContext,
    TextEditingController fechaCtrl,
    StateSetter setStateDialog,
  ) async {
    final ahora = DateTime.now();
    final elegido = await showDatePicker(
      context: dialogContext,
      initialDate: ahora,
      firstDate: DateTime(ahora.year - 5),
      lastDate: DateTime(ahora.year + 1),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _kPrimario),
        ),
        child: child!,
      ),
    );
    if (elegido != null) {
      setStateDialog(() => fechaCtrl.text = formatearFechaEs(elegido));
    }
  }













  Future<void> _descargarTodos() async {
    final rol = _data['rol'] as String? ?? 'ASISTENTE';

    final estudiantes = List<Map<String, dynamic>>.from(_data['estudiantes'] ?? []);
    if (estudiantes.isEmpty) return;

    final fechaCtrl = TextEditingController(text: fechaActual());
    final horasCtrl = TextEditingController(text: '16');
    final llevaHoras = rol == 'ASISTENTE' || rol == 'ORGANIZADOR';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          final motivoPreview = motivoPorRol(
            rol: rol,
            evento: _nombreEventoCtrl.text.trim(),
            fecha: fechaCtrl.text,
            carrera: _nombreCarreraCtrl.text.trim(),
            horas: horasCtrl.text,
          );
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [
              Icon(Icons.download_rounded, color: _kPrimario),
              SizedBox(width: 10),
              Flexible(child: Text('Descargar certificados',
                  style: TextStyle(color: _kPrimario, fontWeight: FontWeight.bold))),
            ]),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Se generará un solo PDF con ${estudiantes.length} '
                  'certificado(s) (uno por persona, con su propio código). '
                  'Esto solo genera el archivo, no lo guarda ni lo envía.',
                  style: const TextStyle(fontSize: 13, color: _kTextoGris),
                ),
                const SizedBox(height: 14),
                _buildCampoNombreEventoCertificado(setStateDialog),
                const SizedBox(height: 14),
                _buildCampoNombreCarreraCertificado(setStateDialog),
                const SizedBox(height: 14),
                TextField(
                  controller: fechaCtrl,
                  onChanged: (_) => setStateDialog(() {}),
                  decoration: InputDecoration(
                    labelText: 'Fecha de emisión',
                    filled: true, fillColor: _kCampoFondo,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today_rounded, size: 18, color: _kTextoGris),
                      tooltip: 'Elegir fecha',
                      onPressed: () => _seleccionarFecha(ctx, fechaCtrl, setStateDialog),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                if (llevaHoras) ...[
                  const SizedBox(height: 14),
                  const Text('Horas académicas',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimario)),
                  const SizedBox(height: 8),
                  _buildSelectorHoras(horasCtrl.text, setStateDialog, horasCtrl),
                  const SizedBox(height: 12),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _kCampoFondo, borderRadius: BorderRadius.circular(10)),
                  child: Text(motivoPreview,
                      style: const TextStyle(fontSize: 11, color: _kTextoGris, height: 1.4)),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: _kPrimario, foregroundColor: Colors.white),
                child: const Text('Generar y descargar'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmar != true) return;

    setState(() { _descargando = true; _descargados = 0; _totalDescargar = estudiantes.length; });

    try {


      final facId = generarFacultadId(_data['facultad'] as String? ?? '');
      final db    = FirebaseFirestore.instance;

      final resultadosFirmas = await Future.wait([
        db.collection('config_firmas').doc('vicerrector').get(),
        db.collection('config_firmas').doc('director_investigacion').get(),
        db.collection('config_firmas').doc('decanos').collection('facultades').doc(facId).get(),
      ]);
      final vSnap   = resultadosFirmas[0];
      final dSnap   = resultadosFirmas[1];
      final decSnap = resultadosFirmas[2];

      final firma1 = FirmanteResumen.fromDoc(vSnap.exists ? vSnap.data() : null);
      final firma2 = FirmanteResumen.fromDoc(decSnap.exists ? decSnap.data() : null);
      final firma3 = FirmanteResumen.fromDoc(dSnap.exists ? dSnap.data() : null);





      final nombreEventoCertificado  = _nombreEventoCtrl.text.trim();
      final nombreCarreraCertificado = _nombreCarreraCtrl.text.trim();


      final motivo = motivoPorRol(
        rol: rol,
        evento: nombreEventoCertificado,
        fecha: fechaCtrl.text,
        carrera: nombreCarreraCertificado,
        horas: horasCtrl.text,
      );


      final bytesFirmas = await Future.wait([
        descargarFirma(firma1.urlFirma),
        descargarFirma(firma2.urlFirma),
        descargarFirma(firma3.urlFirma),
      ]);
      final bytes1 = bytesFirmas[0];
      final bytes2 = bytesFirmas[1];
      final bytes3 = bytesFirmas[2];






      final datos = DatosCertificado(
        facultad: (_data['facultad'] ?? '').toString(),
        carrera:  nombreCarreraCertificado,
        campus:   (_data['filialNombre'] ?? '').toString(),
        motivo: motivo,
        fecha: fechaCtrl.text,
        horas: horasCtrl.text,
        evento: nombreEventoCertificado,
        rol: rol,
        director1: firma1.nombre, cargo1: firma1.cargo,
        director2: firma2.nombre, cargo2: firma2.cargo,
        director3: firma3.nombre, cargo3: firma3.cargo,
        urlFirma1: firma1.urlFirma,
        urlFirma2: firma2.urlFirma,
        urlFirma3: firma3.urlFirma,
        bytesFirma1: bytes1, bytesFirma2: bytes2, bytesFirma3: bytes3,
      );

    final listaEstudiantesPdf = estudiantes.map((e) => Estudiante(
  id: (e['estudianteId'] ?? e['manualId'] ?? '').toString(),
  nombre: (e['nombre'] ?? '').toString(),
  dni: (e['dni'] ?? '').toString(),
  codigo: (e['codigoEstudiante'] ?? '').toString(),
  codigoCertificado: (e['codigoCertificado'] ?? '').toString(),
  motivo: '',
)).toList();

      final builder     = CertificadoBuilder(datos);
      final bytesFinal  = await builder.buildPdf(listaEstudiantesPdf);

      if (mounted) setState(() => _descargados = estudiantes.length);

      final nombreArchivo =
          'certificados_${rol.toLowerCase()}_'
          '${(_data['evento'] ?? '').toString().replaceAll(' ', '_').toLowerCase()}.pdf';
      await Printing.sharePdf(bytes: bytesFinal, filename: nombreArchivo);

      if (!mounted) return;
      _snackLocal('✅ ${estudiantes.length} certificado(s) descargados en un solo PDF', color: _kVerde);
    } catch (e) {
      if (mounted) _snackLocal('Error generando la descarga: $e', color: const Color(0xFFDC2626));
    }
    if (mounted) setState(() => _descargando = false);
  }





  Future<void> _confirmarEnvio(
      List<Map<String, dynamic>> pendientes, Map<String, dynamic> lista) async {
    final rol = lista['rol'] as String? ?? 'ASISTENTE';

    final fechaCtrl = TextEditingController(text: fechaActual());
    final horasCtrl = TextEditingController(text: '16');
    final llevaHoras = rol == 'ASISTENTE' || rol == 'ORGANIZADOR';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          final motivoPreview = motivoPorRol(
            rol: rol,
            evento: _nombreEventoCtrl.text.trim(),
            fecha: fechaCtrl.text,
            carrera: _nombreCarreraCtrl.text.trim(),
            horas: horasCtrl.text,
          );
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [
              Icon(Icons.send_rounded, color: _kPrimario),
              SizedBox(width: 10),
              Text('Enviar certificados', style: TextStyle(color: _kPrimario, fontWeight: FontWeight.bold)),
            ]),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Se completarán ${pendientes.length} certificado(s) pendientes de esta lista '
                    'con los firmantes configurados actualmente.',
                    style: const TextStyle(fontSize: 13, color: _kTextoGris)),
                const SizedBox(height: 14),
                _buildCampoNombreEventoCertificado(setStateDialog),
                const SizedBox(height: 14),
                _buildCampoNombreCarreraCertificado(setStateDialog),
                const SizedBox(height: 14),
                TextField(
                  controller: fechaCtrl,
                  onChanged: (_) => setStateDialog(() {}),
                  decoration: InputDecoration(
                    labelText: 'Fecha de emisión',
                    filled: true, fillColor: _kCampoFondo,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today_rounded, size: 18, color: _kTextoGris),
                      tooltip: 'Elegir fecha',
                      onPressed: () => _seleccionarFecha(ctx, fechaCtrl, setStateDialog),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                if (llevaHoras) ...[
                  const SizedBox(height: 14),
                  const Text('Horas académicas',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimario)),
                  const SizedBox(height: 8),
                  _buildSelectorHoras(horasCtrl.text, setStateDialog, horasCtrl),
                  const SizedBox(height: 12),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _kCampoFondo, borderRadius: BorderRadius.circular(10)),
                  child: Text(motivoPreview,
                      style: const TextStyle(fontSize: 11, color: _kTextoGris, height: 1.4)),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: _kPrimario, foregroundColor: Colors.white),
                child: const Text('Enviar'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmar != true) return;

    setState(() => _enviando = true);
    try {
      final facId = generarFacultadId(lista['facultad'] as String? ?? '');
      final db = FirebaseFirestore.instance;


      final resultadosFirmas = await Future.wait([
        db.collection('config_firmas').doc('vicerrector').get(),
        db.collection('config_firmas').doc('director_investigacion').get(),
        db.collection('config_firmas').doc('decanos').collection('facultades').doc(facId).get(),
      ]);
      final vSnap   = resultadosFirmas[0];
      final dSnap   = resultadosFirmas[1];
      final decSnap = resultadosFirmas[2];

      final firma1 = FirmanteResumen.fromDoc(vSnap.exists ? vSnap.data() : null);
      final firma2 = FirmanteResumen.fromDoc(decSnap.exists ? decSnap.data() : null);
      final firma3 = FirmanteResumen.fromDoc(dSnap.exists ? dSnap.data() : null);




      final nombreEventoCertificado  = _nombreEventoCtrl.text.trim();
      final nombreCarreraCertificado = _nombreCarreraCtrl.text.trim();


      final motivoGeneral = motivoPorRol(
        rol: rol,
        evento: nombreEventoCertificado,
        fecha: fechaCtrl.text,
        carrera: nombreCarreraCertificado,
        horas: horasCtrl.text,
      );

      final docKey = '${lista['filialNombre']}_${lista['carrera']}';
      final ahora  = Timestamp.now();

      int exitosos = 0, errores = 0;
      const batchSize = 500;
      final commits = <Future<void>>[];

      for (int i = 0; i < pendientes.length; i += batchSize) {
        final lote  = pendientes.skip(i).take(batchSize).toList();
        final batch = db.batch();
        for (final e in lote) {
          final estudianteId = e['estudianteId'] as String?;
          final certId       = e['certId'] as String?;
          if (estudianteId == null || certId == null) { errores++; continue; }

          final ref = db.collection('users').doc(docKey)
              .collection('students').doc(estudianteId)
              .collection('certificados').doc(certId);
          batch.set(ref, {
            'facultad': lista['facultad'],
            'carrera': nombreCarreraCertificado,
            'campus': lista['filialNombre'],
            'motivo': motivoGeneral,
            'fecha': fechaCtrl.text,
            'horas': horasCtrl.text,
            'evento': nombreEventoCertificado,
            'rol': rol,
            'director1': firma1.nombre, 'cargo1': firma1.cargo,
            'director2': firma2.nombre, 'cargo2': firma2.cargo,
            'director3': firma3.nombre, 'cargo3': firma3.cargo,
            'urlFirma1': firma1.urlFirma,
            'urlFirma2': firma2.urlFirma,
            'urlFirma3': firma3.urlFirma,
            'creadoEn': ahora,
            'nombreEstudiante': e['nombre'],
            'codigoCertificado': e['codigoCertificado'],
          }, SetOptions(merge: true));
        }




        commits.add(
          batch.commit().then((_) {
            exitosos += lote.length;
          }).catchError((err) {
            errores += lote.length;
            debugPrint('Error en lote de envío: $err');
          }),
        );
      }
      await Future.wait(commits);


      final estudiantesActualizados = List<Map<String, dynamic>>.from(_data['estudiantes'] ?? []);
      for (final e in estudiantesActualizados) {
        if (pendientes.any((p) => p['estudianteId'] == e['estudianteId'])) {
          e['generadoCompleto'] = true;
        }
      }
      await widget.doc.reference.update({'estudiantes': estudiantesActualizados});
      await widget.onEnviado();
      if (mounted) setState(() => _data = {..._data, 'estudiantes': estudiantesActualizados});

      if (!mounted) return;
      if (errores == 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ $exitosos certificado(s) enviados correctamente'),
          backgroundColor: _kVerde, behavior: SnackBarBehavior.floating,
        ));
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚠️ $exitosos enviados, $errores con error'),
          backgroundColor: _kAmbar, behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al enviar: $e'),
          backgroundColor: const Color(0xFFDC2626), behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _enviando = false);
  }














  Future<void> _confirmarEnvioJurados(
      List<Map<String, dynamic>> seleccionados, Map<String, dynamic> lista) async {
    const rol = 'JURADO';

    final fechaCtrl = TextEditingController(text: fechaActual());

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          final motivoPreview = motivoPorRol(
            rol: rol,
            evento: _nombreEventoCtrl.text.trim(),
            fecha: fechaCtrl.text,
            carrera: _nombreCarreraCtrl.text.trim(),
            horas: '',
          );
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [
              Icon(Icons.gavel_rounded, color: _kJurado),
              SizedBox(width: 10),
              Flexible(child: Text('Enviar certificados a jurados',
                  style: TextStyle(color: _kPrimario, fontWeight: FontWeight.bold))),
            ]),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Se enviarán ${seleccionados.length} certificado(s) a los jurados '
                    'seleccionados, cada uno con su propio código de certificado incluido.',
                    style: const TextStyle(fontSize: 13, color: _kTextoGris)),
                const SizedBox(height: 14),
                _buildCampoNombreEventoCertificado(setStateDialog),
                const SizedBox(height: 14),
                _buildCampoNombreCarreraCertificado(setStateDialog),
                const SizedBox(height: 14),
                TextField(
                  controller: fechaCtrl,
                  onChanged: (_) => setStateDialog(() {}),
                  decoration: InputDecoration(
                    labelText: 'Fecha de emisión',
                    filled: true, fillColor: _kCampoFondo,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today_rounded, size: 18, color: _kTextoGris),
                      tooltip: 'Elegir fecha',
                      onPressed: () => _seleccionarFecha(ctx, fechaCtrl, setStateDialog),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _kCampoFondo, borderRadius: BorderRadius.circular(10)),
                  child: Text(motivoPreview,
                      style: const TextStyle(fontSize: 11, color: _kTextoGris, height: 1.4)),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: _kJurado, foregroundColor: Colors.white),
                child: const Text('Enviar'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmar != true) return;

    setState(() => _enviando = true);
    try {
      final facId = generarFacultadId(lista['facultad'] as String? ?? '');
      final db = FirebaseFirestore.instance;

      final resultadosFirmas = await Future.wait([
        db.collection('config_firmas').doc('vicerrector').get(),
        db.collection('config_firmas').doc('director_investigacion').get(),
        db.collection('config_firmas').doc('decanos').collection('facultades').doc(facId).get(),
      ]);
      final vSnap   = resultadosFirmas[0];
      final dSnap   = resultadosFirmas[1];
      final decSnap = resultadosFirmas[2];

      final firma1 = FirmanteResumen.fromDoc(vSnap.exists ? vSnap.data() : null);
      final firma2 = FirmanteResumen.fromDoc(decSnap.exists ? decSnap.data() : null);
      final firma3 = FirmanteResumen.fromDoc(dSnap.exists ? dSnap.data() : null);

      final nombreEventoCertificado  = _nombreEventoCtrl.text.trim();
      final nombreCarreraCertificado = _nombreCarreraCtrl.text.trim();

      final motivoGeneral = motivoPorRol(
        rol: rol,
        evento: nombreEventoCertificado,
        fecha: fechaCtrl.text,
        carrera: nombreCarreraCertificado,
        horas: '',
      );

      final ahora = Timestamp.now();
      int exitosos = 0, errores = 0;




      final listaCompleta = List<Map<String, dynamic>>.from(_data['estudiantes'] ?? []);

      const batchSize = 500;
      for (int i = 0; i < seleccionados.length; i += batchSize) {
        final lote  = seleccionados.skip(i).take(batchSize).toList();
        final batch = db.batch();
        for (final e in lote) {
          final juradoId = e['estudianteId'] as String?;
          if (juradoId == null) { errores++; continue; }

          String? certId = e['certId'] as String?;
          certId ??= 'JURADO_${DateTime.now().millisecondsSinceEpoch}_$juradoId'
              .replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');

          final ref = db.collection('users').doc(juradoId)
              .collection('certificados').doc(certId);
          batch.set(ref, {
            'facultad': lista['facultad'],
            'carrera': nombreCarreraCertificado,
            'campus': lista['filialNombre'],
            'motivo': motivoGeneral,
            'fecha': fechaCtrl.text,
            'horas': '',
            'evento': nombreEventoCertificado,
            'rol': rol,
            'director1': firma1.nombre, 'cargo1': firma1.cargo,
            'director2': firma2.nombre, 'cargo2': firma2.cargo,
            'director3': firma3.nombre, 'cargo3': firma3.cargo,
            'urlFirma1': firma1.urlFirma,
            'urlFirma2': firma2.urlFirma,
            'urlFirma3': firma3.urlFirma,
            'creadoEn': ahora,
            'nombreEstudiante': e['nombre'],


            'codigoCertificado': e['codigoCertificado'],
          }, SetOptions(merge: true));

          final idParaMatch = juradoId;
          for (final le in listaCompleta) {
            if (le['estudianteId'] == idParaMatch) {
              le['certId'] = certId;
              le['generadoCompleto'] = true;
            }
          }
        }
        try {
          await batch.commit();
          exitosos += lote.length;
        } catch (err) {
          errores += lote.length;
          debugPrint('Error en lote de envío a jurados: $err');
        }
      }

      await widget.doc.reference.update({'estudiantes': listaCompleta});
      await widget.onEnviado();
      if (mounted) {
        setState(() {
          _data = {..._data, 'estudiantes': listaCompleta};
          _seleccionadosJurado.clear();
        });
      }

      if (!mounted) return;
      if (errores == 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ $exitosos certificado(s) de jurado enviados correctamente'),
          backgroundColor: _kVerde, behavior: SnackBarBehavior.floating,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚠️ $exitosos enviados, $errores con error'),
          backgroundColor: _kAmbar, behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al enviar: $e'),
          backgroundColor: const Color(0xFFDC2626), behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _enviando = false);
  }
}















