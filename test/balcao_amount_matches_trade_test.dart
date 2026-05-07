import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/balcao/balcao_format.dart';

void main() {
  group('balcaoAmountMatchesTrade', () {
    test('par coerente com preço oficial', () {
      expect(balcaoAmountMatchesTrade(10, 2, 5), isTrue);
      expect(balcaoAmountMatchesTrade(10.05, 2, 5), isTrue);
    });

    test('rejeita divergência acima do epsilon', () {
      expect(balcaoAmountMatchesTrade(10.2, 2, 5), isFalse);
    });

    test('rejeita tokens ou preço inválidos', () {
      expect(balcaoAmountMatchesTrade(10, 0, 5), isFalse);
      expect(balcaoAmountMatchesTrade(10, 2, 0), isFalse);
    });
  });
}
