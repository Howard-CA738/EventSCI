// test/ver_certificados_test.dart
//
// Pruebas unitarias para la lógica del panel de estudiante (VerCertificadosScreen).
// Se testean las funciones puras y helpers SIN depender de Firebase, Flutter widgets
// ni la clase real — se copian / replican las funciones bajo test para aislarlas.
//
// Ejecutar:
//   flutter test test/ver_certificados_test.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FUNCIONES COPIADAS DE _VerCertificadosScreenState (helpers puros)
// Al ser métodos privados de un State, se extraen aquí para poder testearlos.
// En producción se recomienda moverlos a un archivo de utilidades separado.
// ─────────────────────────────────────────────────────────────────────────────

/// Réplica exacta de _formatFecha
String formatFecha(DateTime dt) {
  const meses = [
    '',
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${dt.day} ${meses[dt.month]} ${dt.year}';
}

/// Réplica exacta de _colorPorRol (devuelve el código hexadecimal para poder
/// compararlo sin depender de Flutter Color).
String colorHexPorRol(String rol) {
  switch (rol) {
    case 'PONENTE':
      return '#7C3AED';
    case 'JURADO':
      return '#0F6E56';
    case 'ORGANIZADOR':
      return '#B45309';
    default:
      return '#1E3A5F'; // _kPrimario
  }
}

/// Réplica exacta de _iconPorRol (devuelve un string identificador del ícono).
String iconKeyPorRol(String rol) {
  switch (rol) {
    case 'PONENTE':
      return 'mic_rounded';
    case 'JURADO':
      return 'gavel_rounded';
    case 'ORGANIZADOR':
      return 'manage_accounts_rounded';
    default:
      return 'workspace_premium';
  }
}

/// Réplica de la lógica de _resolverIds (sin async/Firestore).
/// Retorna (carreraPath, studentId) o null si no se puede resolver.
(String, String)? resolverIds(Map<String, dynamic> userData) {
  String carreraPath = userData['carreraPath']?.toString() ?? '';
  String studentId = userData['id']?.toString() ?? '';

  if (carreraPath.isEmpty || studentId.isEmpty) {
    final filial = userData['filial']?.toString().trim() ?? '';
    final carrera = userData['carrera']?.toString().trim() ?? '';
    if (filial.isNotEmpty && carrera.isNotEmpty) {
      carreraPath = '${filial}_$carrera';
    }
    studentId =
        userData['uid']?.toString() ?? userData['docId']?.toString() ?? '';
  }

  if (carreraPath.isEmpty || studentId.isEmpty) return null;
  return (carreraPath, studentId);
}

/// Réplica de la lógica de generación del nombre de archivo PDF.
String generarNombreArchivo(String rol, String evento) {
  return 'certificado_${rol.toLowerCase()}_'
      '${evento.replaceAll(' ', '_').toLowerCase()}.pdf';
}

/// Réplica del texto del resumen de certificados.
String textoResumen(int cantidad) {
  return '$cantidad certificado'
      '${cantidad != 1 ? 's' : ''} recibido'
      '${cantidad != 1 ? 's' : ''}';
}

/// Réplica del texto de roles en el resumen.
String textoRoles(Map<String, int> roles) {
  return roles.entries
      .map((e) =>
          '${e.value} ${e.key.toLowerCase()}'
          '${e.value != 1 ? 's' : ''}')
      .join(' · ');
}

// ─────────────────────────────────────────────────────────────────────────────
// TESTS
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  group('formatFecha', () {
    test('formatea correctamente una fecha estándar', () {
      final fecha = DateTime(2024, 3, 15);
      expect(formatFecha(fecha), '15 mar 2024');
    });

    test('formatea el primer día del año', () {
      final fecha = DateTime(2023, 1, 1);
      expect(formatFecha(fecha), '1 ene 2023');
    });

    test('formatea el último día del año', () {
      final fecha = DateTime(2023, 12, 31);
      expect(formatFecha(fecha), '31 dic 2023');
    });

    test('formatea todos los meses correctamente', () {
      const esperados = [
        'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
      ];
      for (int mes = 1; mes <= 12; mes++) {
        final fecha = DateTime(2024, mes, 1);
        expect(
          formatFecha(fecha),
          '1 ${esperados[mes - 1]} 2024',
          reason: 'Falló en mes $mes',
        );
      }
    });

    test('formatea días de dos dígitos sin relleno', () {
      final fecha = DateTime(2024, 6, 9);
      expect(formatFecha(fecha), '9 jun 2024');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('colorHexPorRol', () {
    test('PONENTE devuelve violeta', () {
      expect(colorHexPorRol('PONENTE'), '#7C3AED');
    });

    test('JURADO devuelve verde oscuro', () {
      expect(colorHexPorRol('JURADO'), '#0F6E56');
    });

    test('ORGANIZADOR devuelve ámbar', () {
      expect(colorHexPorRol('ORGANIZADOR'), '#B45309');
    });

    test('ASISTENTE (default) devuelve azul primario', () {
      expect(colorHexPorRol('ASISTENTE'), '#1E3A5F');
    });

    test('rol vacío devuelve color default', () {
      expect(colorHexPorRol(''), '#1E3A5F');
    });

    test('rol desconocido devuelve color default', () {
      expect(colorHexPorRol('MODERADOR'), '#1E3A5F');
    });

    test('rol en minúsculas NO coincide (case-sensitive)', () {
      // La función usa comparación exacta; 'ponente' ≠ 'PONENTE'
      expect(colorHexPorRol('ponente'), '#1E3A5F');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('iconKeyPorRol', () {
    test('PONENTE devuelve mic_rounded', () {
      expect(iconKeyPorRol('PONENTE'), 'mic_rounded');
    });

    test('JURADO devuelve gavel_rounded', () {
      expect(iconKeyPorRol('JURADO'), 'gavel_rounded');
    });

    test('ORGANIZADOR devuelve manage_accounts_rounded', () {
      expect(iconKeyPorRol('ORGANIZADOR'), 'manage_accounts_rounded');
    });

    test('ASISTENTE (default) devuelve workspace_premium', () {
      expect(iconKeyPorRol('ASISTENTE'), 'workspace_premium');
    });

    test('rol desconocido devuelve workspace_premium', () {
      expect(iconKeyPorRol('INVALIDO'), 'workspace_premium');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('resolverIds', () {
    test('devuelve ids directamente si carreraPath e id están presentes', () {
      final datos = {
        'carreraPath': 'Lima_Ingenieria',
        'id': 'student123',
      };
      final resultado = resolverIds(datos);
      expect(resultado, isNotNull);
      expect(resultado!.$1, 'Lima_Ingenieria');
      expect(resultado.$2, 'student123');
    });

    test('construye carreraPath desde filial y carrera si faltan campos directos', () {
      final datos = {
        'filial': 'Juliaca',
        'carrera': 'Sistemas',
        'uid': 'uid_abc',
      };
      final resultado = resolverIds(datos);
      expect(resultado, isNotNull);
      expect(resultado!.$1, 'Juliaca_Sistemas');
      expect(resultado.$2, 'uid_abc');
    });

    test('usa docId como fallback cuando uid no está disponible', () {
      final datos = {
        'filial': 'Lima',
        'carrera': 'Derecho',
        'docId': 'doc_xyz',
      };
      final resultado = resolverIds(datos);
      expect(resultado, isNotNull);
      expect(resultado!.$2, 'doc_xyz');
    });

    test('devuelve null si no hay carreraPath ni filial+carrera', () {
      final datos = {'id': 'student123'};
      expect(resolverIds(datos), isNull);
    });

    test('devuelve null si no hay studentId de ningún tipo', () {
      final datos = {'carreraPath': 'Lima_Sistemas'};
      expect(resolverIds(datos), isNull);
    });

    test('devuelve null si userData está vacío', () {
      expect(resolverIds({}), isNull);
    });

    test('filial con espacios al inicio/fin son recortados', () {
      final datos = {
        'filial': '  Lima  ',
        'carrera': 'Contabilidad',
        'uid': 'u1',
      };
      final resultado = resolverIds(datos);
      expect(resultado!.$1, 'Lima_Contabilidad');
    });

    test('carreraPath directo tiene prioridad sobre filial+carrera', () {
      final datos = {
        'carreraPath': 'path_directo',
        'id': 'id_directo',
        'filial': 'Lima',
        'carrera': 'Sistemas',
        'uid': 'uid_fallback',
      };
      final resultado = resolverIds(datos);
      expect(resultado!.$1, 'path_directo');
      expect(resultado.$2, 'id_directo');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('generarNombreArchivo', () {
    test('genera nombre correcto para ASISTENTE', () {
      expect(
        generarNombreArchivo('ASISTENTE', 'Congreso de Tecnología'),
        'certificado_asistente_congreso_de_tecnología.pdf',
      );
    });

    test('genera nombre correcto para PONENTE', () {
      expect(
        generarNombreArchivo('PONENTE', 'Taller Flutter 2024'),
        'certificado_ponente_taller_flutter_2024.pdf',
      );
    });

    test('espacios en el evento son reemplazados por guiones bajos', () {
      final nombre = generarNombreArchivo('JURADO', 'Evento con espacios');
      expect(nombre.contains(' '), isFalse);
      expect(nombre, contains('_'));
    });

    test('todo el nombre está en minúsculas', () {
      final nombre = generarNombreArchivo('ORGANIZADOR', 'EVENTO MAYÚSCULAS');
      expect(nombre, nombre.toLowerCase());
    });

    test('evento vacío genera nombre mínimo válido', () {
      final nombre = generarNombreArchivo('ASISTENTE', '');
      expect(nombre, 'certificado_asistente_.pdf');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('textoResumen', () {
    test('plural para cero certificados', () {
      expect(textoResumen(0), '0 certificados recibidos');
    });

    test('singular para exactamente 1', () {
      expect(textoResumen(1), '1 certificado recibido');
    });

    test('plural para 2 o más', () {
      expect(textoResumen(2), '2 certificados recibidos');
      expect(textoResumen(10), '10 certificados recibidos');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('textoRoles', () {
    test('un solo rol en singular', () {
      expect(textoRoles({'ASISTENTE': 1}), '1 asistente');
    });

    test('un solo rol en plural', () {
      expect(textoRoles({'ASISTENTE': 3}), '3 asistentes');
    });

    test('múltiples roles separados por ·', () {
      // El orden depende de la inserción en el mapa; usamos LinkedHashMap implícito
      final roles = <String, int>{'PONENTE': 1, 'ASISTENTE': 2};
      final texto = textoRoles(roles);
      expect(texto, contains('1 ponente'));
      expect(texto, contains('2 asistentes'));
      expect(texto, contains(' · '));
    });

    test('rol con cantidad 1 no lleva "s" al final', () {
      final texto = textoRoles({'JURADO': 1});
      expect(texto.endsWith('s'), isFalse);
    });

    test('mapa vacío produce cadena vacía', () {
      expect(textoRoles({}), '');
    });
  });
}