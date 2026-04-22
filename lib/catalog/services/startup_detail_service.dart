// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Lê um documento Firestore da startup e monta [StartupDetailViewData] para a tela de detalhe.
// Usa [startup_firestore_schema] para os mesmos nomes de campo que o catálogo.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pi_iii/catalog/data/startup_detail_mock.dart';
import 'package:pi_iii/catalog/models/catalog_startup.dart';
import 'package:pi_iii/catalog/models/startup_detail_load_state.dart';

import 'startup_firestore_mapper.dart';

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
      final CatalogStartup? catalog =
          catalogStartupFromFirestoreMap(snap.id, raw);
      if (catalog == null) {
        return const StartupDetailNotFound();
      }
      return StartupDetailReady(_detailFromFirestoreMap(raw, catalog));
    });
  }
}

StartupDetailViewData _detailFromFirestoreMap(
  Map<String, dynamic> d,
  CatalogStartup catalog,
) {
  final String descricao = readFirestoreString(d, kFieldDescricao);
  final String setorRaw = readFirestoreString(d, kFieldSetor);
  final String categoryDisplay = setorRaw.trim().isEmpty
      ? catalog.category
      : '${setorRaw.toUpperCase()} & ECOSYSTEM';
  final int? ano = _readOptionalInt(d, kFieldAnoDeInicio);
  final String foundedLabel = ano != null
      ? 'Ano de início: $ano'
      : 'Ano de início em definição.';
  final List<StartupTeamMember> team = _teamFromFirestore(d);
  final List<String> societary = _societaryLinesFromFirestore(d);
  final List<StartupPerformanceMetric> metrics = _metricsFromFirestore(d);
  final String? videoUrl = readFirestoreOptionalString(d, kFieldVideoDemo);
  final String videoTitle = _videoTitleFromFirestore(d, catalog);
  final double captureFraction = captureProgressFractionFromFirestore(d);
  final String captureHeadline = _captureHeadlineFromFirestore(d);
  final String valuationHeadline = _valuationHeadlineFromFirestore(d);
  final String rodadaRaw = readFirestoreString(d, kFieldValuationRodada).trim();
  final String valuationRound = rodadaRaw.isEmpty ? 'VALUATION' : rodadaRaw;
  final String valuationTrend = _valuationTrendFromFirestore(d);
  final String headquarters = _headquartersFromFirestore(d);

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
    chartSeriesByPeriod: _chartSeriesFromFirestoreOrFallback(d, catalog),
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
    publicQa: const [],
    demoVideoTitle: videoTitle,
    demoVideoUrl: videoUrl,
  );
}

String _captureHeadlineFromFirestore(Map<String, dynamic> d) {
  final String? direct =
      readFirestoreOptionalString(d, kFieldCaptacaoHeadline);
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
  final String? h =
      readFirestoreOptionalString(d, kFieldValuationHeadline);
  if (h != null && h.isNotEmpty) {
    return h;
  }
  return 'R\$ —';
}

String _valuationTrendFromFirestore(Map<String, dynamic> d) {
  final String? t =
      readFirestoreOptionalString(d, kFieldValuationTendencia);
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
    final List<DateTime> times = [];
    final List<double> vals = [];
    for (final Object? item in value) {
      final Map<String, dynamic>? m = _asStringKeyMap(item);
      if (m == null) {
        continue;
      }
      final String t = readFirestoreString(m, 't');
      final double? v = readFirestoreOptionalDouble(m, 'v') ??
          readFirestoreOptionalDouble(m, 'valor');
      if (v == null) {
        continue;
      }
      final DateTime? dt = DateTime.tryParse(t);
      if (dt == null) {
        continue;
      }
      times.add(dt);
      vals.add(v);
    }
    if (times.isEmpty || times.length != vals.length) {
      return null;
    }
    return ValuationChartSeries(
      valuationMillions: vals,
      sampleTimes: times,
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
  final List<String> lines = [];
  final Object? socios = d[kFieldSocios];
  if (socios is List) {
    for (final Object? item in socios) {
      final Map<String, dynamic>? map = _asStringKeyMap(item);
      if (map == null) {
        continue;
      }
      final String nome = readFirestoreString(map, 'nome');
      final Object? pct = map['porcentagem'];
      final String pctStr = pct is num
          ? '${pct.round()}%'
          : readFirestoreString(map, 'porcentagem');
      if (nome.trim().isNotEmpty) {
        lines.add('$nome — $pctStr');
      }
    }
  }
  if (lines.isEmpty) {
    return const ['Estrutura societária em elaboração.'];
  }
  return lines;
}

List<StartupTeamMember> _teamFromFirestore(Map<String, dynamic> d) {
  final List<StartupTeamMember> out = [];
  final Object? socios = d[kFieldSocios];
  if (socios is List) {
    for (final Object? item in socios) {
      final Map<String, dynamic>? map = _asStringKeyMap(item);
      if (map == null) {
        continue;
      }
      final String nome = readFirestoreString(map, 'nome');
      final Object? pct = map['porcentagem'];
      final String pctStr = pct is num
          ? '${pct.round()}%'
          : readFirestoreString(map, 'porcentagem');
      if (nome.trim().isNotEmpty) {
        out.add(
          StartupTeamMember(
            name: nome.trim(),
            role: 'Sócio — $pctStr',
            avatarColor: _avatarColorForString(nome),
          ),
        );
      }
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

String _videoTitleFromFirestore(Map<String, dynamic> d, CatalogStartup catalog) {
  final Map<String, dynamic>? tokens =
      _asStringKeyMap(d[kFieldTokensEmitidos]);
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
