// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592

import 'package:pi_iii/catalog/data/startup_detail_mock.dart';

/// Estado de carregamento do detalhe (evita spinner infinito quando o doc não existe).
sealed class StartupDetailLoadState {
  const StartupDetailLoadState();
}

/// Ainda não chegou o primeiro snapshot do Firestore.
final class StartupDetailLoading extends StartupDetailLoadState {
  const StartupDetailLoading();
}

/// Documento inexistente ou dados insuficientes para montar o modelo.
final class StartupDetailNotFound extends StartupDetailLoadState {
  const StartupDetailNotFound();
}

/// Dados prontos para a [StartupDetailScreen].
final class StartupDetailReady extends StartupDetailLoadState {
  const StartupDetailReady(this.data);

  final StartupDetailViewData data;
}
