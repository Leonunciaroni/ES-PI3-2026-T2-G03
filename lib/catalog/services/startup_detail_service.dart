// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Lê um documento Firestore da startup e monta [StartupDetailViewData] para a tela de detalhe.
// Usa [startup_firestore_schema] para os mesmos nomes de campo que o catálogo.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mescla_invest/catalog/data/chart_sample_time_axis.dart';
import 'package:mescla_invest/catalog/data/startup_detail_mock.dart';
import 'package:mescla_invest/catalog/models/catalog_startup.dart';
import 'package:mescla_invest/catalog/models/startup_detail_load_state.dart';

import 'startup_detail_document.dart';
import 'startup_firestore_mapper.dart';

export 'socio_firestore_mapper.dart'
    show
        socioDetailViewDataFromFirestoreSocioMap,
        resolveSocioDetailForTeamMember;
export 'startup_detail_document.dart'
    show
        normalizeStartupDetailDocument,
        buildNormalizedSociosEntries,
        enrichSociosListPreservingFields,
        socioNomeParaExibicao,
        socioParticipacaoParaExibicao,
        pickFirstDocumentField,
        estruturaSocietariaRawFromDocument;

/// Ouve um único documento; emite [StartupDetailNotFound] se foi apagado ou inválido.
class StartupDetailService {
  StartupDetailService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<StartupDetailLoadState> watchDetail(String documentId) {
    return _db
        .collection(kFirestoreStartupsCollection)
        .doc(documentId)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snap) {
          if (!snap.exists) {
            return const StartupDetailNotFound();
          }
          final Map<String, dynamic>? raw = snap.data();
          if (raw == null) {
            return const StartupDetailNotFound();
          }
          final CatalogStartup? catalog = catalogStartupFromFirestoreMap(
            snap.id,
            raw,
          );
          if (catalog == null) {
            return const StartupDetailNotFound();
          }
          return StartupDetailReady(
            detailViewDataFromFirestoreMap(raw, catalog),
          );
        });
  }
}

/// Monta [StartupDetailViewData] a partir dos campos do documento (Firestore **ou** JSON da Function).
///
/// Exportada para reutilizar no fluxo via callable sem duplicar regras de layout.
StartupDetailViewData detailViewDataFromFirestoreMap(
  Map<String, dynamic> d,
  CatalogStartup catalog, {
  List<StartupPublicQa> publicQa = const <StartupPublicQa>[],
  List<StartupPublicQa> investorQa = const <StartupPublicQa>[],
  bool canSelectQuestionVisibility = false,
  bool canViewInvestorQuestions = false,
}) {
  final Map<String, dynamic> dNorm = normalizeStartupDetailDocument(d);
  final String descricao = readFirestoreString(dNorm, kFieldDescricao);
  final String setorRaw = readFirestoreString(dNorm, kFieldSetor);
  final String categoryDisplay = setorRaw.trim().isEmpty
      ? catalog.category
      : '${setorRaw.toUpperCase()} & ECOSYSTEM';
  final int? ano = _readOptionalInt(dNorm, kFieldAnoDeInicio);
  final String foundedLabel = ano != null
      ? 'Ano de início: $ano'
      : 'Ano de início em definição.';
  final List<StartupTeamMember> team = _teamFromFirestore(dNorm);
  final List<String> societary = _societaryLinesFromFirestore(dNorm);
  final List<StartupPerformanceMetric> metrics = _metricsFromFirestore(dNorm);
  final String? videoUrl = readFirestoreOptionalString(dNorm, kFieldVideoDemo);
  final String videoTitle = _videoTitleFromFirestore(dNorm, catalog);
  final double captureFraction = captureProgressFractionFromFirestore(dNorm);
  final String captureHeadline = _captureHeadlineFromFirestore(dNorm);
  final String valuationHeadline = _valuationHeadlineFromFirestore(dNorm);
  final String rodadaRaw = readFirestoreString(
    dNorm,
    kFieldValuationRodada,
  ).trim();
  final String valuationRound = rodadaRaw.isEmpty ? 'VALUATION' : rodadaRaw;
  final String valuationTrend = _valuationTrendFromFirestore(dNorm);
  final String headquarters = _headquartersFromFirestore(dNorm);

  return StartupDetailViewData(
    catalog: catalog,
    categoryDisplay: categoryDisplay,
    longDescription: descricao.isEmpty ? catalog.description : descricao,
    captureHeadline: captureHeadline,
    captureProgressFraction: captureFraction,
    captureProgressLabel: captureFraction <= 0
        ? 'Meta de captação em definição'
        : '${(captureFraction * 100).round()}% da meta atingida',
    valuationHeadline: valuationHeadline,
    valuationRoundLabel: valuationRound,
    valuationTrendText: valuationTrend,
    chartSeriesByPeriod: _alignDetailChartSeriesForNow(
      _chartSeriesFromFirestoreOrFallback(dNorm, catalog),
      interpolateValues: true,
    ),
    headquarters: headquarters,
    foundedLabel: foundedLabel,
    missionQuote: descricao.isEmpty
        ? 'Missão em definição.'
        : (descricao.length > 200
              ? '${descricao.substring(0, 197)}…'
              : descricao),
    teamMembers: team,
    performanceMetrics: metrics,
    executiveSummary: descricao.isEmpty
        ? 'Sumário executivo em elaboração.'
        : descricao,
    societaryLines: societary,
    publicQa: publicQa,
    investorQa: investorQa,
    canSelectQuestionVisibility: canSelectQuestionVisibility,
    canViewInvestorQuestions: canViewInvestorQuestions,
    demoVideoTitle: videoTitle,
    demoVideoUrl: videoUrl,
    fullFirestoreDocument: Map<String, dynamic>.from(dNorm),
  );
}

String _captureHeadlineFromFirestore(Map<String, dynamic> d) {
  final String? direct = readFirestoreOptionalString(d, kFieldCaptacaoHeadline);
  if (direct != null && direct.isNotEmpty) {
    return direct;
  }
  final double? cap = readFirestoreOptionalDouble(d, kFieldValorCaptadoReais);
  final double? meta = readFirestoreOptionalDouble(d, kFieldMetaCaptacaoReais);
  if (cap != null && meta != null && meta > 0) {
    return 'R\$ ${_formatIntBR(cap.round())} / R\$ ${_formatIntBR(meta.round())}';
  }
  if (cap != null) {
    return 'R\$ ${_formatIntBR(cap.round())}';
  }
  return 'R\$ —';
}

String _valuationHeadlineFromFirestore(Map<String, dynamic> d) {
  final String? h = readFirestoreOptionalString(d, kFieldValuationHeadline);
  if (h != null && h.isNotEmpty) {
    return h;
  }
  return 'R\$ —';
}

String _valuationTrendFromFirestore(Map<String, dynamic> d) {
  final String? t = readFirestoreOptionalString(d, kFieldValuationTendencia);
  if (t != null && t.isNotEmpty) {
    return t;
  }
  return '—';
}

String _headquartersFromFirestore(Map<String, dynamic> d) {
  final String? s = readFirestoreOptionalString(d, kFieldSede);
  if (s != null && s.isNotEmpty) {
    return s;
  }
  return '—';
}

DateTime? _chartInstantFromFirestoreValue(Object? v) {
  if (v == null) {
    return null;
  }
  if (v is Timestamp) {
    return v.toDate();
  }
  if (v is String) {
    final String s = v.trim();
    if (s.isEmpty) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(s);
    return parsed?.toLocal();
  }
  if (v is DateTime) {
    return v.toLocal();
  }
  if (v is int) {
    return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal();
  }
  if (v is double) {
    final int ms = v.round();
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }
  return null;
}

double _interpolateValuationAlongSeries(
  List<DateTime> tAsc,
  List<double> v,
  DateTime x,
) {
  if (tAsc.isEmpty) {
    return 0;
  }
  if (tAsc.length != v.length || v.isEmpty) {
    return v.isNotEmpty ? v.last : 0;
  }
  if (x.isBefore(tAsc.first) || x.isAtSameMomentAs(tAsc.first)) {
    return v.first;
  }
  if (!x.isBefore(tAsc.last)) {
    return v.last;
  }
  final int xms = x.millisecondsSinceEpoch;
  for (var i = 0; i < tAsc.length - 1; i++) {
    final int t0 = tAsc[i].millisecondsSinceEpoch;
    final int t1 = tAsc[i + 1].millisecondsSinceEpoch;
    if (xms >= t0 && xms <= t1) {
      if (t1 <= t0) {
        return v[i];
      }
      final double w = (xms - t0) / (t1 - t0);
      return v[i] * (1 - w) + v[i + 1] * w;
    }
  }
  return v.last;
}

/// Ancora [sampleTimes] em [DateTime.now] por período (§5.4). Com
/// [interpolateValues], recalcula Y por interpolação linear na série antiga —
/// uso típico para dados Firestore; mocks usam `false` (só reposicionam o eixo).
Map<ValuationPeriod, ValuationChartSeries> _alignDetailChartSeriesForNow(
  Map<ValuationPeriod, ValuationChartSeries> input, {
  required bool interpolateValues,
}) {
  final DateTime now = DateTime.now();
  final Map<ValuationPeriod, ValuationChartSeries> out =
      <ValuationPeriod, ValuationChartSeries>{};
  for (final MapEntry<ValuationPeriod, ValuationChartSeries> e
      in input.entries) {
    final ValuationChartSeries s = e.value;
    final List<double> ys = s.valuationMillions;
    final List<DateTime> oldT = s.sampleTimes;
    final int n = ys.length;
    if (n == 0) {
      out[e.key] = s;
      continue;
    }
    final List<DateTime> newTimes = chartEvenlySpacedTimes(
      chartWindowStartForPeriodIndex(e.key.index, now),
      now,
      n,
    );
    final List<double> newYs;
    if (interpolateValues &&
        oldT.length == n &&
        n >= 2 &&
        !oldT.first.isAtSameMomentAs(oldT.last)) {
      newYs = newTimes
          .map(
            (DateTime tx) => _interpolateValuationAlongSeries(oldT, ys, tx),
          )
          .toList();
    } else {
      newYs = List<double>.from(ys);
    }
    out[e.key] = ValuationChartSeries(
      valuationMillions: newYs,
      sampleTimes: newTimes,
    );
  }
  return out;
}

Map<ValuationPeriod, ValuationChartSeries> _chartSeriesFromFirestoreOrFallback(
  Map<String, dynamic> d,
  CatalogStartup catalog,
) {
  final Object? raw = d[kFieldGraficoValuation];
  if (raw is! Map) {
    return fallbackChartSeriesForStartupDetail(catalog);
  }
  final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
  final Map<ValuationPeriod, ValuationChartSeries> fallback =
      fallbackChartSeriesForStartupDetail(catalog);
  ValuationPeriod? periodFromKey(String k) {
    final String x = k.toLowerCase().trim();
    switch (x) {
      case 'diario':
        return ValuationPeriod.diario;
      case 'semanal':
        return ValuationPeriod.semanal;
      case 'mensal':
        return ValuationPeriod.mensal;
      case 'seis_meses':
      case 'seismeses':
      case '6_meses':
        return ValuationPeriod.seisMeses;
      case 'ytd':
        return ValuationPeriod.ytd;
      default:
        return null;
    }
  }

  ValuationChartSeries? parseSeries(Object? value) {
    if (value is! List) {
      return null;
    }
    final pairs = <({DateTime t, double v})>[];
    for (final Object? item in value) {
      final Map<String, dynamic>? m = _asStringKeyMap(item);
      if (m == null) {
        continue;
      }
      final DateTime? dt = _chartInstantFromFirestoreValue(m['t']) ??
          _chartInstantFromFirestoreValue(m['T']);
      final double? val =
          readFirestoreOptionalDouble(m, 'v') ??
          readFirestoreOptionalDouble(m, 'valor');
      if (dt == null || val == null) {
        continue;
      }
      pairs.add((t: dt, v: val));
    }
    if (pairs.isEmpty) {
      return null;
    }
    pairs.sort((a, b) => a.t.compareTo(b.t));
    return ValuationChartSeries(
      valuationMillions: pairs.map((e) => e.v).toList(),
      sampleTimes: pairs.map((e) => e.t).toList(),
    );
  }

  final Map<ValuationPeriod, ValuationChartSeries> out = {};
  for (final MapEntry<String, dynamic> e in map.entries) {
    final ValuationPeriod? p = periodFromKey(e.key);
    if (p == null) {
      continue;
    }
    final ValuationChartSeries? s = parseSeries(e.value);
    if (s != null) {
      out[p] = s;
    }
  }
  for (final ValuationPeriod p in ValuationPeriod.values) {
    out.putIfAbsent(p, () => fallback[p]!);
  }
  return out;
}

int? _readOptionalInt(Map<String, dynamic> d, String key) {
  final Object? v = d[key];
  if (v is int) {
    return v;
  }
  if (v is double) {
    return v.round();
  }
  return null;
}

Map<String, dynamic>? _asStringKeyMap(Object? item) {
  if (item is Map<String, dynamic>) {
    return item;
  }
  if (item is Map) {
    return Map<String, dynamic>.from(item);
  }
  return null;
}

List<String> _societaryLinesFromFirestore(Map<String, dynamic> d) {
  final List<String> lines = <String>[];
  final Object? socios = d[kFieldSocios];
  if (socios is List) {
    for (final Object? item in socios) {
      final Map<String, dynamic>? map = _asStringKeyMap(item);
      if (map == null) {
        continue;
      }
      final String nome = socioNomeParaExibicao(map);
      final String pctStr = socioParticipacaoParaExibicao(map);
      if (nome.trim().isNotEmpty) {
        lines.add(pctStr.isEmpty ? nome : '$nome — $pctStr');
      }
    }
  }
  if (lines.isEmpty) {
    return const <String>['Estrutura societária em elaboração.'];
  }
  return lines;
}

List<StartupTeamMember> _teamFromFirestore(Map<String, dynamic> d) {
  final List<StartupTeamMember> out = <StartupTeamMember>[];
  final Object? socios = d[kFieldSocios];
  if (socios is List) {
    for (final Object? item in socios) {
      final Map<String, dynamic>? map = _asStringKeyMap(item);
      if (map == null) {
        continue;
      }
      final String nome = socioNomeParaExibicao(map);
      final String pctStr = socioParticipacaoParaExibicao(map);
      if (nome.trim().isEmpty) {
        continue;
      }
      final String cargo = readFirestoreString(map, 'Cargo').trim();
      final String role = cargo.isNotEmpty
          ? (pctStr.isNotEmpty ? '$cargo — $pctStr' : cargo)
          : (pctStr.isNotEmpty ? 'Sócio — $pctStr' : 'Sócio');
      out.add(
        StartupTeamMember(
          name: nome.trim(),
          role: role,
          avatarColor: _avatarColorForString(nome),
          firestoreFields: Map<String, dynamic>.from(map),
        ),
      );
    }
  }
  final Object? mentores = d[kFieldMentoresConselho];
  if (mentores is List) {
    for (final Object? m in mentores) {
      if (m is String && m.trim().isNotEmpty) {
        final String name = m.trim();
        out.add(
          StartupTeamMember(
            name: name,
            role: 'Mentor / conselho',
            avatarColor: _avatarColorForString(name),
          ),
        );
      }
    }
  }
  return out;
}

Color _avatarColorForString(String s) {
  int h = 0;
  for (final int c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  const List<Color> palette = <Color>[
    Color(0xFF6366F1),
    Color(0xFFEC4899),
    Color(0xFF22C55E),
    Color(0xFF6234EA),
    Color(0xFFF59E0B),
    Color(0xFF0EA5E9),
  ];
  return palette[h.abs() % palette.length];
}

List<StartupPerformanceMetric> _metricsFromFirestore(Map<String, dynamic> d) {
  final List<StartupPerformanceMetric> list = [];
  final Object? rm = d[kFieldReceitaMensal];
  if (rm is num) {
    list.add(
      StartupPerformanceMetric(
        labelCaps: 'RECEITA MENSAL',
        value: 'R\$ ${_formatIntBR(rm.round())}',
        icon: Icons.payments_outlined,
        iconBackground: const Color(0xFFD1FAE5),
        iconColor: const Color(0xFF059669),
      ),
    );
  }
  final Map<String, dynamic>? tokens = _asStringKeyMap(d[kFieldTokensEmitidos]);
  if (tokens != null) {
    final Object? q = tokens['quantidade'];
    final String tokenNome = readFirestoreString(tokens, 'nome');
    if (q is num) {
      final String suffix = tokenNome.isEmpty ? '' : ' · $tokenNome';
      list.add(
        StartupPerformanceMetric(
          labelCaps: 'TOKENS EMITIDOS',
          value: '${_formatIntBR(q.round())}$suffix',
          icon: Icons.currency_exchange_rounded,
          iconBackground: const Color(0xFFEDE9FE),
          iconColor: const Color(0xFF6234EA),
        ),
      );
    }
  }
  final Object? modelos = d[kFieldModeloNegocio];
  if (modelos is List && modelos.isNotEmpty) {
    final String joined = modelos
        .map((e) => e.toString().trim())
        .where((String s) => s.isNotEmpty)
        .join(' · ');
    if (joined.isNotEmpty) {
      list.add(
        StartupPerformanceMetric(
          labelCaps: 'MODELO DE NEGÓCIO',
          value: joined,
          icon: Icons.business_center_outlined,
          iconBackground: const Color(0xFFDBEAFE),
          iconColor: const Color(0xFF2563EB),
        ),
      );
    }
  }
  return list;
}

String _formatIntBR(int v) {
  final String digits = v.toString();
  final StringBuffer out = StringBuffer();
  final int len = digits.length;
  for (int i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) {
      out.write('.');
    }
    out.write(digits[i]);
  }
  return out.toString();
}

String _videoTitleFromFirestore(
  Map<String, dynamic> d,
  CatalogStartup catalog,
) {
  final Map<String, dynamic>? tokens = _asStringKeyMap(d[kFieldTokensEmitidos]);
  if (tokens != null) {
    final String n = readFirestoreString(tokens, 'nome');
    if (n.isNotEmpty) {
      return 'Demonstração — $n';
    }
  }
  final String? sigla = catalog.sigla;
  if (sigla != null && sigla.isNotEmpty) {
    return 'Vídeo demonstrativo ($sigla)';
  }
  return 'Vídeo demonstrativo';
}
