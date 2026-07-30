import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import '/admin_Carrera/certificado_builder.dart';

const _kPrimario       = Color(0xFF1E3A5F);
const _kPrimario10     = Color(0x1A1E3A5F);
const _kTextoGris      = Color(0xFF64748B);
const _kTextoGrisClaro = Color(0xFF94A3B8);
const _kTextoOscuro    = Color(0xFF334155);
const _kFondo          = Color(0xFFE8EDF2);
const _kCampoFondo     = Color(0xFFF8FAFC);
const _kVerde          = Color(0xFF16A34A);
const _kAmbar          = Color(0xFFF59E0B);
const _kAzulInfo       = Color(0xFF2563EB);
const _kJurado         = Color(0xFF0F6E56);


const List<String> _kRolesFiltro = ['TODOS', 'ASISTENTE', 'PONENTE', 'ORGANIZADOR', 'JURADO'];


class _Firmante {
  final String nombre;
  final String cargo;
  final String urlFirma;
  const _Firmante({this.nombre = '', this.cargo = '', this.urlFirma = ''});

  factory _Firmante.fromDoc(Map<String, dynamic>? d) {
    if (d == null) return const _Firmante();
    final grado  = (d['grado']  as String? ?? '').trim();
    final nombre = (d['nombre'] as String? ?? '').trim();
    return _Firmante(
      nombre:   grado.isEmpty ? nombre : '$grado $nombre',
      cargo:    (d['cargo']      as String? ?? '').trim(),
      urlFirma: (d['storageUrl'] as String? ?? '').trim(),
    );
  }
}

String _generarFacultadId(String texto) => texto
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]'), '_')
    .replaceAll(RegExp(r'_+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');


const List<String> _kTitulosAcademicos = [
  'dr','Dr','Mg','Psic', 'dra', 'ing', 'mg', 'mag', 'mtra', 'mtro', 'lic', 'abg',
  'msc', 'phd', 'prof', 'bach', 'econ', 'arq', 'cpc', 'psic',
];

String _quitarTitulo(String nombre) {
  var r = nombre.trim();
  bool cambio = true;
  while (cambio) {
    cambio = false;
    for (final t in _kTitulosAcademicos) {
      final regex = RegExp('^$t\\.?\\s+', caseSensitive: false);
      if (regex.hasMatch(r)) {
        r = r.replaceFirst(regex, '').trim();
        cambio = true;
      }
    }
  }
  return r;
}

String _motivoPorRol({
  required String rol,
  required String evento,
  required String fecha,
  required String carrera,
  required String horas,
}) {
  final credito = horas.trim() == '16' ? ' con 1 crédito' : '';
  switch (rol) {
    case 'PONENTE':
      return 'Por su valiosa participación en calidad de PONENTE, en la "$evento", '
          'evento desarrollado el $fecha.';
    case 'JURADO':
      return 'Por su participación en calidad de JURADO en la "$evento", '
          'organizado por la Escuela Profesional de $carrera; '
          'realizado el $fecha. Su experticia y conocimientos han contribuido '
          'significativamente en la evaluación de trabajos de investigación.';
    case 'ORGANIZADOR':
      return 'Por su participación en calidad de ORGANIZADOR en la "$evento", '
          'promovido por la Escuela Profesional de $carrera; '
          'realizado el $fecha, con equivalencia a un total de $horas horas académicas$credito. '
          'Su apoyo ha contribuido en el éxito y el desarrollo del evento científico.';
    case 'ASISTENTE':
    default:
      return 'Por su participación en calidad de ASISTENTE en la "$evento", '
          'organizado por la Escuela Profesional de $carrera; '
          'realizado el $fecha, con equivalencia a un total de $horas horas académicas$credito.';
  }
}

const List<String> _kMesesEs = [
  '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

String _formatearFechaEs(DateTime d) =>
    '${d.day} de ${_kMesesEs[d.month]} de ${d.year}';

String _fechaActual() => _formatearFechaEs(DateTime.now());

class ListasCertificadosImportadosScreen extends StatefulWidget {
  const ListasCertificadosImportadosScreen({super.key});

  @override
  State<ListasCertificadosImportadosScreen> createState() =>
      _ListasCertificadosImportadosScreenState();
}

class _ListasCertificadosImportadosScreenState
    extends State<ListasCertificadosImportadosScreen> {
  bool _isLoading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _listas = [];


  final TextEditingController _busquedaCtrl = TextEditingController();
  String _busqueda = '';


  String _filtroRol = 'TODOS';


  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _listasFiltradas {
    final q = _busqueda.trim().toLowerCase();
    return _listas.where((doc) {
      final data = doc.data();
      if (_filtroRol != 'TODOS' && (data['rol'] ?? '') != _filtroRol) {
        return false;
      }
      if (q.isEmpty) return true;
      final carrera = (data['carrera'] ?? '').toString().toLowerCase();
      return carrera.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
  setState(() => _isLoading = true);
  try {
    final snap = await FirebaseFirestore.instance
    .collection('listas_certificados')
    .orderBy('fecha', descending: true)
    .get();
    if (mounted) setState(() => _listas = snap.docs);
  } catch (e) {
    debugPrint('Error cargando listas: $e');
  }
  if (mounted) setState(() => _isLoading = false);
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








  Future<void> _migrarPrefijoS() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.text_fields_rounded, color: _kAmbar),
          SizedBox(width: 10),
          Flexible(child: Text('Agregar prefijo "S"',
              style: TextStyle(color: _kPrimario, fontWeight: FontWeight.bold))),
        ]),
        content: const Text(
          'Esto agregará la letra "S" al inicio de TODOS los códigos de '
          'certificado de TODAS las listas importadas (y de sus documentos '
          'de certificado en Firestore).\n\n'
          'Ej: EVT-0232656 → SEVT-0232656\n\n'
          'Los códigos que ya empiecen con "S" no se tocarán, puedes '
          'ejecutar esto varias veces (incluso con listas nuevas) sin '
          'duplicar la letra.\n\n'
          '¿Continuar?',
          style: TextStyle(fontSize: 13, color: _kTextoGris),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kAmbar, foregroundColor: Colors.white),
            child: const Text('Sí, agregar "S"'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(color: _kPrimario),
          SizedBox(width: 20),
          Expanded(child: Text('Actualizando códigos...')),
        ]),
      ),
    );

    int listasActualizadas = 0;
    int codigosActualizados = 0;
    int errores = 0;

    try {
      final db = FirebaseFirestore.instance;


      final snap = await db.collection('listas_certificados').get();

      for (final doc in snap.docs) {
        try {
          final data   = doc.data();
          final rol    = (data['rol'] ?? '').toString();
          final esJuradoLista = rol == 'JURADO';
          final docKey = '${data['filialNombre']}_${data['carrera']}';
          final estudiantes = List<Map<String, dynamic>>.from(data['estudiantes'] ?? []);
          if (estudiantes.isEmpty) continue;

          bool huboCambios = false;
          final batch = db.batch();

          for (final e in estudiantes) {
            final codigoActual = (e['codigoCertificado'] ?? '').toString();
            if (codigoActual.isEmpty || codigoActual.toUpperCase().startsWith('S')) {
              continue;
            }
            final nuevoCodigo = 'S$codigoActual';
            e['codigoCertificado'] = nuevoCodigo;
            huboCambios = true;
            codigosActualizados++;

            final estudianteId = e['estudianteId'] as String?;
            final certId       = e['certId'] as String?;
            if (estudianteId != null && certId != null) {



              final ref = esJuradoLista
                  ? db.collection('users').doc(estudianteId)
                      .collection('certificados').doc(certId)
                  : db.collection('users').doc(docKey)
                      .collection('students').doc(estudianteId)
                      .collection('certificados').doc(certId);
              batch.update(ref, {'codigoCertificado': nuevoCodigo});
            }
          }

          if (huboCambios) {
            batch.update(doc.reference, {'estudiantes': estudiantes});
            await batch.commit();
            listasActualizadas++;
          }
        } catch (e) {
          errores++;
          debugPrint('Error migrando lista ${doc.id}: $e');
        }
      }
    } catch (e) {
      errores++;
      debugPrint('Error general en migración de prefijo S: $e');
    }

    if (mounted) Navigator.pop(context);
    await _cargar();

    if (mounted) {
      _snack(
        errores == 0
            ? '✅ $codigosActualizados código(s) en $listasActualizadas lista(s) actualizados'
            : '⚠️ $codigosActualizados código(s) actualizados, $errores lista(s) con error',
        color: errores == 0 ? _kVerde : _kAmbar,
      );
    }
  }













  Future<void> _generarListasJurados() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.groups_rounded, color: _kJurado),
          SizedBox(width: 10),
          Flexible(child: Text('Generar listas de jurados',
              style: TextStyle(color: _kPrimario, fontWeight: FontWeight.bold))),
        ]),
        content: const Text(
          'Esto recorrerá todos los jurados registrados y creará (o '
          'actualizará) una lista por cada evento al que pertenecen, '
          'agrupados por filial/facultad/carrera.\n\n'
          'Si una lista ya existe, solo se agregarán los jurados nuevos '
          'que falten: los códigos ya asignados y los cambios previos no '
          'se pierden.\n\n'
          '¿Continuar?',
          style: TextStyle(fontSize: 13, color: _kTextoGris),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kJurado, foregroundColor: Colors.white),
            child: const Text('Generar listas'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(color: _kJurado),
          SizedBox(width: 20),
          Expanded(child: Text('Generando listas de jurados...')),
        ]),
      ),
    );

    int listasCreadas = 0;
    int listasActualizadas = 0;
    int juradosAgregados = 0;
    int juradosOmitidos = 0;
    int errores = 0;

    try {
      final db = FirebaseFirestore.instance;
      final juradosSnap = await db
          .collection('users')
          .where('userType', isEqualTo: 'jurado')
          .get();


      final grupos = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
      for (final doc in juradosSnap.docs) {
        final d = doc.data();
        final filialId  = (d['filial']    ?? '').toString();
        final facultad  = (d['facultad']  ?? '').toString();
        final carreraId = (d['carreraId'] ?? '').toString();
        final eventoId  = (d['eventoId']  ?? '').toString();
        if (filialId.isEmpty || carreraId.isEmpty || eventoId.isEmpty) {
          juradosOmitidos++;
          continue;
        }
        final key = '$filialId|$facultad|$carreraId|$eventoId';
        grupos.putIfAbsent(key, () => []).add(doc);
      }

      for (final entry in grupos.entries) {
        try {
          final docs     = entry.value;
          final primero  = docs.first.data();
          final filialId     = (primero['filial']       ?? '').toString();
          final filialNombre = (primero['filialNombre'] ?? '').toString();
          final facultad     = (primero['facultad']     ?? '').toString();
          final carreraId    = (primero['carreraId']    ?? '').toString();
          final carrera      = (primero['carrera']      ?? '').toString();
          final eventoId     = (primero['eventoId']     ?? '').toString();
          final eventoNombre = (primero['eventoNombre'] ?? '').toString();

          final nuevosJurados = docs.map((doc) {
            final d = doc.data();
            return {
              'estudianteId': doc.id,
              'nombre': d['name'] ?? 'Sin nombre',
              'dni': (d['dni'] ?? '').toString(),
              'codigoEstudiante': (d['usuario'] ?? '').toString(),
              'codigoCertificado': '',
              'certId': null,
              'generadoCompleto': false,
            };
          }).toList();

          final existente = await db.collection('listas_certificados')
              .where('rol', isEqualTo: 'JURADO')
              .where('filialId', isEqualTo: filialId)
              .where('carreraId', isEqualTo: carreraId)
              .where('eventoId', isEqualTo: eventoId)
              .limit(1)
              .get();

          if (existente.docs.isEmpty) {
            await db.collection('listas_certificados').add({
              'filialId': filialId,
              'filialNombre': filialNombre,
              'facultad': facultad,
              'carrera': carrera,
              'carreraId': carreraId,
              'eventoId': eventoId,
              'evento': eventoNombre,
              'rol': 'JURADO',
              'fecha': Timestamp.now(),
              'totalEstudiantes': nuevosJurados.length,
              'estudiantes': nuevosJurados,
            });
            listasCreadas++;
            juradosAgregados += nuevosJurados.length;
          } else {
            final doc = existente.docs.first;
            final actuales = List<Map<String, dynamic>>.from(doc.data()['estudiantes'] ?? []);
            final idsExistentes = actuales.map((e) => e['estudianteId']).toSet();
            final faltantes = nuevosJurados
                .where((j) => !idsExistentes.contains(j['estudianteId']))
                .toList();
            if (faltantes.isNotEmpty) {
              final combinados = [...actuales, ...faltantes];
              await doc.reference.update({
                'estudiantes': combinados,
                'totalEstudiantes': combinados.length,
              });
              listasActualizadas++;
              juradosAgregados += faltantes.length;
            }
          }
        } catch (e) {
          errores++;
          debugPrint('Error generando lista de jurados para ${entry.key}: $e');
        }
      }
    } catch (e) {
      errores++;
      debugPrint('Error general generando listas de jurados: $e');
    }

    if (mounted) Navigator.pop(context);
    await _cargar();

    if (mounted) {
      final resumen = '$listasCreadas lista(s) nueva(s), $listasActualizadas '
          'actualizada(s), $juradosAgregados jurado(s) agregados'
          '${juradosOmitidos > 0 ? ', $juradosOmitidos sin evento asignado' : ''}';
      _snack(
        errores == 0 ? '✅ $resumen' : '⚠️ $resumen, $errores error(es)',
        color: errores == 0 ? _kVerde : _kAmbar,
      );
    }
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
                  : _listas.isEmpty
                      ? _buildVacio()
                      : Column(children: [
                          _buildBuscador(),
                          _buildFiltroRol(),
                          Expanded(
                            child: _listasFiltradas.isEmpty
                                ? _buildSinResultados()
                                : RefreshIndicator(
                                    onRefresh: _cargar,
                                    color: _kPrimario,
                                    child: ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                      itemCount: _listasFiltradas.length,
                                      itemBuilder: (_, i) => _buildListaCard(_listasFiltradas[i]),
                                    ),
                                  ),
                          ),
                        ]),
            ),
          ),
        ]),
      ),
    );
  }


  Widget _buildBuscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _busquedaCtrl,
        onChanged: (v) => setState(() => _busqueda = v),
        style: const TextStyle(fontSize: 13, color: _kTextoOscuro),
        decoration: InputDecoration(
          hintText: 'Buscar por carrera...',
          hintStyle: const TextStyle(fontSize: 13, color: _kTextoGrisClaro),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _kTextoGris),
          suffixIcon: _busqueda.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: _kTextoGris),
                  tooltip: 'Limpiar búsqueda',
                  onPressed: () => setState(() {
                    _busquedaCtrl.clear();
                    _busqueda = '';
                  }),
                ),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
    );
  }


  Widget _buildFiltroRol() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _kRolesFiltro.map((r) {
            final activo = _filtroRol == r;
            final color  = r == 'JURADO' ? _kJurado : _kPrimario;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(r == 'TODOS' ? 'Todos' : r,
                    style: TextStyle(fontSize: 11, color: activo ? Colors.white : color)),
                selected: activo,
                selectedColor: color,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: color.withValues(alpha: activo ? 0 : 0.4)),
                ),
                onSelected: (_) => setState(() => _filtroRol = r),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSinResultados() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.search_off_rounded, size: 56, color: _kTextoGrisClaro),
            const SizedBox(height: 16),
            const Text('Sin resultados',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kPrimario)),
            const SizedBox(height: 6),
            Text(
              _busqueda.trim().isEmpty
                  ? 'No hay listas con el rol "$_filtroRol".'
                  : 'No hay listas con carrera que contenga "${_busqueda.trim()}"'
                    '${_filtroRol != 'TODOS' ? ' y rol "$_filtroRol"' : ''}.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ]),
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration:
                BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.list_alt_rounded, color: _kPrimario, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Listas de Importación',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              Text('Lotes de códigos de certificado importados',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.groups_rounded, color: Colors.white, size: 24),
            tooltip: 'Generar listas de jurados por evento',
            onPressed: _generarListasJurados,
          ),
          IconButton(
            icon: const Icon(Icons.text_fields_rounded, color: Colors.white, size: 24),
            tooltip: 'Agregar prefijo "S" a todos los códigos',
            onPressed: _migrarPrefijoS,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ]),
      );

  Widget _buildVacio() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.inbox_outlined, size: 56, color: _kTextoGrisClaro),
            const SizedBox(height: 16),
            const Text('Aún no hay listas importadas',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kPrimario)),
            const SizedBox(height: 6),
            Text('Cuando importes códigos de certificado, aparecerán aquí.\n'
                'También puedes generar las listas de jurados con el ícono de grupo arriba.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ),
      );

  Widget _buildListaCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final rol = (d['rol'] ?? '').toString();
    final esJuradoLista = rol == 'JURADO';
    final fecha = (d['fecha'] as Timestamp?)?.toDate();
    final total = d['totalEstudiantes'] ?? (d['estudiantes'] as List?)?.length ?? 0;
    final estudiantes = List<Map<String, dynamic>>.from(d['estudiantes'] ?? []);



    final pendientes = estudiantes
        .where((e) => e['generadoCompleto'] != true && e['esManual'] != true)
        .length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _abrirDetalle(doc),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: esJuradoLista ? _kJurado.withValues(alpha: 0.1) : _kPrimario10,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(esJuradoLista ? Icons.gavel_rounded : Icons.qr_code_2_rounded,
                    color: esJuradoLista ? _kJurado : _kPrimario, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${d['evento'] ?? 'Evento'} · ${d['rol'] ?? ''}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                          color: esJuradoLista ? _kJurado : _kPrimario),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                  Text('${d['filialNombre'] ?? ''} · ${d['carrera'] ?? ''}',
                      style: const TextStyle(fontSize: 11, color: _kTextoGris),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                ]),
              ),
              SizedBox(
                width: 36, height: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFDC2626)),
                  tooltip: 'Eliminar lista',
                  onPressed: () => _eliminarLista(doc),
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _kTextoGrisClaro),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _badge(Icons.people_alt_outlined, '$total ${esJuradoLista ? 'jurado(s)' : 'estudiante(s)'}',
                  esJuradoLista ? _kJurado : _kPrimario),
              const SizedBox(width: 8),
              if (pendientes > 0)
                _badge(Icons.pending_actions_rounded, '$pendientes pendiente(s)', _kAmbar)
              else
                _badge(Icons.check_circle_outline, 'Completo', _kVerde),
              const Spacer(),
              if (fecha != null)
                Text('${fecha.day}/${fecha.month}/${fecha.year}',
                    style: const TextStyle(fontSize: 11, color: _kTextoGrisClaro)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
        ]),
      );

  void _abrirDetalle(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _DetalleListaScreen(doc: doc, onEnviado: _cargar),
    ));
  }








  Future<void> _eliminarLista(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data();
    final esJuradoLista = (d['rol'] ?? '') == 'JURADO';
    final estudiantes = List<Map<String, dynamic>>.from(d['estudiantes'] ?? []);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626)),
          SizedBox(width: 10),
          Flexible(child: Text('Eliminar lista',
              style: TextStyle(color: _kPrimario, fontWeight: FontWeight.bold))),
        ]),
        content: Text(
          '¿Eliminar la lista de "${d['evento'] ?? ''}"?\n\n'
          'Esto borrará también los ${estudiantes.length} código(s) de certificado '
          'ya asignados a estos ${esJuradoLista ? 'jurados' : 'estudiantes'}, para que puedas '
          'volver a asignarlos correctamente. Esta acción es irreversible.',
          style: const TextStyle(fontSize: 13, color: _kTextoGris),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Eliminar todo'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      final docKey = '${d['filialNombre']}_${d['carrera']}';
      final db = FirebaseFirestore.instance;


      final borrados = <Future<void>>[];
      for (final e in estudiantes) {
        final estudianteId = e['estudianteId'] as String?;
        final certId = e['certId'] as String?;
        if (estudianteId == null || certId == null) continue;
        final ref = esJuradoLista
            ? db.collection('users').doc(estudianteId)
                .collection('certificados').doc(certId)
            : db.collection('users').doc(docKey)
                .collection('students').doc(estudianteId)
                .collection('certificados').doc(certId);
        borrados.add(ref.delete().catchError((err) {
          debugPrint('Error borrando certificado de $estudianteId: $err');
        }));
      }
      await Future.wait(borrados);


      await doc.reference.delete();

      await _cargar();
      _snack('Lista y códigos de certificado eliminados', color: _kVerde);
    } catch (e) {
      _snack('Error eliminando la lista: $e', color: const Color(0xFFDC2626));
    }
  }
}




class _DetalleListaScreen extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Future<void> Function() onEnviado;
  const _DetalleListaScreen({required this.doc, required this.onEnviado});

  @override
  State<_DetalleListaScreen> createState() => _DetalleListaScreenState();
}

class _DetalleListaScreenState extends State<_DetalleListaScreen> {
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
      builder: (_) => _AgregarJuradosBloqueScreen(
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
      setStateDialog(() => fechaCtrl.text = _formatearFechaEs(elegido));
    }
  }













  Future<void> _descargarTodos() async {
    final rol = _data['rol'] as String? ?? 'ASISTENTE';

    final estudiantes = List<Map<String, dynamic>>.from(_data['estudiantes'] ?? []);
    if (estudiantes.isEmpty) return;

    final fechaCtrl = TextEditingController(text: _fechaActual());
    final horasCtrl = TextEditingController(text: '16');
    final llevaHoras = rol == 'ASISTENTE' || rol == 'ORGANIZADOR';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          final motivoPreview = _motivoPorRol(
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


      final facId = _generarFacultadId(_data['facultad'] as String? ?? '');
      final db    = FirebaseFirestore.instance;

      final resultadosFirmas = await Future.wait([
        db.collection('config_firmas').doc('vicerrector').get(),
        db.collection('config_firmas').doc('director_investigacion').get(),
        db.collection('config_firmas').doc('decanos').collection('facultades').doc(facId).get(),
      ]);
      final vSnap   = resultadosFirmas[0];
      final dSnap   = resultadosFirmas[1];
      final decSnap = resultadosFirmas[2];

      final firma1 = _Firmante.fromDoc(vSnap.exists ? vSnap.data() : null);
      final firma2 = _Firmante.fromDoc(decSnap.exists ? decSnap.data() : null);
      final firma3 = _Firmante.fromDoc(dSnap.exists ? dSnap.data() : null);





      final nombreEventoCertificado  = _nombreEventoCtrl.text.trim();
      final nombreCarreraCertificado = _nombreCarreraCtrl.text.trim();


      final motivo = _motivoPorRol(
        rol: rol,
        evento: nombreEventoCertificado,
        fecha: fechaCtrl.text,
        carrera: nombreCarreraCertificado,
        horas: horasCtrl.text,
      );


      final bytesFirmas = await Future.wait([
        _descargarFirma(firma1.urlFirma),
        _descargarFirma(firma2.urlFirma),
        _descargarFirma(firma3.urlFirma),
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

    final fechaCtrl = TextEditingController(text: _fechaActual());
    final horasCtrl = TextEditingController(text: '16');
    final llevaHoras = rol == 'ASISTENTE' || rol == 'ORGANIZADOR';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          final motivoPreview = _motivoPorRol(
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
      final facId = _generarFacultadId(lista['facultad'] as String? ?? '');
      final db = FirebaseFirestore.instance;


      final resultadosFirmas = await Future.wait([
        db.collection('config_firmas').doc('vicerrector').get(),
        db.collection('config_firmas').doc('director_investigacion').get(),
        db.collection('config_firmas').doc('decanos').collection('facultades').doc(facId).get(),
      ]);
      final vSnap   = resultadosFirmas[0];
      final dSnap   = resultadosFirmas[1];
      final decSnap = resultadosFirmas[2];

      final firma1 = _Firmante.fromDoc(vSnap.exists ? vSnap.data() : null);
      final firma2 = _Firmante.fromDoc(decSnap.exists ? decSnap.data() : null);
      final firma3 = _Firmante.fromDoc(dSnap.exists ? dSnap.data() : null);




      final nombreEventoCertificado  = _nombreEventoCtrl.text.trim();
      final nombreCarreraCertificado = _nombreCarreraCtrl.text.trim();


      final motivoGeneral = _motivoPorRol(
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

    final fechaCtrl = TextEditingController(text: _fechaActual());

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          final motivoPreview = _motivoPorRol(
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
      final facId = _generarFacultadId(lista['facultad'] as String? ?? '');
      final db = FirebaseFirestore.instance;

      final resultadosFirmas = await Future.wait([
        db.collection('config_firmas').doc('vicerrector').get(),
        db.collection('config_firmas').doc('director_investigacion').get(),
        db.collection('config_firmas').doc('decanos').collection('facultades').doc(facId).get(),
      ]);
      final vSnap   = resultadosFirmas[0];
      final dSnap   = resultadosFirmas[1];
      final decSnap = resultadosFirmas[2];

      final firma1 = _Firmante.fromDoc(vSnap.exists ? vSnap.data() : null);
      final firma2 = _Firmante.fromDoc(decSnap.exists ? decSnap.data() : null);
      final firma3 = _Firmante.fromDoc(dSnap.exists ? dSnap.data() : null);

      final nombreEventoCertificado  = _nombreEventoCtrl.text.trim();
      final nombreCarreraCertificado = _nombreCarreraCtrl.text.trim();

      final motivoGeneral = _motivoPorRol(
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

class _AgregarJuradosBloqueScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> listaRef;
  final Map<String, dynamic> listaData;
  const _AgregarJuradosBloqueScreen({required this.listaRef, required this.listaData});

  @override
  State<_AgregarJuradosBloqueScreen> createState() => _AgregarJuradosBloqueScreenState();
}

class _AgregarJuradosBloqueScreenState extends State<_AgregarJuradosBloqueScreen> {
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
    _fechaManualCtrl = TextEditingController(text: _fechaActual());
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
      .map((e) => _quitarTitulo(e.trim()))
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
          final nombreReal = _quitarTitulo((d['name'] ?? '').toString().trim());
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
        motivoManual = _motivoPorRol(
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
                    setState(() => _fechaManualCtrl.text = _formatearFechaEs(elegido));
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
                Text(e.codigoCertificadoNuevo,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kVerde, fontFamily: 'monospace')),
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