// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Garante o contrato `isPrivate` → `visibility` da callable `createStartupQuestion`.

import 'package:flutter_test/flutter_test.dart';

import 'package:mescla_invest/catalog/services/startup_catalog_functions_service.dart';

void main() {
  group('StartupCatalogFunctionsService.visibilityForCallable', () {
    test('público mapeia para publica', () {
      expect(
        StartupCatalogFunctionsService.visibilityForCallable(false),
        'publica',
      );
    });

    test('privado mapeia para privada', () {
      expect(
        StartupCatalogFunctionsService.visibilityForCallable(true),
        'privada',
      );
    });
  });
}
