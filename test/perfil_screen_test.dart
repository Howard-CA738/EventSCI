import 'package:flutter_test/flutter_test.dart';
import 'package:eventos/roles/usuarios/logica/perfil_controller.dart';

void main() {
  // ─────────────────────────────────────────────────────────
  // getSede
  // ─────────────────────────────────────────────────────────
  group('PerfilController - getSede', () {
    test('retorna sede cuando existe', () {
      final controller = PerfilController();

      controller.userData = {
        'sede': 'Juliaca',
        'filial': '',
      };

      expect(controller.getSede(), 'Juliaca');
    });

    test('retorna filial cuando sede está vacía', () {
      final controller = PerfilController();

      controller.userData = {
        'sede': '',
        'filial': 'Puno',
      };

      expect(controller.getSede(), 'Puno');
    });

    test('retorna null cuando ambas están vacías', () {
      final controller = PerfilController();

      controller.userData = {
        'sede': '',
        'filial': '',
      };

      expect(controller.getSede(), null);
    });

    test('retorna null cuando userData es null', () {
      final controller = PerfilController();

      controller.userData = null;

      expect(controller.getSede(), null);
    });
  });

  // ─────────────────────────────────────────────────────────
  // getCampo
  // ─────────────────────────────────────────────────────────
  group('PerfilController - getCampo', () {
    test('retorna valor cuando existe', () {
      final controller = PerfilController();

      controller.userData = {
        'ciclo': '5',
      };

      expect(controller.getCampo('ciclo'), '5');
    });

    test('retorna null cuando está vacío', () {
      final controller = PerfilController();

      controller.userData = {
        'ciclo': '',
      };

      expect(controller.getCampo('ciclo'), null);
    });

    test('retorna null cuando no existe', () {
      final controller = PerfilController();

      controller.userData = {};

      expect(controller.getCampo('ciclo'), null);
    });

    test('retorna null cuando userData es null', () {
      final controller = PerfilController();

      controller.userData = null;

      expect(controller.getCampo('ciclo'), null);
    });
  });

  // ─────────────────────────────────────────────────────────
  // loadUserData
  // ─────────────────────────────────────────────────────────
  group('PerfilController - loadUserData', () {
    test('carga datos correctamente', () async {
      final controller = PerfilController(
        fetchUserData: () async => {
          'name': 'Juan',
          'sede': 'Juliaca',
        },
      );

      await controller.loadUserData();

      expect(controller.userData!['name'], 'Juan');
      expect(controller.isLoading, false);
      expect(controller.errorMessage, null);
    });

    test('maneja cuando retorna null', () async {
      final controller = PerfilController(
        fetchUserData: () async => null,
      );

      await controller.loadUserData();

      expect(controller.userData, null);
      expect(controller.errorMessage, isNotNull);
      expect(controller.isLoading, false);
    });

    test('maneja errores correctamente', () async {
      final controller = PerfilController(
        fetchUserData: () async => throw Exception('Error de prueba'),
      );

      await controller.loadUserData();

      expect(controller.errorMessage, contains('Error'));
      expect(controller.isLoading, false);
    });

    test('isLoading cambia correctamente durante la ejecución', () async {
      final controller = PerfilController(
        fetchUserData: () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return {'name': 'Juan'};
        },
      );

      final future = controller.loadUserData();

      expect(controller.isLoading, true);

      await future;

      expect(controller.isLoading, false);
    });
  });
}