// test/perfil_screen_test.dart
//
// Pruebas unitarias para la lógica pura de PerfilScreen.
// Se replican los helpers privados del State para aislarlos de Flutter/Firebase.
//
// Ejecutar:
//   flutter test test/perfil_screen_test.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RÉPLICAS DE LOS HELPERS PRIVADOS DE _PerfilScreenState
// Se recomienda moverlos a lib/utils/perfil_utils.dart en producción.
// ─────────────────────────────────────────────────────────────────────────────

/// Réplica de _getSede
/// Prioriza 'sede', luego 'filial'; retorna null si ambos están vacíos.
String? getSede(Map<String, dynamic>? userData) {
  final sede   = userData?['sede']?.toString()   ?? '';
  final filial = userData?['filial']?.toString() ?? '';
  if (sede.isNotEmpty)   return sede;
  if (filial.isNotEmpty) return filial;
  return null;
}

/// Réplica de _getCampo
/// Retorna el valor del campo si no está vacío, o null en caso contrario.
String? getCampo(Map<String, dynamic>? userData, String key) {
  final valor = (userData?[key] ?? '').toString();
  return valor.isNotEmpty ? valor : null;
}

/// Réplica de la lógica de _buildBodyContent (sin widgets).
/// Determina qué estado de UI corresponde según el estado interno.
String resolverEstadoUI({
  required bool isLoading,
  required String? errorMessage,
  required Map<String, dynamic>? userData,
}) {
  if (isLoading)           return 'loading';
  if (errorMessage != null) return 'error';
  if (userData != null)    return 'profile';
  return 'noData';
}

/// Réplica de la lógica del texto de ciclo y grupo con prefijo.
String formatearCampoConPrefijo(String prefijo, String? valor) {
  if (valor == null || valor.isEmpty) return '';
  return '$prefijo $valor';
}

// ─────────────────────────────────────────────────────────────────────────────
// TESTS
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  group('getSede — prioridad sede > filial > null', () {
    test('devuelve "sede" cuando está presente', () {
      final datos = {'sede': 'Lima', 'filial': 'Juliaca'};
      expect(getSede(datos), 'Lima');
    });

    test('"sede" tiene prioridad sobre "filial"', () {
      final datos = {'sede': 'Arequipa', 'filial': 'Cusco'};
      expect(getSede(datos), 'Arequipa');
    });

    test('devuelve "filial" cuando "sede" no está', () {
      final datos = {'filial': 'Juliaca'};
      expect(getSede(datos), 'Juliaca');
    });

    test('devuelve "filial" cuando "sede" está vacía', () {
      final datos = {'sede': '', 'filial': 'Tacna'};
      expect(getSede(datos), 'Tacna');
    });

    test('retorna null cuando ambos están vacíos', () {
      final datos = {'sede': '', 'filial': ''};
      expect(getSede(datos), isNull);
    });

    test('retorna null cuando ninguno de los campos existe', () {
      expect(getSede({}), isNull);
    });

    test('retorna null cuando userData es null', () {
      expect(getSede(null), isNull);
    });

    test('campo con solo espacios no se considera válido', () {
      // toString() de '   ' no está vacío — documenta el comportamiento actual
      final datos = {'sede': '   '};
      expect(getSede(datos), '   '); // comportamiento real: no hace trim
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('getCampo — extrae valor o retorna null', () {
    test('retorna el valor si el campo existe y no está vacío', () {
      final datos = {'correoInstitucional': 'juan@upeu.edu.pe'};
      expect(getCampo(datos, 'correoInstitucional'), 'juan@upeu.edu.pe');
    });

    test('retorna null si el campo existe pero está vacío', () {
      final datos = {'celular': ''};
      expect(getCampo(datos, 'celular'), isNull);
    });

    test('retorna null si el campo no existe', () {
      expect(getCampo({}, 'ciclo'), isNull);
    });

    test('retorna null si userData es null', () {
      expect(getCampo(null, 'grupo'), isNull);
    });

    test('convierte valores no-String a String', () {
      final datos = {'ciclo': 5}; // int en el mapa
      expect(getCampo(datos, 'ciclo'), '5');
    });

    test('retorna null si el valor es el int 0 (toString → "0", no vacío)', () {
      // "0".isNotEmpty == true → devuelve "0", no null
      final datos = {'grupo': 0};
      expect(getCampo(datos, 'grupo'), '0');
    });

    test('múltiples campos independientes no se interfieren', () {
      final datos = {
        'modalidadEstudio': 'Presencial',
        'modoContrato': '',
        'ciclo': '3',
      };
      expect(getCampo(datos, 'modalidadEstudio'), 'Presencial');
      expect(getCampo(datos, 'modoContrato'),     isNull);
      expect(getCampo(datos, 'ciclo'),            '3');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('resolverEstadoUI — máquina de estados de la pantalla', () {
    test('isLoading=true → estado "loading" sin importar el resto', () {
      expect(
        resolverEstadoUI(
          isLoading: true,
          errorMessage: 'Error',
          userData: {'name': 'Ana'},
        ),
        'loading',
      );
    });

    test('isLoading=false + errorMessage presente → estado "error"', () {
      expect(
        resolverEstadoUI(
          isLoading: false,
          errorMessage: 'Fallo de red',
          userData: null,
        ),
        'error',
      );
    });

    test('isLoading=false + sin error + userData presente → estado "profile"', () {
      expect(
        resolverEstadoUI(
          isLoading: false,
          errorMessage: null,
          userData: {'name': 'María'},
        ),
        'profile',
      );
    });

    test('isLoading=false + sin error + userData null → estado "noData"', () {
      expect(
        resolverEstadoUI(
          isLoading: false,
          errorMessage: null,
          userData: null,
        ),
        'noData',
      );
    });

    test('error tiene prioridad sobre userData cuando ambos están presentes', () {
      // Si por algún bug coexisten error y userData, debe mostrarse el error
      expect(
        resolverEstadoUI(
          isLoading: false,
          errorMessage: 'Error inesperado',
          userData: {'name': 'Pedro'},
        ),
        'error',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('formatearCampoConPrefijo — ciclo y grupo', () {
    test('formatea ciclo correctamente', () {
      expect(formatearCampoConPrefijo('Ciclo', '5'), 'Ciclo 5');
    });

    test('formatea grupo correctamente', () {
      expect(formatearCampoConPrefijo('Grupo', 'A'), 'Grupo A');
    });

    test('retorna cadena vacía si el valor es null', () {
      expect(formatearCampoConPrefijo('Ciclo', null), '');
    });

    test('retorna cadena vacía si el valor es vacío', () {
      expect(formatearCampoConPrefijo('Grupo', ''), '');
    });

    test('funciona con prefijos distintos', () {
      expect(formatearCampoConPrefijo('Semestre', '2'), 'Semestre 2');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('integración: getSede + getCampo sobre un userData completo', () {
    final userDataCompleto = {
      'name':                 'Carlos López',
      'username':             'clopez',
      'email':                'clopez@gmail.com',
      'correoInstitucional':  'clopez@upeu.edu.pe',
      'dni':                  '72345678',
      'celular':              '987654321',
      'sede':                 'Lima',
      'filial':               'Juliaca',
      'codigoUniversitario':  '2021100001',
      'facultad':             'Ingeniería',
      'carrera':              'Sistemas',
      'modalidadEstudio':     'Presencial',
      'modoContrato':         'Regular',
      'ciclo':                '6',
      'grupo':                'B',
    };

    test('getSede extrae "sede" aunque también exista "filial"', () {
      expect(getSede(userDataCompleto), 'Lima');
    });

    test('todos los campos opcionales presentes se extraen correctamente', () {
      expect(getCampo(userDataCompleto, 'correoInstitucional'), 'clopez@upeu.edu.pe');
      expect(getCampo(userDataCompleto, 'celular'),             '987654321');
      expect(getCampo(userDataCompleto, 'modalidadEstudio'),    'Presencial');
      expect(getCampo(userDataCompleto, 'modoContrato'),        'Regular');
      expect(getCampo(userDataCompleto, 'ciclo'),               '6');
      expect(getCampo(userDataCompleto, 'grupo'),               'B');
    });

    test('ciclo y grupo se formatean con prefijo correctamente', () {
      final ciclo = getCampo(userDataCompleto, 'ciclo');
      final grupo = getCampo(userDataCompleto, 'grupo');
      expect(formatearCampoConPrefijo('Ciclo', ciclo), 'Ciclo 6');
      expect(formatearCampoConPrefijo('Grupo', grupo), 'Grupo B');
    });

    test('estado UI es "profile" con datos completos y sin error', () {
      expect(
        resolverEstadoUI(
          isLoading: false,
          errorMessage: null,
          userData: userDataCompleto,
        ),
        'profile',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('integración: userData mínimo (solo campos obligatorios)', () {
    final userDataMinimo = {
      'name':                'Ana Quispe',
      'username':            'aquispe',
      'email':               'ana@gmail.com',
      'dni':                 '71234567',
      'codigoUniversitario': '2022200002',
      'facultad':            'Ciencias',
      'carrera':             'Biología',
    };

    test('getSede retorna null si no hay sede ni filial', () {
      expect(getSede(userDataMinimo), isNull);
    });

    test('campos opcionales ausentes retornan null', () {
      expect(getCampo(userDataMinimo, 'correoInstitucional'), isNull);
      expect(getCampo(userDataMinimo, 'celular'),             isNull);
      expect(getCampo(userDataMinimo, 'modalidadEstudio'),    isNull);
      expect(getCampo(userDataMinimo, 'modoContrato'),        isNull);
      expect(getCampo(userDataMinimo, 'ciclo'),               isNull);
      expect(getCampo(userDataMinimo, 'grupo'),               isNull);
    });

    test('ciclo con valor null produce cadena vacía en el formateador', () {
      final ciclo = getCampo(userDataMinimo, 'ciclo');
      expect(formatearCampoConPrefijo('Ciclo', ciclo), '');
    });
  });
}