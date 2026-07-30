import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

const _kPrimario   = Color(0xFF1E3A5F);
const _kPrimario10 = Color(0x1A1E3A5F);
const _kTextoGris  = Color(0xFF64748B);
const _kTextoClaro = Color(0xFF94A3B8);
const _kFondo      = Color(0xFFE8EDF2);
const _kVerde      = Color(0xFF10B981);
const _kRojo       = Color(0xFFEF4444);
const _kAmbar      = Color(0xFFF59E0B);

({String mime, String ext}) _mimeDesdeExtension(String rutaOExtension) {
  final e = rutaOExtension.split('.').last.toLowerCase();
  if (e == 'jpg' || e == 'jpeg') return (mime: 'image/jpeg', ext: 'jpeg');
  return (mime: 'image/png', ext: 'png');
}

class FirmanteModel {
  final String docId;
  final String grado;
  final String nombre;
  final String cargo;
  final String storageUrl;
  final String storagePath;

  const FirmanteModel({
    required this.docId,
    required this.grado,
    required this.nombre,
    required this.cargo,
    required this.storageUrl,
    required this.storagePath,
  });

  bool get tieneImagen => storageUrl.isNotEmpty;
  bool get tieneDatos  => nombre.isNotEmpty;
  String get nombreCompleto => '$grado $nombre'.trim();

  factory FirmanteModel.vacio(String docId, String storageBasePath) =>
      FirmanteModel(
        docId: docId, grado: '', nombre: '', cargo: '',
        storageUrl: '', storagePath: storageBasePath,
      );

  factory FirmanteModel.fromMap(
      Map<String, dynamic> d, String docId, String storageBasePath) =>
      FirmanteModel(
        docId:       docId,
        grado:       d['grado']      ?? '',
        nombre:      d['nombre']     ?? '',
        cargo:       d['cargo']      ?? '',
        storageUrl:  d['storageUrl'] ?? '',
        storagePath: storageBasePath,
      );

  Map<String, dynamic> toMap() => {
    'grado':         grado,
    'nombre':        nombre,
    'cargo':         cargo,
    'storageUrl':    storageUrl,
    'actualizadoEn': FieldValue.serverTimestamp(),
  };

  FirmanteModel copyWith({
    String? grado, String? nombre, String? cargo, String? storageUrl,
  }) => FirmanteModel(
    docId:       docId,
    grado:       grado      ?? this.grado,
    nombre:      nombre     ?? this.nombre,
    cargo:       cargo      ?? this.cargo,
    storageUrl:  storageUrl ?? this.storageUrl,
    storagePath: storagePath,
  );
}

class ConfigurarFirmasScreen extends StatefulWidget {
  const ConfigurarFirmasScreen({super.key});

  @override
  State<ConfigurarFirmasScreen> createState() => _ConfigurarFirmasScreenState();
}

class _ConfigurarFirmasScreenState extends State<ConfigurarFirmasScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  FirmanteModel? _vicerrector;
  FirmanteModel? _directorInv;
  Map<String, FirmanteModel> _decanos    = {};
  Map<String, String>        _facultades = {};

  bool   _cargando = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    setState(() { _cargando = true; _errorMsg = null; });
    try {
      final db = FirebaseFirestore.instance;

      final vSnap = await db.collection('config_firmas').doc('vicerrector').get();
      _vicerrector = vSnap.exists
          ? FirmanteModel.fromMap(vSnap.data()!, 'vicerrector', 'firmas/vicerrector')
          : FirmanteModel.vacio('vicerrector', 'firmas/vicerrector');

      final dSnap = await db
          .collection('config_firmas')
          .doc('director_investigacion')
          .get();
      _directorInv = dSnap.exists
          ? FirmanteModel.fromMap(dSnap.data()!, 'director_investigacion',
              'firmas/director_investigacion')
          : FirmanteModel.vacio('director_investigacion',
              'firmas/director_investigacion');

      final decSnap = await db
          .collection('config_firmas')
          .doc('decanos')
          .collection('facultades')
          .get();
      _decanos = {
        for (final doc in decSnap.docs)
          doc.id: FirmanteModel.fromMap(
              doc.data(), doc.id, 'firmas/decanos/${doc.id}'),
      };

      final filialesSnap = await db.collection('filiales').get();
      final Map<String, String> facMap = {};

      for (final filialDoc in filialesSnap.docs) {
        final facSnap = await db
            .collection('filiales')
            .doc(filialDoc.id)
            .collection('facultades')
            .get();
        for (final facDoc in facSnap.docs) {
          final nombre = (facDoc.data()['nombre'] as String?)?.trim() ?? '';
          if (nombre.isNotEmpty) facMap[facDoc.id] = nombre;
        }
      }

      final sortedEntries = facMap.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      _facultades = Map.fromEntries(sortedEntries);

      for (final k in _decanos.keys) {
        if (!_facultades.containsKey(k)) _facultades[k] = k;
      }

      if (mounted) setState(() => _cargando = false);
    } catch (e) {
      if (mounted) setState(() { _cargando = false; _errorMsg = e.toString(); });
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: _cargando
                  ? const Center(
                      child: CircularProgressIndicator(color: _kPrimario))
                  : _errorMsg != null
                      ? _buildError()
                      : _buildCuerpo(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 8, 20),
    child: Row(children: [
      Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.draw_outlined, color: _kPrimario, size: 24),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Configurar Firmas',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Text(
            'Firmantes del certificado academico',
            style: TextStyle(fontSize: 11, color: Colors.white60),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ]),
      ),
      IconButton(
        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
        onPressed: _cargarTodo,
        tooltip: 'Recargar',
      ),
      IconButton(
        icon: const Icon(Icons.close, color: Colors.white, size: 24),
        onPressed: () => Navigator.pop(context),
        tooltip: 'Cerrar',
      ),
    ]),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: _kRojo, size: 52),
        const SizedBox(height: 12),
        Text(
          _errorMsg!,
          style: const TextStyle(color: _kTextoGris),
          textAlign: TextAlign.center,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _cargarTodo,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Reintentar'),
          style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimario, foregroundColor: Colors.white),
        ),
      ]),
    ),
  );

  Widget _buildCuerpo() => Column(children: [
    Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabs,
        labelColor: _kPrimario,
        unselectedLabelColor: _kTextoClaro,
        indicatorColor: _kPrimario,
        indicatorWeight: 3,
        labelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        tabs: const [
          Tab(icon: Icon(Icons.account_balance, size: 18), text: 'Globales'),
          Tab(icon: Icon(Icons.school_outlined,  size: 18), text: 'Decanos'),
          Tab(icon: Icon(Icons.info_outline,     size: 18), text: 'Guia'),
        ],
      ),
    ),
    Expanded(
      child: TabBarView(controller: _tabs, children: [
        _buildTabGlobales(),
        _buildTabDecanos(),
        _buildTabGuia(),
      ]),
    ),
  ]);

  Widget _buildTabGlobales() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _infoChip(Icons.public_rounded,
          'Estos firmantes aparecen en TODOS los certificados de cualquier filial y facultad.'),
      const SizedBox(height: 16),
      _TarjetaFirmante(
        etiqueta:          'Firma 1',
        titulo:            'Vicerrector',
        descripcion:       'Global - Aparece en toda la universidad',
        color:             const Color(0xFF7C3AED),
        icono:             Icons.verified_outlined,
        firmante:          _vicerrector!,
        gradosDisponibles: const ['Dr.', 'Dra.', 'Mg.', 'Lic.', 'Ing.'],
        onGuardado: (f) {
          setState(() => _vicerrector = f);
          _guardarFirmanteGlobal(f);
        },
      ),
      const SizedBox(height: 14),
      _TarjetaFirmante(
        etiqueta:          'Firma 3',
        titulo:            'Director General de Investigacion e Innovacion',
        descripcion:       'Global - Aparece en toda la universidad',
        color:             const Color(0xFF059669),
        icono:             Icons.science_outlined,
        firmante:          _directorInv!,
        gradosDisponibles: const ['Dr.', 'Dra.', 'Mg.', 'Lic.', 'Ing.'],
        onGuardado: (f) {
          setState(() => _directorInv = f);
          _guardarFirmanteGlobal(f);
        },
      ),
    ],
  );

  Widget _buildTabDecanos() {
    if (_facultades.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.domain_outlined, color: _kTextoClaro, size: 52),
            const SizedBox(height: 12),
            const Text(
              'No hay facultades registradas',
              style: TextStyle(color: _kTextoGris, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Primero crea facultades en "Gestion de Filiales"',
              style: TextStyle(color: _kTextoClaro, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoChip(Icons.info_outline,
            'El Decano es por FACULTAD y aplica a todas sus filiales. '
            'Ej: el Decano de FIA es el mismo para Juliaca, Lima y Tarapoto.'),
        const SizedBox(height: 16),
        ..._facultades.entries.map((entry) {
          final facId     = entry.key;
          final facNombre = entry.value;
          final firmante  = _decanos[facId] ??
              FirmanteModel.vacio(facId, 'firmas/decanos/$facId');
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _TarjetaFirmante(
              etiqueta:          'Firma 2',
              titulo:            'Decano - $facNombre',
              descripcion:       'Aplica a todas las filiales de $facNombre',
              color:             const Color(0xFF0D9488),
              icono:             Icons.school_outlined,
              firmante:          firmante,
              gradosDisponibles: const ['Dr.', 'Dra.', 'Mg.', 'Lic.', 'Ing.'],
              onGuardado: (f) {
                setState(() => _decanos[facId] = f);
                _guardarDecano(f, facId);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTabGuia() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _buildGuiaCard(
        '1. Prepara las imagenes de firma',
        Icons.image_outlined,
        const Color(0xFF7C3AED),
        [
          'Formatos aceptados: PNG, JPG o JPEG',
          'Fondo transparente (PNG) o fondo blanco/negro',
          'Tamano ideal: 400x150 px o similar proporcion horizontal',
          'Peso maximo: 2 MB por imagen',
          'Nombres sugeridos: vicerrector.png, decano_fia.jpg, etc.',
        ],
      ),
      const SizedBox(height: 12),
      _buildGuiaCard(
        '2. Estructura en Firebase Storage',
        Icons.folder_outlined,
        const Color(0xFF0369A1),
        [
          'firmas/vicerrector.png  (o .jpeg)',
          'firmas/director_investigacion.png  (o .jpeg)',
          'firmas/decanos/{facultadId}.png  (o .jpeg)',
          '',
          'No es necesario subir manualmente - la app lo hace al guardar.',
        ],
      ),
      const SizedBox(height: 12),
      _buildGuiaCard(
        '3. Reglas de seguridad en Storage',
        Icons.lock_outline,
        const Color(0xFF059669),
        [
          'Ve a Firebase Console > Storage > Rules',
          'Copia y pega estas reglas:',
          '',
          'match /firmas/{allPaths=**} {',
          '  allow read: if request.auth != null;',
          '  allow write: if request.auth != null',
          '    && firestore.exists(...superadmins/uid);',
          '}',
        ],
        esCode: true,
      ),
      const SizedBox(height: 12),
      _buildGuiaCard(
        '4. Estructura en Firestore',
        Icons.storage_outlined,
        const Color(0xFFD97706),
        [
          'config_firmas/',
          '  vicerrector          > grado, nombre, cargo, storageUrl',
          '  director_investigacion > grado, nombre, cargo, storageUrl',
          '  decanos/',
          '    facultades/',
          '      {facultadId}     > grado, nombre, cargo, storageUrl',
        ],
        esCode: true,
      ),
      const SizedBox(height: 12),
      _buildGuiaCard(
        '5. Como actualizar una firma',
        Icons.edit_outlined,
        const Color(0xFF7C3AED),
        [
          '1 Abre la tarjeta del firmante que quieres cambiar',
          '2 Toca el icono de edicion (lapiz)',
          '3 Actualiza nombre, grado y/o cargo',
          '4 Para cambiar la imagen toca "Cambiar imagen"',
          '5 Selecciona un archivo PNG, JPG o JPEG (max 2 MB)',
          '6 Toca GUARDAR - se sube a Storage y guarda en Firestore',
          '7 Los certificados nuevos usaran la firma actualizada',
        ],
      ),
    ],
  );

  Widget _buildGuiaCard(
    String titulo, IconData icono, Color color, List<String> lineas,
    {bool esCode = false}) =>
      Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icono, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            ...lineas.map((l) => l.isEmpty
                ? const SizedBox(height: 4)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!esCode) ...[
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 4, height: 4,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            l,
                            style: TextStyle(
                              fontSize: esCode ? 11 : 12,
                              color: esCode ? _kPrimario : _kTextoGris,
                              fontFamily: esCode ? 'monospace' : null,
                              height: 1.5,
                            ),
                            overflow: TextOverflow.visible,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  )),
          ]),
        ),
      );

  Future<void> _guardarFirmanteGlobal(FirmanteModel f) async {
    await FirebaseFirestore.instance
        .collection('config_firmas')
        .doc(f.docId)
        .set(f.toMap(), SetOptions(merge: true));
  }

  Future<void> _guardarDecano(FirmanteModel f, String facultadId) async {
    await FirebaseFirestore.instance
        .collection('config_firmas')
        .doc('decanos')
        .collection('facultades')
        .doc(facultadId)
        .set(f.toMap(), SetOptions(merge: true));
  }

  Widget _infoChip(IconData icono, String texto) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _kPrimario10,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kPrimario.withValues(alpha: 0.2)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icono, color: _kPrimario, size: 16),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          texto,
          style: const TextStyle(fontSize: 11.5, color: _kPrimario, height: 1.5),
        ),
      ),
    ]),
  );
}

class _TarjetaFirmante extends StatefulWidget {
  final String   etiqueta;
  final String   titulo;
  final String   descripcion;
  final Color    color;
  final IconData icono;
  final FirmanteModel              firmante;
  final List<String>               gradosDisponibles;
  final ValueChanged<FirmanteModel> onGuardado;

  const _TarjetaFirmante({
    required this.etiqueta,
    required this.titulo,
    required this.descripcion,
    required this.color,
    required this.icono,
    required this.firmante,
    required this.gradosDisponibles,
    required this.onGuardado,
  });

  @override
  State<_TarjetaFirmante> createState() => _TarjetaFirmanteState();
}

class _TarjetaFirmanteState extends State<_TarjetaFirmante> {
  bool _editando    = false;
  bool _guardando   = false;
  bool _subiendoImg = false;

  late TextEditingController _nombreCtrl;
  late TextEditingController _cargoCtrl;
  late String _gradoSeleccionado;
  late FirmanteModel _firmanteLocal;

  File?   _imgLocal;
  String  _imgExt   = 'png';
  double  _progreso = 0;

  StreamSubscription<TaskSnapshot>? _uploadSubscription;

  @override
  void initState() {
    super.initState();
    _firmanteLocal     = widget.firmante;
    _nombreCtrl        = TextEditingController(text: widget.firmante.nombre);
    _cargoCtrl         = TextEditingController(text: widget.firmante.cargo);
    _gradoSeleccionado = widget.firmante.grado.isNotEmpty
        ? widget.firmante.grado
        : widget.gradosDisponibles.first;
  }

  @override
  void dispose() {
    _uploadSubscription?.cancel();
    _nombreCtrl.dispose();
    _cargoCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirImagen() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final info = _mimeDesdeExtension(path);

    final file      = File(path);
    final sizeBytes = await file.length();
    if (sizeBytes > 2 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La imagen supera 2 MB. Elige una mas pequena.'),
          backgroundColor: _kAmbar,
        ));
      }
      return;
    }

    setState(() {
      _imgLocal = file;
      _imgExt   = info.ext;
    });
  }

  Future<String?> _subirImagen() async {
    if (_imgLocal == null) return _firmanteLocal.storageUrl;

    final info        = _mimeDesdeExtension(_imgExt);
    final storagePath = '${_firmanteLocal.storagePath}.$_imgExt';

    setState(() { _subiendoImg = true; _progreso = 0; });
    try {
      final ref  = FirebaseStorage.instance.ref(storagePath);
      final task = ref.putFile(
        _imgLocal!,
        SettableMetadata(contentType: info.mime),
      );

      _uploadSubscription = task.snapshotEvents.listen((s) {
        final p = s.bytesTransferred / (s.totalBytes == 0 ? 1 : s.totalBytes);
        if (mounted) setState(() => _progreso = p);
      });

      await task;
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al subir imagen: $e'),
          backgroundColor: _kRojo,
        ));
      }
      return null;
    } finally {
      _uploadSubscription?.cancel();
      _uploadSubscription = null;
      if (mounted) setState(() => _subiendoImg = false);
    }
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('El nombre no puede estar vacio'),
        backgroundColor: _kAmbar,
      ));
      return;
    }

    setState(() => _guardando = true);

    final url = await _subirImagen();
    if (url == null && _imgLocal != null) {
      setState(() => _guardando = false);
      return;
    }

    final actualizado = _firmanteLocal.copyWith(
      grado:      _gradoSeleccionado,
      nombre:     _nombreCtrl.text.trim(),
      cargo:      _cargoCtrl.text.trim(),
      storageUrl: url ?? _firmanteLocal.storageUrl,
    );

    try {
      widget.onGuardado(actualizado);
      setState(() {
        _firmanteLocal = actualizado;
        _imgLocal      = null;
        _imgExt        = 'png';
        _editando      = false;
        _guardando     = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${actualizado.nombreCompleto} guardado'),
          backgroundColor: _kVerde,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completo = _firmanteLocal.tieneDatos && _firmanteLocal.tieneImagen;
    final parcial  = _firmanteLocal.tieneDatos && !_firmanteLocal.tieneImagen;

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: completo
              ? _kVerde.withValues(alpha: 0.4)
              : parcial
                  ? _kAmbar.withValues(alpha: 0.5)
                  : _kRojo.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(widget.icono, color: widget.color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: widget.color,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        widget.etiqueta,
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.titulo,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _kPrimario),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    widget.descripcion,
                    style: const TextStyle(fontSize: 10, color: _kTextoClaro),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _buildEstadoBadge(completo, parcial),
            const SizedBox(width: 4),
            if (!_editando)
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 20),
                color: _kPrimario,
                onPressed: () => setState(() => _editando = true),
                tooltip: 'Editar',
              )
            else
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: _kTextoGris,
                onPressed: () {
                  setState(() {
                    _editando  = false;
                    _imgLocal  = null;
                    _imgExt    = 'png';
                    _nombreCtrl.text = _firmanteLocal.nombre;
                    _cargoCtrl.text  = _firmanteLocal.cargo;
                    _gradoSeleccionado = _firmanteLocal.grado.isNotEmpty
                        ? _firmanteLocal.grado
                        : widget.gradosDisponibles.first;
                  });
                },
                tooltip: 'Cancelar',
              ),
          ]),

          const SizedBox(height: 12),
          _editando ? _buildFormulario() : _buildVista(),

          if (_subiendoImg) ...[
            const SizedBox(height: 10),
            Row(children: [
              const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _kPrimario),
              ),
              const SizedBox(width: 8),
              Expanded(child: LinearProgressIndicator(
                value: _progreso,
                color: _kPrimario,
                backgroundColor: _kPrimario10,
              )),
              const SizedBox(width: 8),
              Text('${(_progreso * 100).toInt()}%',
                  style: const TextStyle(fontSize: 10, color: _kTextoGris)),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _buildVista() {
    if (!_firmanteLocal.tieneDatos) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(Icons.add_circle_outline, color: _kTextoClaro, size: 20),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Toca el lapiz para configurar este firmante',
              style: TextStyle(
                  fontSize: 12,
                  color: _kTextoClaro,
                  fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      );
    }

    return Row(children: [
      _buildPreviewFirma(),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _firmanteLocal.nombreCompleto,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _kPrimario),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            _firmanteLocal.cargo,
            style: const TextStyle(fontSize: 11, color: _kTextoGris),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!_firmanteLocal.tieneImagen) ...[
            const SizedBox(height: 6),
            const Row(children: [
              Icon(Icons.warning_amber_rounded, color: _kAmbar, size: 14),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Sin imagen de firma',
                  style: TextStyle(fontSize: 10, color: _kAmbar),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ],
        ]),
      ),
    ]);
  }

  Widget _buildPreviewFirma() {
    final tieneImg = _firmanteLocal.tieneImagen;
    return Container(
      width: 90, height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: tieneImg
          ? ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.network(
                _firmanteLocal.storageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: _kTextoClaro, size: 22),
              ),
            )
          : const Icon(Icons.draw_outlined, color: _kTextoClaro, size: 24),
    );
  }

  Widget _buildFormulario() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Grado academico',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kPrimario),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8, runSpacing: 6,
          children: widget.gradosDisponibles
              .map((g) => ChoiceChip(
                    label: Text(g,
                        style: TextStyle(
                            fontSize: 11,
                            color: _gradoSeleccionado == g
                                ? Colors.white
                                : _kPrimario)),
                    selected: _gradoSeleccionado == g,
                    selectedColor: widget.color,
                    backgroundColor: Colors.grey.shade100,
                    onSelected: (_) =>
                        setState(() => _gradoSeleccionado = g),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),

        _campoTexto(
          controller: _nombreCtrl,
          label: 'Nombre completo (sin grado)',
          hint: 'Ej: Carlos Coaquira Tuco',
          icono: Icons.person_outline,
        ),
        const SizedBox(height: 10),

        _campoTexto(
          controller: _cargoCtrl,
          label: 'Cargo / titulo del puesto',
          hint: 'Ej: VICERRECTOR DE INVESTIGACION',
          icono: Icons.badge_outlined,
          maxLines: 2,
        ),
        const SizedBox(height: 14),

        const Text(
          'Imagen de la firma',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kPrimario),
        ),
        const SizedBox(height: 8),

        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 100, height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _imgLocal != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.file(_imgLocal!, fit: BoxFit.contain))
                : _firmanteLocal.tieneImagen
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.network(
                            _firmanteLocal.storageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                color: _kTextoClaro, size: 22)))
                    : const Icon(Icons.draw_outlined,
                        color: _kTextoClaro, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              OutlinedButton.icon(
                onPressed: _guardando ? null : _elegirImagen,
                icon: const Icon(Icons.upload_file_outlined, size: 16),
                label: Text(_imgLocal != null
                    ? 'Imagen seleccionada'
                    : _firmanteLocal.tieneImagen
                        ? 'Cambiar imagen'
                        : 'Subir imagen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.color,
                  side: BorderSide(color: widget.color),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'PNG, JPG o JPEG - max 2 MB',
                style: TextStyle(fontSize: 9, color: _kTextoClaro),
                maxLines: 2,
                overflow: TextOverflow.visible,
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: _guardando ? null : _guardar,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              foregroundColor: Colors.white,
              disabledBackgroundColor: widget.color.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _guardando
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Guardando...',
                          style: TextStyle(fontSize: 14)),
                    ])
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('GUARDAR FIRMANTE',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                    ]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );

  Widget _buildEstadoBadge(bool completo, bool parcial) {
    final color = completo ? _kVerde : parcial ? _kAmbar : _kRojo;
    final icono = completo
        ? Icons.check_circle
        : parcial
            ? Icons.warning_amber
            : Icons.error_outline;
    final texto =
        completo ? 'Listo' : parcial ? 'Sin imagen' : 'Pendiente';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, color: color, size: 12),
        const SizedBox(width: 4),
        Text(
          texto,
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold),
        ),
      ]),
    );
  }

  Widget _campoTexto({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icono,
    int maxLines = 1,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13, color: _kPrimario),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle:
              const TextStyle(fontSize: 11, color: _kTextoGris),
          hintStyle:
              const TextStyle(fontSize: 11, color: _kTextoClaro),
          prefixIcon: Icon(icono, size: 18, color: _kTextoClaro),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kPrimario, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
        ),
      );
}