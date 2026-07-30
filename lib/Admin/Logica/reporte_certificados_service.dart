import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '/encryption_helper.dart';

/// Una escuela (carrera) dentro de la estructura filial→facultad→escuela.
class EscuelaItem {
  final String filialId;
  final String filialNombre;
  final String facultad;
  final String carreraId;
  final String carreraNombre;
  const EscuelaItem({
    required this.filialId,
    required this.filialNombre,
    required this.facultad,
    required this.carreraId,
    required this.carreraNombre,
  });
}

/// Un evento de una escuela.
class EventoItem {
  final String id;
  final String name;
  const EventoItem(this.id, this.name);
}

/// Fila de la hoja ASISTENTE.
class CertificadoRow {
  final String nombre;
  final String dni;
  final String codigo;
  final String ciclo;
  final String grupo;
  final int sellos;
  const CertificadoRow({
    required this.nombre,
    required this.dni,
    required this.codigo,
    required this.ciclo,
    required this.grupo,
    required this.sellos,
  });
}

/// Fila de la hoja PONENTE (estudiante integrante de proyecto).
class PonenteRow {
  final String nombre;
  final String dni;
  final String codigo;
  final String ciclo;
  final String grupo;
  final bool evaluado;
  const PonenteRow({
    required this.nombre,
    required this.dni,
    required this.codigo,
    required this.ciclo,
    required this.grupo,
    required this.evaluado,
  });
}

/// Fila de la hoja JURADO (docente).
class JuradoRow {
  final String nombre;
  final int proyectosEvaluados;
  const JuradoRow({
    required this.nombre,
    required this.proyectosEvaluados,
  });
}

/// Fila de la hoja ORGANIZADOR (estudiante con esAsisteQR).
class OrganizadorRow {
  final String nombre;
  final String dni;
  final String codigo;
  final String ciclo;
  final String grupo;
  const OrganizadorRow({
    required this.nombre,
    required this.dni,
    required this.codigo,
    required this.ciclo,
    required this.grupo,
  });
}

/// Contenedor con las 4 hojas del reporte.
class ReporteRoles {
  final List<CertificadoRow> asistentes;
  final List<PonenteRow> ponentes;
  final List<JuradoRow> jurados;
  final List<OrganizadorRow> organizadores;
  const ReporteRoles({
    required this.asistentes,
    required this.ponentes,
    required this.jurados,
    required this.organizadores,
  });
}

class ReporteCertificadosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── 1) Estructura filial → facultad → escuela (desde 'events') ──────────
  Future<List<EscuelaItem>> getEstructura() async {
    final snap = await _firestore.collection('events').get();
    final mapa = <String, EscuelaItem>{};
    for (final doc in snap.docs) {
      final d = doc.data();
      final filialId = (d['filialId'] ?? '').toString();
      final filialNombre =
          (d['filialNombre'] ?? d['filialId'] ?? 'Sin filial').toString();
      final facultad = (d['facultad'] ?? 'Sin facultad').toString();
      final carreraId = (d['carreraId'] ?? '').toString();
      final carreraNombre =
          (d['carreraNombre'] ?? d['carreraId'] ?? 'Sin carrera').toString();
      if (filialId.isEmpty || carreraNombre.isEmpty) continue;

      final clave = '$filialId|$facultad|$carreraNombre';
      mapa.putIfAbsent(
        clave,
        () => EscuelaItem(
          filialId: filialId,
          filialNombre: filialNombre,
          facultad: facultad,
          carreraId: carreraId,
          carreraNombre: carreraNombre,
        ),
      );
    }
    return mapa.values.toList();
  }

  // ── 2) Eventos de una escuela ───────────────────────────────────────────
  Future<List<EventoItem>> getEventos(EscuelaItem escuela) async {
    final snap = await _firestore
        .collection('events')
        .where('filialId', isEqualTo: escuela.filialId)
        .where('facultad', isEqualTo: escuela.facultad)
        .get();

    final docs = snap.docs.where((doc) {
      final data = doc.data();
      if (escuela.carreraId.isNotEmpty) {
        return data['carreraId'] == escuela.carreraId;
      }
      return data['carreraNombre'] == escuela.carreraNombre ||
          data['carrera'] == escuela.carreraNombre;
    }).toList();

    return docs
        .map((doc) =>
            EventoItem(doc.id, (doc.data()['name'] ?? 'Sin nombre').toString()))
        .toList();
  }

  // ── 3) Meta de sellos del evento ────────────────────────────────────────
  Future<int> getMetaSellos(EscuelaItem escuela, String eventoId) async {
    try {
      final docId =
          '${escuela.filialId}_${escuela.facultad}_${escuela.carreraId}_$eventoId'
              .replaceAll(' ', '_')
              .replaceAll('/', '_')
              .replaceAll('.', '_');
      final doc =
          await _firestore.collection('sellos_asistencia').doc(docId).get();
      if (!doc.exists) return 0;
      final m = doc.data()!['meta'];
      if (m is int && m > 0) return m;
      if (m is double && m > 0) return m.toInt();
      return 0;
    } catch (e) {
      debugPrint('⚠️ Error meta sellos: $e');
      return 0;
    }
  }

  // ── Helper: descifrar DNI ────────────────────────────────────────────────
  String _dni(Map<String, dynamic> est) {
    final dniEnc = (est['dniEncrypted'] ?? '').toString();
    if (dniEnc.isEmpty) return '—';
    final d = EncryptionHelper.decryptDni(dniEnc);
    if (d.isEmpty || d == '(error)' || d == 'Sin DNI') return '—';
    return d;
  }

  // ── Helper: ordenar por ciclo → grupo → nombre ──────────────────────────
  int _comparar(String a, String b) {
    final na = int.tryParse(a.trim());
    final nb = int.tryParse(b.trim());
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ASISTENTE — inscritos con sellos (optimizado con totalScans + híbrido)
  // ═════════════════════════════════════════════════════════════════════════
  Future<List<CertificadoRow>> getInscritosConSellos({
    required EscuelaItem escuela,
    required String eventoId,
  }) async {
   final docKey = '${escuela.filialNombre}_${escuela.carreraNombre}';
    debugPrint('🔑 docKey buscado: "$docKey"');
    final snap = await _firestore
        .collection('users')
        .doc(docKey)
        .collection('students')
        .orderBy('name')
        .get();
    debugPrint('👥 students encontrados: ${snap.docs.length}');

    final inscritos = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      final pagos = d['pagos'] as Map<String, dynamic>? ?? {};
      if (pagos[eventoId] == true) {
        inscritos.add({'id': doc.id, ...d});
      }
    }
    if (inscritos.isEmpty) return [];

    final idsInscritos = inscritos.map((e) => e['id'] as String).toSet();

    // Personales
   // Personales — dos fuentes, igual que Control de Asistencias:
    //  (1) asistencias_personales vivas + sus registros
    //  (2) collectionGroup('registros') huérfanos (padre borrado)
    // Para no duplicar, guardamos un set de "asistenciaId|studentId" ya contados.
    final conteoPersonales = <String, int>{};
    final yaContados = <String>{};

    // (1) Vivas
    final personalesSnap = await _firestore
        .collection('events')
        .doc(eventoId)
        .collection('asistencias_personales')
        .get();
    await Future.wait(personalesSnap.docs.map((ap) async {
      final regs = await ap.reference.collection('registros').get();
      for (final r in regs.docs) {
        final clave = '${ap.id}|${r.id}';
        if (yaContados.add(clave)) {
          conteoPersonales[r.id] = (conteoPersonales[r.id] ?? 0) + 1;
        }
      }
    }));

    // (2) Huérfanos (o cualquier registro del evento por collectionGroup)
    try {
      final huerfanosSnap = await _firestore
          .collectionGroup('registros')
          .where('eventId', isEqualTo: eventoId)
          .where('type', isEqualTo: 'asistencia_personal')
          .get();
      for (final r in huerfanosSnap.docs) {
        final data = r.data();
        final asistId = (data['asistenciaId'] ?? '').toString();
        final clave = '$asistId|${r.id}';
        if (yaContados.add(clave)) {
          conteoPersonales[r.id] = (conteoPersonales[r.id] ?? 0) + 1;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error leyendo registros huérfanos: $e');
    }
    debugPrint('📝 asistencias_personales docs: ${personalesSnap.docs.length}');
    debugPrint('📝 estudiantes con registro personal: ${conteoPersonales.length}');
    final personalesCoinciden =
        conteoPersonales.keys.where((k) => idsInscritos.contains(k)).length;
    debugPrint('📝 personales que coinciden con inscritos: $personalesCoinciden');

    // Scans vía totalScans
    final scansPorEstudiante = <String, int>{};
    final necesitanRecuento = <String>[];
 final asistenciasSnap = await _firestore
        .collection('events')
        .doc(eventoId)
        .collection('asistencias')
        .get();

    // ── DEBUG temporal ──
    debugPrint('🚀 getInscritosConSellos — eventoId="$eventoId"');
    debugPrint('📋 docs en asistencias: ${asistenciasSnap.docs.length}');
    if (asistenciasSnap.docs.isNotEmpty) {
      debugPrint('   ej. id asistencia: "${asistenciasSnap.docs.first.id}"');
    }
    debugPrint('   ej. ids inscritos: ${idsInscritos.take(3).toList()}');
    final coinciden =
        asistenciasSnap.docs.where((d) => idsInscritos.contains(d.id)).length;
    debugPrint('   coincidencias id: $coinciden de ${asistenciasSnap.docs.length}');
    // ── FIN DEBUG ──

    for (final doc in asistenciasSnap.docs) {
      if (!idsInscritos.contains(doc.id)) continue;
      final ts = doc.data()['totalScans'];
      if (ts is int && ts >= 0) {
        scansPorEstudiante[doc.id] = ts;
      } else if (ts is num) {
        scansPorEstudiante[doc.id] = ts.toInt();
      } else {
        necesitanRecuento.add(doc.id);
      }
    }

    if (necesitanRecuento.isNotEmpty) {
      const lote = 8;
      for (var i = 0; i < necesitanRecuento.length; i += lote) {
        final slice = necesitanRecuento.skip(i).take(lote).toList();
        await Future.wait(slice.map((id) async {
          try {
            final agg = await _firestore
                .collection('events')
                .doc(eventoId)
                .collection('asistencias')
                .doc(id)
                .collection('scans')
                .count()
                .get();
            scansPorEstudiante[id] = agg.count ?? 0;
          } catch (_) {
            scansPorEstudiante[id] = 0;
          }
        }));
      }
    }

    final filas = <CertificadoRow>[];
    for (final est in inscritos) {
      final id = est['id'] as String;
      final sellos =
          (scansPorEstudiante[id] ?? 0) + (conteoPersonales[id] ?? 0);
      filas.add(CertificadoRow(
        nombre: (est['name'] ?? 'Sin nombre').toString(),
        dni: _dni(est),
        codigo: (est['codigoUniversitario'] ?? '').toString(),
        ciclo: (est['ciclo'] ?? '').toString(),
        grupo: (est['grupo'] ?? '').toString(),
        sellos: sellos,
      ));
    }

    filas.sort((x, y) {
      final c = _comparar(x.ciclo, y.ciclo);
      if (c != 0) return c;
      final g = _comparar(x.grupo, y.grupo);
      if (g != 0) return g;
      return x.nombre.toLowerCase().compareTo(y.nombre.toLowerCase());
    });

    return filas;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // MATRICULADOS — todos los estudiantes de la carrera con sus sellos
  // (misma lógica de sellos que asistente, sin filtrar por pago)
  // ═════════════════════════════════════════════════════════════════════════
  Future<List<CertificadoRow>> getMatriculadosConSellos({
    required EscuelaItem escuela,
    required String eventoId,
  }) async {
    final docKey = '${escuela.filialNombre}_${escuela.carreraNombre}';

    final snap = await _firestore
        .collection('users')
        .doc(docKey)
        .collection('students')
        .orderBy('name')
        .get();

    // Todos los estudiantes (sin filtro de pago)
    final estudiantes = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      estudiantes.add({'id': doc.id, ...doc.data()});
    }
    if (estudiantes.isEmpty) return [];

    final ids = estudiantes.map((e) => e['id'] as String).toSet();

    // Personales
    final conteoPersonales = <String, int>{};
    final personalesSnap = await _firestore
        .collection('events')
        .doc(eventoId)
        .collection('asistencias_personales')
        .get();
    await Future.wait(personalesSnap.docs.map((ap) async {
      final regs = await ap.reference.collection('registros').get();
      for (final r in regs.docs) {
        conteoPersonales[r.id] = (conteoPersonales[r.id] ?? 0) + 1;
      }
    }));

 // Scans vía totalScans (+ recuento híbrido)
    final scansPorEstudiante = <String, int>{};
    final necesitanRecuento = <String>[];
    final asistenciasSnap = await _firestore
        .collection('events')
        .doc(eventoId)
        .collection('asistencias')
        .get();

    // ── DEBUG temporal ──
    debugPrint('📋 docs en asistencias: ${asistenciasSnap.docs.length}');
    if (asistenciasSnap.docs.isNotEmpty) {
      debugPrint('   ej. id asistencia: "${asistenciasSnap.docs.first.id}"');
    }
    debugPrint('   ej. ids que busco (students): ${ids.take(3).toList()}');
    final coinciden =
        asistenciasSnap.docs.where((d) => ids.contains(d.id)).length;
    debugPrint('   coincidencias id: $coinciden de ${asistenciasSnap.docs.length}');
    // ── FIN DEBUG ──

    for (final doc in asistenciasSnap.docs) {
      if (!ids.contains(doc.id)) continue;
      final ts = doc.data()['totalScans'];
      if (ts is int && ts >= 0) {
        scansPorEstudiante[doc.id] = ts;
      } else if (ts is num) {
        scansPorEstudiante[doc.id] = ts.toInt();
      } else {
        necesitanRecuento.add(doc.id);
      }
    }

    if (necesitanRecuento.isNotEmpty) {
      const lote = 8;
      for (var i = 0; i < necesitanRecuento.length; i += lote) {
        final slice = necesitanRecuento.skip(i).take(lote).toList();
        await Future.wait(slice.map((id) async {
          try {
            final agg = await _firestore
                .collection('events')
                .doc(eventoId)
                .collection('asistencias')
                .doc(id)
                .collection('scans')
                .count()
                .get();
            scansPorEstudiante[id] = agg.count ?? 0;
          } catch (_) {
            scansPorEstudiante[id] = 0;
          }
        }));
      }
    }

    final filas = <CertificadoRow>[];
    for (final est in estudiantes) {
      final id = est['id'] as String;
      final sellos =
          (scansPorEstudiante[id] ?? 0) + (conteoPersonales[id] ?? 0);
      filas.add(CertificadoRow(
        nombre: (est['name'] ?? 'Sin nombre').toString(),
        dni: _dni(est),
        codigo: (est['codigoUniversitario'] ?? '').toString(),
        ciclo: (est['ciclo'] ?? '').toString(),
        grupo: (est['grupo'] ?? '').toString(),
        sellos: sellos,
      ));
    }

    filas.sort((x, y) {
      final c = _comparar(x.ciclo, y.ciclo);
      if (c != 0) return c;
      final g = _comparar(x.grupo, y.grupo);
      if (g != 0) return g;
      return x.nombre.toLowerCase().compareTo(y.nombre.toLowerCase());
    });

    return filas;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Reporte de las otras 3 hojas: ponentes, jurados, organizadores
  // ═════════════════════════════════════════════════════════════════════════
  Future<ReporteRoles> getReporteRoles({
    required EscuelaItem escuela,
    required String eventoId,
    required List<CertificadoRow> asistentes,
  }) async {
    final docKey = '${escuela.filialNombre}_${escuela.carreraNombre}';

    // Cargar estudiantes de la carrera (para cruces por código)
    final studentsSnap = await _firestore
        .collection('users')
        .doc(docKey)
        .collection('students')
        .get();

final porCodigo = <String, Map<String, dynamic>>{};
    // 🆕 lista de estudiantes con sus tokens de nombre, para matching flexible
    final estudiantesTokens = <MapEntry<Set<String>, Map<String, dynamic>>>[];
    final organizadores = <OrganizadorRow>[];

    for (final doc in studentsSnap.docs) {
      final d = doc.data();
      final cod = (d['codigoUniversitario'] ?? '').toString().trim();
      if (cod.isNotEmpty) porCodigo[cod] = {'id': doc.id, ...d};

      final tokens = _tokens((d['name'] ?? '').toString());
      if (tokens.isNotEmpty) {
        estudiantesTokens.add(MapEntry(tokens, {'id': doc.id, ...d}));
      }

      if (d['esAsisteQR'] == true) {
        organizadores.add(OrganizadorRow(
          nombre: (d['name'] ?? 'Sin nombre').toString(),
          dni: _dni(d),
          codigo: cod,
          ciclo: (d['ciclo'] ?? '').toString(),
          grupo: (d['grupo'] ?? '').toString(),
        ));
      }
    }

    // ── Proyectos del evento + evaluaciones ────────────────────────────────
    final proyectosSnap = await _firestore
        .collection('events')
        .doc(eventoId)
        .collection('proyectos')
        .get();

    // Conteo de evaluaciones por jurado y set de códigos de ponentes evaluados
    final evalPorJurado = <String, int>{};
    // codigo integrante → fue evaluado en algún proyecto
    final ponenteEvaluado = <String, bool>{};
    // codigo integrante → (asegura presencia aunque no evaluado)
    final ponentesCodigos = <String>{};

    await Future.wait(proyectosSnap.docs.map((proyDoc) async {
      final pData = proyDoc.data();
      final integrantesRaw = pData['Integrantes'] ?? pData['integrantes'];
      final codigos = _extraerCodigos(integrantesRaw);

      // Evaluaciones de este proyecto
      final evalSnap = await proyDoc.reference.collection('evaluaciones').get();
      bool proyectoEvaluado = false;
      for (final ev in evalSnap.docs) {
        final evData = ev.data();
        final evaluada = evData['evaluada'] == true;
        if (evaluada) {
          proyectoEvaluado = true;
          final juradoId = ev.id; // doc.id == juradoId
          evalPorJurado[juradoId] = (evalPorJurado[juradoId] ?? 0) + 1;
        }
      }

      for (final cod in codigos) {
        ponentesCodigos.add(cod);
        ponenteEvaluado[cod] =
            (ponenteEvaluado[cod] ?? false) || proyectoEvaluado;
      }
    }));

final ponentes = <PonenteRow>[];
for (final cod in ponentesCodigos) {
      final est = porCodigo[cod] ?? _buscarPorNombreParecido(cod, estudiantesTokens);
      if (est != null) {
        ponentes.add(PonenteRow(
          nombre: (est['name'] ?? 'Sin nombre').toString(),
          dni: _dni(est),
          codigo: (est['codigoUniversitario'] ?? cod).toString(),
      ciclo: (est['ciclo'] ?? '').toString(),
      grupo: (est['grupo'] ?? '').toString(),
      evaluado: ponenteEvaluado[cod] ?? false,
    ));
  } else {
    ponentes.add(PonenteRow(
      nombre: cod,
      dni: '—',
      codigo: cod,
      ciclo: '',
      grupo: '',
      evaluado: ponenteEvaluado[cod] ?? false,
    ));
  }
}
    ponentes.sort((x, y) {
      final c = _comparar(x.ciclo, y.ciclo);
      if (c != 0) return c;
      final g = _comparar(x.grupo, y.grupo);
      if (g != 0) return g;
      return x.nombre.toLowerCase().compareTo(y.nombre.toLowerCase());
    });

    // ── Jurados: todos los de la carrera + su conteo ───────────────────────
    final juradosSnap = await _firestore
        .collection('users')
        .where('userType', isEqualTo: 'jurado')
        .where('filial', isEqualTo: escuela.filialId)
        .where('facultad', isEqualTo: escuela.facultad)
        .where('carrera', isEqualTo: escuela.carreraNombre)
        .get();

    final jurados = <JuradoRow>[];
    for (final doc in juradosSnap.docs) {
      final d = doc.data();
      jurados.add(JuradoRow(
        nombre: (d['name'] ?? 'Sin nombre').toString(),
        proyectosEvaluados: evalPorJurado[doc.id] ?? 0,
      ));
    }
    jurados.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

    // Organizadores ordenados
    organizadores.sort((x, y) {
      final c = _comparar(x.ciclo, y.ciclo);
      if (c != 0) return c;
      final g = _comparar(x.grupo, y.grupo);
      if (g != 0) return g;
      return x.nombre.toLowerCase().compareTo(y.nombre.toLowerCase());
    });

    return ReporteRoles(
      asistentes: asistentes,
      ponentes: ponentes,
      jurados: jurados,
      organizadores: organizadores,
    );
  }
  
Map<String, dynamic>? _buscarPorNombreParecido(
    String texto,
    List<MapEntry<Set<String>, Map<String, dynamic>>> estudiantesTokens,
  ) {
    final buscado = _tokens(texto);
    if (buscado.isEmpty) return null;

    Map<String, dynamic>? mejor;
    int mejorScore = 0;

    for (final entry in estudiantesTokens) {
      final tEst = entry.key;
      final chico = buscado.length <= tEst.length ? buscado : tEst;
      final grande = buscado.length <= tEst.length ? tEst : buscado;

      int coincidencias = 0;
      for (final tChico in chico) {
        final hayParecido = grande.any((tGrande) => _tokenParecido(tChico, tGrande));
        if (hayParecido) coincidencias++;
      }

      if (coincidencias == chico.length && coincidencias >= 2) {
        if (coincidencias > mejorScore) {
          mejorScore = coincidencias;
          mejor = entry.value;
        }
      }
    }
    return mejor;
  }
 String _quitarTildes(String s) {
    const con = 'áéíóúàèìòùäëïöüñ';
    const sin = 'aeiouaeiouaeioun';
    final buffer = StringBuffer();
    for (final ch in s.split('')) {
      final idx = con.indexOf(ch);
      buffer.write(idx >= 0 ? sin[idx] : ch);
    }
    return buffer.toString();
  }
int _distanciaEdicion(String a, String b) {
    if (a == b) return 0;
    final la = a.length, lb = b.length;
    if ((la - lb).abs() > 2) return 99; // corte rápido, muy distintas en longitud
    final dp = List.generate(la + 1, (_) => List.filled(lb + 1, 0));
    for (var i = 0; i <= la; i++) dp[i][0] = i;
    for (var j = 0; j <= lb; j++) dp[0][j] = j;
    for (var i = 1; i <= la; i++) {
      for (var j = 1; j <= lb; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
              .reduce((x, y) => x < y ? x : y);
        }
      }
    }
    return dp[la][lb];
  }

  bool _tokenParecido(String a, String b) {
    if (a == b) return true;
    // tolerancia: 1 letra de diferencia para palabras de 4+ letras
    if (a.length >= 4 && b.length >= 4) {
      return _distanciaEdicion(a, b) <= 1;
    }
    return false;
  }
  Set<String> _tokens(String s) {
    final limpio = _quitarTildes(s.trim().toLowerCase());
    return limpio
        .replaceAll(RegExp(r'[^a-z\s]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1)
        .toSet();
  }
  List<String> _extraerCodigos(dynamic integrantes) {
    if (integrantes == null) return [];

    // Junta todo en una sola cadena, venga como lista o como texto
    final String texto;
    if (integrantes is List) {
      texto = integrantes.map((e) => e.toString()).join(',');
    } else {
      texto = integrantes.toString();
    }
    if (texto.trim().isEmpty) return [];

    // Parte por coma o salto de línea, sin importar cómo vino agrupado
    return texto
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}