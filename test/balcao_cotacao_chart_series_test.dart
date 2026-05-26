import 'package:flutter_test/flutter_test.dart';

import 'package:mescla_invest/balcao/balcao_cotacao_chart_series.dart';
import 'package:mescla_invest/catalog/data/startup_detail_mock.dart';

void main() {
  test('balcaoExtendSeriesToNow atualiza último ponto no passado recente', () {
    final t0 = DateTime(2026, 5, 4, 10, 0);
    final pts = <BalcaoMarketPricePoint>[
      BalcaoMarketPricePoint(t0, 10),
    ];
    final now = DateTime(2026, 5, 4, 12, 0);
    final out = balcaoExtendSeriesToNow(pts, now, 12);
    expect(out.length, 2);
    expect(out.last.t, now);
    expect(out.last.priceBrl, 12);
  });

  test('balcaoStats24hRolling calcula variação entre ref interpolada e último', () {
    final base = DateTime(2026, 5, 4, 0, 0);
    final asc = <BalcaoMarketPricePoint>[
      BalcaoMarketPricePoint(base, 100),
      BalcaoMarketPricePoint(base.add(const Duration(hours: 12)), 110),
      BalcaoMarketPricePoint(base.add(const Duration(hours: 24)), 121),
    ];
    final s = balcaoStats24hRolling(asc);
    expect(s.changePct24h, isNotNull);
    expect(s.minBrl, lessThanOrEqualTo(s.maxBrl ?? 0));
  });

  test('balcaoCotacaoSeriesForPeriod fallback usa janela até agora', () {
    final detail = startupDetailFor(kPreviewCatalogStartup);
    final now = DateTime(2026, 5, 4, 15, 30);
    final s = balcaoCotacaoSeriesForPeriod(
      period: ValuationPeriod.diario,
      nowLocal: now,
      precoMercadoBrl: 20,
      serverPoints: null,
      detailFallback: detail,
    );
    expect(s.sampleTimes.isNotEmpty, true);
    expect(s.sampleTimes.last.difference(now).inMinutes.abs() < 2, true);
    expect(s.valuationMillions.last, closeTo(20, 0.02));
  });
}
