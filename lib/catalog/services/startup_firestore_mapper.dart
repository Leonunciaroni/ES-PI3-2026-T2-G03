// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Funções partilhadas entre catálogo e detalhe: ler campos do Firestore e montar [CatalogStartup].

export 'startup_firestore_schema.dart';

import 'package:flutter/material.dart';
import 'package:pi_iii/catalog/models/catalog_startup.dart';

import 'startup_firestore_schema.dart';

/// Placeholder de rendimento até existir valor em [kFieldRendimentoLabel].
const String kPlaceholderYieldLabel = 'N/D';

/// Constrói [CatalogStartup] a partir do mapa de um documento e do [documentId].
///
/// Devolve null se faltar [kFieldNomeStartup]. Usado na lista Explorar e na rota de detalhe.
CatalogStartup? catalogStartupFromFirestoreMap(
  String documentId,
  Map<String, dynamic> d,
) {
  try {
    final String name = readFirestoreString(d, kFieldNomeStartup);
    if (name.trim().isEmpty) {
      return null;
    }
    final String setorRaw = readFirestoreString(d, kFieldSetor);
    final String category =
        setorRaw.trim().isEmpty ? 'SETOR' : setorRaw.toUpperCase();
    final String description = readFirestoreString(d, kFieldDescricao);
    final StartupStage stage =
        parseFirestoreStage(readFirestoreString(d, kFieldEstagio));
    final String? sigla = _siglaFromFirestore(d);
    final String? logoPath = readFirestoreLogoStoragePath(d);
    final Color logoColor = firestoreColorForSector(setorRaw);
    final IconData logoIcon = firestoreIconForSector(setorRaw);
    final String yieldPercentLabel = yieldLabelFromFirestore(d);
    final double tokenPrice = tokenPriceFromFirestore(d);
    final double captureProgress = captureProgressFractionFromFirestore(d);
    return CatalogStartup(
      name: name,
      category: category,
      stage: stage,
      yieldPercentLabel: yieldPercentLabel,
      tokenPrice: tokenPrice,
      description: description,
      captureProgress: captureProgress,
      logoColor: logoColor,
      logoIcon: logoIcon,
      sigla: sigla,
      firestoreId: documentId,
      logoPath: logoPath,
    );
  } catch (_) {
    return null;
  }
}

String? _siglaFromFirestore(Map<String, dynamic> d) {
  final String? direct = readFirestoreOptionalString(d, kFieldSigla);
  if (direct != null && direct.isNotEmpty) {
    return direct.trim().toUpperCase();
  }

  final Map<String, dynamic>? tokens = _asStringKeyMap(d[kFieldTokensEmitidos]);
  if (tokens == null) return null;

  // No console, o campo tem aparecido como map com "sigla" ou "nome".
  final String raw = (readFirestoreString(tokens, 'sigla').trim().isNotEmpty
          ? readFirestoreString(tokens, 'sigla')
          : readFirestoreString(tokens, 'nome'))
      .trim();
  if (raw.isEmpty) return null;
  return raw.toUpperCase();
}

Map<String, dynamic>? _asStringKeyMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    final out = <String, dynamic>{};
    v.forEach((k, value) {
      if (k != null) out[k.toString()] = value;
    });
    return out;
  }
  return null;
}

/// Lê string; campo ausente ou tipo estranho vira string vazia ou [toString].
String readFirestoreString(Map<String, dynamic> d, String key) {
  final Object? v = d[key];
  if (v is String) {
    return v;
  }
  if (v != null) {
    return v.toString();
  }
  return '';
}

/// String opcional: null se vazia.
String? readFirestoreOptionalString(Map<String, dynamic> d, String key) {
  final String s = readFirestoreString(d, key).trim();
  if (s.isEmpty) {
    return null;
  }
  return s;
}

/// Caminho ou URL do logo: aceita [kFieldLogoPath] ou [kFieldLogoPathSnake].
String? readFirestoreLogoStoragePath(Map<String, dynamic> d) {
  return readFirestoreOptionalString(d, kFieldLogoPath) ??
      readFirestoreOptionalString(d, kFieldLogoPathSnake);
}

double? readFirestoreOptionalDouble(Map<String, dynamic> d, String key) {
  final Object? v = d[key];
  if (v is num) {
    return v.toDouble();
  }
  if (v is String) {
    return double.tryParse(v.trim().replaceAll(',', '.'));
  }
  return null;
}

String yieldLabelFromFirestore(Map<String, dynamic> d) {
  final String? s = readFirestoreOptionalString(d, kFieldRendimentoLabel);
  if (s != null && s.isNotEmpty) {
    return s;
  }
  return kPlaceholderYieldLabel;
}

double tokenPriceFromFirestore(Map<String, dynamic> d) {
  return readFirestoreOptionalDouble(d, kFieldPrecoToken) ?? 0.0;
}

double captureProgressFractionFromFirestore(Map<String, dynamic> d) {
  final double? v = readFirestoreOptionalDouble(d, kFieldProgressoCaptacao);
  if (v == null) {
    return 0.0;
  }
  if (v > 1.0) {
    return (v / 100.0).clamp(0.0, 1.0);
  }
  return v.clamp(0.0, 1.0);
}

String _foldPortuguese(String s) {
  return s
      .toLowerCase()
      .trim()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c');
}

/// Igual à lógica do catálogo: texto livre → enum.
StartupStage parseFirestoreStage(String raw) {
  final String x = _foldPortuguese(raw);
  if (x.contains('expans')) {
    return StartupStage.emExpansao;
  }
  if (x.contains('operac')) {
    return StartupStage.emOperacao;
  }
  if (x.contains('nova')) {
    return StartupStage.nova;
  }
  return StartupStage.nova;
}

/// Ícone por setor (mesma heurística do catálogo).
IconData firestoreIconForSector(String setor) {
  final String k = _foldPortuguese(setor);
  if (k.contains('fin')) {
    return Icons.account_balance_outlined;
  }
  if (k.contains('agro')) {
    return Icons.eco_outlined;
  }
  if (k.contains('health') || k.contains('medic')) {
    return Icons.favorite_outline;
  }
  if (k.contains('cyber') || k.contains('sec')) {
    return Icons.security_outlined;
  }
  if (k.contains('edu')) {
    return Icons.school_outlined;
  }
  return Icons.lightbulb_outline;
}

/// Cor do avatar/quadrado por setor.
Color firestoreColorForSector(String setor) {
  final String k = _foldPortuguese(setor);
  if (k.contains('fin')) {
    return const Color(0xFF6234EA);
  }
  if (k.contains('agro')) {
    return const Color(0xFF22C55E);
  }
  if (k.contains('health') || k.contains('medic')) {
    return const Color(0xFF14B8A6);
  }
  if (k.contains('cyber') || k.contains('sec')) {
    return const Color(0xFF18181B);
  }
  if (k.contains('edu')) {
    return const Color(0xFF3B82F6);
  }
  return const Color(0xFF7C3AED);
}
