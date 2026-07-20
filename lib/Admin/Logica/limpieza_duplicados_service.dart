import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Servicio TEMPORAL para detectar y corregir carreras duplicadas
/// (mismo nombre, distinto ID) dentro de una filial.
///
/// USO SUGERIDO:
/// 0. ANTES DE NADA: revisa `coleccionesRelacionadas` abajo y agrega
///    cualquier colección de tu app (además de 'events') que tenga un
///    campo 'carreraId' (ej. 'admin_carrera', 'jurados', 'certificados').
///    Si te falta una, esos documentos quedarán con un carreraId huérfano.
///
/// 1. Agrega un botón temporal en una pantalla de admin, y corre PRIMERO
///    en modo dryRun (no borra ni modifica nada, solo reporta):
///
///    ElevatedButton(
///      onPressed: () async {
///        final reporte = await LimpiezaDuplicadosService()
///            .limpiarDuplicados('juliaca', dryRun: true);
///        debugPrint(reporte.toString());
///      },
///      child: const Text('Ver duplicados Juliaca (dry run)'),
///    )
///
/// 2. Revisa el 'detalle' del reporte con calma: confirma que las
///    reasignaciones y los IDs a borrar tienen sentido.
///
/// 3. Recién entonces corre con dryRun: false para aplicar los cambios
///    de verdad.
///
/// 4. Llama `FilialesService.clearCache()` después, y borra el botón /
///    este archivo cuando confirmes que todo quedó bien.
///
/// QUÉ HACE:
/// - Recorre las facultades de la filial indicada.
/// - Agrupa las carreras por nombre normalizado (trim + lowercase).
/// - Si encuentra más de un documento con el mismo nombre, revisa cuál de
///   los IDs duplicados tiene referencias reales en las colecciones
///   relacionadas (eventos, etc.) y lo conserva como "canónico".
/// - Si DOS O MÁS copias duplicadas tienen referencias activas al mismo
///   tiempo, el grupo se marca como "ambiguo" y NO se toca — evita fusionar
///   mal datos que en realidad pertenecen a cosas distintas.
/// - Antes de borrar cada duplicado, reasigna cualquier documento en las
///   colecciones relacionadas que tenga `carreraId` apuntando a él, para
///   que apunte al ID canónico (así no se pierden datos ya creados).
/// - Borra los documentos de carrera duplicados (solo en grupos no ambiguos).
class LimpiezaDuplicadosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Colecciones adicionales (fuera de 'events') que guardan un campo
  /// 'carreraId' y que también deben reasignarse antes de borrar duplicados.
  /// AGREGA AQUÍ cualquier otra colección de tu app que dependa de carreraId
  /// (ej. 'admin_carrera', 'jurados', 'certificados', etc.) antes de correr
  /// el script con dryRun: false.
  static const List<String> coleccionesRelacionadas = [
    'events',
    'admins_carrera',      // confirmado: admin_carrera_service.dart
    'listas_certificados', // confirmado: importar_codigos_certificado_screen.dart
    // 'jurados',
    // 'certificados',
  ];

  /// [dryRun] = true (por defecto): NO escribe ni borra nada, solo reporta
  /// qué haría. Úsalo primero para revisar antes de aplicar cambios reales.
  Future<Map<String, dynamic>> limpiarDuplicados(
    String filialId, {
    bool dryRun = true,
  }) async {
    final reporte = <String, dynamic>{
      'filialId': filialId,
      'dryRun': dryRun,
      'facultadesRevisadas': 0,
      'gruposDuplicados': 0,
      'carrerasEliminadas': 0,
      'eventosReasignados': 0,
      'detalle': <String>[],
    };

    final facultadesSnap = await _firestore
        .collection('filiales')
        .doc(filialId)
        .collection('facultades')
        .get();

    debugPrint(
      '🧹 [LimpiezaDuplicados] Iniciando filial="$filialId" '
      'dryRun=$dryRun · ${facultadesSnap.docs.length} facultades encontradas',
    );

    for (final facultadDoc in facultadesSnap.docs) {
      reporte['facultadesRevisadas'] = (reporte['facultadesRevisadas'] as int) + 1;
      final facultadNombre =
          (facultadDoc.data()['nombre'] as String?) ?? facultadDoc.id;
      debugPrint('📂 Revisando facultad: $facultadNombre (${facultadDoc.id})');

      // Traemos SIN orderBy a propósito: usar orderBy('createdAt') haría
      // que Firestore excluya silenciosamente cualquier documento que no
      // tenga ese campo (ej. uno creado manualmente desde la consola sin
      // timestamp), y el script ni se enteraría de que existe.
      final carrerasSnap =
          await facultadDoc.reference.collection('carreras').get();

      final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
          grupos = {};

      for (final doc in carrerasSnap.docs) {
        final nombre = (doc.data())['nombre'] as String? ?? '';
        final clave = nombre.trim().toLowerCase();
        if (clave.isEmpty) continue;
        grupos.putIfAbsent(clave, () => []).add(doc);
      }

      for (final entry in grupos.entries) {
        final docs = entry.value;
        if (docs.length <= 1) continue;

        reporte['gruposDuplicados'] = (reporte['gruposDuplicados'] as int) + 1;

        // Para cada ID duplicado, contamos cuántos documentos reales lo
        // referencian en las colecciones relacionadas. El que tenga más
        // referencias activas es el "canónico" real (el que de verdad se
        // está usando), en vez de simplemente asumir el más antiguo.
        final Map<String, int> referenciasPorId = {};
        for (final doc in docs) {
          int total = 0;
          for (final coleccion in coleccionesRelacionadas) {
            final refsSnap = await _firestore
                .collection(coleccion)
                .where('carreraId', isEqualTo: doc.id)
                .get();
            total += refsSnap.docs.length;
          }
          referenciasPorId[doc.id] = total;
        }

        final idsConReferencias =
            referenciasPorId.entries.where((e) => e.value > 0).toList();

        if (idsConReferencias.length > 1) {
          // Ambiguo: dos o más copias duplicadas tienen datos reales
          // asociados. No adivinamos cuál conservar — se deja intacto
          // para revisión manual.
          final linea =
              '⚠️ AMBIGUO - $facultadNombre → "${docs.first.data()['nombre']}": '
              'varias copias tienen referencias activas '
              '(${referenciasPorId.entries.map((e) => "${e.key}: ${e.value} refs").join(", ")}). '
              'Requiere revisión manual, NO se tocó este grupo.';
          (reporte['detalle'] as List<String>).add(linea);
          debugPrint(linea);
          reporte['gruposAmbiguos'] =
              ((reporte['gruposAmbiguos'] as int?) ?? 0) + 1;
          continue;
        }

        // Canónico = el que tiene referencias activas; si ninguno tiene
        // referencias todavía, se conserva el primero de la lista.
        final canonico = idsConReferencias.isNotEmpty
            ? docs.firstWhere((d) => d.id == idsConReferencias.first.key)
            : docs.first;
        final duplicados = docs.where((d) => d.id != canonico.id).toList();

        final lineaGrupo =
            '$facultadNombre → "${docs.first.data()['nombre']}": '
            '${docs.length} copias encontradas. Se conserva ${canonico.id} '
            '(${referenciasPorId[canonico.id]} refs), '
            'se eliminan ${duplicados.map((d) => d.id).join(', ')}';
        (reporte['detalle'] as List<String>).add(lineaGrupo);
        debugPrint(lineaGrupo);

        for (final dup in duplicados) {
          // 1) Reasignar referencias en TODAS las colecciones relacionadas
          for (final coleccion in coleccionesRelacionadas) {
            final refsSnap = await _firestore
                .collection(coleccion)
                .where('carreraId', isEqualTo: dup.id)
                .get();

            for (final refDoc in refsSnap.docs) {
              final lineaRef =
                  '  [$coleccion/${refDoc.id}] carreraId ${dup.id} → ${canonico.id}'
                  '${dryRun ? " (dry run, no aplicado)" : ""}';
              (reporte['detalle'] as List<String>).add(lineaRef);
              debugPrint(lineaRef);
              if (!dryRun) {
                await refDoc.reference.update({'carreraId': canonico.id});
              }
              if (coleccion == 'events') {
                reporte['eventosReasignados'] =
                    (reporte['eventosReasignados'] as int) + 1;
              }
            }
          }

          // 2) Eliminar el documento de carrera duplicado
          final lineaEliminar = '  Eliminar carrera duplicada ${dup.id}'
              '${dryRun ? " (dry run, no aplicado)" : ""}';
          (reporte['detalle'] as List<String>).add(lineaEliminar);
          debugPrint(lineaEliminar);
          if (!dryRun) {
            await dup.reference.delete();
          }
          reporte['carrerasEliminadas'] =
              (reporte['carrerasEliminadas'] as int) + 1;
        }
      }
    }

    debugPrint(
      '✅ [LimpiezaDuplicados] Terminado filial="$filialId" dryRun=$dryRun · '
      'facultades=${reporte['facultadesRevisadas']} '
      'gruposDuplicados=${reporte['gruposDuplicados']} '
      'gruposAmbiguos=${reporte['gruposAmbiguos'] ?? 0} '
      'carrerasEliminadas=${reporte['carrerasEliminadas']} '
      'eventosReasignados=${reporte['eventosReasignados']}',
    );

    return reporte;
  }

  /// Revisa TODAS las filiales (útil para confirmar que Lima/Tarapoto
  /// realmente están limpias antes de cerrar el tema).
  Future<Map<String, dynamic>> limpiarTodasLasFiliales() async {
    final filialesSnap = await _firestore.collection('filiales').get();
    final resultados = <String, dynamic>{};
    for (final filial in filialesSnap.docs) {
      resultados[filial.id] = await limpiarDuplicados(filial.id);
    }
    return resultados;
  }
}