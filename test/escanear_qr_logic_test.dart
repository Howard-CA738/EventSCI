// test/escanear_qr_logic_test.dart
//
// Pruebas unitarias para la lógica PURA del panel de estudiante.
// No requieren Firebase ni Flutter widgets — solo dart:core.
//
// Cómo ejecutar:
//   flutter test test/escanear_qr_logic_test.dart
//
// Dependencias necesarias en pubspec.yaml (ya las tienes):
//   dev_dependencies:
//     flutter_test:
//       sdk: flutter

import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Lógica extraída de _EscanearQRScreenState
// (copia fiel de los métodos privados para poder testearlos en aislamiento)
// ─────────────────────────────────────────────────────────────────────────────

/// Normaliza un string: minúsculas, sin tildes, sin espacios extremos.
String normalizar(String? valor) {
  if (valor == null) return '';
  const Map<String, String> tildes = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c',
  };
  String result = valor.trim().toLowerCase();
  tildes.forEach((tilde, reemplazo) {
    result = result.replaceAll(tilde, reemplazo);
  });
  return result;
}

/// Quita prefijos comunes de carrera antes de comparar.
String normalizarCarrera(String? valor) {
  return normalizar(valor).replaceAll(RegExp(r'^ep\s*'), '');
}

/// Retorna true si el evento es para TODA la UPeU.
bool esEventoUniversitario(Map<String, dynamic> qrInfo) {
  final f = normalizar(qrInfo['facultad']);
  final c = normalizar(qrInfo['carrera']);
  return f == 'universidad peruana union' ||
      f == 'universidad peruana unión' ||
      c == 'general';
}

/// Retorna true si el evento es para TODA una sede.
bool esEventoDeSede(Map<String, dynamic> qrInfo) {
  final c = normalizar(qrInfo['carrera']);
  return c == 'general';
}

/// Compara la sede del QR con la sede del estudiante.
bool sedeCoincide(Map<String, dynamic> qrInfo, String? studentSede) {
  final qrSede = normalizar(qrInfo['sede']);
  if (qrSede.isEmpty) return true;
  final studentSedeNorm = normalizar(studentSede);
  return studentSedeNorm.isEmpty || studentSedeNorm == qrSede;
}

/// Retorna true si el valor es considerado vacío/nulo semánticamente.
bool esBlancoONulo(String? valor) {
  if (valor == null || valor.trim().isEmpty) return true;
  final v = valor.trim().toLowerCase();
  return v == 'null' ||
      v == 'sin código' ||
      v == 'sin codigo' ||
      v == 'sin título' ||
      v == 'sin titulo' ||
      v == 'sin grupo';
}

// ─────────────────────────────────────────────────────────────────────────────
// TESTS
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════════
  // 1. normalizar()
  // ═══════════════════════════════════════════════════════════════
  group('normalizar()', () {
    test('convierte a minúsculas', () {
      expect(normalizar('LIMA'), equals('lima'));
    });

    test('elimina tildes vocales', () {
      expect(normalizar('Á É Í Ó Ú'), equals('a e i o u'));
    });

    test('elimina ñ → n y ç → c', () {
      expect(normalizar('Señor Françés'), equals('senor frances'));
    });

    test('recorta espacios extremos', () {
      expect(normalizar('  Tarapoto  '), equals('tarapoto'));
    });

    test('retorna string vacío para null', () {
      expect(normalizar(null), equals(''));
    });

    test('retorna string vacío para cadena vacía', () {
      expect(normalizar(''), equals(''));
    });

    test('maneja string con solo espacios', () {
      expect(normalizar('   '), equals(''));
    });

    test('conserva caracteres sin tilde correctamente', () {
      expect(normalizar('Administracion'), equals('administracion'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 2. normalizarCarrera()
  // ═══════════════════════════════════════════════════════════════
  group('normalizarCarrera()', () {
    test('quita prefijo "ep " al inicio', () {
      expect(normalizarCarrera('EP Ingeniería de Sistemas'),
          equals('ingenieria de sistemas'));
    });

    test('quita prefijo "ep" sin espacio', () {
      expect(normalizarCarrera('EPContabilidad'), equals('contabilidad'));
    });

    test('no altera carreras sin prefijo', () {
      expect(normalizarCarrera('Medicina Humana'), equals('medicina humana'));
    });

    test('aplica normalización de tildes además del prefijo', () {
      expect(normalizarCarrera('EP Administración'), equals('administracion'));
    });

    test('retorna vacío para null', () {
      expect(normalizarCarrera(null), equals(''));
    });

    test('no quita "ep" en medio del string', () {
      // "ep" solo se elimina al inicio
      expect(normalizarCarrera('Ingeniería ep Sistemas'),
          equals('ingenieria ep sistemas'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 3. esEventoUniversitario()
  // ═══════════════════════════════════════════════════════════════
  group('esEventoUniversitario()', () {
    test('retorna true cuando facultad es "Universidad Peruana Union"', () {
      expect(
        esEventoUniversitario({
          'facultad': 'Universidad Peruana Union',
          'carrera': 'Cualquier carrera',
        }),
        isTrue,
      );
    });

    test('retorna true cuando facultad es "Universidad Peruana Unión" (con tilde)', () {
      expect(
        esEventoUniversitario({
          'facultad': 'Universidad Peruana Unión',
          'carrera': 'x',
        }),
        isTrue,
      );
    });

    test('retorna true cuando carrera es "general"', () {
      expect(
        esEventoUniversitario({
          'facultad': 'Facultad de Ingeniería',
          'carrera': 'General',
        }),
        isTrue,
      );
    });

    test('retorna false para evento de facultad específica', () {
      expect(
        esEventoUniversitario({
          'facultad': 'Facultad de Ingeniería',
          'carrera': 'Ingeniería de Sistemas',
        }),
        isFalse,
      );
    });

    test('es case-insensitive en facultad', () {
      expect(
        esEventoUniversitario({
          'facultad': 'UNIVERSIDAD PERUANA UNION',
          'carrera': 'Sistemas',
        }),
        isTrue,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 4. esEventoDeSede()
  // ═══════════════════════════════════════════════════════════════
  group('esEventoDeSede()', () {
    test('retorna true cuando carrera es "General"', () {
      expect(
        esEventoDeSede({'facultad': 'Ingeniería', 'carrera': 'General'}),
        isTrue,
      );
    });

    test('retorna true cuando carrera es "general" en minúsculas', () {
      expect(
        esEventoDeSede({'facultad': 'Salud', 'carrera': 'general'}),
        isTrue,
      );
    });

    test('retorna false para carrera específica', () {
      expect(
        esEventoDeSede({'facultad': 'Ingeniería', 'carrera': 'Sistemas'}),
        isFalse,
      );
    });

    test('retorna false cuando carrera es null', () {
      expect(
        esEventoDeSede({'facultad': 'Ingeniería', 'carrera': null}),
        isFalse,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 5. sedeCoincide()
  // ═══════════════════════════════════════════════════════════════
  group('sedeCoincide()', () {
    test('retorna true cuando las sedes coinciden (mismo string)', () {
      expect(
        sedeCoincide({'sede': 'Lima'}, 'Lima'),
        isTrue,
      );
    });

    test('es case-insensitive', () {
      expect(
        sedeCoincide({'sede': 'LIMA'}, 'lima'),
        isTrue,
      );
    });

    test('retorna true cuando QR no tiene sede (sin restricción)', () {
      expect(
        sedeCoincide({'sede': ''}, 'Lima'),
        isTrue,
      );
    });

    test('retorna true cuando sede del QR es null', () {
      expect(
        sedeCoincide({'sede': null}, 'Tarapoto'),
        isTrue,
      );
    });

    test('retorna true cuando el estudiante no tiene sede registrada', () {
      // studentSede vacío → sin restricción de lado del estudiante
      expect(
        sedeCoincide({'sede': 'Lima'}, ''),
        isTrue,
      );
    });

    test('retorna true cuando studentSede es null', () {
      expect(
        sedeCoincide({'sede': 'Lima'}, null),
        isTrue,
      );
    });

    test('retorna false cuando las sedes no coinciden', () {
      expect(
        sedeCoincide({'sede': 'Tarapoto'}, 'Lima'),
        isFalse,
      );
    });

    test('compara correctamente sedes con tildes', () {
      // "Juliáca" vs "Juliaca" deben coincidir tras normalización
      expect(
        sedeCoincide({'sede': 'Juliáca'}, 'Juliaca'),
        isTrue,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 6. esBlancoONulo()
  // ═══════════════════════════════════════════════════════════════
  group('esBlancoONulo()', () {
    test('retorna true para null', () {
      expect(esBlancoONulo(null), isTrue);
    });

    test('retorna true para string vacío', () {
      expect(esBlancoONulo(''), isTrue);
    });

    test('retorna true para solo espacios', () {
      expect(esBlancoONulo('   '), isTrue);
    });

    test('retorna true para "null" literal', () {
      expect(esBlancoONulo('null'), isTrue);
    });

    test('retorna true para "sin código"', () {
      expect(esBlancoONulo('sin código'), isTrue);
    });

    test('retorna true para "sin codigo" sin tilde', () {
      expect(esBlancoONulo('sin codigo'), isTrue);
    });

    test('retorna true para "sin título"', () {
      expect(esBlancoONulo('sin título'), isTrue);
    });

    test('retorna true para "sin titulo" sin tilde', () {
      expect(esBlancoONulo('sin titulo'), isTrue);
    });

    test('retorna true para "sin grupo"', () {
      expect(esBlancoONulo('sin grupo'), isTrue);
    });

    test('retorna true para variantes con espacios extra', () {
      expect(esBlancoONulo('  sin codigo  '), isTrue);
    });

    test('retorna false para código válido', () {
      expect(esBlancoONulo('PRY-001'), isFalse);
    });

    test('retorna false para título real', () {
      expect(esBlancoONulo('Proyecto de investigación'), isFalse);
    });

    test('retorna false para "0" (número como string)', () {
      expect(esBlancoONulo('0'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 7. Integración — flujo completo de validación
  // ═══════════════════════════════════════════════════════════════
  group('Flujo de validación completo', () {
    // Simula un estudiante de Lima, Facultad de Ingeniería, Sistemas
    const studentSede = 'Lima';
    const studentFacultad = 'Facultad de Ingeniería';
    const studentCarrera = 'EP Ingeniería de Sistemas';

    Map<String, dynamic> buildQr({
      required String facultad,
      required String carrera,
      String sede = '',
    }) =>
        {'facultad': facultad, 'carrera': carrera, 'sede': sede};

    test('Evento universitario → cualquier estudiante puede entrar', () {
      final qr = buildQr(
        facultad: 'Universidad Peruana Union',
        carrera: 'Cualquier',
        sede: 'Tarapoto',
      );
      expect(esEventoUniversitario(qr), isTrue);
      // No se validan sede ni carrera → acceso permitido
    });

    test('Evento de sede Lima → estudiante Lima puede entrar', () {
      final qr = buildQr(
        facultad: 'Facultad de Ingeniería',
        carrera: 'General',
        sede: 'Lima',
      );
      expect(esEventoUniversitario(qr), isFalse);
      expect(sedeCoincide(qr, studentSede), isTrue);
      expect(esEventoDeSede(qr), isTrue);
      // Carrera = General → no se valida carrera → acceso permitido
    });

    test('Evento de sede Tarapoto → estudiante Lima NO puede entrar', () {
      final qr = buildQr(
        facultad: 'Facultad de Ingeniería',
        carrera: 'General',
        sede: 'Tarapoto',
      );
      expect(esEventoUniversitario(qr), isFalse);
      expect(sedeCoincide(qr, studentSede), isFalse);
      // Sede no coincide → acceso denegado
    });

    test('Evento de carrera específica coincidente → acceso permitido', () {
      final qr = buildQr(
        facultad: 'Facultad de Ingeniería',
        carrera: 'EP Ingeniería de Sistemas',
        sede: 'Lima',
      );
      expect(esEventoUniversitario(qr), isFalse);
      expect(sedeCoincide(qr, studentSede), isTrue);
      expect(esEventoDeSede(qr), isFalse);

      final userFacultad = normalizar(studentFacultad);
      final userCarrera = normalizarCarrera(studentCarrera);
      final eventFacultad = normalizar(qr['facultad']);
      final eventCarrera = normalizarCarrera(qr['carrera']);

      expect(userFacultad, equals(eventFacultad));
      expect(userCarrera, equals(eventCarrera));
      // Facultad y carrera coinciden → acceso permitido
    });

    test('Evento de otra carrera → acceso denegado', () {
      final qr = buildQr(
        facultad: 'Facultad de Ciencias Empresariales',
        carrera: 'Contabilidad',
        sede: 'Lima',
      );
      expect(esEventoUniversitario(qr), isFalse);
      expect(sedeCoincide(qr, studentSede), isTrue);
      expect(esEventoDeSede(qr), isFalse);

      final userFacultad = normalizar(studentFacultad);
      final userCarrera = normalizarCarrera(studentCarrera);
      final eventFacultad = normalizar(qr['facultad']);
      final eventCarrera = normalizarCarrera(qr['carrera']);

      expect(
        userFacultad == eventFacultad && userCarrera == eventCarrera,
        isFalse,
      );
    });
  });
}