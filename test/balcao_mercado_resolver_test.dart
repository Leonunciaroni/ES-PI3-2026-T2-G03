import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/balcao/balcao_format.dart';

void main() {
  group('balcaoResolveMercadoDesdeQuantidadeTokens', () {
    test('2 tokens a 5 BRL/token -> par coerente', () {
      final r = balcaoResolveMercadoDesdeQuantidadeTokens(2, 5);
      expect(r.isValid, isTrue);
      expect(r.amountBrl, closeTo(10, 0.02));
      expect(r.tokens, 2);
      expect(
        (r.amountBrl - r.tokens * 5).abs(),
        lessThanOrEqualTo(balcaoEpsilonBrl + 1e-11),
      );
    });

    test('mantém quantidade inteira informada com preço fracionário', () {
      final r = balcaoResolveMercadoDesdeQuantidadeTokens(3, 60.78);
      expect(r.isValid, isTrue);
      expect(r.tokens, 3);
      expect(
        (r.amountBrl - r.tokens * 60.78).abs(),
        lessThanOrEqualTo(balcaoEpsilonBrl + 1e-11),
      );
    });

    test('quantidade zero ou preço inválido -> inválido', () {
      expect(
        balcaoResolveMercadoDesdeQuantidadeTokens(0, 5).isValid,
        isFalse,
      );
      expect(
        balcaoResolveMercadoDesdeQuantidadeTokens(2, 0).isValid,
        isFalse,
      );
    });
  });

  group('formatQuantidadeTokensBr', () {
    test('inteiros sem casas decimais', () {
      expect(formatQuantidadeTokensBr(2), '2');
      expect(formatQuantidadeTokensBr(10), '10');
    });

    test('legado fracionário ainda formatável (ledger/saldo pré-migração)', () {
      expect(formatQuantidadeTokensBr(2.466), '2,466');
    });
  });
}
