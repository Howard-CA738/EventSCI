import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PeriodosHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<bool> createPeriodo({
    required String nombre,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    bool activo = false,
  }) async {
    try {
      final existingPeriodo = await _firestore
          .collection('periodos')
          .where('nombre', isEqualTo: nombre.trim())
          .get();

      if (existingPeriodo.docs.isNotEmpty) {
        debugPrint('Ya existe un período con ese nombre');
        return false;
      }

      await _firestore.collection('periodos').add({
        'nombre': nombre.trim(),
        'fechaInicio': Timestamp.fromDate(fechaInicio),
        'fechaFin': Timestamp.fromDate(fechaFin),
        'activo': activo,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Período creado exitosamente: $nombre');
      return true;
    } catch (e) {
      debugPrint('Error creando período: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getPeriodos() async {
    try {
      final periodosQuery = await _firestore
          .collection('periodos')
          .orderBy('createdAt', descending: true)
          .get();

      return periodosQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error obteniendo períodos: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getPeriodosActivos() async {
    try {
      final periodosQuery = await _firestore
          .collection('periodos')
          .where('activo', isEqualTo: true)
          .get();

      final periodos = periodosQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      periodos.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return periodos;
    } catch (e) {
      debugPrint('Error obteniendo períodos activos: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getPeriodoActivo() async {
    try {
      final querySnapshot = await _firestore
          .collection('periodos')
          .where('activo', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      final doc = querySnapshot.docs.first;
      return {'id': doc.id, ...doc.data()};
    } catch (e) {
      debugPrint('Error al obtener período activo: $e');
      return null;
    }
  }

  static Stream<QuerySnapshot> getPeriodosStream() {
    return _firestore
        .collection('periodos')
        .orderBy('fechaInicio', descending: true)
        .snapshots();
  }

  static Future<bool> updatePeriodo({
    required String periodoId,
    String? nombre,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    bool? activo,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (nombre != null && nombre.isNotEmpty) {
        final existingPeriodo = await _firestore
            .collection('periodos')
            .where('nombre', isEqualTo: nombre.trim())
            .get();

        if (existingPeriodo.docs.isNotEmpty &&
            existingPeriodo.docs.first.id != periodoId) {
          debugPrint('Ya existe otro período con ese nombre');
          return false;
        }
        updateData['nombre'] = nombre.trim();
      }

      if (fechaInicio != null) {
        updateData['fechaInicio'] = Timestamp.fromDate(fechaInicio);
      }

      if (fechaFin != null) {
        updateData['fechaFin'] = Timestamp.fromDate(fechaFin);
      }

      if (activo != null) {
        updateData['activo'] = activo;
      }

      await _firestore.collection('periodos').doc(periodoId).update(updateData);
      debugPrint('Período actualizado exitosamente');
      return true;
    } catch (e) {
      debugPrint('Error actualizando período: $e');
      return false;
    }
  }

  static Future<bool> activarPeriodo(String periodoId) async {
    try {
      await _firestore.collection('periodos').doc(periodoId).update({
        'activo': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Período activado exitosamente');
      return true;
    } catch (e) {
      debugPrint('Error activando período: $e');
      return false;
    }
  }

  static Future<bool> desactivarPeriodo(String periodoId) async {
    try {
      await _firestore.collection('periodos').doc(periodoId).update({
        'activo': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Período desactivado exitosamente');
      return true;
    } catch (e) {
      debugPrint('Error desactivando período: $e');
      return false;
    }
  }

  static Future<bool> deletePeriodo(String periodoId) async {
    try {
      await _firestore.collection('periodos').doc(periodoId).delete();
      debugPrint('Período eliminado exitosamente');
      return true;
    } catch (e) {
      debugPrint('Error eliminando período: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> searchPeriodos(
    String searchTerm,
  ) async {
    try {
      final periodosQuery = await _firestore
          .collection('periodos')
          .orderBy('createdAt', descending: true)
          .get();

      final periodos = periodosQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      if (searchTerm.isEmpty) return periodos;

      final searchLower = searchTerm.toLowerCase();
      return periodos.where((periodo) {
        final nombre = (periodo['nombre'] ?? '').toString().toLowerCase();
        return nombre.contains(searchLower);
      }).toList();
    } catch (e) {
      debugPrint('Error buscando períodos: $e');
      return [];
    }
  }

  static Future<bool> hayPeriodosActivos() async {
    try {
      final periodoQuery = await _firestore
          .collection('periodos')
          .where('activo', isEqualTo: true)
          .limit(1)
          .get();

      return periodoQuery.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error verificando períodos activos: $e');
      return false;
    }
  }

  static Future<int> contarPeriodosActivos() async {
    try {
      final periodoQuery = await _firestore
          .collection('periodos')
          .where('activo', isEqualTo: true)
          .get();

      return periodoQuery.docs.length;
    } catch (e) {
      debugPrint('Error contando períodos activos: $e');
      return 0;
    }
  }
}
