// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Chama a callable `listStartups` (us-central1) e converte o JSON em [CatalogStartup]
// e, com `includeDetail`, em [StartupDetailViewData].

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:pi_iii/catalog/data/startup_detail_mock.dart';
import 'package:pi_iii/catalog/models/catalog_startup.dart';
import 'package:pi_iii/catalog/services/startup_detail_service.dart';
import 'package:pi_iii/catalog/services/startup_firestore_mapper.dart';

/// Converte o código de estágio da API (`nova`, `em_operacao`, …) em texto
/// que o [parseFirestoreStage] já entende (igual ao que costuma estar no Firestore).
String _estagioTextFromApiCode(String? code) {
  switch (code) {
    case 'em_expansao':
      return 'Em expansão';
    case 'em_operacao':
      return 'Em operação';
    case 'nova':
    default:
      return 'Nova';
  }
}

void _mergeCallableDetailIntoMap(Map<String, dynamic> map, Object? detailAny) {
  final Object? raw = detailAny;
  if (raw == null || raw is! Map) {
    return;
  }
  final Map<String, dynamic> dm = Map<String, dynamic>.from(
    raw.map(
      (Object? k, Object? v) => MapEntry(k.toString(), v),
    ),
  );
  dm.forEach((String k, dynamic v) {
    if (v != null) {
      map[k] = v;
    }
  });
}

/// Monta um mapa no **mesmo formato** do documento Firestore a partir de um item
/// retornado por `listStartups`, para reutilizar [catalogStartupFromFirestoreMap]
/// e [detailViewDataFromFirestoreMap] sem duplicar regras.
Map<String, dynamic> firestoreShapedMapFromApiItem(
  Map<String, dynamic> item,
) {
  final Object? detailAny = item['detail'];
  final map = <String, dynamic>{
    kFieldNomeStartup: item['name'] == null ? '' : item['name'].toString(),
    kFieldDescricao: item['shortDescription'] == null
        ? ''
        : item['shortDescription'].toString(),
    kFieldSetor: item['setor'] ?? '',
    kFieldEstagio: _estagioTextFromApiCode(item['stage']?.toString()),
    kFieldPrecoToken: item['tokenPrice'],
    kFieldProgressoCaptacao: item['captureProgress'],
    kFieldRendimentoLabel: item['yieldPercentLabel'],
  };
  final String? sigla = item['sigla'] as String?;
  if (sigla != null && sigla.isNotEmpty) {
    map[kFieldSigla] = sigla;
  }
  final String? logo = item['logoPath'] as String?;
  if (logo != null && logo.isNotEmpty) {
    map[kFieldLogoPath] = logo;
  }
  _mergeCallableDetailIntoMap(map, detailAny);
  return map;
}

String _apiItemId(Map<String, dynamic> item) {
  final Object? v = item['id'];
  if (v is String) {
    return v;
  }
  if (v != null) {
    return v.toString();
  }
  return '';
}

CatalogStartup? catalogStartupFromApiItem(Map<String, dynamic> item) {
  final String id = _apiItemId(item);
  if (id.isEmpty) {
    return null;
  }
  final merged = firestoreShapedMapFromApiItem(item);
  return catalogStartupFromFirestoreMap(id, merged);
}

/// Interpreta o JSON devolvido por `listStartups` (`data` + `count`, ou lista direta).
({List<Map<String, dynamic>> rows, int? backendCount}) _parseListStartupsPayload(
  Object? raw,
) {
  int? countFromMap(Map<String, dynamic> m) {
    final Object? c = m['count'];
    if (c is num) {
      return c.toInt();
    }
    return null;
  }

  if (raw == null) {
    if (kDebugMode) {
      debugPrint('[listStartups] resposta null');
    }
    return (rows: <Map<String, dynamic>>[], backendCount: null);
  }

  if (raw is List) {
    final rows = <Map<String, dynamic>>[];
    for (final Object? e in raw) {
      if (e is Map) {
        rows.add(
          Map<String, dynamic>.from(
            e.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
          ),
        );
      }
    }
    return (rows: rows, backendCount: rows.length);
  }

  if (raw is! Map) {
    if (kDebugMode) {
      debugPrint('[listStartups] tipo inesperado: ${raw.runtimeType}');
    }
    return (rows: <Map<String, dynamic>>[], backendCount: null);
  }

  final Map<String, dynamic> top = Map<String, dynamic>.from(
    raw.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
  );

  int? backendCount = countFromMap(top);

  dynamic dataField = top['data'];
  if (dataField == null && top['result'] is Map) {
    final Map<String, dynamic> nested = Map<String, dynamic>.from(
      (top['result'] as Map<dynamic, dynamic>)
          .map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
    );
    backendCount ??= countFromMap(nested);
    dataField = nested['data'];
  }

  if (dataField is! List) {
    if (kDebugMode) {
      debugPrint(
        '[listStartups] sem lista em data (keys: ${top.keys.join(", ")})',
      );
    }
    return (rows: <Map<String, dynamic>>[], backendCount: backendCount);
  }

  final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  for (final Object? row in dataField) {
    if (row is Map) {
      rows.add(
        Map<String, dynamic>.from(
          row.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
        ),
      );
    }
  }
  return (rows: rows, backendCount: backendCount ?? rows.length);
}

bool _matchesCatalogStage(CatalogStartup s, StartupStage? filter) {
  if (filter == null) {
    return true;
  }
  return s.stage == filter;
}

bool _matchesCatalogSearch(CatalogStartup s, String? search) {
  final String t = search?.trim() ?? '';
  if (t.isEmpty) {
    return true;
  }
  final String q = t.toLowerCase();
  final String sigla = s.sigla?.toLowerCase() ?? '';
  return s.name.toLowerCase().contains(q) ||
      s.category.toLowerCase().contains(q) ||
      s.description.toLowerCase().contains(q) ||
      (sigla.isNotEmpty && sigla.contains(q));
}

Future<List<CatalogStartup>> _listStartupsFromFirestoreFallback({
  required StartupStage? stage,
  required String? search,
}) async {
  try {
    final QuerySnapshot<Map<String, dynamic>> snap =
        await FirebaseFirestore.instance
            .collection(kFirestoreStartupsCollection)
            .get();
    final List<CatalogStartup> list = <CatalogStartup>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      final CatalogStartup? c = catalogStartupFromFirestoreMap(doc.id, doc.data());
      if (c != null) {
        list.add(c);
      }
    }
    list.sort(
      (CatalogStartup a, CatalogStartup b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return list
        .where((CatalogStartup s) => _matchesCatalogStage(s, stage))
        .where((CatalogStartup s) => _matchesCatalogSearch(s, search))
        .toList();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[listStartups] Firestore fallback falhou: $e');
    }
    return <CatalogStartup>[];
  }
}

Future<StartupDetailViewData?> _fetchStartupDetailFromFirestore(
  String startupId,
) async {
  final String id = startupId.trim();
  if (id.isEmpty) {
    return null;
  }
  try {
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await FirebaseFirestore.instance
            .collection(kFirestoreStartupsCollection)
            .doc(id)
            .get();
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
    if (kDebugMode) {
      debugPrint(
        '[fetchStartupDetail] detalhe via Firestore (callable vazia ou emulador).',
      );
    }
    return detailViewDataFromFirestoreMap(raw, catalog);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[fetchStartupDetail] Firestore: $e');
    }
    return null;
  }
}

/// Serviço que lista startups via Firebase Callable Function `listStartups`.
class StartupCatalogFunctionsService {
  StartupCatalogFunctionsService({FirebaseFunctions? functions})
      : _functions = functions;

  final FirebaseFunctions? _functions;

  /// Mesma região que [TwoFactorService] — deploy em `us-central1`.
  FirebaseFunctions get _instance =>
      _functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Lista resumida (Explorar / Balcão — lista inicial).
  Future<List<CatalogStartup>> listStartups({
    StartupStage? stage,
    String? search,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{};
    if (stage != null) {
      payload['stage'] = _apiStageCode(stage);
    }
    if (search != null && search.trim().isNotEmpty) {
      payload['search'] = search.trim();
    }
    payload['includeDetail'] = false;

    final result = await _instance
        .httpsCallable('listStartups')
        .call<Map<Object?, Object?>>(payload);

    final parsed = _parseListStartupsPayload(result.data);
    final List<Map<String, dynamic>> rows = parsed.rows;
    final int? backendCount = parsed.backendCount;

    if (kDebugMode && backendCount != null && backendCount > 0 && rows.isEmpty) {
      debugPrint(
        '[listStartups] backend count=$backendCount mas lista de linhas vazia '
        '(payload ou coleção Firestore).',
      );
    }

    final out = <CatalogStartup>[];
    for (final Map<String, dynamic> map in rows) {
      final c = catalogStartupFromApiItem(map);
      if (c != null) {
        out.add(c);
      }
    }

    if (kDebugMode &&
        backendCount != null &&
        backendCount > 0 &&
        out.length < backendCount) {
      debugPrint(
        '[listStartups] $backendCount itens no servidor, ${out.length} após mapear '
        '(verifique id nos JSON).',
      );
    }

    if (out.isEmpty) {
      final List<CatalogStartup> fromFs =
          await _listStartupsFromFirestoreFallback(
        stage: stage,
        search: search,
      );
      if (fromFs.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[listStartups] callable devolveu 0 itens; Firestore direto: '
            '${fromFs.length} (ex.: emulador de Functions sem dados ou deploy em falta).',
          );
        }
        return fromFs;
      }
    }

    if (kDebugMode && out.isEmpty) {
      debugPrint(
        '[listStartups] 0 itens no ecrã (count do servidor: ${backendCount ?? "desconhecido"}). '
        'Verifique: coleção `startups` no Firestore, campos `nome_startup` ou `name`, '
        'deploy de `listStartups` (us-central1) e login.',
      );
    }

    return out;
  }

  /// Detalhe completo para uma startup (substitui leitura direta do Firestore).
  ///
  /// Tenta a callable `listStartups` com `includeDetail`; se falhar ou vier vazia
  /// (ex.: emulador de Functions sem dados), lê o documento diretamente no Firestore.
  Future<StartupDetailViewData?> fetchStartupDetail(String startupId) async {
    final String id = startupId.trim();
    if (id.isEmpty) {
      return null;
    }

    try {
      final result = await _instance
          .httpsCallable('listStartups')
          .call<Map<Object?, Object?>>(<String, dynamic>{
        'includeDetail': true,
        'startupId': id,
      });

      final parsed = _parseListStartupsPayload(result.data);
      if (parsed.rows.isNotEmpty) {
        final Map<String, dynamic> item =
            Map<String, dynamic>.from(parsed.rows.first);
        final CatalogStartup? catalog = catalogStartupFromApiItem(item);
        if (catalog != null) {
          final Map<String, dynamic> merged = firestoreShapedMapFromApiItem(item);
          return detailViewDataFromFirestoreMap(merged, catalog);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[fetchStartupDetail] callable falhou ou vazia: $e');
      }
    }

    return _fetchStartupDetailFromFirestore(id);
  }

  static String _apiStageCode(StartupStage s) {
    switch (s) {
      case StartupStage.nova:
        return 'nova';
      case StartupStage.emOperacao:
        return 'em_operacao';
      case StartupStage.emExpansao:
        return 'em_expansao';
    }
  }

  /// Mensagens amigáveis para erros da callable (login, rede, argumentos).
  static String messageForError(Object error) {
    if (error is FirebaseFunctionsException) {
      final code = error.code.toLowerCase().replaceAll('_', '-');
      if (kDebugMode) {
        debugPrint(
          '[listStartups] code=$code message=${error.message}',
        );
      }
      switch (code) {
        case 'unauthenticated':
          return 'Faça login para ver o catálogo.';
        case 'invalid-argument':
          return error.message?.trim().isNotEmpty == true
              ? error.message!.trim()
              : 'Parâmetros inválidos.';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'Serviço indisponível. Em debug: confira o emulador de Functions.';
        default:
          return 'Não foi possível carregar estes dados agora.';
      }
    }
    return 'Não foi possível carregar estes dados agora.';
  }
}
