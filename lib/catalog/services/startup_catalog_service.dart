// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Serviço que lê a coleção de startups no Firestore e transforma cada documento
// num [CatalogStartup] para a tela Explorar. Comentários passo a passo para estudo.

// Import do SDK Flutter: cores e ícones usados no card do catálogo.
import 'package:flutter/material.dart';
// Cliente Firestore: conversa com a base de dados na nuvem do Firebase.
import 'package:cloud_firestore/cloud_firestore.dart';
// Modelo que a UI já conhece (nome, setor, estágio, etc.).
import 'package:pi_iii/catalog/models/catalog_startup.dart';

/// Nome da coleção no console Firebase (ajuste aqui se o ID for outro).
///
/// No Firestore, em "Coleções", o identificador deve coincidir com esta string.
const String kFirestoreStartupsCollection = 'startups';

/// Texto temporário até existir rendimento vindo do backend ou cálculo oficial.
const String kPlaceholderYieldLabel = 'N/D';

/// Serviço pequeno: só expõe um [Stream] de lista para a tela ouvir em tempo real.
class StartupCatalogService {
  /// Referência à instância única do Firestore (já configurada após [Firebase.initializeApp]).
  final FirebaseFirestore _db;

  /// Construtor com injeção opcional: nos testes de integração futuros pode passar mock.
  StartupCatalogService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Devolve um fluxo contínuo: cada vez que um documento muda, a lista é reemitida.
  ///
  /// A UI usa [StreamBuilder] em cima deste stream — não precisa de "atualizar" manualmente.
  Stream<List<CatalogStartup>> watchStartups() {
    // snapshots() subscreve alterações na coleção inteira (add/update/delete).
    return _db.collection(kFirestoreStartupsCollection).snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        // Lista acumulada desta "rodada" de documentos.
        final List<CatalogStartup> out = [];
        // Percorre cada documento devolvido pelo Firestore.
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
          // Tenta converter; um documento mal formatado não derruba os outros.
          final CatalogStartup? item = _tryMapDocument(doc);
          if (item != null) {
            // Só adiciona entradas válidas.
            out.add(item);
          }
        }
        // Ordem estável e legível: ordena pelo nome, ignorando maiúsculas.
        out.sort(
          (CatalogStartup a, CatalogStartup b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        return out;
      },
    );
  }

  /// Converte [doc] em modelo ou devolve null se faltar dado essencial.
  CatalogStartup? _tryMapDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      // data() traz o mapa chave → valor guardado no documento.
      final Map<String, dynamic> d = doc.data();
      // Nome é obrigatório para o card; campo real no Firestore: nome_startup.
      final String name = _readString(d, 'nome_startup');
      if (name.trim().isEmpty) {
        // Sem nome não faz sentido mostrar no catálogo.
        return null;
      }
      // Setor vira "categoria" no layout (ex.: FinTech → pode exibir em maiúsculas).
      final String setorRaw = _readString(d, 'setor');
      final String category = setorRaw.trim().isEmpty ? 'SETOR' : setorRaw.toUpperCase();
      // Descrição longa do projeto.
      final String description = _readString(d, 'descricao');
      // Estágio vem como texto livre; convertemos para o enum do app.
      final StartupStage stage = _parseStage(_readString(d, 'estagio'));
      // Sigla opcional (ex.: ABKT) — entra na busca, não muda o layout do card.
      final String? sigla = _readOptionalString(d, 'sigla');
      // Cor e ícone decorativos: derivados do setor para manter cards coloridos.
      final Color logoColor = _colorForSector(setorRaw);
      final IconData logoIcon = _iconForSector(setorRaw);
      // Rendimento: placeholder até haver regra de negócio (pedido do projeto).
      const String yieldPercentLabel = kPlaceholderYieldLabel;
      // Preço do token: 0.0 sinaliza à UI para mostrar "—" (sem inventar valor).
      const double tokenPrice = 0.0;
      // Barra de captação: 0% até calcular depois (não usar % de sócios agora).
      const double captureProgress = 0.0;
      // Monta o objeto imutável que o Flutter já sabe desenhar.
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
      );
    } catch (_) {
      // Qualquer erro de tipo inesperado: ignora só este documento.
      return null;
    }
  }
}

/// Lê string obrigatória; se o campo não existir ou não for texto, devolve ''.
String _readString(Map<String, dynamic> d, String key) {
  final Object? v = d[key];
  if (v is String) {
    return v;
  }
  if (v != null) {
    return v.toString();
  }
  return '';
}

/// Lê string opcional: null se vazio ou ausente (útil para não poluir o modelo).
String? _readOptionalString(Map<String, dynamic> d, String key) {
  final String s = _readString(d, key).trim();
  if (s.isEmpty) {
    return null;
  }
  return s;
}

/// Normaliza acentos comuns para comparar estágio vindo do Firestore com palavras-chave.
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

/// Mapeia texto humano ("Em expansão") para o enum [StartupStage].
StartupStage _parseStage(String raw) {
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
  // Fallback seguro: trata como ideia nova se o texto não reconhecermos.
  return StartupStage.nova;
}

/// Escolhe um ícone Material aproximado pelo nome do setor (heurística simples).
IconData _iconForSector(String setor) {
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

/// Cor de destaque para o quadrado do ícone, alinhada ao tom do setor.
Color _colorForSector(String setor) {
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
