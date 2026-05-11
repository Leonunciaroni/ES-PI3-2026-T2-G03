// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Serviço que lê a coleção de startups no Firestore e transforma cada documento
// num [CatalogStartup] para a tela Explorar. Comentários passo a passo para estudo.

// Cliente Firestore: conversa com a base de dados na nuvem do Firebase.
import 'package:cloud_firestore/cloud_firestore.dart';
// Modelo que a UI já conhece (nome, setor, estágio, etc.).
import 'package:mescla_invest/catalog/models/catalog_startup.dart';
import 'package:mescla_invest/catalog/widgets/startup_logo_avatar.dart';

import 'startup_firestore_mapper.dart';

export 'startup_firestore_mapper.dart' show kFirestoreStartupsCollection;

/// Serviço pequeno: só expõe um [Stream] de lista para a tela ouvir em tempo real.
class StartupCatalogService {
  /// Referência à instância única do Firestore (já configurada após [Firebase.initializeApp]).
  final FirebaseFirestore _db;

  /// Construtor com injeção opcional: nos testes de integração futuros pode passar mock.
  StartupCatalogService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Devolve um fluxo contínuo: cada vez que um documento muda, a lista é reemitida.
  /// Para muitas startups, considere paginação ou queries filtradas (escala).
  Stream<List<CatalogStartup>> watchStartups() {
    return _db.collection(kFirestoreStartupsCollection).snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final List<CatalogStartup> out = [];
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
          final CatalogStartup? item = catalogStartupFromFirestoreMap(doc.id, doc.data());
          if (item != null) {
            out.add(item);
          }
        }
        out.sort(
          (CatalogStartup a, CatalogStartup b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        // Pré-aquece o cache de URLs do Storage para todos os logos da lista.
        // Quando o utilizador navegar para Balcão, Detalhes, etc.,
        // o Future já está resolvido e o logo aparece imediatamente.
        prewarmLogoUrlCache(out.map((s) => s.logoPath));
        return out;
      },
    );
  }
}
