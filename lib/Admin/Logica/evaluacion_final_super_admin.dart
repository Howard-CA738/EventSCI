import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/shared/logica/filiales_service.dart';
import '/roles/admin_carrera/datos/eval_final_config.dart';
import '/roles/admin_carrera/datos/nota_final_item.dart';
import '/roles/admin_carrera/pantallas/widgets/boton_exportar_evaluacion_final.dart';

class _C {
  static const navy    = Color(0xFF0F2342);
  static const accent  = Color(0xFF3B82F6);
  static const green   = Color(0xFF059669);
  static const orange  = Color(0xFFD97706);
  static const orangeL = Color(0xFFFEF3C7);
  static const red     = Color(0xFFDC2626);
  static const redL    = Color(0xFFFEE2E2);
  static const purple  = Color(0xFF7C3AED);
  static const purpleL = Color(0xFFEDE9FE);
  static const teal    = Color(0xFF0F9D58);
  static const tealL   = Color(0xFFD7F5E6);
  static const surface = Color(0xFFF8FAFC);
  static const card    = Colors.white;
  static const border  = Color(0xFFE2E8F0);
  static const txt1    = Color(0xFF0F172A);
  static const txt2    = Color(0xFF475569);
  static const txt3    = Color(0xFF94A3B8);
}




class _Config {
  double pctAsistNoSel;
  double pctDocenteNoSel;
  bool   incluirDocenteNoSel;
  String modalidad;
  double pctAsistSel;
  double pctJuradoSel;
  double pctAsistSelMixta;
  double pctJuradoSelMixta;
  double pctDocenteSelMixta;

  _Config({
    this.pctAsistNoSel       = 100,
    this.pctDocenteNoSel     = 0,
    this.incluirDocenteNoSel = false,
    this.modalidad           = 'jurado',
    this.pctAsistSel         = 40,
    this.pctJuradoSel        = 60,
    this.pctAsistSelMixta    = 30,
    this.pctJuradoSelMixta   = 50,
    this.pctDocenteSelMixta  = 20,
  });

  factory _Config.fromMap(Map<String, dynamic> m) => _Config(
    pctAsistNoSel       : ((m['pctAsistNoSel']       ?? 100) as num).toDouble(),
    pctDocenteNoSel     : ((m['pctDocenteNoSel']     ?? 0) as num).toDouble(),
    incluirDocenteNoSel : (m['incluirDocenteNoSel'] as bool?) ?? false,
    modalidad           : (m['modalidad'] as String?) ?? 'jurado',
    pctAsistSel         : ((m['pctAsistSel']         ?? 40) as num).toDouble(),
    pctJuradoSel        : ((m['pctJuradoSel']        ?? 60) as num).toDouble(),
    pctAsistSelMixta    : ((m['pctAsistSelMixta']    ?? 30) as num).toDouble(),
    pctJuradoSelMixta   : ((m['pctJuradoSelMixta']   ?? 50) as num).toDouble(),
    pctDocenteSelMixta  : ((m['pctDocenteSelMixta']  ?? 20) as num).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'pctAsistNoSel'       : pctAsistNoSel,
    'pctDocenteNoSel'     : pctDocenteNoSel,
    'incluirDocenteNoSel' : incluirDocenteNoSel,
    'modalidad'           : modalidad,
    'pctAsistSel'         : pctAsistSel,
    'pctJuradoSel'        : pctJuradoSel,
    'pctAsistSelMixta'    : pctAsistSelMixta,
    'pctJuradoSelMixta'   : pctJuradoSelMixta,
    'pctDocenteSelMixta'  : pctDocenteSelMixta,
    'updatedAt'           : FieldValue.serverTimestamp(),
  };
}

class _NotaFinal {
  final String studentId;
  final String nombre;
  final String codigo;
  final String ciclo;
  final String grupo;
  final bool   seleccionado;
  final String proyectoCodigo;
  final double notaAsist;
  final double notaJurado;
  final double notaDocente;
  final double notaFinal;

  const _NotaFinal({
    required this.studentId,
    required this.nombre,
    required this.codigo,
    required this.ciclo,
    required this.grupo,
    required this.seleccionado,
    required this.proyectoCodigo,
    required this.notaAsist,
    required this.notaJurado,
    required this.notaDocente,
    required this.notaFinal,
  });
}

class _IntegranteRef {
  final String codigo;
  final String proyectoCodigo;
  final String proyectoDocId;
  const _IntegranteRef({
    required this.codigo,
    required this.proyectoCodigo,
    required this.proyectoDocId,
  });
}




class EvaluacionFinalSuperAdminScreen extends StatefulWidget {
  const EvaluacionFinalSuperAdminScreen({super.key});

  @override
  State<EvaluacionFinalSuperAdminScreen> createState() =>
      _EvaluacionFinalSuperAdminScreenState();
}

class _EvaluacionFinalSuperAdminScreenState
    extends State<EvaluacionFinalSuperAdminScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FilialesService _filialesService = FilialesService();


  Map<String, dynamic> _estructura = {};
  bool _isLoadingEstructura = true;


  String? _filialId;
  String? _filialNombre;
  String? _facultad;
  String? _carreraId;
  String? _carreraNombre;

  List<String> _facultadesDisp = [];
  List<Map<String, dynamic>> _carrerasDisp = [];


  List<Map<String, dynamic>> _eventos = [];
  String? _eventoId;
  String? _eventoNombre;
  bool _isLoadingEventos = false;


  _Config _config = _Config();
  bool _configCargada = false;


  List<_NotaFinal> _notas = [];
  bool _isCalculando = false;
  bool _calculoDone  = false;


  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQ = '';
  bool   _ordenDesc = true;
  String _filtro = 'todos';


  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  String _docIdConfig(String eventoId) =>
      '${_filialId}_${_facultad}_${_carreraId}_$eventoId'
          .replaceAll(' ', '_');

  String _docIdSellos(String eventoId) =>
      '${_filialId}_${_facultad}_${_carreraId}_$eventoId'
          .replaceAll(' ', '_')
          .replaceAll('/', '_')
          .replaceAll('.', '_');

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadEstructura();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }




  Future<void> _loadEstructura() async {
    setState(() => _isLoadingEstructura = true);
    try {
      await _filialesService.inicializarSiEsNecesario();
      _estructura = await _filialesService.getEstructuraCompleta();
    } catch (e) {
      _snack('Error al cargar filiales: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingEstructura = false);
    }
  }


  void _resetResultados() {
    _eventos      = [];
    _eventoId     = null;
    _eventoNombre = null;
    _notas        = [];
    _calculoDone  = false;
    _configCargada = false;
  }

  void _onFilialChanged(String? filial) {
    setState(() {
      _filialId      = filial;
      _filialNombre  =
          filial != null ? _filialesService.getNombreFilial(filial) : null;
      _facultad      = null;
      _carreraId     = null;
      _carreraNombre = null;
      _facultadesDisp = [];
      _carrerasDisp   = [];
      _resetResultados();

      if (filial != null && _estructura.containsKey(filial)) {
        final facultades =
            _estructura[filial]['facultades'] as Map<String, dynamic>?;
        if (facultades != null) {
          _facultadesDisp = facultades.keys.toList();
        }
      }
    });
  }

  void _onFacultadChanged(String? facultad) {
    setState(() {
      _facultad      = facultad;
      _carreraId     = null;
      _carreraNombre = null;
      _carrerasDisp  = [];
      _resetResultados();

      if (_filialId != null &&
          facultad != null &&
          _estructura.containsKey(_filialId)) {
        final facultades =
            _estructura[_filialId!]['facultades'] as Map<String, dynamic>?;
        if (facultades != null && facultades.containsKey(facultad)) {
          _carrerasDisp = List<Map<String, dynamic>>.from(
              facultades[facultad]['carreras'] ?? []);
        }
      }
    });
  }

  void _onCarreraChanged(String? nombreCarrera) {
    if (nombreCarrera == null) return;
    final carreraData = _carrerasDisp.firstWhere(
      (c) => c['nombre'] == nombreCarrera,
      orElse: () => {},
    );
    setState(() {
      _carreraNombre = nombreCarrera;
      _carreraId =
          carreraData.isNotEmpty ? carreraData['id'] as String? : null;
      _resetResultados();
    });
    if (_carreraId != null) {
      unawaited(_cargarEventos());
    }
  }

  bool get _seleccionCompleta =>
      _filialId != null &&
      _facultad != null &&
      _carreraNombre != null &&
      _carreraId != null;




  Future<void> _cargarEventos() async {
    setState(() => _isLoadingEventos = true);
    try {
      final snap = await _firestore
          .collection('events')
          .where('filialId',  isEqualTo: _filialId)
          .where('facultad',  isEqualTo: _facultad)
          .where('carreraId', isEqualTo: _carreraId)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _eventos = snap.docs.map((d) => {
          'id':   d.id,
          'name': d.data()['name'] ?? 'Sin nombre',
        }).toList();
      });
    } catch (e) {
      _snack('Error al cargar eventos: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingEventos = false);
    }
  }




  Future<void> _cargarConfig(String eventoId) async {
    try {
      final doc = await _firestore
          .collection('evaluacion_final_config')
          .doc(_docIdConfig(eventoId))
          .get();

      setState(() {
        _config        = doc.exists ? _Config.fromMap(doc.data()!) : _Config();
        _configCargada = true;
      });
    } catch (e) {
      setState(() {
        _config        = _Config();
        _configCargada = true;
      });
    }
  }

  Future<void> _guardarConfig() async {
    if (_eventoId == null) return;

    if (_config.incluirDocenteNoSel) {
      final sum = _config.pctAsistNoSel + _config.pctDocenteNoSel;
      if ((sum - 100).abs() > 0.5) {
        _snack('No seleccionados: los porcentajes deben sumar 100% (actual: ${sum.toStringAsFixed(1)}%)', isError: true);
        return;
      }
    }

    if (_config.modalidad == 'jurado') {
      final sum = _config.pctAsistSel + _config.pctJuradoSel;
      if ((sum - 100).abs() > 0.5) {
        _snack('Seleccionados (jurado): los porcentajes deben sumar 100% (actual: ${sum.toStringAsFixed(1)}%)', isError: true);
        return;
      }
    } else {
      final sum = _config.pctAsistSelMixta + _config.pctJuradoSelMixta + _config.pctDocenteSelMixta;
      if ((sum - 100).abs() > 0.5) {
        _snack('Seleccionados (mixta): los porcentajes deben sumar 100% (actual: ${sum.toStringAsFixed(1)}%)', isError: true);
        return;
      }
    }

    try {
      await _firestore
          .collection('evaluacion_final_config')
          .doc(_docIdConfig(_eventoId!))
          .set(_config.toMap(), SetOptions(merge: true));
      _snack('Configuración guardada ✓');
    } catch (e) {
      _snack('Error al guardar config: $e', isError: true);
    }
  }




  Future<void> _calcularNotas() async {
    final eventoId = _eventoId;
    if (eventoId == null || !_seleccionCompleta) return;
    setState(() {
      _isCalculando = true;
      _notas        = [];
      _calculoDone  = false;
    });

    try {

      final candidatos = [
        '${_filialNombre}_$_carreraNombre',
        '${_filialNombre}_$_carreraId',
        '${_filialId}_$_carreraNombre',
        '${_filialId}_$_carreraId',
      ];

      List<QueryDocumentSnapshot<Map<String, dynamic>>> estudianteDocs = [];
      for (final path in candidatos) {
        final snap = await _firestore
            .collection('users')
            .doc(path)
            .collection('students')
            .get();
        if (snap.docs.isNotEmpty) {
          estudianteDocs = snap.docs;
          break;
        }
      }

      if (estudianteDocs.isEmpty) {
        _snack('No se encontraron estudiantes para esta carrera', isError: true);
        setState(() => _isCalculando = false);
        return;
      }


      final List<_IntegranteRef> integrantesProyecto = [];

      final proyectosSnap = await _firestore
          .collection('events')
          .doc(eventoId)
          .collection('proyectos')
          .get();

      for (final pDoc in proyectosSnap.docs) {
        final pData = pDoc.data();
        final codProyecto = pData['Código']?.toString() ?? '';
        final integrantesRaw = pData['Integrantes'] ?? pData['integrantes'];
        List<String> integrantes = [];
        if (integrantesRaw is List) {
          integrantes = integrantesRaw.map((e) => e.toString()).toList();
        } else if (integrantesRaw is String && integrantesRaw.isNotEmpty) {
          integrantes = integrantesRaw
              .split(RegExp(r'[,\n]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
        for (final cod in integrantes) {
          final codNorm = cod.trim();
          if (codNorm.isEmpty) continue;
          integrantesProyecto.add(_IntegranteRef(
            codigo: codNorm,
            proyectoCodigo: codProyecto,
            proyectoDocId: pDoc.id,
          ));
        }
      }


      final Map<String, double> promedioJuradoPorProyecto = {};
      final proyectoIdsUnicos =
          integrantesProyecto.map((e) => e.proyectoDocId).toSet();

      final juradoEntries = await Future.wait(
        proyectoIdsUnicos.map((pDocId) async {
          final evalSnap = await _firestore
              .collection('events')
              .doc(eventoId)
              .collection('proyectos')
              .doc(pDocId)
              .collection('evaluaciones')
              .where('evaluada', isEqualTo: true)
              .get();

          if (evalSnap.docs.isEmpty) return MapEntry(pDocId, 0.0);

          double sumNorm = 0;
          int    count   = 0;
          for (final eDoc in evalSnap.docs) {
            final eData = eDoc.data();
            final notaTotal     = ((eData['notaTotal']     ?? 0) as num).toDouble();
            final puntajeMaximo = ((eData['puntajeMaximo'] ?? 20) as num).toDouble();
            final base = puntajeMaximo > 0 ? puntajeMaximo : 20;
            sumNorm += (notaTotal / base * 20).clamp(0.0, 20.0);
            count++;
          }
          return MapEntry(pDocId, count > 0 ? sumNorm / count : 0.0);
        }),
      );
      promedioJuradoPorProyecto.addEntries(juradoEntries);


      int metaSellos = 0;
      try {
        final configSellos = await _firestore
            .collection('sellos_asistencia')
            .doc(_docIdSellos(eventoId))
            .get();
        if (configSellos.exists) {
          final meta = configSellos.data()!['meta'];
          if (meta is int)    metaSellos = meta;
          if (meta is double) metaSellos = meta.toInt();
        }
      } catch (_) {}


      final Map<String, double> notaDocentePorCodigo = {};
      try {
        final docentesSnap = await _firestore
            .collection('events')
            .doc(eventoId)
            .collection('notas_docente')
            .get();
        for (final d in docentesSnap.docs) {
          final n = ((d.data()['nota'] ?? 0) as num).toDouble();
          notaDocentePorCodigo[d.id.trim()] = n.clamp(0.0, 20.0);
        }
      } catch (_) {}


      final Map<String, int> sellosPersonalesPorStudent = {};
      if (metaSellos > 0) {
        try {
          final asistPersonalesSnap = await _firestore
              .collection('events')
              .doc(eventoId)
              .collection('asistencias_personales')
              .get();

          final registrosSnaps = await Future.wait(
            asistPersonalesSnap.docs.map((d) => _firestore
                .collection('events')
                .doc(eventoId)
                .collection('asistencias_personales')
                .doc(d.id)
                .collection('registros')
                .get()),
          );

          for (final rs in registrosSnaps) {
            for (final reg in rs.docs) {
              sellosPersonalesPorStudent[reg.id] =
                  (sellosPersonalesPorStudent[reg.id] ?? 0) + 1;
            }
          }
        } catch (_) {}
      }


      final List<Future<_NotaFinal>> futuros =
          estudianteDocs.map((sDoc) async {
        final sData = sDoc.data();
        final codigoUniv = sData['codigoUniversitario']?.toString() ?? '';


        double notaAsist = 0;
        if (metaSellos > 0) {
          try {
            final scansCount = await _firestore
                .collection('events')
                .doc(eventoId)
                .collection('asistencias')
                .doc(sDoc.id)
                .collection('scans')
                .count()
                .get();
            final sellosProyectos = scansCount.count ?? 0;
            final sellosPersonales =
                sellosPersonalesPorStudent[sDoc.id] ?? 0;
            final totalSellos = sellosProyectos + sellosPersonales;
            notaAsist =
                (totalSellos / metaSellos * 20).clamp(0.0, 20.0);
          } catch (_) {}
        }


        final codAlumno = codigoUniv.trim();
        String proyectoDocId  = '';
        String proyectoCodigo = '';
        if (codAlumno.isNotEmpty) {
          for (final ref in integrantesProyecto) {
            if (ref.codigo == codAlumno) {
              proyectoDocId  = ref.proyectoDocId;
              proyectoCodigo = ref.proyectoCodigo;
              break;
            }
          }
        }
        final seleccionado = proyectoDocId.isNotEmpty;

        final notaJurado = seleccionado
            ? (promedioJuradoPorProyecto[proyectoDocId] ?? 0)
            : 0.0;
        final notaDocente = notaDocentePorCodigo[codigoUniv.trim()] ?? 0.0;

        double notaFinal;
        if (!seleccionado) {
          if (_config.incluirDocenteNoSel) {
            notaFinal =
                (notaAsist   * _config.pctAsistNoSel   / 100) +
                (notaDocente * _config.pctDocenteNoSel / 100);
          } else {
            notaFinal = notaAsist;
          }
        } else {
          if (_config.modalidad == 'jurado') {
            notaFinal =
                (notaAsist  * _config.pctAsistSel  / 100) +
                (notaJurado * _config.pctJuradoSel / 100);
          } else {
            notaFinal =
                (notaAsist   * _config.pctAsistSelMixta   / 100) +
                (notaJurado  * _config.pctJuradoSelMixta  / 100) +
                (notaDocente * _config.pctDocenteSelMixta / 100);
          }
        }
        notaFinal = notaFinal.clamp(0.0, 20.0);

        return _NotaFinal(
          studentId:      sDoc.id,
          nombre:         sData['name']?.toString()  ?? 'Sin nombre',
          codigo:         codigoUniv,
          ciclo:          sData['ciclo']?.toString() ?? '',
          grupo:          sData['grupo']?.toString() ?? '',
          seleccionado:   seleccionado,
          proyectoCodigo: proyectoCodigo,
          notaAsist:      notaAsist,
          notaJurado:     notaJurado,
          notaDocente:    notaDocente,
          notaFinal:      notaFinal,
        );
      }).toList();

      final resultados = await Future.wait(futuros);
      resultados.sort((a, b) => b.notaFinal.compareTo(a.notaFinal));

      setState(() {
        _notas       = resultados;
        _calculoDone = true;
      });
      _animCtrl.reset();
      unawaited(_animCtrl.forward());
    } catch (e, st) {
      debugPrint('❌ Error calculando notas: $e\n$st');
      _snack('Error al calcular: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isCalculando = false);
    }
  }




  List<_NotaFinal> get _notasFiltradas {
    final lista = _notas.where((n) {
      if (_filtro == 'seleccionados')    return n.seleccionado;
      if (_filtro == 'no_seleccionados') return !n.seleccionado;
      return true;
    }).where((n) {
      if (_searchQ.isEmpty) return true;
      final q = _searchQ.toLowerCase();
      return n.nombre.toLowerCase().contains(q) ||
             n.codigo.toLowerCase().contains(q) ||
             n.proyectoCodigo.toLowerCase().contains(q);
    }).toList();

    lista.sort((a, b) {
      final c = a.notaFinal.compareTo(b.notaFinal);
      return _ordenDesc ? -c : c;
    });
    return lista;
  }

  Color _colorNota(double n) {
    if (n >= 17) return _C.green;
    if (n >= 14) return _C.accent;
    if (n >= 11) return _C.orange;
    if (n >= 7)  return const Color(0xFFEA580C);
    return _C.red;
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _C.red : _C.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.navy,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.only(
                    topLeft:  Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: _isLoadingEstructura
                    ? const Center(child: CircularProgressIndicator(color: _C.navy))
                    : _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Evaluación Final',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3)),
                Text(
                  _carreraNombre ?? 'Super Admin',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.65)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_eventoId != null)
            GestureDetector(
              onTap: _abrirConfig,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: _C.purple.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _C.purple.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded,
                        color: Colors.white, size: 17),
                    SizedBox(width: 5),
                    Text('Config',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: _buildSelectorDestino(),
        ),
        if (_seleccionCompleta)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: _buildSelectorEvento(),
          ),
        Expanded(
          child: !_seleccionCompleta
              ? _buildEstadoSinSeleccion()
              : _isCalculando
                  ? _buildCalculando()
                  : !_calculoDone
                      ? _buildEstadoInicial()
                      : _buildResultados(),
        ),
      ],
    );
  }


  Widget _buildSelectorDestino() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _C.navy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_tree_rounded,
                    color: _C.navy, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Filial · Facultad · Carrera',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _C.navy)),
            ],
          ),
          const SizedBox(height: 12),
          _buildDropdown<String>(
            value: _filialId,
            label: 'Filial (Sede)',
            icon: Icons.location_city,
            items: _estructura.keys.map((k) {
              return DropdownMenuItem<String>(
                value: k,
                child: Text(_filialesService.getNombreFilial(k),
                    overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: _onFilialChanged,
          ),
          if (_filialId != null) ...[
            const SizedBox(height: 12),
            _buildDropdown<String>(
              value: _facultad,
              label: 'Facultad',
              icon: Icons.business,
              items: _facultadesDisp.map((f) {
                return DropdownMenuItem<String>(
                  value: f,
                  child: Text(f, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: _onFacultadChanged,
            ),
          ],
          if (_facultad != null) ...[
            const SizedBox(height: 12),
            _buildDropdown<String>(
              value: _carreraNombre,
              label: 'Carrera',
              icon: Icons.school,
              items: _carrerasDisp.map((c) {
                return DropdownMenuItem<String>(
                  value: c['nombre'] as String,
                  child: Text(c['nombre'] as String,
                      overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: _onCarreraChanged,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?)? onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: 320,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _C.navy),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.navy, width: 1.5),
        ),
        filled: true,
        fillColor: _C.surface,
        labelStyle: const TextStyle(color: _C.txt2),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items,
      onChanged: onChanged,
    );
  }


  Widget _buildSelectorEvento() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _C.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_rounded,
                    color: _C.teal, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Seleccionar evento',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _C.navy)),
              const Spacer(),
              if (_isLoadingEventos)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _C.teal),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isLoadingEventos && _eventos.isEmpty)
            _infoBox('No hay eventos disponibles para esta carrera.',
                _C.orange, Icons.event_busy_rounded)
          else
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _eventoId != null ? _C.teal : _C.border,
                  width: 1.5,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _eventoId,
                  isExpanded: true,
                  hint: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Elige un evento...',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13)),
                  ),
                  icon: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(Icons.arrow_drop_down,
                        color: Colors.grey.shade600),
                  ),
                  items: _eventos
                      .map((e) => DropdownMenuItem<String?>(
                            value: e['id'] as String,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.event,
                                      size: 18, color: _C.teal),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(e['name'],
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: _C.navy,
                                            fontWeight:
                                                FontWeight.w600),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final nombre = _eventos.firstWhere(
                        (e) => e['id'] == v)['name'] as String;
                    setState(() {
                      _eventoId      = v;
                      _eventoNombre  = nombre;
                      _notas         = [];
                      _calculoDone   = false;
                      _configCargada = false;
                    });
                    unawaited(_cargarConfig(v));
                  },
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ),
          if (_eventoId != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCalculando ? null : _calcularNotas,
                icon: const Icon(Icons.calculate_rounded, size: 20),
                label: Text(
                  _calculoDone ? 'Recalcular notas' : 'Calcular notas finales',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildEstadoSinSeleccion() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_tree_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const Text(
              'Selecciona filial, facultad y carrera',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _C.navy),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Elige el destino para ver sus eventos y calcular las notas finales',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoInicial() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calculate_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              _eventoId == null
                  ? 'Selecciona un evento'
                  : 'Presiona "Calcular notas finales"',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _C.navy),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _eventoId == null
                  ? 'Elige un evento para comenzar el cálculo'
                  : 'Se ponderarán asistencias, jurados y docentes\nsegún la configuración activa',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (_eventoId != null && _configCargada) ...[
              const SizedBox(height: 20),
              _buildResumenConfig(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalculando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _C.teal),
          SizedBox(height: 16),
          Text('Calculando notas finales...',
              style: TextStyle(color: _C.txt2, fontSize: 14)),
          SizedBox(height: 6),
          Text('Esto puede tomar unos segundos',
              style: TextStyle(color: _C.txt3, fontSize: 12)),
        ],
      ),
    );
  }


  Widget _buildResultados() {
    final filtradas = _notasFiltradas;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                _buildStatsCard(),
                const SizedBox(height: 12),
                _buildFiltrosYBusqueda(),
                const SizedBox(height: 12),
                _buildBotonExportar(),
              ],
            ),
          ),
          Expanded(
            child: filtradas.isEmpty
                ? Center(
                    child: Text('Sin resultados',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 14)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: filtradas.length,
                    itemBuilder: (ctx, i) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 200 + (i * 35)),
                        curve: Curves.easeOut,
                        builder: (c, v, _) => Transform.translate(
                          offset: Offset(0, 14 * (1 - v)),
                          child: Opacity(
                              opacity: v,
                              child: _buildStudentCard(filtradas[i], i)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_notas.isEmpty) return const SizedBox.shrink();

    final sel       = _notas.where((n) => n.seleccionado).length;
    final noSel     = _notas.length - sel;
    final aprobados = _notas.where((n) => n.notaFinal >= 11).length;
    final prom      = _notas.map((n) => n.notaFinal).reduce((a, b) => a + b) /
        _notas.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.navy, _C.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _C.navy.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _eventoNombre ?? '',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statItem('Total',      '${_notas.length}', Colors.white),
              _vDivider(),
              _statItem('Seleccion.', '$sel',   const Color(0xFF86EFAC)),
              _vDivider(),
              _statItem('Sin exp.',   '$noSel', Colors.amber),
              _vDivider(),
              _statItem('Aprobados',  '$aprobados', const Color(0xFF6EE7B7)),
              _vDivider(),
              _statItem('Promedio',   prom.toStringAsFixed(1), const Color(0xFF93C5FD)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String val, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(val,
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 32,
        color: Colors.white.withValues(alpha: 0.15),
      );

  Widget _buildFiltrosYBusqueda() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.border),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQ = v),
              style: const TextStyle(fontSize: 13, color: _C.navy),
              decoration: InputDecoration(
                hintText: 'Buscar...',
                hintStyle:
                    TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: Icon(Icons.search,
                    color: Colors.grey.shade400, size: 18),
                suffixIcon: _searchQ.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close,
                            color: Colors.grey.shade400, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQ = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _filtroBtn(),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() => _ordenDesc = !_ordenDesc),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _C.navy,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  _ordenDesc
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _ordenDesc ? 'Mayor' : 'Menor',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _filtroBtn() {
    final opciones = {
      'todos':            'Todos',
      'seleccionados':    'Exponen',
      'no_seleccionados': 'Sin exp.',
    };
    return PopupMenuButton<String>(
      initialValue: _filtro,
      onSelected: (v) => setState(() => _filtro = v),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => opciones.entries
          .map((e) => PopupMenuItem(
                value: e.key,
                child: Text(e.value,
                    style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.filter_list_rounded,
                color: _C.navy, size: 18),
            const SizedBox(width: 4),
            Text(opciones[_filtro]!,
                style: const TextStyle(
                    color: _C.navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonExportar() {
    return SizedBox(
      width: double.infinity,
      child: BotonExportarEvaluacionFinal(
        notas: _notas.map((n) => NotaFinalItem(
          studentId:      n.studentId,
          nombre:         n.nombre,
          codigo:         n.codigo,
          ciclo:          n.ciclo,
          grupo:          n.grupo,
          seleccionado:   n.seleccionado,
          proyectoCodigo: n.proyectoCodigo,
          notaAsist:      n.notaAsist,
          notaJurado:     n.notaJurado,
          notaDocente:    n.notaDocente,
          notaFinal:      n.notaFinal,
        )).toList(),
        config: EvalFinalConfig(
          pctAsistNoSel:       _config.pctAsistNoSel,
          pctDocenteNoSel:     _config.pctDocenteNoSel,
          incluirDocenteNoSel: _config.incluirDocenteNoSel,
          modalidad:           _config.modalidad,
          pctAsistSel:         _config.pctAsistSel,
          pctJuradoSel:        _config.pctJuradoSel,
          pctAsistSelMixta:    _config.pctAsistSelMixta,
          pctJuradoSelMixta:   _config.pctJuradoSelMixta,
          pctDocenteSelMixta:  _config.pctDocenteSelMixta,
        ),
        eventoNombre: _eventoNombre ?? '',
        filialNombre: _filialNombre ?? '',
        facultad:     _facultad ?? '',
        carrera:      _carreraNombre ?? '',
        onExportado: (path) async {},
      ),
    );
  }


  Widget _buildStudentCard(_NotaFinal n, int index) {
    final color = _colorNota(n.notaFinal);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: n.seleccionado
              ? _C.teal.withValues(alpha: 0.3)
              : _C.border,
          width: n.seleccionado ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: index < 3
                        ? [
                            const Color(0xFFFFD700),
                            const Color(0xFFC0C0C0),
                            const Color(0xFFCD7F32),
                          ][index]
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${index + 1}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: index < 3
                                ? Colors.white
                                : Colors.grey.shade600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.nombre,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _C.navy),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (n.codigo.isNotEmpty)
                            Text(n.codigo,
                                style: const TextStyle(
                                    fontSize: 10, color: _C.txt3)),
                          if (n.ciclo.isNotEmpty)
                            _miniTag('C${n.ciclo}', _C.accent),
                          if (n.grupo.isNotEmpty)
                            _miniTag('G${n.grupo}', _C.purple),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: n.seleccionado
                                  ? _C.tealL
                                  : _C.orangeL,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  n.seleccionado
                                      ? Icons.present_to_all_rounded
                                      : Icons.person_rounded,
                                  size: 9,
                                  color: n.seleccionado
                                      ? _C.teal
                                      : _C.orange,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  n.seleccionado ? 'Expone' : 'Sin exp.',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: n.seleccionado
                                          ? _C.teal
                                          : _C.orange),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: color.withValues(alpha: 0.35),
                        width: 1.5),
                  ),
                  child: Text(
                    n.notaFinal.toStringAsFixed(1),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _notaChip('Asist.', n.notaAsist, _C.accent),
                const SizedBox(width: 6),
                if (n.seleccionado)
                  _notaChip('Jurado', n.notaJurado, _C.purple),
                if (n.seleccionado) const SizedBox(width: 6),
                _notaChip('Docente', n.notaDocente, _C.orange,
                    isEmpty: n.notaDocente == 0),
                if (n.seleccionado && n.proyectoCodigo.isNotEmpty) ...[
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.assignment_rounded,
                          size: 11, color: _C.txt3),
                      const SizedBox(width: 3),
                      Text(n.proyectoCodigo,
                          style: const TextStyle(
                              fontSize: 10,
                              color: _C.txt3,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _notaChip(String label, double nota, Color color,
      {bool isEmpty = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isEmpty
            ? Colors.grey.shade100
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEmpty
              ? _C.border
              : color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            isEmpty ? '—' : nota.toStringAsFixed(1),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isEmpty ? _C.txt3 : color),
          ),
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  color: _C.txt3,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _miniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _infoBox(String msg, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: TextStyle(color: color, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildResumenConfig() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.purpleL,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: _C.purple, size: 15),
              SizedBox(width: 6),
              Text('Configuración activa',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _C.purple)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Sin exponer: Asist. ${_config.pctAsistNoSel.toStringAsFixed(0)}%'
            '${_config.incluirDocenteNoSel ? ' / Docente ${_config.pctDocenteNoSel.toStringAsFixed(0)}%' : ''}',
            style: const TextStyle(fontSize: 11, color: _C.txt2),
          ),
          const SizedBox(height: 3),
          Text(
            _config.modalidad == 'jurado'
                ? '• Expone (Solo jurado): Asist. ${_config.pctAsistSel.toStringAsFixed(0)}% / Jurado ${_config.pctJuradoSel.toStringAsFixed(0)}%'
                : '• Expone (Mixta): Asist. ${_config.pctAsistSelMixta.toStringAsFixed(0)}% / Jurado ${_config.pctJuradoSelMixta.toStringAsFixed(0)}% / Docente ${_config.pctDocenteSelMixta.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 11, color: _C.txt2),
          ),
        ],
      ),
    );
  }




  void _abrirConfig() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfigBottomSheet(
        config: _Config.fromMap(_config.toMap()..remove('updatedAt')),
        onGuardar: (nuevaConfig) async {
          setState(() => _config = nuevaConfig);
          await _guardarConfig();
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }
}




class _ConfigBottomSheet extends StatefulWidget {
  final _Config config;
  final Future<void> Function(_Config) onGuardar;

  const _ConfigBottomSheet({
    required this.config,
    required this.onGuardar,
  });

  @override
  State<_ConfigBottomSheet> createState() => _ConfigBottomSheetState();
}

class _ConfigBottomSheetState extends State<_ConfigBottomSheet> {
  late _Config _cfg;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cfg = widget.config;
  }

  String? _validar() {
    if (_cfg.incluirDocenteNoSel) {
      final s = _cfg.pctAsistNoSel + _cfg.pctDocenteNoSel;
      if ((s - 100).abs() > 0.5) {
        return 'Sin exponer: suma ${s.toStringAsFixed(1)}% (debe ser 100%)';
      }
    }
    if (_cfg.modalidad == 'jurado') {
      final s = _cfg.pctAsistSel + _cfg.pctJuradoSel;
      if ((s - 100).abs() > 0.5) {
        return 'Expone (jurado): suma ${s.toStringAsFixed(1)}% (debe ser 100%)';
      }
    } else {
      final s = _cfg.pctAsistSelMixta +
          _cfg.pctJuradoSelMixta +
          _cfg.pctDocenteSelMixta;
      if ((s - 100).abs() > 0.5) {
        return 'Expone (mixta): suma ${s.toStringAsFixed(1)}% (debe ser 100%)';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final error = _validar();

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.only(
            topLeft:  Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: _C.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _C.purpleL,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.tune_rounded,
                        color: _C.purple, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Configurar ponderación',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _C.navy)),
                  ),
                ],
              ),
            ),
            Container(
                height: 1,
                margin: const EdgeInsets.only(top: 14),
                color: _C.border),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(20),
                children: [
                  _seccionLabel(
                      'Estudiantes sin exponer (no seleccionados)',
                      Icons.person_rounded,
                      _C.orange),
                  const SizedBox(height: 10),
                  _infoChip(
                      'Tienen nota de asistencias (N1) siempre.'
                      ' Opcionalmente incluye nota docente (N3).'),
                  const SizedBox(height: 12),
                  _sliderRow(
                    label:   'Asistencias (N1)',
                    value:   _cfg.pctAsistNoSel,
                    color:   _C.accent,
                    onChanged: (v) => setState(() {
                      _cfg.pctAsistNoSel = v;
                      if (_cfg.incluirDocenteNoSel) {
                        _cfg.pctDocenteNoSel = (100 - v).clamp(0, 100);
                      }
                    }),
                    enabled: true,
                  ),
                  _toggleRow(
                    label:   'Incluir nota docente (N3)',
                    value:   _cfg.incluirDocenteNoSel,
                    onChanged: (v) => setState(() {
                      _cfg.incluirDocenteNoSel = v;
                      if (v) {
                        _cfg.pctAsistNoSel   = 70;
                        _cfg.pctDocenteNoSel = 30;
                      } else {
                        _cfg.pctAsistNoSel   = 100;
                        _cfg.pctDocenteNoSel = 0;
                      }
                    }),
                  ),
                  if (_cfg.incluirDocenteNoSel) ...[
                    const SizedBox(height: 4),
                    _sliderRow(
                      label:   'Docente (N3)',
                      value:   _cfg.pctDocenteNoSel,
                      color:   _C.orange,
                      onChanged: (v) => setState(() {
                        _cfg.pctDocenteNoSel = v;
                        _cfg.pctAsistNoSel = (100 - v).clamp(0, 100);
                      }),
                      enabled: true,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(height: 1, color: _C.border),
                  const SizedBox(height: 24),
                  _seccionLabel(
                      'Estudiantes que exponen (seleccionados)',
                      Icons.present_to_all_rounded,
                      _C.teal),
                  const SizedBox(height: 10),
                  const Text('Modalidad de calificación',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _C.txt2)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _modeBtn('jurado', 'Solo jurado',
                          Icons.gavel_rounded),
                      const SizedBox(width: 10),
                      _modeBtn('mixta',  'Mixta (+ docente)',
                          Icons.merge_type_rounded),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_cfg.modalidad == 'jurado') ...[
                    _infoChip(
                        'Solo jurado: N1 (Asistencias) + N2 (Jurados). '
                        'No se usa nota docente.'),
                    const SizedBox(height: 12),
                    _sliderRow(
                      label:   'Asistencias (N1)',
                      value:   _cfg.pctAsistSel,
                      color:   _C.accent,
                      onChanged: (v) => setState(() {
                        _cfg.pctAsistSel  = v;
                        _cfg.pctJuradoSel = (100 - v).clamp(0, 100);
                      }),
                      enabled: true,
                    ),
                    const SizedBox(height: 4),
                    _sliderRow(
                      label:   'Jurado (N2)',
                      value:   _cfg.pctJuradoSel,
                      color:   _C.purple,
                      onChanged: (v) => setState(() {
                        _cfg.pctJuradoSel = v;
                        _cfg.pctAsistSel  = (100 - v).clamp(0, 100);
                      }),
                      enabled: true,
                    ),
                  ] else ...[
                    _infoChip(
                        'Mixta: N1 (Asistencias) + N2 (Jurados) + N3 (Docente). '
                        'La nota docente estará vacía hasta completarla en el Excel.'),
                    const SizedBox(height: 12),
                    _sliderRow(
                      label:   'Asistencias (N1)',
                      value:   _cfg.pctAsistSelMixta,
                      color:   _C.accent,
                      onChanged: (v) => setState(() {
                        final resto = 100 - v;
                        _cfg.pctAsistSelMixta   = v;
                        _cfg.pctJuradoSelMixta  =
                            (resto * 0.7).roundToDouble();
                        _cfg.pctDocenteSelMixta =
                            (resto * 0.3).roundToDouble();
                      }),
                      enabled: true,
                    ),
                    const SizedBox(height: 4),
                    _sliderRow(
                      label:   'Jurado (N2)',
                      value:   _cfg.pctJuradoSelMixta,
                      color:   _C.purple,
                      onChanged: (v) => setState(() {
                        _cfg.pctJuradoSelMixta  = v;
                        _cfg.pctDocenteSelMixta =
                            (100 - _cfg.pctAsistSelMixta - v)
                                .clamp(0, 100);
                      }),
                      enabled: true,
                    ),
                    const SizedBox(height: 4),
                    _sliderRow(
                      label:   'Docente (N3)',
                      value:   _cfg.pctDocenteSelMixta,
                      color:   _C.orange,
                      onChanged: (v) => setState(() {
                        _cfg.pctDocenteSelMixta = v;
                        _cfg.pctJuradoSelMixta  =
                            (100 - _cfg.pctAsistSelMixta - v)
                                .clamp(0, 100);
                      }),
                      enabled: true,
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _C.redL,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _C.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_rounded,
                              color: _C.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(error,
                                style: const TextStyle(
                                    color: _C.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (error != null || _guardando)
                          ? null
                          : () async {
                              setState(() => _guardando = true);
                              await widget.onGuardar(_cfg);
                              if (mounted) {
                                setState(() => _guardando = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.purple,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Text('Guardar configuración',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionLabel(String label, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _C.navy)),
        ),
      ],
    );
  }

  Widget _infoChip(String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.border),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11, color: _C.txt2, height: 1.4)),
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
    required bool enabled,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _C.txt2)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor:       color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              overlayColor:       color.withValues(alpha: 0.1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.clamp(0, 100),
              max: 100,
              divisions: 20,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${value.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color),
          ),
        ),
      ],
    );
  }

  Widget _toggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _C.txt1)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: _C.teal,
        ),
      ],
    );
  }

  Widget _modeBtn(String value, String label, IconData icon) {
    final sel = _cfg.modalidad == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _cfg.modalidad = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
              vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: sel ? _C.teal : _C.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? _C.teal : _C.border,
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: sel ? Colors.white : _C.txt2),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : _C.txt2)),
            ],
          ),
        ),
      ),
    );
  }
}