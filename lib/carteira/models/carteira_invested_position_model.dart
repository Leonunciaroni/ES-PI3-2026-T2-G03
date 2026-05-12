// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Modelo de dados de uma **startup investida** vindos de `sim_wallet/.../positions`
// cruzados opcionalmente com o catálogo. Partilhado entre [CarteiraScreen] e [DashboardScreen].

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../catalog/models/catalog_startup.dart';
import '../../catalog/services/startup_firestore_mapper.dart';
import '../invested_startup_position_math.dart';
import '../widgets/invested_startup_card.dart';

/// Estado agregado por posição (custos, rótulo de rendimento, branding).
class CarteiraInvestedPositionModel {
  const CarteiraInvestedPositionModel({
    required this.nome,
    required this.categoria,
    required this.rendimentoLabel,
    required this.totalInvestido,
    required this.valorMercadoAtualBrl,
    required this.corLogo,
    required this.icone,
    this.logoPath,
  });

  final String nome;
  final String categoria;
  final String rendimentoLabel;

  /// Capital investido (custos) em reais.
  final double totalInvestido;

  /// Valor de mercado atual (tokens × cotação quando possível).
  final double valorMercadoAtualBrl;
  final Color corLogo;
  final IconData icone;
  final String? logoPath;

  /// Converte no DTO leve consumido pelo widget [InvestedStartupCard].
  InvestedStartupRowUi toInvestedRowUi() {
    return InvestedStartupRowUi(
      nome: nome,
      categoria: categoria,
      corLogo: corLogo,
      icone: icone,
      logoPath: logoPath,
    );
  }
}

/// Igual à lógica antes privada em `carteira_screen.dart` — não duplicar regras aqui.
CarteiraInvestedPositionModel mapFirestorePosicaoParaInvestida(
  QueryDocumentSnapshot<Map<String, dynamic>> d, {
  CatalogStartup? catalogMatch,
}) {
  final m = d.data();
  final nomeFs = ((m['startupName'] as String?) ?? '').trim();
  final nome = (catalogMatch?.name.trim().isNotEmpty ?? false)
      ? catalogMatch!.name.trim()
      : (nomeFs.isNotEmpty ? nomeFs : 'Startup');

  final catRaw =
      ((catalogMatch?.category ?? (m['category'] as String?)) ?? '—').trim();
  final setor = catRaw.isEmpty ? '—' : catRaw;

  final cost = (m['costBasisBrl'] as num?)?.toDouble() ?? 0.0;
  final held = (m['tokensHeld'] as num?)?.toDouble() ?? 0.0;
  final px = catalogMatch?.tokenPrice ?? 0.0;
  final rendimentoLabel = carteiraYieldPercentLabel(
    costBasisBrl: cost,
    tokensHeld: held,
    tokenPriceBrl: px,
  );

  final valorMercadoAtualBrl =
      (px > 1e-9 && held.isFinite && held >= 0) ? held * px : cost;

  return CarteiraInvestedPositionModel(
    nome: nome,
    categoria: setor.toUpperCase(),
    rendimentoLabel: rendimentoLabel,
    totalInvestido: cost,
    valorMercadoAtualBrl: valorMercadoAtualBrl,
    corLogo: catalogMatch?.logoColor ?? firestoreColorForSector(setor),
    icone: catalogMatch?.logoIcon ?? firestoreIconForSector(setor),
    logoPath: catalogMatch?.logoPath,
  );
}
