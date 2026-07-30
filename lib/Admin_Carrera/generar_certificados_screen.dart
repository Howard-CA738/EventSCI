import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import '/prefs_helper.dart';
import 'certificado_builder.dart';

const _kPrimario       = Color(0xFF1E3A5F);
const _kPrimario10     = Color(0x1A1E3A5F);
const _kTextoGris      = Color(0xFF64748B);
const _kTextoGrisClaro = Color(0xFF94A3B8);
const _kTextoOscuro    = Color(0xFF334155);
const _kFondo          = Color(0xFFE8EDF2);
const _kCampoFondo     = Color(0xFFF8FAFC);
const _kCampoFondo2    = Color(0xFFF1F5F9);
const _kVerde          = Color(0xFF16A34A);
const _kAmbar          = Color(0xFFF59E0B);
const _kJurado         = Color(0xFF0F6E56);

const _kRoles = ['ASISTENTE', 'PONENTE', 'JURADO', 'ORGANIZADOR'];



class _Persona {
  final String id;
  final String nombre;
  final String dni;
  final String codigo;
  final bool esJurado;

  _Persona({
    required this.id,
    required this.nombre,
    this.dni = '',
    this.codigo = '',
    this.esJurado = false,
  });
}


class _CertificadoEnviado {
  final String id;
  final String evento;
  final String rol;
  final String fecha;
  final String codigoCertificado;
  final Timestamp? creadoEn;
  final Map<String, dynamic> raw;

  _CertificadoEnviado({
    required this.id,
    required this.evento,
    required this.rol,
    required this.fecha,
    required this.codigoCertificado,
    this.creadoEn,
    required this.raw,
  });




  bool get tieneDatosCompletos => (raw['motivo'] as String? ?? '').trim().isNotEmpty;

  factory _CertificadoEnviado.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return _CertificadoEnviado(
      id: doc.id,
      evento: (d['evento'] as String? ?? '').trim(),
      rol: (d['rol'] as String? ?? '').trim(),
      fecha: (d['fecha'] as String? ?? '').trim(),
      codigoCertificado: (d['codigoCertificado'] as String? ?? '').trim(),
      creadoEn: d['creadoEn'] as Timestamp?,
      raw: d,
    );
  }
}

class GenerarCertificadosScreen extends StatefulWidget {
  const GenerarCertificadosScreen({super.key});

  @override
  State<GenerarCertificadosScreen> createState() =>
      _GenerarCertificadosScreenState();
}

class _GenerarCertificadosScreenState
    extends State<GenerarCertificadosScreen> {

  String _carrera   = '';
  String _facultad  = '';
  String _filial    = '';
  String _filialId  = '';

  String get _docKeyEstudiantes => '${_filial}_$_carrera';


  String _rol = 'ASISTENTE';


  List<_Persona> _estudiantes = [];
  List<_Persona> _jurados     = [];
  bool _isLoading = true;

  List<_Persona> get _fuenteActiva => _rol == 'JURADO' ? _jurados : _estudiantes;


  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  List<_Persona> _resultados = [];


  final Map<String, Future<List<_CertificadoEnviado>>> _certsCache = {};


  final Set<String> _generandoIds = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    final data = await PrefsHelper.getAdminCarreraData();
    if (data != null) {
      _carrera   = data['carrera']      ?? '';
      _facultad  = data['facultad']     ?? '';
      _filial    = data['filialNombre'] ?? '';
      _filialId  = data['filial']       ?? '';
    }
    await Future.wait([_cargarEstudiantes(), _cargarJurados()]);
    if (mounted) setState(() => _isLoading = false);
  }


  Future<void> _cargarEstudiantes() async {
    if (_filial.isEmpty || _carrera.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_docKeyEstudiantes)
          .collection('students')
          .orderBy('name')
          .get();
      final lista = snap.docs.map((doc) {
        final d = doc.data();
        return _Persona(
          id: doc.id,
          nombre: d['name'] as String? ?? 'Sin nombre',
          dni: d['dni'] as String? ?? '',
          codigo: d['codigoUniversitario'] as String? ?? '',
        );
      }).toList();
      if (mounted) setState(() => _estudiantes = lista);
    } catch (e) {
      debugPrint('Error cargando estudiantes: $e');
    }
  }

  Future<void> _cargarJurados() async {
    if (_filialId.isEmpty || _facultad.isEmpty || _carrera.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'jurado')
          .where('filial', isEqualTo: _filialId)
          .where('facultad', isEqualTo: _facultad)
          .where('carrera', isEqualTo: _carrera)
          .get();
      final lista = snap.docs.map((doc) {
        final d = doc.data();
        return _Persona(
          id: doc.id,
          nombre: d['name'] as String? ?? 'Sin nombre',
          dni: d['dni'] as String? ?? '',
          codigo: d['usuario'] as String? ?? '',
          esJurado: true,
        );
      }).toList();
      lista.sort((a, b) => a.nombre.compareTo(b.nombre));
      if (mounted) setState(() => _jurados = lista);
    } catch (e) {
      debugPrint('Error cargando jurados: $e');
    }
  }


  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() {
        _searchQuery = q.trim();
        _actualizarResultados();
      });
    });
  }

  void _actualizarResultados() {
    final q = _searchQuery.toLowerCase();
    if (q.isEmpty) {
      _resultados = [];
      return;
    }
    _resultados = _fuenteActiva.where((p) {
      return p.nombre.toLowerCase().contains(q) ||
          p.dni.contains(q) ||
          p.codigo.toLowerCase().contains(q);
    }).toList();
  }

  void _cambiarRol(String rol) {
    setState(() {
      _rol = rol;
      _certsCache.clear();
      _actualizarResultados();
    });
  }


  Future<List<_CertificadoEnviado>> _certificadosDe(_Persona p) {
    final key = '${p.id}_$_rol';
    return _certsCache.putIfAbsent(key, () async {
      try {
        final ref = p.esJurado
            ? FirebaseFirestore.instance.collection('users').doc(p.id).collection('certificados')
            : FirebaseFirestore.instance
                .collection('users')
                .doc(_docKeyEstudiantes)
                .collection('students')
                .doc(p.id)
                .collection('certificados');

        final snap = await ref.where('rol', isEqualTo: _rol).get();
        final lista = snap.docs.map(_CertificadoEnviado.fromDoc).toList();
        lista.sort((a, b) {
          final ta = a.creadoEn?.millisecondsSinceEpoch ?? 0;
          final tb = b.creadoEn?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });
        return lista;
      } catch (e) {
        debugPrint('Error cargando certificados de ${p.nombre}: $e');
        return <_CertificadoEnviado>[];
      }
    });
  }

  void _snack(String msg, {Color color = _kPrimario}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }


  Future<Uint8List?> _descargarFirma(String url) async {
    if (url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (e) {
      debugPrint('Error HTTP directo: $e — intentando refrescar...');
    }
    try {
      final uri      = Uri.parse(url);
      final segments = uri.path.split('/o/');
      if (segments.length < 2) return null;
      final fullPath = Uri.decodeComponent(segments.last.split('?').first);
      final newUrl   = await FirebaseStorage.instance.ref(fullPath).getDownloadURL();
      final response = await http.get(Uri.parse(newUrl)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (e) {
      debugPrint('Error refrescando URL: $e');
    }
    return null;
  }



  Future<Uint8List?> _generarPdfCertificado(_Persona p, _CertificadoEnviado c) async {
    if (!c.tieneDatosCompletos) {
      _snack('Este certificado no tiene datos completos guardados, no se puede generar el PDF',
          color: _kAmbar);
      return null;
    }
    try {
      final datosBase = DatosCertificado.fromMap(c.raw);
      final resultados = await Future.wait([
        _descargarFirma(datosBase.urlFirma1),
        _descargarFirma(datosBase.urlFirma2),
        _descargarFirma(datosBase.urlFirma3),
      ]);
      final datos = DatosCertificado(
        facultad: datosBase.facultad, carrera: datosBase.carrera, campus: datosBase.campus,
        motivo: datosBase.motivo, fecha: datosBase.fecha, horas: datosBase.horas,
        evento: datosBase.evento, rol: datosBase.rol,
        director1: datosBase.director1, cargo1: datosBase.cargo1,
        director2: datosBase.director2, cargo2: datosBase.cargo2,
        director3: datosBase.director3, cargo3: datosBase.cargo3,
        codigoCertificado: c.codigoCertificado,
        bytesFirma1: resultados[0], bytesFirma2: resultados[1], bytesFirma3: resultados[2],
      );
      final estudiante = Estudiante(
        id: p.id,
        nombre: (c.raw['nombreEstudiante'] as String? ?? '').isNotEmpty
            ? c.raw['nombreEstudiante'] as String
            : p.nombre,
        dni: p.dni,
        codigo: p.codigo,
        codigoCertificado: c.codigoCertificado,
      );
      final builder = CertificadoBuilder(datos);
      return await builder.buildPdf([estudiante]);
    } catch (e) {
      debugPrint('Error generando PDF del certificado: $e');
      _snack('Error generando el PDF: $e', color: _kAmbar);
      return null;
    }
  }

  Future<void> _verCertificado(_Persona p, _CertificadoEnviado c) async {
    if (_generandoIds.contains(c.id)) return;
    setState(() => _generandoIds.add(c.id));
    final bytes = await _generarPdfCertificado(p, c);
    if (mounted) setState(() => _generandoIds.remove(c.id));
    if (bytes == null) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _descargarCertificado(_Persona p, _CertificadoEnviado c) async {
    if (_generandoIds.contains(c.id)) return;
    setState(() => _generandoIds.add(c.id));
    final bytes = await _generarPdfCertificado(p, c);
    if (mounted) setState(() => _generandoIds.remove(c.id));
    if (bytes == null) return;
    final nombreArchivo =
        'certificado_${c.codigoCertificado.isNotEmpty ? c.codigoCertificado : p.nombre.replaceAll(' ', '_')}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: nombreArchivo);
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPrimario,
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _kPrimario))
                  : _buildBody(),
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
        child: const Icon(Icons.workspace_premium, color: _kPrimario, size: 26),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ver Certificados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              overflow: TextOverflow.ellipsis, maxLines: 1),
          Text('Busca por nombre o código',
              style: TextStyle(fontSize: 11, color: Colors.white70),
              overflow: TextOverflow.ellipsis, maxLines: 1),
        ]),
      ),
      SizedBox(
        width: 44, height: 44,
        child: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
        ),
      ),
    ]),
  );

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildCardRol(),
        const SizedBox(height: 12),
        _buildCardBusqueda(),
        const SizedBox(height: 12),
        _buildResultados(),
      ],
    );
  }


  Widget _buildCardRol() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: _kPrimario10, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.filter_alt_outlined, color: _kPrimario, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Rol de certificado',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kPrimario))),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _kRoles.map((rol) {
            final activo = _rol == rol;
            final color = rol == 'JURADO' ? _kJurado : _kPrimario;
            return ChoiceChip(
              label: Text(rol, style: TextStyle(fontSize: 11, color: activo ? Colors.white : color)),
              selected: activo,
              selectedColor: color,
              backgroundColor: Colors.grey.shade100,
              onSelected: (_) => _cambiarRol(rol),
            );
          }).toList(),
        ),
      ]),
    );
  }


  Widget _buildCardBusqueda() {
    final esJuradoRol = _rol == 'JURADO';
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: _kPrimario10, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.search, color: _kPrimario, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(esJuradoRol ? 'Buscar jurado' : 'Buscar estudiante',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kPrimario))),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: esJuradoRol
                ? 'Nombre o usuario del jurado...'
                : 'Nombre, DNI o código universitario...',
            hintStyle: const TextStyle(fontSize: 12, color: _kTextoGrisClaro),
            prefixIcon: const Icon(Icons.person_search_outlined, color: _kTextoGrisClaro, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: _kTextoGrisClaro, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() { _searchQuery = ''; _resultados = []; });
                    },
                  )
                : null,
            filled: true, fillColor: _kCampoFondo2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          ),
        ),
      ]),
    );
  }


  Widget _buildResultados() {
    if (_searchQuery.isEmpty) {
      return _Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              'Escribe un nombre o código para buscar',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            ),
          ),
        ),
      );
    }

    if (_resultados.isEmpty) {
      return _Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              'Sin resultados para "$_searchQuery"',
              style: const TextStyle(fontSize: 12, color: _kTextoGrisClaro, fontStyle: FontStyle.italic),
            ),
          ),
        ),
      );
    }

    return Column(
      children: _resultados.map((p) => _buildPersonaConCertificados(p)).toList(),
    );
  }

  Widget _buildPersonaConCertificados(_Persona p) {
    final accentColor = p.esJurado ? _kJurado : _kPrimario;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Center(
                child: Text(p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?',
                    style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.nombre,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextoOscuro),
                    overflow: TextOverflow.ellipsis, maxLines: 1),
                if (p.codigo.isNotEmpty)
                  Text(p.codigo, style: const TextStyle(fontSize: 11, color: _kTextoGrisClaro)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          FutureBuilder<List<_CertificadoEnviado>>(
            future: _certificadosDe(p),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimario),
                  )),
                );
              }
              final certs = snapshot.data ?? [];
              if (certs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'No tiene certificados enviados como $_rol',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                );
              }
              return Column(
                children: certs.map((c) => _buildCertificadoTile(p, c)).toList(),
              );
            },
          ),
        ]),
      ),
    );
  }

  Widget _buildCertificadoTile(_Persona p, _CertificadoEnviado c) {
    final tieneCodigo    = c.codigoCertificado.isNotEmpty;
    final generando      = _generandoIds.contains(c.id);
    final puedeGenerar   = c.tieneDatosCompletos && !generando;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kCampoFondo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.description_outlined, size: 16,
              color: tieneCodigo ? _kVerde : _kAmbar),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.evento.isNotEmpty ? c.evento : 'Evento sin nombre',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextoOscuro),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              if (c.fecha.isNotEmpty)
                Text(c.fecha, style: const TextStyle(fontSize: 10, color: _kTextoGrisClaro)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tieneCodigo ? _kVerde.withValues(alpha: 0.1) : _kAmbar.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tieneCodigo ? c.codigoCertificado : 'Sin código',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: tieneCodigo ? _kVerde : _kAmbar,
                fontFamily: tieneCodigo ? 'monospace' : null,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        if (!c.tieneDatosCompletos)
          Text(
            'Sin datos suficientes para generar el PDF (certificado creado solo con código)',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
          )
        else if (generando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimario)),
              SizedBox(width: 8),
              Text('Generando PDF...', style: TextStyle(fontSize: 11, color: _kTextoGris)),
            ]),
          )
        else
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: puedeGenerar ? () => _verCertificado(p, c) : null,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Ver', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPrimario,
                  side: const BorderSide(color: _kPrimario),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: puedeGenerar ? () => _descargarCertificado(p, c) : null,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Descargar', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimario, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
      ]),
    );
  }
}


class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Card(
    elevation: 2, shadowColor: Colors.black12,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    color: Colors.white,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}