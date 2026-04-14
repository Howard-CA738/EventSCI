// test/estudiante_screen_test.dart
//
// Pruebas unitarias para la lógica pura de EstudianteScreen.
// Se replican / extraen los helpers privados del State para aislarlos
// de Flutter, Firebase y PrefsHelper.
//
// Ejecutar:
//   flutter test test/estudiante_screen_test.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RÉPLICAS DE LA LÓGICA PURA DE _EstudianteScreenState
// Se recomienda mover estas funciones a lib/utils/estudiante_utils.dart
// ─────────────────────────────────────────────────────────────────────────────

/// Réplica de la lógica de parseo de campos académicos desde userData.
/// Devuelve un mapa con 'filial', 'facultad' y 'carrera' (cadenas, nunca null).
Map<String, String> extraerCamposAcademicos(Map<String, dynamic> userData) {
  return {
    'filial':   userData['filial']?.toString().trim()   ?? '',
    'facultad': userData['facultad']?.toString().trim() ?? '',
    'carrera':  userData['carrera']?.toString().trim()  ?? '',
  };
}

/// Réplica de la lógica de _loadStudentData: determina si se necesita
/// consultar el documento padre en Firestore.
bool necesitaDocPadre(Map<String, String> campos) {
  return campos['filial']!.isEmpty ||
      campos['facultad']!.isEmpty ||
      campos['carrera']!.isEmpty;
}

/// Réplica de la lógica de fallback desde carreraPath cuando el doc padre
/// no resuelve todos los campos.
/// Recibe el carreraPath y los campos actuales; devuelve campos actualizados.
Map<String, String> aplicarFallbackDesdeCarreraPath(
  String carreraPath,
  Map<String, String> campos,
) {
  if (!carreraPath.contains('_')) return campos;

  final resultado = Map<String, String>.from(campos);
  final parts = carreraPath.split('_');

  if (resultado['filial']!.isEmpty) {
    resultado['filial'] = parts.first.trim();
  }
  if (resultado['carrera']!.isEmpty) {
    resultado['carrera'] = parts.skip(1).join('_').trim();
  }
  return resultado;
}

/// Réplica de la lógica de setState final: convierte cadenas vacías a null.
({String? filial, String? facultad, String? carrera}) resolverCamposFinales(
  Map<String, String> campos,
) {
  return (
    filial:   campos['filial']!.isNotEmpty   ? campos['filial']   : null,
    facultad: campos['facultad']!.isNotEmpty ? campos['facultad'] : null,
    carrera:  campos['carrera']!.isNotEmpty  ? campos['carrera']  : null,
  );
}

/// Réplica de la lógica del botón "Entendido": texto según segundos restantes.
String textoBotonEntendido(int segundos) {
  return segundos > 0 ? 'Entendido ($segundos)' : 'Entendido';
}

/// Réplica de la lógica del botón: habilitado solo cuando segundos <= 0.
bool botonHabilitado(int segundos) => segundos <= 0;

/// Réplica de la lógica de cuenta regresiva: decrementa hasta 0.
int decrementarSegundos(int segundos) {
  return segundos > 0 ? segundos - 1 : 0;
}

/// Indica si los info-chips del welcome card deben mostrarse.
bool mostrarInfoChips({
  required String? filial,
  required String? facultad,
  required String? carrera,
}) =>
    filial != null || facultad != null || carrera != null;

// ─────────────────────────────────────────────────────────────────────────────
// TESTS
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  group('extraerCamposAcademicos — parseo desde userData', () {
    test('extrae los tres campos cuando todos están presentes', () {
      final datos = {
        'filial':   'Lima',
        'facultad': 'Ingeniería',
        'carrera':  'Sistemas',
      };
      final resultado = extraerCamposAcademicos(datos);
      expect(resultado['filial'],   'Lima');
      expect(resultado['facultad'], 'Ingeniería');
      expect(resultado['carrera'],  'Sistemas');
    });

    test('aplica trim a los valores', () {
      final datos = {
        'filial':   '  Juliaca  ',
        'facultad': ' Ciencias ',
        'carrera':  ' Biología ',
      };
      final resultado = extraerCamposAcademicos(datos);
      expect(resultado['filial'],   'Juliaca');
      expect(resultado['facultad'], 'Ciencias');
      expect(resultado['carrera'],  'Biología');
    });

    test('devuelve cadena vacía para campos ausentes', () {
      final resultado = extraerCamposAcademicos({});
      expect(resultado['filial'],   '');
      expect(resultado['facultad'], '');
      expect(resultado['carrera'],  '');
    });

    test('devuelve cadena vacía para campos con valor null explícito', () {
      final datos = {'filial': null, 'facultad': null, 'carrera': null};
      final resultado = extraerCamposAcademicos(datos);
      expect(resultado['filial'],   '');
      expect(resultado['facultad'], '');
      expect(resultado['carrera'],  '');
    });

    test('convierte valores no-String a String', () {
      final datos = {'filial': 123, 'facultad': true, 'carrera': 0};
      final resultado = extraerCamposAcademicos(datos);
      expect(resultado['filial'],   '123');
      expect(resultado['facultad'], 'true');
      expect(resultado['carrera'],  '0');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('necesitaDocPadre — determina si consultar Firestore', () {
    test('false cuando los tres campos están completos', () {
      final campos = {
        'filial': 'Lima', 'facultad': 'Ingeniería', 'carrera': 'Sistemas'
      };
      expect(necesitaDocPadre(campos), isFalse);
    });

    test('true cuando filial está vacía', () {
      final campos = {'filial': '', 'facultad': 'Ingeniería', 'carrera': 'Sistemas'};
      expect(necesitaDocPadre(campos), isTrue);
    });

    test('true cuando facultad está vacía', () {
      final campos = {'filial': 'Lima', 'facultad': '', 'carrera': 'Sistemas'};
      expect(necesitaDocPadre(campos), isTrue);
    });

    test('true cuando carrera está vacía', () {
      final campos = {'filial': 'Lima', 'facultad': 'Ingeniería', 'carrera': ''};
      expect(necesitaDocPadre(campos), isTrue);
    });

    test('true cuando los tres campos están vacíos', () {
      final campos = {'filial': '', 'facultad': '', 'carrera': ''};
      expect(necesitaDocPadre(campos), isTrue);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('aplicarFallbackDesdeCarreraPath — parseo del path', () {
    test('extrae filial y carrera de "Lima_Sistemas"', () {
      final campos = {'filial': '', 'facultad': '', 'carrera': ''};
      final resultado = aplicarFallbackDesdeCarreraPath('Lima_Sistemas', campos);
      expect(resultado['filial'],  'Lima');
      expect(resultado['carrera'], 'Sistemas');
    });

    test('preserva carrera con múltiples guiones bajos "Lima_Ing_Sistemas"', () {
      final campos = {'filial': '', 'facultad': '', 'carrera': ''};
      final resultado =
          aplicarFallbackDesdeCarreraPath('Lima_Ing_Sistemas', campos);
      expect(resultado['filial'],  'Lima');
      expect(resultado['carrera'], 'Ing_Sistemas');
    });

    test('no sobreescribe filial si ya tiene valor', () {
      final campos = {'filial': 'Arequipa', 'facultad': '', 'carrera': ''};
      final resultado = aplicarFallbackDesdeCarreraPath('Lima_Sistemas', campos);
      expect(resultado['filial'], 'Arequipa'); // no cambia
      expect(resultado['carrera'], 'Sistemas');
    });

    test('no sobreescribe carrera si ya tiene valor', () {
      final campos = {'filial': '', 'facultad': '', 'carrera': 'Derecho'};
      final resultado = aplicarFallbackDesdeCarreraPath('Lima_Sistemas', campos);
      expect(resultado['filial'],  'Lima');
      expect(resultado['carrera'], 'Derecho'); // no cambia
    });

    test('no hace nada si el path no contiene "_"', () {
      final campos = {'filial': '', 'facultad': '', 'carrera': ''};
      final resultado = aplicarFallbackDesdeCarreraPath('SinSeparador', campos);
      expect(resultado['filial'],  '');
      expect(resultado['carrera'], '');
    });

    test('no hace nada si el path está vacío', () {
      final campos = {'filial': '', 'facultad': '', 'carrera': ''};
      final resultado = aplicarFallbackDesdeCarreraPath('', campos);
      expect(resultado['filial'],  '');
      expect(resultado['carrera'], '');
    });

    test('facultad nunca se modifica (no está en el path)', () {
      final campos = {'filial': '', 'facultad': '', 'carrera': ''};
      final resultado = aplicarFallbackDesdeCarreraPath('Lima_Sistemas', campos);
      expect(resultado['facultad'], ''); // siempre vacía desde el path
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('resolverCamposFinales — cadenas vacías → null', () {
    test('devuelve los tres valores cuando todos están completos', () {
      final campos = {
        'filial': 'Lima', 'facultad': 'Ingeniería', 'carrera': 'Sistemas'
      };
      final r = resolverCamposFinales(campos);
      expect(r.filial,   'Lima');
      expect(r.facultad, 'Ingeniería');
      expect(r.carrera,  'Sistemas');
    });

    test('convierte cadena vacía a null para filial', () {
      final campos = {'filial': '', 'facultad': 'Ciencias', 'carrera': 'Bio'};
      expect(resolverCamposFinales(campos).filial, isNull);
    });

    test('convierte cadena vacía a null para facultad', () {
      final campos = {'filial': 'Lima', 'facultad': '', 'carrera': 'Bio'};
      expect(resolverCamposFinales(campos).facultad, isNull);
    });

    test('convierte cadena vacía a null para carrera', () {
      final campos = {'filial': 'Lima', 'facultad': 'Ciencias', 'carrera': ''};
      expect(resolverCamposFinales(campos).carrera, isNull);
    });

    test('los tres campos vacíos producen todos null', () {
      final campos = {'filial': '', 'facultad': '', 'carrera': ''};
      final r = resolverCamposFinales(campos);
      expect(r.filial,   isNull);
      expect(r.facultad, isNull);
      expect(r.carrera,  isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('textoBotonEntendido — cuenta regresiva', () {
    test('muestra countdown cuando segundos > 0', () {
      expect(textoBotonEntendido(5), 'Entendido (5)');
      expect(textoBotonEntendido(3), 'Entendido (3)');
      expect(textoBotonEntendido(1), 'Entendido (1)');
    });

    test('muestra solo "Entendido" cuando segundos == 0', () {
      expect(textoBotonEntendido(0), 'Entendido');
    });

    test('no muestra paréntesis cuando segundos == 0', () {
      expect(textoBotonEntendido(0).contains('('), isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('botonHabilitado — activación del botón', () {
    test('deshabilitado cuando segundos > 0', () {
      expect(botonHabilitado(5), isFalse);
      expect(botonHabilitado(1), isFalse);
    });

    test('habilitado cuando segundos == 0', () {
      expect(botonHabilitado(0), isTrue);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('decrementarSegundos — lógica de cuenta regresiva', () {
    test('decrementa de 5 a 4', () {
      expect(decrementarSegundos(5), 4);
    });

    test('decrementa de 1 a 0', () {
      expect(decrementarSegundos(1), 0);
    });

    test('no va por debajo de 0', () {
      expect(decrementarSegundos(0), 0);
    });

    test('simulación completa de 5 segundos', () {
      int seg = 5;
      while (seg > 0) {
        seg = decrementarSegundos(seg);
      }
      expect(seg, 0);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('mostrarInfoChips — visibilidad del welcome card', () {
    test('true cuando solo filial está presente', () {
      expect(
        mostrarInfoChips(filial: 'Lima', facultad: null, carrera: null),
        isTrue,
      );
    });

    test('true cuando solo facultad está presente', () {
      expect(
        mostrarInfoChips(filial: null, facultad: 'Ingeniería', carrera: null),
        isTrue,
      );
    });

    test('true cuando solo carrera está presente', () {
      expect(
        mostrarInfoChips(filial: null, facultad: null, carrera: 'Sistemas'),
        isTrue,
      );
    });

    test('true cuando los tres están presentes', () {
      expect(
        mostrarInfoChips(
            filial: 'Lima', facultad: 'Ingeniería', carrera: 'Sistemas'),
        isTrue,
      );
    });

    test('false cuando los tres son null', () {
      expect(
        mostrarInfoChips(filial: null, facultad: null, carrera: null),
        isFalse,
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('integración: flujo completo de carga de datos', () {
    test('userData completo no necesita doc padre', () {
      final userData = {
        'filial': 'Lima', 'facultad': 'Ingeniería', 'carrera': 'Sistemas'
      };
      final campos = extraerCamposAcademicos(userData);
      expect(necesitaDocPadre(campos), isFalse);

      final finales = resolverCamposFinales(campos);
      expect(finales.filial,   'Lima');
      expect(finales.facultad, 'Ingeniería');
      expect(finales.carrera,  'Sistemas');

      expect(mostrarInfoChips(
        filial: finales.filial,
        facultad: finales.facultad,
        carrera: finales.carrera,
      ), isTrue);
    });

    test('userData vacío aplica fallback desde carreraPath', () {
      final userData = <String, dynamic>{};
      var campos = extraerCamposAcademicos(userData);
      expect(necesitaDocPadre(campos), isTrue);

      // Simula que el doc padre tampoco tenía datos; aplica fallback
      campos = aplicarFallbackDesdeCarreraPath('Juliaca_Contabilidad', campos);
      expect(campos['filial'],  'Juliaca');
      expect(campos['carrera'], 'Contabilidad');

      final finales = resolverCamposFinales(campos);
      expect(finales.filial,   'Juliaca');
      expect(finales.facultad, isNull);    // nunca se resuelve desde el path
      expect(finales.carrera,  'Contabilidad');
    });

    test('fallback no sobreescribe campos ya resueltos por el doc padre', () {
      // Simula doc padre que resolvió filial y facultad, pero no carrera
      final camposConDocPadre = {
        'filial': 'Arequipa', 'facultad': 'Ciencias', 'carrera': ''
      };
      final conFallback = aplicarFallbackDesdeCarreraPath(
          'Lima_Sistemas', camposConDocPadre);

      // filial ya estaba → no cambia; carrera vacía → se toma del path
      expect(conFallback['filial'],   'Arequipa');
      expect(conFallback['facultad'], 'Ciencias');
      expect(conFallback['carrera'],  'Sistemas');
    });

    test('cuenta regresiva llega a 0 y habilita el botón', () {
      int seg = 5;
      while (seg > 0) {
        expect(botonHabilitado(seg), isFalse);
        expect(textoBotonEntendido(seg), contains('($seg)'));
        seg = decrementarSegundos(seg);
      }
      expect(botonHabilitado(0), isTrue);
      expect(textoBotonEntendido(0), 'Entendido');
    });
  });
}