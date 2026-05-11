// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Pré-descarga das fotos/logos das startups para a cache de bitmaps do Flutter
// ([PaintingBinding.instance.imageCache]), em paralelo lógico com o pedido inicial
// do catálogo no [StartupCatalogListCache], para reduzir spinners quando o utilizador
// abre Explorar ou Balcão.

import 'dart:async' show unawaited;

import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

import '../models/catalog_startup.dart';
import '../widgets/startup_logo_avatar.dart';

/// API centralizada para aquecer tanto as URLs Storage quanto as imagens em memória.
///
/// A resolução de URL continua em [startup_logo_avatar.dart] (`_logoUrlCache`); esta
/// classe apenas orquestra o momento do pedido (`BuildContext` montado + lista já carregada).
abstract final class StartupLogoPrecacheService {
  StartupLogoPrecacheService._();

  /// Encadeia todos os `logoPath` das [startups], elimina duplicados no widget e delega em
  /// [preloadStartupLogoBitmaps] (implementação técnica no ficheiro do avatar).
  ///
  /// Chamada típica: após [StartupCatalogListCache.fullList], no primeiro quadro há
  /// [mounted] garantido pelo [StatefulWidget].
  ///
  /// O retorno é um `Future` opcionalmente ignorado pelo chamador (ex.: corre em fundo para
  /// não atrasar navegações); até completar as imagens vão ficando disponíveis na cache.
  static Future<void> preloadForStartupList(
    BuildContext context,
    List<CatalogStartup> startups,
  ) async {
    return preloadStartupLogoBitmaps(
      context,
      startups.map((CatalogStartup s) => s.logoPath),
    );
  }

  /// Variante quando já se tem só os caminhos (ex.: testes ou outro pipeline).
  static Future<void> preloadForLogoPaths(
    BuildContext context,
    Iterable<String?> logoPaths,
  ) async {
    return preloadStartupLogoBitmaps(context, logoPaths);
  }

  /// Dispara [preloadForStartupList] sem `await` e **após um quadro**.
  ///
  /// Garante [MediaQuery] disponível mesmo quando [Future.then] regressa já na mesma
  /// volta do ciclo desde [initState] (lista de teste ou cache instantâneo).
  static void schedulePreloadForStartupList(
    BuildContext context,
    List<CatalogStartup> startups,
  ) {
    final copied = List<CatalogStartup>.from(startups);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      unawaited(preloadForStartupList(context, copied));
    });
  }
}
