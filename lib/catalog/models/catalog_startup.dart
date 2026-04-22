// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Modelos partilhados entre o catálogo (Explorar) e a tela de detalhes da startup.
// Os cards podem vir do Firestore ([firestoreId] preenchido) ou de dados locais de pré-visualização.

import 'package:flutter/material.dart';

/// Estágios possíveis de uma startup no ecossistema (documento MesclaInvest §5.2).
///
/// O [enum] obriga o [switch] a tratar todos os valores — evita esquecer um caso.
enum StartupStage {
  /// Ideia recentemente publicada.
  nova,

  /// Operação em curso.
  emOperacao,

  /// Crescimento / expansão.
  emExpansao,
}

/// Linha do catálogo: informação mínima do card na lista "Explorar".
///
/// [captureProgress] ∈ [0, 1] alimenta barras de captação no catálogo e no detalhe.
class CatalogStartup {
  const CatalogStartup({
    required this.name,
    required this.category,
    required this.stage,
    required this.yieldPercentLabel,
    required this.tokenPrice,
    required this.description,
    required this.captureProgress,
    required this.logoColor,
    required this.logoIcon,
    this.sigla,
    this.firestoreId,
  });

  /// Nome comercial exibido no card e no cabeçalho do detalhe.
  final String name;

  /// Setor ou vertente (ex.: AGROTECH), em maiúsculas no layout.
  final String category;

  /// Estágio de maturidade (filtros do catálogo).
  final StartupStage stage;

  /// Texto já formatado para o rendimento (ex.: "+18.5%").
  final String yieldPercentLabel;

  /// Preço unitário simulado do token em reais.
  final double tokenPrice;

  /// Resumo curto do projeto.
  final String description;

  /// Fração da meta de captação já atingida (0.0 a 1.0).
  final double captureProgress;

  /// Cor de fundo do quadrado com ícone no card.
  final Color logoColor;

  /// Ícone Material representando o setor.
  final IconData logoIcon;

  /// Sigla/ticker (ex.: ABKT) para busca no catálogo; opcional.
  final String? sigla;

  /// ID do documento na coleção Firestore `startups`; null só em mock/preview local.
  final String? firestoreId;
}
