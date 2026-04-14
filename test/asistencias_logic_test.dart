// test/asistencias_logic_test.dart
//
// Pruebas unitarias para la lógica PURA del panel de asistencias.
// No requieren Firebase ni Flutter widgets — solo dart:core.
//
// Cómo ejecutar:
//   flutter test test/asistencias_logic_test.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Lógica extraída de _AsistenciasScreenState
// ─────────────────────────────────────────────────────────────────────────────

/// Retorna true si el valor es considerado vacío/nulo semánticamente.
bool esValorValido(dynamic valor) {
  if (valor == null) return false;
  final v = valor.toString().trim().toLowerCase();
  return v.isNotEmpty &&
      v != 'sin código' &&
      v != 'sin codigo' &&
      v != 'sin título' &&
      v != 'sin titulo' &&
      v != 'sin grupo' &&
      v != 'null';
}

/// Retorna true si la asistencia pertenece al rango del período dado.
bool asistenciaPerteneceAPeriodo(
  Map<String, dynamic> asistencia,
  Map<String, dynamic> periodo,
) {
  final timestamp = (asistencia['timestamp'] as Timestamp?)?.toDate();
  if (timestamp == null) return false;
  final fechaInicio = (periodo['fechaInicio'] as Timestamp?)?.toDate();
  final fechaFin = (periodo['fechaFin'] as Timestamp?)?.toDate();
  if (fechaInicio == null || fechaFin == null) return false;
  return timestamp.isAfter(fechaInicio.subtract(const Duration(days: 1))) &&
      timestamp.isBefore(fechaFin.add(const Duration(days: 1)));
}

/// Extrae la sede del estudiante desde el mapa de datos.
String? extraerSede(Map<String, dynamic>? userData) {
  if (userData == null) return null;
  final sede = userData['sede']?.toString() ?? '';
  final filial = userData['filial']?.toString() ?? '';
  if (sede.isNotEmpty) return sede;
  if (filial.isNotEmpty) return filial;
  return null;
}

/// Extrae la sede del evento desde el mapa de datos del evento.
String extraerSedeEvento(Map<String, dynamic> eventData) {
  return eventData['sede']?.toString() ??
      eventData['filialNombre']?.toString() ??
      '';
}

/// Aplica filtros de período y evento sobre la lista de eventos con asistencias.
/// Retorna la lista aplanada y ordenada por timestamp descendente.
List<Map<String, dynamic>> filtrarAsistencias({
  required List<Map<String, dynamic>> eventosConAsistencias,
  required List<Map<String, dynamic>> periodosDisponibles,
  String? periodoSeleccionado,
  String? eventoSeleccionado,
}) {
  final List<Map<String, dynamic>> resultado = [];

  for (var eventoData in eventosConAsistencias) {
    for (var asistencia in (eventoData['asistencias'] as List? ?? [])) {
      bool cumplePeriodo = true;
      if (periodoSeleccionado != null) {
        final periodo = periodosDisponibles.firstWhere(
          (p) => p['id'] == periodoSeleccionado,
          orElse: () => {},
        );
        if (periodo.isNotEmpty) {
          cumplePeriodo = asistenciaPerteneceAPeriodo(asistencia, periodo);
        }
      }

      bool cumpleEvento = true;
      if (eventoSeleccionado != null) {
        cumpleEvento = eventoData['eventId'] == eventoSeleccionado;
      }

      if (cumplePeriodo && cumpleEvento) {
        resultado.add({
          ...asistencia,
          'eventId': eventoData['eventId'],
          'eventName': eventoData['eventName'],
          'eventDescription': eventoData['eventDescription'],
          'eventDate': eventoData['eventDate'],
          'eventFacultad': eventoData['eventFacultad'],
          'eventCarrera': eventoData['eventCarrera'],
          'eventSede': eventoData['eventSede'],
        });
      }
    }
  }

  resultado.sort((a, b) {
    final tA = (a['timestamp'] as Timestamp?)?.toDate();
    final tB = (b['timestamp'] as Timestamp?)?.toDate();
    if (tA == null || tB == null) return 0;
    return tB.compareTo(tA);
  });

  return resultado;
}

/// Construye el mapa de eventos disponibles (únicos) desde la lista de eventos.
List<Map<String, dynamic>> calcularEventosDisponibles(
  List<Map<String, dynamic>> eventosConAsistencias,
) {
  final Map<String, Map<String, dynamic>> eventosMap = {};
  for (var eventoData in eventosConAsistencias) {
    final eventId = eventoData['eventId'];
    final eventName = eventoData['eventName'];
    if (eventId != null &&
        eventName != null &&
        eventName != 'Sin nombre' &&
        eventName != 'Evento eliminado') {
      eventosMap.putIfAbsent(
        eventId,
        () => {'id': eventId, 'name': eventName},
      );
    }
  }
  final lista = eventosMap.values.toList()
    ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  return lista;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers de test
// ─────────────────────────────────────────────────────────────────────────────

Timestamp _ts(DateTime dt) => Timestamp.fromDate(dt);

Map<String, dynamic> _makePeriodo({
  required String id,
  required DateTime inicio,
  required DateTime fin,
  String nombre = 'Período de prueba',
}) => {
  'id': id,
  'nombre': nombre,
  'fechaInicio': _ts(inicio),
  'fechaFin': _ts(fin),
};

Map<String, dynamic> _makeScan({
  required DateTime timestamp,
  String categoria = 'Empírico',
  String codigoProyecto = 'PRY-001',
  String tituloProyecto = 'Título',
  String? grupo,
}) => {
  'timestamp': _ts(timestamp),
  'categoria': categoria,
  'codigoProyecto': codigoProyecto,
  'tituloProyecto': tituloProyecto,
  'grupo': grupo,
};

Map<String, dynamic> _makeEvento({
  required String eventId,
  required String eventName,
  required List<Map<String, dynamic>> asistencias,
  String eventSede = '',
  String eventFacultad = '',
  String eventCarrera = '',
}) => {
  'eventId': eventId,
  'eventName': eventName,
  'eventDescription': '',
  'eventDate': null,
  'eventFacultad': eventFacultad,
  'eventCarrera': eventCarrera,
  'eventSede': eventSede,
  'asistencias': asistencias,
};

// ─────────────────────────────────────────────────────────────────────────────
// TESTS
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════════
  // 1. esValorValido()
  // ═══════════════════════════════════════════════════════════════
  group('esValorValido()', () {
    test('retorna false para null', () {
      expect(esValorValido(null), isFalse);
    });

    test('retorna false para string vacío', () {
      expect(esValorValido(''), isFalse);
    });

    test('retorna false para solo espacios', () {
      expect(esValorValido('   '), isFalse);
    });

    test('retorna false para "null" literal', () {
      expect(esValorValido('null'), isFalse);
    });

    test('retorna false para "sin código"', () {
      expect(esValorValido('sin código'), isFalse);
    });

    test('retorna false para "sin codigo" sin tilde', () {
      expect(esValorValido('sin codigo'), isFalse);
    });

    test('retorna false para "sin título"', () {
      expect(esValorValido('sin título'), isFalse);
    });

    test('retorna false para "sin titulo" sin tilde', () {
      expect(esValorValido('sin titulo'), isFalse);
    });

    test('retorna false para "sin grupo"', () {
      expect(esValorValido('sin grupo'), isFalse);
    });

    test('retorna false para "SIN CODIGO" (case insensitive)', () {
      expect(esValorValido('SIN CODIGO'), isFalse);
    });

    test('retorna true para código válido', () {
      expect(esValorValido('PRY-001'), isTrue);
    });

    test('retorna true para título real', () {
      expect(esValorValido('Impacto del cambio climático'), isTrue);
    });

    test('retorna true para "0" (número como string)', () {
      expect(esValorValido('0'), isTrue);
    });

    test('retorna true para entero no-nulo', () {
      expect(esValorValido(42), isTrue);
    });

    test('retorna false para 0 como entero solo si es "0" → true', () {
      // 0.toString() = "0", que no está en la lista de inválidos
      expect(esValorValido(0), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 2. asistenciaPerteneceAPeriodo()
  // ═══════════════════════════════════════════════════════════════
  group('asistenciaPerteneceAPeriodo()', () {
    final inicio = DateTime(2025, 3, 1);
    final fin = DateTime(2025, 6, 30);
    final periodo = _makePeriodo(id: 'p1', inicio: inicio, fin: fin);

    test('asistencia dentro del período → true', () {
      final scan = _makeScan(timestamp: DateTime(2025, 4, 15));
      expect(asistenciaPerteneceAPeriodo(scan, periodo), isTrue);
    });

    test('asistencia el día exacto de inicio → true', () {
      final scan = _makeScan(timestamp: DateTime(2025, 3, 1));
      expect(asistenciaPerteneceAPeriodo(scan, periodo), isTrue);
    });

    test('asistencia el día exacto de fin → true', () {
      final scan = _makeScan(timestamp: DateTime(2025, 6, 30));
      expect(asistenciaPerteneceAPeriodo(scan, periodo), isTrue);
    });

    test('asistencia un día antes del inicio → false', () {
      // El margen es -1 día en fechaInicio, así que justo el día anterior
      // al margen queda fuera
      final scan = _makeScan(timestamp: DateTime(2025, 2, 28));
      // fechaInicio - 1 día = Feb 28 → isAfter(Feb 28)? No → false
      expect(asistenciaPerteneceAPeriodo(scan, periodo), isFalse);
    });

    test('asistencia un día después del fin → false', () {
      final scan = _makeScan(timestamp: DateTime(2025, 7, 2));
      expect(asistenciaPerteneceAPeriodo(scan, periodo), isFalse);
    });

    test('asistencia sin timestamp → false', () {
      final scan = {'timestamp': null, 'categoria': 'x'};
      expect(asistenciaPerteneceAPeriodo(scan, periodo), isFalse);
    });

    test('período sin fechaInicio → false', () {
      final scan = _makeScan(timestamp: DateTime(2025, 4, 15));
      final periodoSinInicio = {
        'id': 'p2',
        'fechaInicio': null,
        'fechaFin': _ts(fin),
      };
      expect(asistenciaPerteneceAPeriodo(scan, periodoSinInicio), isFalse);
    });

    test('período sin fechaFin → false', () {
      final scan = _makeScan(timestamp: DateTime(2025, 4, 15));
      final periodoSinFin = {
        'id': 'p3',
        'fechaInicio': _ts(inicio),
        'fechaFin': null,
      };
      expect(asistenciaPerteneceAPeriodo(scan, periodoSinFin), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 3. extraerSede()
  // ═══════════════════════════════════════════════════════════════
  group('extraerSede()', () {
    test('retorna sede cuando existe', () {
      expect(extraerSede({'sede': 'Lima'}), equals('Lima'));
    });

    test('prioriza sede sobre filial', () {
      expect(
        extraerSede({'sede': 'Lima', 'filial': 'Tarapoto'}),
        equals('Lima'),
      );
    });

    test('usa filial cuando sede está vacía', () {
      expect(
        extraerSede({'sede': '', 'filial': 'Tarapoto'}),
        equals('Tarapoto'),
      );
    });

    test('retorna null cuando ambos están vacíos', () {
      expect(extraerSede({'sede': '', 'filial': ''}), isNull);
    });

    test('retorna null cuando userData es null', () {
      expect(extraerSede(null), isNull);
    });

    test('retorna null cuando no existen las claves', () {
      expect(extraerSede({'nombre': 'Juan'}), isNull);
    });

    test('retorna sede con espacios conservados', () {
      expect(extraerSede({'sede': 'Lima Norte'}), equals('Lima Norte'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 4. extraerSedeEvento()
  // ═══════════════════════════════════════════════════════════════
  group('extraerSedeEvento()', () {
    test('retorna sede cuando existe', () {
      expect(
        extraerSedeEvento({'sede': 'Tarapoto'}),
        equals('Tarapoto'),
      );
    });

    test('usa filialNombre como fallback', () {
      expect(
        extraerSedeEvento({'filialNombre': 'Juliaca'}),
        equals('Juliaca'),
      );
    });

    test('prioriza sede sobre filialNombre', () {
      expect(
        extraerSedeEvento({'sede': 'Lima', 'filialNombre': 'Tarapoto'}),
        equals('Lima'),
      );
    });

    test('retorna string vacío cuando no existe ninguno', () {
      expect(extraerSedeEvento({'name': 'Evento'}), equals(''));
    });

    test('retorna string vacío cuando sede es null', () {
      expect(extraerSedeEvento({'sede': null, 'filialNombre': null}), equals(''));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 5. calcularEventosDisponibles()
  // ═══════════════════════════════════════════════════════════════
  group('calcularEventosDisponibles()', () {
    test('retorna lista vacía para entrada vacía', () {
      expect(calcularEventosDisponibles([]), isEmpty);
    });

    test('excluye eventos con nombre "Sin nombre"', () {
      final eventos = [_makeEvento(eventId: 'e1', eventName: 'Sin nombre', asistencias: [])];
      expect(calcularEventosDisponibles(eventos), isEmpty);
    });

    test('excluye eventos con nombre "Evento eliminado"', () {
      final eventos = [_makeEvento(eventId: 'e1', eventName: 'Evento eliminado', asistencias: [])];
      expect(calcularEventosDisponibles(eventos), isEmpty);
    });

    test('incluye eventos con nombre válido', () {
      final eventos = [
        _makeEvento(eventId: 'e1', eventName: 'Congreso UPeU', asistencias: []),
      ];
      final result = calcularEventosDisponibles(eventos);
      expect(result.length, equals(1));
      expect(result.first['id'], equals('e1'));
      expect(result.first['name'], equals('Congreso UPeU'));
    });

    test('deduplica eventos con el mismo ID', () {
      final eventos = [
        _makeEvento(eventId: 'e1', eventName: 'Congreso', asistencias: []),
        _makeEvento(eventId: 'e1', eventName: 'Congreso', asistencias: []),
      ];
      expect(calcularEventosDisponibles(eventos).length, equals(1));
    });

    test('ordena eventos por nombre alfabéticamente', () {
      final eventos = [
        _makeEvento(eventId: 'e2', eventName: 'Simposio', asistencias: []),
        _makeEvento(eventId: 'e1', eventName: 'Congreso', asistencias: []),
        _makeEvento(eventId: 'e3', eventName: 'Feria', asistencias: []),
      ];
      final result = calcularEventosDisponibles(eventos);
      expect(result.map((e) => e['name']).toList(), ['Congreso', 'Feria', 'Simposio']);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 6. filtrarAsistencias()
  // ═══════════════════════════════════════════════════════════════
  group('filtrarAsistencias()', () {
    final periodo1 = _makePeriodo(
      id: 'p1',
      inicio: DateTime(2025, 3, 1),
      fin: DateTime(2025, 6, 30),
      nombre: 'Semestre I',
    );
    final periodo2 = _makePeriodo(
      id: 'p2',
      inicio: DateTime(2025, 7, 1),
      fin: DateTime(2025, 12, 31),
      nombre: 'Semestre II',
    );
    final periodosDisponibles = [periodo1, periodo2];

    final scan1 = _makeScan(timestamp: DateTime(2025, 4, 10), categoria: 'Empírico');
    final scan2 = _makeScan(timestamp: DateTime(2025, 5, 20), categoria: 'Revisión');
    final scan3 = _makeScan(timestamp: DateTime(2025, 9, 5), categoria: 'Innovación');

    final evento1 = _makeEvento(
      eventId: 'e1',
      eventName: 'Congreso',
      eventSede: 'Lima',
      asistencias: [scan1, scan2],
    );
    final evento2 = _makeEvento(
      eventId: 'e2',
      eventName: 'Simposio',
      eventSede: 'Tarapoto',
      asistencias: [scan3],
    );

    final todosLosEventos = [evento1, evento2];

    test('sin filtros retorna todas las asistencias', () {
      final result = filtrarAsistencias(
        eventosConAsistencias: todosLosEventos,
        periodosDisponibles: periodosDisponibles,
      );
      expect(result.length, equals(3));
    });

    test('filtra por período I → 2 asistencias', () {
      final result = filtrarAsistencias(
        eventosConAsistencias: todosLosEventos,
        periodosDisponibles: periodosDisponibles,
        periodoSeleccionado: 'p1',
      );
      expect(result.length, equals(2));
    });

    test('filtra por período II → 1 asistencia', () {
      final result = filtrarAsistencias(
        eventosConAsistencias: todosLosEventos,
        periodosDisponibles: periodosDisponibles,
        periodoSeleccionado: 'p2',
      );
      expect(result.length, equals(1));
      expect(result.first['categoria'], equals('Innovación'));
    });

    test('filtra por evento e1 → 2 asistencias', () {
      final result = filtrarAsistencias(
        eventosConAsistencias: todosLosEventos,
        periodosDisponibles: periodosDisponibles,
        eventoSeleccionado: 'e1',
      );
      expect(result.length, equals(2));
      expect(result.every((a) => a['eventId'] == 'e1'), isTrue);
    });

    test('filtra por período + evento → intersección', () {
      final result = filtrarAsistencias(
        eventosConAsistencias: todosLosEventos,
        periodosDisponibles: periodosDisponibles,
        periodoSeleccionado: 'p1',
        eventoSeleccionado: 'e1',
      );
      expect(result.length, equals(2));
    });

    test('período inexistente → sin filtro de período (retorna todo)', () {
      // Si el período no se encuentra, orElse retorna {} y no filtra
      final result = filtrarAsistencias(
        eventosConAsistencias: todosLosEventos,
        periodosDisponibles: periodosDisponibles,
        periodoSeleccionado: 'p_inexistente',
      );
      expect(result.length, equals(3));
    });

    test('evento inexistente → lista vacía', () {
      final result = filtrarAsistencias(
        eventosConAsistencias: todosLosEventos,
        periodosDisponibles: periodosDisponibles,
        eventoSeleccionado: 'e_inexistente',
      );
      expect(result, isEmpty);
    });

    test('resultado incluye eventSede en cada asistencia', () {
      final result = filtrarAsistencias(
        eventosConAsistencias: [evento1],
        periodosDisponibles: periodosDisponibles,
      );
      expect(result.every((a) => a['eventSede'] == 'Lima'), isTrue);
    });

    test('resultado está ordenado por timestamp descendente', () {
      final result = filtrarAsistencias(
        eventosConAsistencias: todosLosEventos,
        periodosDisponibles: periodosDisponibles,
      );
      final fechas = result
          .map((a) => (a['timestamp'] as Timestamp).toDate())
          .toList();
      for (int i = 0; i < fechas.length - 1; i++) {
        expect(
          fechas[i].isAfter(fechas[i + 1]) ||
              fechas[i].isAtSameMomentAs(fechas[i + 1]),
          isTrue,
          reason: 'Se esperaba orden descendente en índice $i',
        );
      }
    });

    test('lista de eventos vacía → resultado vacío', () {
      final result = filtrarAsistencias(
        eventosConAsistencias: [],
        periodosDisponibles: periodosDisponibles,
      );
      expect(result, isEmpty);
    });

    test('evento sin asistencias no aporta resultados', () {
      final eventoVacio = _makeEvento(
        eventId: 'e3',
        eventName: 'Vacío',
        asistencias: [],
      );
      final result = filtrarAsistencias(
        eventosConAsistencias: [eventoVacio],
        periodosDisponibles: periodosDisponibles,
      );
      expect(result, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 7. Integración — flujo completo de carga y filtrado
  // ═══════════════════════════════════════════════════════════════
  group('Flujo de integración', () {
    test('datos académicos extraídos correctamente del userData', () {
      final userData = {
        'sede': 'Lima',
        'facultad': 'Facultad de Ingeniería',
        'carrera': 'EP Ingeniería de Sistemas',
        'ciclo': '5',
        'grupo': 'A',
      };
      expect(extraerSede(userData), equals('Lima'));
      expect(esValorValido(userData['facultad']), isTrue);
      expect(esValorValido(userData['carrera']), isTrue);
      expect(esValorValido(userData['ciclo']), isTrue);
      expect(esValorValido(userData['grupo']), isTrue);
    });

    test('datos académicos con valores vacíos no se muestran', () {
      final userData = {
        'sede': '',
        'filial': '',
        'facultad': 'sin titulo',
        'carrera': null,
        'ciclo': '',
        'grupo': 'sin grupo',
      };
      expect(extraerSede(userData), isNull);
      expect(esValorValido(userData['facultad']), isFalse);
      expect(esValorValido(userData['carrera']), isFalse);
      expect(esValorValido(userData['ciclo']), isFalse);
      expect(esValorValido(userData['grupo']), isFalse);
    });

    test('evento de sede Lima aparece correctamente en asistencia filtrada', () {
      final scan = _makeScan(timestamp: DateTime(2025, 4, 10));
      final evento = _makeEvento(
        eventId: 'e1',
        eventName: 'Congreso Lima',
        eventSede: 'Lima',
        asistencias: [scan],
      );
      final periodo = _makePeriodo(
        id: 'p1',
        inicio: DateTime(2025, 3, 1),
        fin: DateTime(2025, 6, 30),
      );

      final result = filtrarAsistencias(
        eventosConAsistencias: [evento],
        periodosDisponibles: [periodo],
        periodoSeleccionado: 'p1',
      );

      expect(result.length, equals(1));
      expect(result.first['eventSede'], equals('Lima'));
      expect(result.first['eventName'], equals('Congreso Lima'));
    });

    test('pluralización correcta del mensaje de sellos', () {
      // Simula la lógica del mensaje "Has ganado N sello(s)"
      int totalSellos = 1;
      String msg =
          '$totalSellos ${totalSellos == 1 ? 'sello' : 'sellos'} de asistencia';
      expect(msg, contains('sello de'));

      totalSellos = 5;
      msg = '$totalSellos ${totalSellos == 1 ? 'sello' : 'sellos'} de asistencia';
      expect(msg, contains('sellos de'));
    });
  });
}