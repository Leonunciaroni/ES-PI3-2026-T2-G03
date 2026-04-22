// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Lê um documento Firestore da startup e monta [StartupDetailViewData] para a tela de detalhe.
// Mesmo padrão do catálogo: stream em tempo real + mapeamento explícito dos campos do console.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pi_iii/catalog/data/startup_detail_mock.dart';
import 'package:pi_iii/catalog/models/catalog_startup.dart';

import 'startup_firestore_mapper.dart';

/// Ouve um único documento; emite null se foi apagado ou inválido.
class StartupDetailService {
  StartupDetailService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<StartupDetailViewData?> watchDetail(String documentId) {
    return _db
        .collection(kFirestoreStartupsCollection)
        .doc(documentId)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snap) {
      if (!snap.exists) {
        return null;
      }
      final Map<String, dynamic>? raw = snap.data();
      if (raw == null) {
        return null;
      }
      final CatalogStartup? catalog = catalogStartupFromFirestoreMap(snap.id, raw);
      if (catalog == null) {
        return null;
      }
      return _detailFromFirestoreMap(raw, catalog);
    });
  }
}

StartupDetailViewData _detailFromFirestoreMap(
  Map<String, dynamic> d,
  CatalogStartup catalog,
) {
  final String descricao = readFirestoreString(d, 'descricao');
  final String setorRaw = readFirestoreString(d, 'setor');
  final String categoryDisplay =
      setorRaw.trim().isEmpty ? catalog.category : '${setorRaw.toUpperCase()} & ECOSYSTEM';
  final int? ano = _readOptionalInt(d, 'anoDeInicio');
  final String foundedLabel =
      ano != null ? 'Ano de início: $ano' : 'Ano de início em definição.';
  final List<StartupTeamMember> team = _teamFromFirestore(d);
  final List<String> societary = _societaryLinesFromFirestore(d);
  final List<StartupPerformanceMetric> metrics = _metricsFromFirestore(d);
  final String? videoUrl = readFirestoreOptionalString(d, 'video_demo');
  final String videoTitle = _videoTitleFromFirestore(d, catalog);

  return StartupDetailViewData(
    catalog: catalog,
    categoryDisplay: categoryDisplay,
    longDescription: descricao.isEmpty ? catalog.description : descricao,
    captureHeadline: 'R\$ —',
    captureProgressFraction: catalog.captureProgress,
    captureProgressLabel: catalog.captureProgress <= 0
        ? 'Meta de captação em definição'
        : '${(catalog.captureProgress * 100).round()}% da meta atingida',
    valuationHeadline: 'R\$ —',
    valuationRoundLabel: 'VALUATION',
    valuationTrendText: '—',
    chartSeriesByPeriod: fallbackChartSeriesForStartupDetail(catalog),
    headquarters: '—',
    foundedLabel: foundedLabel,
    missionQuote: descricao.isEmpty
        ? 'Missão em definição.'
        : (descricao.length > 200 ? '${descricao.substring(0, 197)}…' : descricao),
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
  final Object? socios = d['socios'];
  if (socios is List) {
    for (final Object? item in socios) {
      final Map<String, dynamic>? map = _asStringKeyMap(item);
      if (map == null) {
        continue;
      }
      final String nome = readFirestoreString(map, 'nome');
      final Object? pct = map['porcentagem'];
      final String pctStr =
          pct is num ? '${pct.round()}%' : readFirestoreString(map, 'porcentagem');
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
  final Object? socios = d['socios'];
  if (socios is List) {
    for (final Object? item in socios) {
      final Map<String, dynamic>? map = _asStringKeyMap(item);
      if (map == null) {
        continue;
      }
      final String nome = readFirestoreString(map, 'nome');
      final Object? pct = map['porcentagem'];
      final String pctStr =
          pct is num ? '${pct.round()}%' : readFirestoreString(map, 'porcentagem');
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
  final Object? mentores = d['mentores_conselho'];
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
  final Object? rm = d['receita_mensal'];
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
  final Map<String, dynamic>? tokens = _asStringKeyMap(d['tokens_emitidos']);
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
  final Object? modelos = d['modelo_negocio'];
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
  final Map<String, dynamic>? tokens = _asStringKeyMap(d['tokens_emitidos']);
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
