import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'detalle_lista_certificados_screen.dart';

const _kPrimario       = Color(0xFF1E3A5F);
const _kPrimario10     = Color(0x1A1E3A5F);
const _kTextoGris      = Color(0xFF64748B);
const _kTextoGrisClaro = Color(0xFF94A3B8);
const _kTextoOscuro    = Color(0xFF334155);
const _kFondo          = Color(0xFFE8EDF2);
const _kVerde          = Color(0xFF16A34A);
const _kAmbar          = Color(0xFFF59E0B);
const _kJurado         = Color(0xFF0F6E56);

const List<String> _kRolesFiltro = ['TODOS', 'ASISTENTE', 'PONENTE', 'ORGANIZADOR', 'JURADO'];

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
      builder: (_) => DetalleListaCertificadosScreen(doc: doc, onEnviado: _cargar),
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
