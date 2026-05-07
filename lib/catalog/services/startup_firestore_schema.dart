// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Contrato único dos nomes de campos Firestore para startups.
// Mantém [StartupCatalogService] (Firestore direto, legado) e a callable / [StartupDetailService] alinhados.

/// Nome da coleção no console Firebase.
const String kFirestoreStartupsCollection = 'startups';

// --- Obrigatório para listagem no Explorar ---
//
/// Nome comercial. Se vazio ou ausente, o documento é ignorado no catálogo.
const String kFieldNomeStartup = 'nome_startup';

/// Texto longo / resumo (pode ser vazio).
const String kFieldDescricao = 'descricao';

/// Setor livre (ex.: agro, fintech); alimenta categoria e ícone.
const String kFieldSetor = 'setor';

/// Estágio (texto livre interpretado por [parseFirestoreStage]).
const String kFieldEstagio = 'estagio';

/// Sigla ou ticker opcional.
const String kFieldSigla = 'sigla';

/// Caminho do logo no Firebase Storage (ex.: `logos/startups/nome.png`) — camelCase.
const String kFieldLogoPath = 'logoPath';

/// Mesmo significado que [kFieldLogoPath]; use no console se preferir snake_case.
const String kFieldLogoPathSnake = 'logo_path';

// --- Card do catálogo (opcional; fallback 0 ou N/D) ---

/// Preço unitário do token em reais (número).
const String kFieldPrecoToken = 'preco_token';

/// Progresso da meta de captação: 0.0–1.0 ou 0–100.
const String kFieldProgressoCaptacao = 'progresso_captacao';

/// Rendimento já formatado para o card (ex.: "+18,5%"); se ausente, usa placeholder.
const String kFieldRendimentoLabel = 'rendimento_label';

// --- Detalhe: captação, valuation, sede (opcional) ---
//
/// Meta de captação esperada da rodada, em **reais** (número).
/// Usado para o texto de captação no detalhe da startup.
const String kFieldCaptacaoEsperada = 'captacao_esperada';

/// Valuation atual da empresa, em **reais** (número).
/// Usado para o headline do bloco de valuation no detalhe.
const String kFieldValuationAtual = 'valuation_atual';

/// Cidade / sede da empresa.
const String kFieldSede = 'sede';

/// Mapa de séries para o gráfico §5.4 — ver documentação em [StartupDetailService].
///
/// Formato esperado (chaves: diario, semanal, mensal, seis_meses, ytd):
/// ```json
/// "grafico_valuation": {
///   "mensal": [ {"t": "2026-04-01T12:00:00.000Z", "v": 22.5} ]
/// }
/// ```
/// Períodos em falta usam o fallback sintético da UI (mesmo critério do mock).
const String kFieldGraficoValuation = 'grafico_valuation';

// --- Detalhe: institucional ---

const String kFieldAnoDeInicio = 'anoDeInicio';
const String kFieldVideoDemo = 'video_demo';

// --- Objetos aninhados / listas ---

const String kFieldSocios = 'socios';
const String kFieldMentoresConselho = 'mentores_conselho';

/// Texto ou lista de linhas sobre composição acionista (alternativa/agregado a [kFieldSocios]).
const String kFieldEstruturaSocietaria = 'estrutura_societaria';

/// Variações possíveis no console Firebase (camelCase / acentos).
const List<String> kFieldEstruturaSocietariaAliases = <String>[
  kFieldEstruturaSocietaria,
  'estruturaSocietaria',
  'Estrutura societária',
  'estrutura societária',
  'Estrutura Societária',
  'quadro_societario',
  'quadroSocietario',
  'composicao_societaria',
  'composicaoSocietaria',
];

const String kFieldReceitaMensal = 'receita_mensal';
const String kFieldTokensEmitidos = 'tokens_emitidos';
const String kFieldModeloNegocio = 'modelo_negocio';
