// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Normaliza documentos Firestore / JSON da callable: sócios com **todos** os campos
// preservados (mesmos nomes do console), para detalhe e telas futuras.

import 'startup_firestore_schema.dart';

bool _isAbsentFirestoreValue(Object? v) {
  if (v == null) {
    return true;
  }
  if (v is String) {
    return v.trim().isEmpty;
  }
  if (v is List) {
    return v.isEmpty;
  }
  if (v is Map) {
    return v.isEmpty;
  }
  return false;
}

/// Primeiro valor não nulo entre vários nomes de campo (ex.: `estrutura_societaria` vs camelCase).
Object? pickFirstDocumentField(Map<String, dynamic> d, List<String> keys) {
  for (final String k in keys) {
    if (!d.containsKey(k)) {
      continue;
    }
    final Object? v = d[k];
    if (_isAbsentFirestoreValue(v)) {
      continue;
    }
    return v;
  }
  return null;
}

Object? estruturaSocietariaRawFromDocument(Map<String, dynamic> d) {
  return pickFirstDocumentField(d, kFieldEstruturaSocietariaAliases);
}

final RegExp _pctInParens = RegExp(r'\(\s*([0-9]+(?:[.,][0-9]+)?)\s*%?\s*\)\s*$');
final RegExp _pctAfterDash = RegExp(r'[–\-]\s*([0-9]+(?:[.,][0-9]+)?)\s*%?\s*$');
/// Nome seguido de percentagem no fim da linha (ex.: `Vicenzo Trevizan 45%`).
final RegExp _pctTrailingSpace = RegExp(r'^(.+?)\s+(\d{1,3}(?:[.,]\d+)?)\s*%\s*$');

/// Copia o mapa e harmoniza `socios` (preservando campos originais), mentores e modelo.
///
/// Reutilize nas telas que precisem do mesmo contrato (Balcão, relatórios, etc.).
Map<String, dynamic> normalizeStartupDetailDocument(Map<String, dynamic> raw) {
  final Map<String, dynamic> d = Map<String, dynamic>.from(raw);

  final List<Map<String, dynamic>>? socios =
      enrichSociosListPreservingFields(d[kFieldSocios], firestoreDoc: d);
  if (socios != null && socios.isNotEmpty) {
    d[kFieldSocios] = socios;
  }

  final Object? mentoresNorm = _normalizeMentoresRaw(d[kFieldMentoresConselho]);
  if (mentoresNorm != null) {
    d[kFieldMentoresConselho] = mentoresNorm;
  }

  final Object? modeloNorm = _normalizeModeloNegocioRaw(d[kFieldModeloNegocio]);
  if (modeloNorm != null) {
    d[kFieldModeloNegocio] = modeloNorm;
  }

  return d;
}

bool _looksLikeGroupHeader(String s) {
  final String lower = s.toLowerCase().trim();
  const List<String> groups = <String>[
    'sócios',
    'socios',
    'ativos',
    'fundadores',
    'anjo',
    'investidores',
    'outros',
    'esop',
    'conselho',
    'mentores',
    'grupo',
    'categoria',
    'pool',
    'quadro',
    'estrutura',
    'acionistas',
    'capital',
  ];
  for (final String g in groups) {
    if (lower == g || lower.startsWith('$g ') || lower.endsWith(' $g')) {
      return true;
    }
  }
  return false;
}

/// Chave externa vira [Nome] só quando o mapa interno não tem pessoa identificada (ex.: `"Vicenzo Trevizan" → { ... }`).
void _maybeApplyOuterKeyAsNome(
  Map<String, dynamic> merged,
  String keyLabel, {
  required bool fromList,
}) {
  if (keyLabel.isEmpty || socioNomeParaExibicao(merged).isNotEmpty) {
    return;
  }
  if (_looksLikeGroupHeader(keyLabel)) {
    return;
  }
  final List<String> parts =
      keyLabel.split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
  if (fromList && parts.length < 2) {
    return;
  }
  merged['Nome'] = keyLabel;
  merged['nome'] = keyLabel;
}

/// Suporta mapas onde o valor é lista de pessoas, mapa aninhado ou escalar (nome → %).
void _expandSociosMapTopLevel(
  Map<dynamic, dynamic> sociosRaw,
  void Function(Map<String, dynamic>) pushEnriched,
  List<Map<String, dynamic>> stringSink,
) {
  sociosRaw.forEach((Object? k, Object? v) {
    final String keyLabel = k?.toString().trim() ?? '';
    if (v is List) {
      for (final Object? item in v) {
        if (item == null) {
          continue;
        }
        if (item is Map) {
          final Map<String, dynamic> merged = Map<String, dynamic>.from(
            item.map((Object? kk, Object? vv) => MapEntry(kk.toString(), vv)),
          );
          if (keyLabel.isNotEmpty) {
            merged.putIfAbsent('Categoria', () => keyLabel);
          }
          _maybeApplyOuterKeyAsNome(merged, keyLabel, fromList: true);
          pushEnriched(merged);
        } else if (item is String) {
          _parseSociosStringLineToMaps(item, stringSink);
        }
      }
    } else if (v is Map) {
      final Map<String, dynamic> merged = Map<String, dynamic>.from(
        v.map((Object? kk, Object? vv) => MapEntry(kk.toString(), vv)),
      );
      _maybeApplyOuterKeyAsNome(merged, keyLabel, fromList: false);
      pushEnriched(merged);
    } else {
      if (keyLabel.isEmpty) {
        return;
      }
      pushEnriched(<String, dynamic>{
        'Nome': keyLabel,
        'nome': keyLabel,
        'Porcentagem de Participação': v,
        'porcentagem': v is num ? '${_roundNum(v)}%' : v?.toString() ?? '',
      });
    }
  });
}

void _splitEstruturaStringIntoLines(String raw, List<Map<String, dynamic>> appendTo) {
  final String s = raw.trim();
  if (s.isEmpty) {
    return;
  }
  final List<String> segments = s.split(RegExp(r'[\r\n•·]+'));
  for (final String seg in segments) {
    for (final String part in seg.split(';')) {
      _parseSociosStringLineToMaps(part.trim(), appendTo);
    }
  }
}

/// Lista de sócios: cada item é o objeto Firestore **com todos os campos**, mais
/// `nome` + `porcentagem` (string) para compatibilidade com a UI legada.
///
/// Com [firestoreDoc], todos os aliases em [kFieldEstruturaSocietariaAliases] são agregados.
List<Map<String, dynamic>>? enrichSociosListPreservingFields(
  Object? sociosRaw, {
  Map<String, dynamic>? firestoreDoc,
  Object? estruturaFallback,
}) {
  final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];

  void pushEnriched(Map<String, dynamic> original) {
    out.add(enrichSocioMapPreservingFields(original));
  }

  if (sociosRaw != null) {
    if (sociosRaw is Map) {
      _expandSociosMapTopLevel(
        Map<dynamic, dynamic>.from(sociosRaw),
        pushEnriched,
        out,
      );
    } else if (sociosRaw is List) {
      for (final Object? item in sociosRaw) {
        if (item == null) {
          continue;
        }
        if (item is String) {
          _parseSociosStringLineToMaps(item, out);
        } else if (item is Map) {
          final bool looksNested = item.values.any(
            (Object? v) => v is List || (v is Map && v.isNotEmpty),
          );
          if (looksNested) {
            _expandSociosMapTopLevel(
              Map<dynamic, dynamic>.from(item),
              pushEnriched,
              out,
            );
          } else {
            pushEnriched(
              Map<String, dynamic>.from(
                item.map((Object? k, Object? v) => MapEntry(k.toString(), v)),
              ),
            );
          }
        }
      }
    } else if (sociosRaw is String) {
      _splitEstruturaStringIntoLines(sociosRaw, out);
    }
  }

  if (estruturaFallback != null && !_isAbsentFirestoreValue(estruturaFallback)) {
    _appendEstruturaSocietariaFallback(out, estruturaFallback, pushEnriched);
  }

  if (firestoreDoc != null) {
    for (final String alias in kFieldEstruturaSocietariaAliases) {
      final Object? chunk = firestoreDoc[alias];
      if (_isAbsentFirestoreValue(chunk)) {
        continue;
      }
      _appendEstruturaSocietariaFallback(out, chunk, pushEnriched);
    }
  }

  return out.isEmpty ? null : _dedupeSociosMaps(out);
}

void _appendEstruturaSocietariaFallback(
  List<Map<String, dynamic>> out,
  Object? estruturaFallback,
  void Function(Map<String, dynamic>) pushEnriched,
) {
  if (estruturaFallback is List) {
    for (final Object? e in estruturaFallback) {
      if (e is String) {
        _parseSociosStringLineToMaps(e, out);
      } else if (e is Map) {
        final bool looksNested = e.values.any(
          (Object? v) => v is List || (v is Map && v.isNotEmpty),
        );
        if (looksNested) {
          _expandSociosMapTopLevel(
            Map<dynamic, dynamic>.from(e),
            pushEnriched,
            out,
          );
        } else {
          pushEnriched(
            Map<String, dynamic>.from(
              e.map((Object? k, Object? v) => MapEntry(k.toString(), v)),
            ),
          );
        }
      }
    }
  } else if (estruturaFallback is String) {
    _splitEstruturaStringIntoLines(estruturaFallback, out);
  } else if (estruturaFallback is Map) {
    _expandSociosMapTopLevel(
      Map<dynamic, dynamic>.from(estruturaFallback),
      pushEnriched,
      out,
    );
  }
}

/// Evita duplicar a mesma pessoa se aparecer em `socios` e em `estrutura_societaria`.
List<Map<String, dynamic>> _dedupeSociosMaps(List<Map<String, dynamic>> items) {
  final Map<String, Map<String, dynamic>> byNomeLower = <String, Map<String, dynamic>>{};
  final List<Map<String, dynamic>> semNome = <Map<String, dynamic>>[];
  for (final Map<String, dynamic> m in items) {
    final String nome = socioNomeParaExibicao(m).trim();
    if (nome.isEmpty) {
      semNome.add(m);
      continue;
    }
    final String key = nome.toLowerCase();
    final Map<String, dynamic>? prev = byNomeLower[key];
    if (prev == null) {
      byNomeLower[key] = m;
    } else if (m.length > prev.length) {
      byNomeLower[key] = m;
    }
  }
  return <Map<String, dynamic>>[
    ...byNomeLower.values,
    ...semNome,
  ];
}

/// Uma linha de sócio com **campos adicionais** de compatibilidade (`nome`, `porcentagem`).
Map<String, dynamic> enrichSocioMapPreservingFields(Map<String, dynamic> original) {
  final Map<String, dynamic> m = Map<String, dynamic>.from(original);
  final String nome = socioNomeParaExibicao(m);
  final String pct = socioParticipacaoParaExibicao(m);
  if (nome.isNotEmpty) {
    m.putIfAbsent('nome', () => nome);
    m.putIfAbsent('Nome', () => nome);
  }
  if (pct.isNotEmpty) {
    m.putIfAbsent('porcentagem', () => pct);
  }
  return m;
}

/// Nome para cards / linhas (aceita `Nome`, `nome`, … como no Firestore).
String socioNomeParaExibicao(Map<String, dynamic> m) {
  final String direct = _pickFirstNonEmptyString(m, <String>[
    'Nome',
    'nome',
    'name',
    'Nome completo',
    'nome_completo',
    'Nome do sócio',
    'socio',
    'titular',
    'fullName',
    'Sócio',
  ]);
  if (direct.isNotEmpty) {
    return direct;
  }
  for (final MapEntry<String, dynamic> e in m.entries) {
    final String kk = e.key.toLowerCase();
    final bool keyLooksLikePersonName = kk.contains('nome') ||
        kk == 'name' ||
        kk.endsWith('_name') ||
        kk.startsWith('nome');
    if (!keyLooksLikePersonName) {
      continue;
    }
    if (kk.contains('startup') || kk.contains('empresa') || kk.contains('razao')) {
      continue;
    }
    final Object? v = e.value;
    if (v == null) {
      continue;
    }
    final String s = v.toString().trim();
    if (s.isNotEmpty) {
      return s;
    }
  }
  return '';
}

/// Participação formatada para texto (ex.: `55%`).
String socioParticipacaoParaExibicao(Map<String, dynamic> m) {
  return _formatPctLabelExtended(m);
}

/// Compatível com código que esperava só `{ nome, porcentagem }`.
List<Map<String, dynamic>> buildNormalizedSociosEntries(
  Object? sociosRaw, {
  Object? estruturaFallback,
  Map<String, dynamic>? firestoreDoc,
}) {
  final List<Map<String, dynamic>>? full = enrichSociosListPreservingFields(
    sociosRaw,
    estruturaFallback: estruturaFallback,
    firestoreDoc: firestoreDoc,
  );
  if (full == null || full.isEmpty) {
    return <Map<String, dynamic>>[];
  }
  return full
      .map(
        (Map<String, dynamic> m) => <String, dynamic>{
          'nome': socioNomeParaExibicao(m),
          'porcentagem': socioParticipacaoParaExibicao(m),
        },
      )
      .toList();
}

void _parseSociosStringLineToMaps(
  String line,
  List<Map<String, dynamic>> appendTo,
) {
  final String t = line.trim();
  if (t.isEmpty) {
    return;
  }
  final RegExpMatch? mParen = _pctInParens.firstMatch(t);
  if (mParen != null) {
    final String nome = t.substring(0, mParen.start).trim();
    final String n = mParen.group(1) ?? '';
    final String? p = double.tryParse(n.replaceAll(',', '.'))?.round().toString();
    appendTo.add(<String, dynamic>{
      'Nome': nome.isEmpty ? t : nome,
      'nome': nome.isEmpty ? t : nome,
      'porcentagem': p != null ? '$p%' : '',
    });
    return;
  }
  final RegExpMatch? mDash = _pctAfterDash.firstMatch(t);
  if (mDash != null) {
    final String nome = t.substring(0, mDash.start).trim();
    final String n = mDash.group(1) ?? '';
    final String? p = double.tryParse(n.replaceAll(',', '.'))?.round().toString();
    appendTo.add(<String, dynamic>{
      'Nome': nome.isEmpty ? t : nome,
      'nome': nome.isEmpty ? t : nome,
      'porcentagem': p != null ? '$p%' : '',
    });
    return;
  }
  final RegExpMatch? mTrail = _pctTrailingSpace.firstMatch(t);
  if (mTrail != null) {
    final String nome = mTrail.group(1)!.trim();
    final String n = mTrail.group(2) ?? '';
    final String? p = double.tryParse(n.replaceAll(',', '.'))?.round().toString();
    appendTo.add(<String, dynamic>{
      'Nome': nome.isEmpty ? t : nome,
      'nome': nome.isEmpty ? t : nome,
      'porcentagem': p != null ? '$p%' : '',
    });
    return;
  }
  appendTo.add(<String, dynamic>{'Nome': t, 'nome': t, 'porcentagem': ''});
}

String _pickFirstNonEmptyString(Map<String, dynamic> m, List<String> keys) {
  for (final String k in keys) {
    final Object? v = m[k];
    if (v == null) {
      continue;
    }
    final String s = v.toString().trim();
    if (s.isNotEmpty) {
      return s;
    }
  }
  return '';
}

String _formatPctLabelExtended(Map<String, dynamic> m) {
  final List<String> keys = <String>[
    'Porcentagem de Participação',
    'porcentagem',
    'percentual',
    'pct',
    'percent',
    'participacao',
    'Participação',
    'quota',
    'share',
  ];
  for (final String k in keys) {
    final Object? v = m[k];
    if (v is num) {
      return '${_roundNum(v)}%';
    }
    if (v is String) {
      final String s = v.trim();
      if (s.isEmpty) {
        continue;
      }
      if (s.contains('%')) {
        return s;
      }
      final double? p = double.tryParse(s.replaceAll(',', '.').replaceAll('%', ''));
      if (p != null) {
        return '${p.round()}%';
      }
      return s;
    }
  }
  return '';
}

int _roundNum(num v) => v.round();

Object? _normalizeMentoresRaw(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is String) {
    final String t = raw.trim();
    return t.isEmpty ? null : <String>[t];
  }
  if (raw is List) {
    final List<String> names = <String>[];
    for (final Object? e in raw) {
      if (e is String) {
        final String t = e.trim();
        if (t.isNotEmpty) {
          names.add(t);
        }
      } else if (e is Map) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(
          e.map((Object? k, Object? v) => MapEntry(k.toString(), v)),
        );
        final String n = _pickFirstNonEmptyString(map, <String>[
          'nome',
          'Nome',
          'name',
          'mentor',
          'titulo',
        ]);
        if (n.isNotEmpty) {
          names.add(n);
        }
      }
    }
    return names.isEmpty ? null : names;
  }
  return null;
}

Object? _normalizeModeloNegocioRaw(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is List) {
    return raw;
  }
  if (raw is String) {
    final String t = raw.trim();
    if (t.isEmpty) {
      return null;
    }
    return <String>[t];
  }
  if (raw is Map) {
    final List<String> parts = <String>[];
    raw.forEach((Object? k, Object? v) {
      final String ks = k?.toString().trim() ?? '';
      final String vs = v?.toString().trim() ?? '';
      if (ks.isNotEmpty && vs.isNotEmpty) {
        parts.add('$ks: $vs');
      } else if (vs.isNotEmpty) {
        parts.add(vs);
      } else if (ks.isNotEmpty) {
        parts.add(ks);
      }
    });
    return parts.isEmpty ? null : parts;
  }
  return <String>[raw.toString()];
}
