import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/roles/admin/logica/certificado_texto_helper.dart';

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
enum _EstadoJuradoBloque {
  encontrado,
  creadoManual,
  duplicado,
  yaEnLista,
}

bool _bloqueaJurado(_EstadoJuradoBloque e) =>
    e == _EstadoJuradoBloque.duplicado;

class _JuradoBloqueEntry {
  final int linea;
  final String nombreIngresado;
  _EstadoJuradoBloque estado = _EstadoJuradoBloque.creadoManual;
  String mensaje = '';

  String? juradoId;
  String  dni = '';
  String  codigoUsuario = '';

  String codigoCertificadoNuevo = '';

  _JuradoBloqueEntry({
    required this.linea,
    required this.nombreIngresado,
  });

  bool get esValido => !_bloqueaJurado(estado);
}

class AgregarJuradosBloqueScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> listaRef;
  final Map<String, dynamic> listaData;
  const AgregarJuradosBloqueScreen({super.key, required this.listaRef, required this.listaData});

  @override
  State<AgregarJuradosBloqueScreen> createState() => _AgregarJuradosBloqueScreenState();
}

class _AgregarJuradosBloqueScreenState extends State<AgregarJuradosBloqueScreen> {
  final _nombresCtrl = TextEditingController();
  final _codigosCtrl = TextEditingController();

  final _eventoManualCtrl  = TextEditingController();
  final _carreraManualCtrl = TextEditingController();
  late final TextEditingController _fechaManualCtrl;

  bool _validando    = false;
  bool _campo1Listo  = false;
  bool _previewListo = false;
  bool _guardando    = false;



  String _normalizar(String s) {
    const con = 'áéíóúÁÉÍÓÚüÜñÑ';
    const sin = 'aeiouAEIOUuUnN';
    var r = s;
    for (int i = 0; i < con.length; i++) {
      r = r.replaceAll(con[i], sin[i]);
    }
    return r.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  }





  String _clavePorPalabras(String s) {
    final palabras = _normalizar(s)
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList()
      ..sort();
    return palabras.join(' ');
  }



  Set<String> _setPalabras(String s) => _normalizar(s)
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toSet();

 int _levenshtein(String a, String b) {
    if (a == b) return 0;
    final la = a.length, lb = b.length;
    if (la == 0) return lb;
    if (lb == 0) return la;

    final d = List.generate(la + 1, (_) => List<int>.filled(lb + 1, 0));
    for (int i = 0; i <= la; i++) d[i][0] = i;
    for (int j = 0; j <= lb; j++) d[0][j] = j;

    for (int i = 1; i <= la; i++) {
      for (int j = 1; j <= lb; j++) {
        final costo = a[i - 1] == b[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + costo,
        ].reduce((x, y) => x < y ? x : y);


        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          d[i][j] = [d[i][j], d[i - 2][j - 2] + 1].reduce((x, y) => x < y ? x : y);
        }
      }
    }
    return d[la][lb];
  }





  String _claveFonetica(String palabra) {
    var r = palabra.toLowerCase();
    r = r.replaceAll('h', '');
    r = r.replaceAll(RegExp(r'[zsc]'), 's');
    r = r.replaceAll(RegExp(r'(ll|y)'), 'i');
    r = r.replaceAll('v', 'b');
    r = r.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);
    return r;
  }

  bool _palabraSimilar(String a, String b) {
    if (a == b) return true;
    if (a.length < 4 || b.length < 4) return false;

    final fa = _claveFonetica(a);
    final fb = _claveFonetica(b);
    if (fa == fb) return true;

    final tol = (fa.length >= 7 || fb.length >= 7) ? 2 : 1;
    return _levenshtein(fa, fb) <= tol;
  }












  bool _esCoincidenciaFlexible(Set<String> a, Set<String> b) {
    final corto = a.length <= b.length ? a : b;
    final largo = a.length <= b.length ? b : a;
    if (corto.length < 2) return false;
    final restante = List<String>.from(largo);
    for (final palabra in corto) {
      final idx = restante.indexWhere((p) => _palabraSimilar(palabra, p));
      if (idx == -1) return false;
      restante.removeAt(idx);
    }
    return true;
  }
  List<_JuradoBloqueEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _eventoManualCtrl.text  = (widget.listaData['evento']  ?? '').toString();
    _carreraManualCtrl.text = (widget.listaData['carrera'] ?? '').toString();
    _fechaManualCtrl = TextEditingController(text: fechaActual());
  }

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _codigosCtrl.dispose();
    _eventoManualCtrl.dispose();
    _carreraManualCtrl.dispose();
    _fechaManualCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {Color color = _kJurado}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

 List<String> _parsearNombres(String texto) => texto
      .split('\n')
      .map((e) => quitarTitulo(e.trim()))
      .where((e) => e.isNotEmpty)
      .toList();

  List<String> _parsearCodigos(String texto) => texto
      .split(RegExp(r'[\s,;]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();


  Future<void> _validarNombres() async {
    final nombres = _parsearNombres(_nombresCtrl.text);
    if (nombres.isEmpty) {
      _snack('⚠️ Pega al menos un nombre de jurado', color: _kAmbar);
      return;
    }

    setState(() {
      _validando    = true;
      _campo1Listo  = false;
      _previewListo = false;
      _entries      = [];
    });

    try {
      final db = FirebaseFirestore.instance;
      final filialId  = (widget.listaData['filialId']  ?? '').toString();
      final carreraId = (widget.listaData['carreraId'] ?? '').toString();
      final eventoId  = (widget.listaData['eventoId']  ?? '').toString();








      final Map<String, Map<String, dynamic>> juradosPorNombreExacto = {};
      final Map<String, Map<String, dynamic>> juradosPorClavePalabras = {};
      final List<Map<String, dynamic>> todosJurados = [];

      if (filialId.isNotEmpty && carreraId.isNotEmpty && eventoId.isNotEmpty) {
        final snap = await db.collection('users')
            .where('userType', isEqualTo: 'jurado')
            .where('filial', isEqualTo: filialId)
            .where('carreraId', isEqualTo: carreraId)
            .where('eventoId', isEqualTo: eventoId)
            .get();
        for (final doc in snap.docs) {
          final d = doc.data();
          final nombreReal = quitarTitulo((d['name'] ?? '').toString().trim());
          if (nombreReal.isEmpty) continue;
          final datos = {
            'id': doc.id,
            'dni': (d['dni'] ?? '').toString(),
            'usuario': (d['usuario'] ?? '').toString(),
            'nombreReal': nombreReal,
            'palabras': _setPalabras(nombreReal),
          };
          juradosPorNombreExacto[nombreReal.toLowerCase()] = datos;
          juradosPorClavePalabras.putIfAbsent(_clavePorPalabras(nombreReal), () => datos);
          todosJurados.add(datos);
        }
      }


      final estudiantesActuales =
          List<Map<String, dynamic>>.from(widget.listaData['estudiantes'] ?? []);
      final nombresEnLista = estudiantesActuales
          .map((e) => (e['nombre'] ?? '').toString().trim().toLowerCase())
          .toSet();
      final clavesEnLista = estudiantesActuales
          .map((e) => _clavePorPalabras((e['nombre'] ?? '').toString()))
          .toSet();
      final idsEnLista = estudiantesActuales
          .map((e) => e['estudianteId'])
          .where((v) => v != null)
          .toSet();

      final vistos = <String>{};
      final nuevas = <_JuradoBloqueEntry>[];

      for (int i = 0; i < nombres.length; i++) {
        final nombreOriginal = nombres[i];
        final key = nombreOriginal.toLowerCase();
        final clave = _clavePorPalabras(nombreOriginal);
        final entry = _JuradoBloqueEntry(linea: i + 1, nombreIngresado: nombreOriginal);

        if (vistos.contains(clave)) {
          entry.estado  = _EstadoJuradoBloque.duplicado;
          entry.mensaje = 'Nombre repetido dentro de la lista pegada';
          nuevas.add(entry);
          continue;
        }
        vistos.add(clave);


        Map<String, dynamic>? match = juradosPorNombreExacto[key] ?? juradosPorClavePalabras[clave];
        String? tipoMatch = match != null
            ? (juradosPorNombreExacto[key] != null ? 'exacto' : 'permutado')
            : null;







       if (match == null) {
          final palabrasExcel = _setPalabras(nombreOriginal);
          final candidatos = todosJurados
              .where((j) => _esCoincidenciaFlexible(palabrasExcel, j['palabras'] as Set<String>))
              .toList();
          if (candidatos.length == 1) {
            match = candidatos.first;
            tipoMatch = 'parcial';
          }
        }

        if (match != null) {
          final yaEstaba = nombresEnLista.contains(key) ||
              clavesEnLista.contains(clave) ||
              idsEnLista.contains(match['id']);
          entry.juradoId      = match['id'] as String;
          entry.dni           = match['dni'] as String;
          entry.codigoUsuario = match['usuario'] as String;

          if (yaEstaba) {
            entry.estado  = _EstadoJuradoBloque.yaEnLista;
            entry.mensaje = tipoMatch == 'parcial'
                ? 'Ya está en la lista con nombre incompleto: se actualizará '
                  'a "$nombreOriginal" y su código'
                : 'Ya está en la lista: se actualizará su código de certificado';
          } else {
            entry.estado  = _EstadoJuradoBloque.encontrado;
            entry.mensaje = switch (tipoMatch) {
              'exacto'    => 'Encontrado en el sistema para este evento',
              'permutado' => 'Encontrado (nombre/apellido en distinto orden)',
              _           => 'Encontrado con nombre incompleto en el sistema '
                             '("${match['nombreReal']}"): se usará "$nombreOriginal"',
            };
          }
        } else {
          if (nombresEnLista.contains(key) || clavesEnLista.contains(clave)) {
            entry.estado  = _EstadoJuradoBloque.yaEnLista;
            entry.mensaje = 'Ya hay un registro con ese nombre en esta lista';
            nuevas.add(entry);
            continue;
          }
          entry.estado  = _EstadoJuradoBloque.creadoManual;
          entry.mensaje = 'No existe en el sistema para este evento: se creará '
              'como certificado manual (solo se podrá descargar, no enviar)';
        }
        nuevas.add(entry);
      }

      if (mounted) {
        setState(() {
          _entries     = nuevas;
          _campo1Listo = nuevas.isNotEmpty && nuevas.every((e) => e.esValido);
          _validando   = false;
        });
        if (_campo1Listo) {
          final encontrados = nuevas.where((e) => e.estado == _EstadoJuradoBloque.encontrado).length;
          final manuales    = nuevas.where((e) => e.estado == _EstadoJuradoBloque.creadoManual).length;
          _snack('✅ $encontrados encontrado(s) en el sistema, $manuales se crearán como manual',
              color: _kVerde);
        } else {
          final bloqueantes = nuevas.where((e) => _bloqueaJurado(e.estado)).length;
          _snack('⚠️ $bloqueantes nombre(s) con problemas (duplicados)',
              color: _kAmbar);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _validando = false);
        _snack('Error validando nombres: $e', color: const Color(0xFFDC2626));
      }
    }
  }


  void _procesarCodigos() {
    final codigos = _parsearCodigos(_codigosCtrl.text);
    if (codigos.isEmpty) {
      _snack('⚠️ Pega los códigos de certificado', color: _kAmbar);
      return;
    }
    if (codigos.length != _entries.length) {
      _snack(
        '⚠️ Cantidad distinta: ${_entries.length} nombre(s) vs '
        '${codigos.length} código(s). Deben coincidir.',
        color: _kAmbar,
      );
      return;
    }
    for (int i = 0; i < _entries.length; i++) {
      _entries[i].codigoCertificadoNuevo = codigos[i];
    }
    setState(() => _previewListo = true);
  }

  bool get _hayManuales =>
      _entries.any((e) => e.estado == _EstadoJuradoBloque.creadoManual);


  Future<void> _confirmarYGuardar() async {
    final aCrearManual = _entries.where((e) => e.estado == _EstadoJuradoBloque.creadoManual).length;
    final encontrados  = _entries.where((e) => e.estado == _EstadoJuradoBloque.encontrado).length;
    final aActualizar  = _entries.where((e) => e.estado == _EstadoJuradoBloque.yaEnLista).length;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.playlist_add_check_rounded, color: _kJurado),
          SizedBox(width: 10),
          Text('Confirmar', style: TextStyle(color: _kPrimario, fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          '• $encontrados jurado(s) del sistema se agregarán con su código\n'
          '• $aCrearManual certificado(s) manual(es) se crearán (no se podrán '
          'enviar, solo descargar)\n'
          '${aActualizar > 0 ? '• $aActualizar ya estaban en la lista: se actualizará su nombre y código de certificado\n' : ''}'
          '\n¿Continuar?',
          style: const TextStyle(fontSize: 14, color: _kTextoGris),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kJurado, foregroundColor: Colors.white),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _guardando = true);
    try {
      String? motivoManual;
      if (_hayManuales) {
        motivoManual = motivoPorRol(
          rol: 'JURADO',
          evento: _eventoManualCtrl.text.trim(),
          fecha: _fechaManualCtrl.text,
          carrera: _carreraManualCtrl.text.trim(),
          horas: '',
        );
      }

      final actuales = List<Map<String, dynamic>>.from(widget.listaData['estudiantes'] ?? []);







      int actualizados = 0;
      for (final e in _entries.where((e) => e.estado == _EstadoJuradoBloque.yaEnLista)) {
        final claveIngresada    = _clavePorPalabras(e.nombreIngresado);
        final palabrasIngresado = _setPalabras(e.nombreIngresado);
        for (final ex in actuales) {
          final nombreEx = (ex['nombre'] ?? '').toString();
          final matchPorId = e.juradoId != null && ex['estudianteId'] == e.juradoId;
          final matchPorClave = !matchPorId && _clavePorPalabras(nombreEx) == claveIngresada;
         final matchFlexible = !matchPorId && !matchPorClave &&
              _esCoincidenciaFlexible(_setPalabras(nombreEx), palabrasIngresado);
          if (matchPorId || matchPorClave || matchFlexible) {
            ex['codigoCertificado'] = e.codigoCertificadoNuevo;
            ex['nombre'] = e.nombreIngresado;
            actualizados++;
            break;
          }
        }
      }



      final nuevosRegistros = _entries
          .where((e) =>
              e.estado == _EstadoJuradoBloque.encontrado ||
              e.estado == _EstadoJuradoBloque.creadoManual)
          .map((e) {
        if (e.estado == _EstadoJuradoBloque.encontrado) {
          return {
            'estudianteId': e.juradoId,
            'nombre': e.nombreIngresado,
            'dni': e.dni,
            'codigoEstudiante': e.codigoUsuario,
            'codigoCertificado': e.codigoCertificadoNuevo,
            'certId': null,
            'generadoCompleto': false,
          };
        }

        return {
          'estudianteId': null,
          'certId': null,
          'manualId': 'manual_${DateTime.now().millisecondsSinceEpoch}_${e.linea}',
          'esManual': true,
          'nombre': e.nombreIngresado,
          'dni': '',
          'codigoEstudiante': '',
          'codigoCertificado': e.codigoCertificadoNuevo,
          'generadoCompleto': false,
          'fechaManual': _fechaManualCtrl.text,
          'eventoManual': _eventoManualCtrl.text.trim(),
          'carreraManual': _carreraManualCtrl.text.trim(),
          'horasManual': '',
          'motivoManual': motivoManual,
        };
      }).toList();

      final combinados = [...actuales, ...nuevosRegistros];

      await widget.listaRef.update({
        'estudiantes': combinados,
        'totalEstudiantes': combinados.length,
      });

      if (mounted) {
        _snack(
          '✅ ${nuevosRegistros.length} jurado(s) agregados'
          '${actualizados > 0 ? ', $actualizados nombre(s)/código(s) actualizados' : ''}',
          color: _kVerde,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        _snack('Error guardando: $e', color: const Color(0xFFDC2626));
      }
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kJurado,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _kFondo,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildInfoDestino(),
                  const SizedBox(height: 14),
                  _buildCampo1(),
                  const SizedBox(height: 14),
                  if (_entries.isNotEmpty) _buildResultadosValidacion(),
                  if (_hayManuales) ...[
                    const SizedBox(height: 14),
                    _buildDatosManualCard(),
                  ],
                  const SizedBox(height: 14),
                  _buildCampo2(),
                  if (_previewListo) ...[
                    const SizedBox(height: 14),
                    _buildPreviewFinal(),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.playlist_add_rounded, color: _kJurado, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Agregar Jurados en Bloque',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              Text('Pega nombres y luego sus códigos de certificado',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ]),
      );

  Widget _card({required Widget child}) => Card(
        elevation: 2, shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );

  Widget _sectionTitle(IconData icon, String title, {Color color = _kJurado}) => Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis)),
      ]);

  Widget _buildInfoDestino() => _card(
        child: Row(children: [
          const Icon(Icons.info_outline, size: 18, color: _kJurado),
          const SizedBox(width: 10),
          Expanded(child: Text(
            '${widget.listaData['evento'] ?? ''} · ${widget.listaData['carrera'] ?? ''} · '
            '${widget.listaData['filialNombre'] ?? ''}',
            style: const TextStyle(fontSize: 12, color: _kTextoGris, fontWeight: FontWeight.w600),
          )),
        ]),
      );

  Widget _buildCampo1() => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle(Icons.looks_one_rounded, '1. Nombres de los jurados'),
          const SizedBox(height: 6),
          const Text(
            'Un nombre por línea. Se validará contra los jurados registrados '
            'para este evento; si un nombre no existe, se creará como '
            'certificado manual (no enviable, solo descargable).',
            style: TextStyle(fontSize: 11, color: _kTextoGrisClaro),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nombresCtrl,
            maxLines: 8,
            minLines: 4,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ej:\nJuan Pérez Quispe\nMaría Condori Mamani',
              hintStyle: const TextStyle(fontSize: 12, color: _kTextoGrisClaro),
              filled: true, fillColor: _kCampoFondo,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              onPressed: _validando ? null : _validarNombres,
              icon: _validando
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.fact_check_outlined, size: 20),
              label: Text(_validando ? 'Validando...' : 'Validar nombres'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kJurado, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      );

  Widget _buildResultadosValidacion() {
    final encontrados = _entries.where((e) => e.estado == _EstadoJuradoBloque.encontrado).length;
    final manuales     = _entries.where((e) => e.estado == _EstadoJuradoBloque.creadoManual).length;
    final actualizar   = _entries.where((e) => e.estado == _EstadoJuradoBloque.yaEnLista).length;
    final problemas    = _entries.where((e) => _bloqueaJurado(e.estado)).length;

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.checklist_rounded, 'Resultado de validación',
            color: _campo1Listo ? _kVerde : _kAmbar),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _statMini('$encontrados', 'Nuevos', _kVerde)),
          const SizedBox(width: 6),
          Expanded(child: _statMini('$actualizar', 'Actualizar código', _kJurado)),
          const SizedBox(width: 6),
          Expanded(child: _statMini('$manuales', 'Manuales', _kAzulInfo)),
          const SizedBox(width: 6),
          Expanded(child: _statMini('$problemas', 'Bloqueantes', _kAmbar)),
        ]),
        const SizedBox(height: 12),
        ...List.generate(_entries.length, (i) => _buildEntryTile(_entries[i])),
        if (!_campo1Listo) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(children: [
              Icon(Icons.lock_outline, size: 16, color: Color(0xFF78350F)),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Corrige los nombres duplicados dentro de lo pegado '
                'para desbloquear el segundo campo.',
                style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
              )),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _statMini(String value, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
          Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.85))),
        ]),
      );

 Widget _buildEntryTile(_JuradoBloqueEntry e) {
    final (color, icon) = switch (e.estado) {
      _EstadoJuradoBloque.encontrado   => (_kVerde, Icons.check_circle_outline),
      _EstadoJuradoBloque.creadoManual => (_kAzulInfo, Icons.person_add_alt_1_outlined),
      _EstadoJuradoBloque.duplicado    => (const Color(0xFFDC2626), Icons.content_copy_rounded),
      _EstadoJuradoBloque.yaEnLista    => (_kJurado, Icons.sync_alt_rounded),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('#${e.linea}  ${e.nombreIngresado}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            if (e.mensaje.isNotEmpty)
              Text(e.mensaje, style: TextStyle(fontSize: 10.5, color: color)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildDatosManualCard() => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle(Icons.edit_note_rounded, 'Datos para los certificados manuales', color: _kAzulInfo),
          const SizedBox(height: 6),
          const Text(
            'Se usan para armar el motivo de los nombres que no se '
            'encontraron en el sistema (se crean como certificado manual: '
            'solo se pueden descargar, no enviar).',
            style: TextStyle(fontSize: 11, color: _kTextoGrisClaro),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _eventoManualCtrl,
            maxLines: 2, minLines: 1,
            decoration: InputDecoration(
              labelText: 'Nombre del evento en el certificado',
              filled: true, fillColor: _kCampoFondo,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _carreraManualCtrl,
            maxLines: 2, minLines: 1,
            decoration: InputDecoration(
              labelText: 'Nombre de la carrera/escuela en el certificado',
              filled: true, fillColor: _kCampoFondo,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _fechaManualCtrl,
            decoration: InputDecoration(
              labelText: 'Fecha de emisión',
              filled: true, fillColor: _kCampoFondo,
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today_rounded, size: 18, color: _kTextoGris),
                tooltip: 'Elegir fecha',
                onPressed: () async {
                  final ahora = DateTime.now();
                  final elegido = await showDatePicker(
                    context: context,
                    initialDate: ahora,
                    firstDate: DateTime(ahora.year - 5),
                    lastDate: DateTime(ahora.year + 1),
                  );
                  if (elegido != null) {
                    setState(() => _fechaManualCtrl.text = formatearFechaEs(elegido));
                  }
                },
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ]),
      );

  Widget _buildCampo2() => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle(Icons.looks_two_rounded, '2. Códigos de certificado',
              color: _campo1Listo ? _kJurado : _kTextoGrisClaro),
          const SizedBox(height: 6),
          Text(
            _campo1Listo
                ? 'Pega ${_entries.length} código(s), en el mismo orden que los nombres.'
                : 'Se habilita cuando el paso 1 no tenga nombres bloqueantes.',
            style: const TextStyle(fontSize: 11, color: _kTextoGrisClaro),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _codigosCtrl,
            enabled: _campo1Listo && !_guardando,
            maxLines: 8,
            minLines: 4,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'Ej: EVT-26-J0401001',
              hintStyle: const TextStyle(fontSize: 12, color: _kTextoGrisClaro),
              filled: true,
              fillColor: _campo1Listo ? _kCampoFondo : Colors.grey.shade100,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              onPressed: _campo1Listo ? _procesarCodigos : null,
              icon: const Icon(Icons.preview_rounded, size: 20),
              label: const Text('Emparejar y previsualizar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kJurado, foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0x660F6E56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      );

 Widget _buildPreviewFinal() => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle(Icons.rule_folder_outlined, 'Vista previa final'),
          const SizedBox(height: 10),
          ...List.generate(_entries.length, (i) {
            final e = _entries[i];
            final (badgeColor, badgeTexto) = switch (e.estado) {
              _EstadoJuradoBloque.creadoManual => (_kAzulInfo, 'Manual · solo descarga'),
              _EstadoJuradoBloque.yaEnLista    => (_kJurado, 'Se actualizará código'),
              _ => (_kVerde, 'En el sistema'),
            };
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _kCampoFondo,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(children: [
                SizedBox(width: 24, child: Text('${i + 1}',
                    style: const TextStyle(fontSize: 11, color: _kTextoGrisClaro))),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(e.nombreIngresado,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextoOscuro),
                          overflow: TextOverflow.ellipsis)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(badgeTexto,
                            style: TextStyle(fontSize: 9, color: badgeColor)),
                      ),
                    ]),
                  ]),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: _kTextoGrisClaro),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(e.codigoCertificadoNuevo,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kVerde, fontFamily: 'monospace')),
                ),
              ]),
            );
          }),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: _guardando ? null : _confirmarYGuardar,
              icon: _guardando
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 22),
              label: Text(_guardando ? 'Guardando...' : 'Agregar ${_entries.length} jurado(s) a la lista'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kVerde, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]),
      );
}