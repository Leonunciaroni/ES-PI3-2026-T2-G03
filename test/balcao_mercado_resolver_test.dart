import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/balcao/balcao_format.dart';

void main() {
  group('balcaoResolveMercadoDesdeBrl', () {
    test('10 BRL a 5/token respeita epsilon', () {
      final r = balcaoResolveMercadoDesdeBrl(10, 5);
      expect(r.isValid, isTrue);
      expect((r.amountBrl - r.tokens * 5).abs(), lessThanOrEqualTo(balcaoEpsilonBrl + 1e-11));
    });

    test('10,05 BRL a 5/token ainda passa (epsilon 0,06)', () {
      final r = balcaoResolveMercadoDesdeBrl(10.05, 5);
      expect(r.isValid, isTrue);
    });
  });

  group('balcaoResolveMercadoDesdeQuantidadeTokens', () {
    test('2 tokens a 5 -> 10 BRL coerente', () {
      final r = balcaoResolveMercadoDesdeQuantidadeTokens(2, 5);
      expect(r.isValid, isTrue);
      expect(r.amountBrl, closeTo(10, 0.02));
      expect(r.tokens, greaterThan(1.5));
      expect(r.tokens, lessThan(2.5));
    });
  });
}
