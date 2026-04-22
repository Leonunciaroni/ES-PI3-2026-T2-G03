// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Funções partilhadas entre catálogo e detalhe: ler campos do Firestore e montar [CatalogStartup].

import 'package:flutter/material.dart';
import 'package:pi_iii/catalog/models/catalog_startup.dart';

/// Nome da coleção no console Firebase (mesmo ID em catálogo e detalhe).
const String kFirestoreStartupsCollection = 'startups';

/// Placeholder de rendimento até regra de negócio no backend.
const String kPlaceholderYieldLabel = 'N/D';

/// Constrói [CatalogStartup] a partir do mapa de um documento e do [documentId].
///
/// Devolve null se faltar [nome_startup]. Usado na lista Explorar e na rota de detalhe.
CatalogStartup? catalogStartupFromFirestoreMap(
  String documentId,
  Map<String, dynamic> d,
) {
  try {
    final String name = readFirestoreString(d, 'nome_startup');
    if (name.trim().isEmpty) {
      return null;
    }
    final String setorRaw = readFirestoreString(d, 'setor');
    final String category =
        setorRaw.trim().isEmpty ? 'SETOR' : setorRaw.toUpperCase();
    final String description = readFirestoreString(d, 'descricao');
    final StartupStage stage = parseFirestoreStage(readFirestoreString(d, 'estagio'));
    final String? sigla = readFirestoreOptionalString(d, 'sigla');
    final Color logoColor = firestoreColorForSector(setorRaw);
    final IconData logoIcon = firestoreIconForSector(setorRaw);
    const String yieldPercentLabel = kPlaceholderYieldLabel;
    const double tokenPrice = 0.0;
    const double captureProgress = 0.0;
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
    );
  } catch (_) {
    return null;
  }
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
