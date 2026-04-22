// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Dados fictícios da tela "Detalhes da startup" até existir API + Firestore.
// Períodos do gráfico alinhados ao documento MesclaInvest §5.4 (não ao Figma "1 ANO/MÁX").

import 'package:flutter/material.dart';

import '../models/catalog_startup.dart';

/// Períodos de visualização exigidos no documento (§5.4) para gráficos de variação.
enum ValuationPeriod {
  /// Variação agregada por dia.
  diario,

  /// Por semana.
  semanal,

  /// Por mês.
  mensal,

  /// Janela móvel de seis meses.
  seisMeses,

  /// Year to Date — acumulado no ano civil.
  ytd,
}

/// Rótulo curto para chip na UI (maiúsculas, estilo Figma).
extension ValuationPeriodLabel on ValuationPeriod {
  String get chipLabel => switch (this) {
    ValuationPeriod.diario => 'DIÁRIO',
    ValuationPeriod.semanal => 'SEMANAL',
    ValuationPeriod.mensal => 'MENSAL',
    ValuationPeriod.seisMeses => '6 MESES',
    ValuationPeriod.ytd => 'YTD',
  };
}

/// Startup fictícia para abrir a tela de detalhes sem catálogo (protótipo nesta branch).
const CatalogStartup kPreviewCatalogStartup = CatalogStartup(
  name: 'GreenFlow',
  category: 'AGROTECH',
  stage: StartupStage.nova,
  yieldPercentLabel: '+18.5%',
  tokenPrice: 15.30,
  description: 'Soluções de automações para a sua colheita',
  captureProgress: 0.8,
  logoColor: Color(0xFF22C55E),
  logoIcon: Icons.eco_outlined,
  firestoreId: null,
);

/// Pontos do gráfico de área: valuation em **milhões de R$** + instante por amostra.
///
/// [valuationMillions] e [sampleTimes] devem ter o mesmo comprimento.
class ValuationChartSeries {
  ValuationChartSeries({
    required this.valuationMillions,
    required this.sampleTimes,
  });

  final List<double> valuationMillions;
  final List<DateTime> sampleTimes;
}

// --- Instantes fictícios reutilizados pelos mocks (§5.4) ----------------------

final _sampleTimesDaily9 = <DateTime>[
  DateTime(2026, 4, 8, 9, 5),
  DateTime(2026, 4, 9, 11, 20),
  DateTime(2026, 4, 10, 8, 45),
  DateTime(2026, 4, 11, 14, 10),
  DateTime(2026, 4, 12, 10, 0),
  DateTime(2026, 4, 13, 16, 35),
  DateTime(2026, 4, 14, 9, 50),
  DateTime(2026, 4, 15, 13, 25),
  DateTime(2026, 4, 16, 17, 42),
];

final _sampleTimesWeekly9 = <DateTime>[
  DateTime(2026, 2, 17, 10, 15),
  DateTime(2026, 2, 24, 11, 40),
  DateTime(2026, 3, 3, 9, 30),
  DateTime(2026, 3, 10, 15, 5),
  DateTime(2026, 3, 17, 12, 20),
  DateTime(2026, 3, 24, 10, 50),
  DateTime(2026, 3, 31, 14, 0),
  DateTime(2026, 4, 7, 11, 10),
  DateTime(2026, 4, 14, 17, 55),
];

/// Mensal Ago/25 … Abr/26 — primeiro dia útil ao meio-dia.
final _sampleTimesMonthly9 = <DateTime>[
  DateTime(2025, 8, 1, 12, 0),
  DateTime(2025, 9, 1, 12, 0),
  DateTime(2025, 10, 1, 12, 0),
  DateTime(2025, 11, 1, 12, 0),
  DateTime(2025, 12, 1, 12, 0),
  DateTime(2026, 1, 1, 12, 0),
  DateTime(2026, 2, 1, 12, 0),
  DateTime(2026, 3, 1, 12, 0),
  DateTime(2026, 4, 1, 12, 0),
];

/// Último ponto “Hoje” para protótipo (abr/2026).
final _sampleTimeHoje = DateTime(2026, 4, 19, 18, 30);

final _sampleTimesSixMonths9 = <DateTime>[
  DateTime(2025, 11, 12, 10, 5),
  DateTime(2025, 12, 8, 10, 45),
  DateTime(2026, 1, 10, 11, 15),
  DateTime(2026, 2, 14, 11, 40),
  DateTime(2026, 3, 11, 12, 20),
  DateTime(2026, 4, 2, 13, 0),
  DateTime(2026, 4, 12, 14, 30),
  DateTime(2026, 4, 17, 16, 0),
  _sampleTimeHoje,
];

final _sampleTimesYtd9 = <DateTime>[
  DateTime(2026, 1, 8, 9, 5),
  DateTime(2026, 2, 5, 9, 45),
  DateTime(2026, 3, 6, 10, 30),
  DateTime(2026, 4, 1, 11, 15),
  DateTime(2026, 4, 12, 12, 40),
  DateTime(2026, 4, 15, 14, 20),
  DateTime(2026, 4, 17, 15, 50),
  DateTime(2026, 4, 18, 17, 25),
  _sampleTimeHoje,
];

final _sampleTimesShape7Daily = <DateTime>[
  DateTime(2026, 4, 8, 9, 0),
  DateTime(2026, 4, 9, 10, 15),
  DateTime(2026, 4, 10, 8, 30),
  DateTime(2026, 4, 11, 11, 45),
  DateTime(2026, 4, 12, 14, 20),
  DateTime(2026, 4, 13, 9, 50),
  DateTime(2026, 4, 14, 16, 10),
];

final _sampleTimesShape7Weekly = <DateTime>[
  DateTime(2026, 2, 24, 10, 0),
  DateTime(2026, 3, 3, 10, 20),
  DateTime(2026, 3, 10, 11, 0),
  DateTime(2026, 3, 17, 11, 40),
  DateTime(2026, 3, 24, 12, 0),
  DateTime(2026, 3, 31, 12, 30),
  DateTime(2026, 4, 7, 13, 0),
];

final _sampleTimesShape7Monthly = <DateTime>[
  DateTime(2025, 10, 1, 12, 0),
  DateTime(2025, 11, 1, 12, 0),
  DateTime(2025, 12, 1, 12, 0),
  DateTime(2026, 1, 1, 12, 0),
  DateTime(2026, 2, 1, 12, 0),
  DateTime(2026, 3, 1, 12, 0),
  DateTime(2026, 4, 1, 12, 0),
];

final _sampleTimesShape7SixM = <DateTime>[
  DateTime(2025, 12, 1, 10, 0),
  DateTime(2026, 1, 1, 10, 30),
  DateTime(2026, 2, 1, 11, 0),
  DateTime(2026, 3, 1, 11, 30),
  DateTime(2026, 4, 1, 12, 0),
  DateTime(2026, 5, 1, 12, 30),
  _sampleTimeHoje,
];

final _sampleTimesShape7Ytd = <DateTime>[
  DateTime(2026, 1, 15, 9, 0),
  DateTime(2026, 2, 15, 9, 30),
  DateTime(2026, 3, 15, 10, 0),
  DateTime(2026, 4, 15, 10, 30),
  DateTime(2026, 5, 15, 11, 0),
  DateTime(2026, 6, 15, 11, 30),
  _sampleTimeHoje,
];

/// Membro-chave / sócio apresentado na lista circular.
class StartupTeamMember {
  const StartupTeamMember({
    required this.name,
    required this.role,
    required this.avatarColor,
  });

  final String name;
  final String role;

  /// Cor de fundo do círculo com iniciais (sem fotos no protótipo).
  final Color avatarColor;
}

/// Linha de pergunta e resposta pública (§5.2).
class StartupPublicQa {
  const StartupPublicQa({required this.question, required this.answer});

  final String question;
  final String answer;
}

/// Uma linha da secção "Métricas de performance" (referência visual Figma).
class StartupPerformanceMetric {
  const StartupPerformanceMetric({
    required this.labelCaps,
    required this.value,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
  });

  final String labelCaps;
  final String value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
}

/// Tudo o que a [StartupDetailScreen] precisa para desenhar o scroll completo.
class StartupDetailViewData {
  const StartupDetailViewData({
    required this.catalog,
    required this.categoryDisplay,
    required this.longDescription,
    required this.captureHeadline,
    required this.captureProgressFraction,
    required this.captureProgressLabel,
    required this.valuationHeadline,
    required this.valuationRoundLabel,
    required this.valuationTrendText,
    required this.chartSeriesByPeriod,
    required this.headquarters,
    required this.foundedLabel,
    required this.missionQuote,
    required this.teamMembers,
    required this.performanceMetrics,
    required this.executiveSummary,
    required this.societaryLines,
    required this.publicQa,
    required this.demoVideoTitle,
    this.demoVideoUrl,
  });

  /// Dados já mostrados no catálogo (ícone, cor, nome curto, etc.).
  final CatalogStartup catalog;

  /// Categoria por extenso para o subtítulo em roxo (ex.: "AGROTECH & SUSTENTABILIDADE").
  final String categoryDisplay;

  /// Parágrafo principal no card branco (pode ser mais longo que [catalog.description]).
  final String longDescription;

  /// Texto grande no card roxo (ex.: "R$ 4.2M").
  final String captureHeadline;

  /// Mesma semântica que [CatalogStartup.captureProgress] (pode espelhar ou ajustar mock).
  final double captureProgressFraction;

  /// Legenda sob a barra (ex.: "80% da meta atingida").
  final String captureProgressLabel;

  /// Valor principal de valuation (ex.: "R$ 28.5M").
  final String valuationHeadline;

  /// Subtítulo da ronda (ex.: "VALUATION (SÉRIE A)").
  final String valuationRoundLabel;

  /// Texto verde de tendência (ex.: "+18% vs Previsto").
  final String valuationTrendText;

  /// Para cada período (§5.4), série temporal para o gráfico de área.
  final Map<ValuationPeriod, ValuationChartSeries> chartSeriesByPeriod;

  final String headquarters;
  final String foundedLabel;
  final String missionQuote;
  final List<StartupTeamMember> teamMembers;
  final List<StartupPerformanceMetric> performanceMetrics;

  /// Sumário executivo (§5.2).
  final String executiveSummary;

  /// Estrutura societária em linhas legíveis (§5.2).
  final List<String> societaryLines;

  /// Perguntas e respostas públicas (§5.2).
  final List<StartupPublicQa> publicQa;

  /// Título placeholder para vídeo demonstrativo (§5.2).
  final String demoVideoTitle;

  /// URL do vídeo (ex.: YouTube) quando existir no Firestore.
  final String? demoVideoUrl;
}

/// Curvas fictícias 0–1 (7 pontos) — escalamos para milhões de R$ no fallback.
Map<ValuationPeriod, List<double>> _shapePattern({
  required double base,
  required double spread,
}) {
  final raw = List<double>.generate(7, (i) => base + spread * (i / 6));
  final max = raw.reduce((a, b) => a > b ? a : b);
  final min = raw.reduce((a, b) => a < b ? a : b);
  final denom = (max - min).abs() < 1e-9 ? 1.0 : (max - min);
  List<double> norm(double lo, double hi) =>
      raw.map((v) => lo + (hi - lo) * ((v - min) / denom)).toList();
  return {
    ValuationPeriod.diario: norm(0.25, 1.0),
    ValuationPeriod.semanal: norm(0.3, 0.98),
    ValuationPeriod.mensal: norm(0.35, 0.96),
    ValuationPeriod.seisMeses: norm(0.4, 0.94),
    ValuationPeriod.ytd: norm(0.45, 0.92),
  };
}

/// Converte o padrão normalizado em [ValuationChartSeries] com instantes por período.
Map<ValuationPeriod, ValuationChartSeries> _seriesFromShape(
  Map<ValuationPeriod, List<double>> shape,
  double scaleMinM,
  double scaleMaxM,
) {
  List<double> toM(List<double> f) =>
      f.map((t) => scaleMinM + (scaleMaxM - scaleMinM) * t).toList();
  return {
    ValuationPeriod.diario: ValuationChartSeries(
      valuationMillions: toM(shape[ValuationPeriod.diario]!),
      sampleTimes: _sampleTimesShape7Daily,
    ),
    ValuationPeriod.semanal: ValuationChartSeries(
      valuationMillions: toM(shape[ValuationPeriod.semanal]!),
      sampleTimes: _sampleTimesShape7Weekly,
    ),
    ValuationPeriod.mensal: ValuationChartSeries(
      valuationMillions: toM(shape[ValuationPeriod.mensal]!),
      sampleTimes: _sampleTimesShape7Monthly,
    ),
    ValuationPeriod.seisMeses: ValuationChartSeries(
      valuationMillions: toM(shape[ValuationPeriod.seisMeses]!),
      sampleTimes: _sampleTimesShape7SixM,
    ),
    ValuationPeriod.ytd: ValuationChartSeries(
      valuationMillions: toM(shape[ValuationPeriod.ytd]!),
      sampleTimes: _sampleTimesShape7Ytd,
    ),
  };
}

/// Séries do gráfico §5.4 para startups sem template estático (ex.: dados só no Firestore).
Map<ValuationPeriod, ValuationChartSeries> fallbackChartSeriesForStartupDetail(
  CatalogStartup _,
) {
  final shape = _shapePattern(base: 0.3, spread: 0.5);
  return _seriesFromShape(shape, 14.0, 24.0);
}

Map<ValuationPeriod, ValuationChartSeries> _greenFlowCharts() => {
  ValuationPeriod.diario: ValuationChartSeries(
    valuationMillions: [
      20.85,
      20.72,
      21.05,
      20.98,
      21.35,
      21.28,
      21.72,
      21.65,
      22.0,
    ],
    sampleTimes: _sampleTimesDaily9,
  ),
  ValuationPeriod.semanal: ValuationChartSeries(
    valuationMillions: [19.4, 19.9, 19.6, 20.2, 20.6, 21.0, 21.3, 21.6, 22.0],
    sampleTimes: _sampleTimesWeekly9,
  ),
  ValuationPeriod.mensal: ValuationChartSeries(
    valuationMillions: [17.8, 18.5, 18.2, 19.0, 19.8, 20.4, 21.1, 21.6, 22.0],
    sampleTimes: _sampleTimesMonthly9,
  ),
  ValuationPeriod.seisMeses: ValuationChartSeries(
    valuationMillions: [14.5, 15.8, 16.2, 17.5, 18.9, 19.8, 20.6, 21.4, 22.0],
    sampleTimes: _sampleTimesSixMonths9,
  ),
  ValuationPeriod.ytd: ValuationChartSeries(
    valuationMillions: [12.0, 13.5, 15.0, 16.8, 18.2, 19.5, 20.5, 21.4, 22.0],
    sampleTimes: _sampleTimesYtd9,
  ),
};

Map<ValuationPeriod, ValuationChartSeries> _cyberMeshCharts() => {
  ValuationPeriod.diario: ValuationChartSeries(
    valuationMillions: [
      39.1,
      38.85,
      39.4,
      39.25,
      39.9,
      39.75,
      40.4,
      40.25,
      40.8,
    ],
    sampleTimes: _sampleTimesDaily9,
  ),
  ValuationPeriod.semanal: ValuationChartSeries(
    valuationMillions: [36.5, 37.2, 36.9, 37.8, 38.4, 39.0, 39.5, 40.0, 40.8],
    sampleTimes: _sampleTimesWeekly9,
  ),
  ValuationPeriod.mensal: ValuationChartSeries(
    valuationMillions: [33.0, 34.2, 33.8, 35.0, 36.2, 37.5, 38.6, 39.5, 40.8],
    sampleTimes: _sampleTimesMonthly9,
  ),
  ValuationPeriod.seisMeses: ValuationChartSeries(
    valuationMillions: [28.0, 30.5, 31.2, 33.0, 35.0, 36.8, 38.2, 39.5, 40.8],
    sampleTimes: _sampleTimesSixMonths9,
  ),
  ValuationPeriod.ytd: ValuationChartSeries(
    valuationMillions: [26.0, 28.5, 30.0, 32.5, 34.5, 36.5, 38.0, 39.5, 40.8],
    sampleTimes: _sampleTimesYtd9,
  ),
};

Map<ValuationPeriod, ValuationChartSeries> _healthlyCharts() => {
  ValuationPeriod.diario: ValuationChartSeries(
    valuationMillions: [65.2, 64.9, 65.6, 65.4, 66.1, 65.95, 66.8, 66.6, 67.5],
    sampleTimes: _sampleTimesDaily9,
  ),
  ValuationPeriod.semanal: ValuationChartSeries(
    valuationMillions: [61.0, 62.2, 61.8, 63.0, 64.0, 65.0, 65.8, 66.4, 67.5],
    sampleTimes: _sampleTimesWeekly9,
  ),
  ValuationPeriod.mensal: ValuationChartSeries(
    valuationMillions: [54.0, 55.5, 56.2, 58.0, 60.0, 62.0, 64.0, 66.0, 67.5],
    sampleTimes: _sampleTimesMonthly9,
  ),
  ValuationPeriod.seisMeses: ValuationChartSeries(
    valuationMillions: [48.0, 50.5, 52.0, 54.5, 57.0, 60.0, 62.5, 65.0, 67.5],
    sampleTimes: _sampleTimesSixMonths9,
  ),
  ValuationPeriod.ytd: ValuationChartSeries(
    valuationMillions: [45.0, 48.0, 51.0, 54.0, 57.5, 61.0, 63.5, 65.5, 67.5],
    sampleTimes: _sampleTimesYtd9,
  ),
};

/// Só serve de placeholder de [catalog] dentro do mapa estático; em runtime
/// [startupDetailFor] substitui pelo [CatalogStartup] real vindo do catálogo.
const CatalogStartup _catalogPlaceholder = CatalogStartup(
  name: '',
  category: '',
  stage: StartupStage.nova,
  yieldPercentLabel: '',
  tokenPrice: 0,
  description: '',
  captureProgress: 0,
  logoColor: Color(0xFF000000),
  logoIcon: Icons.help_outline,
  firestoreId: null,
);

/// Modelos por nome da startup (sem acoplar à instância exacta vinda do card).
final Map<String, StartupDetailViewData> _detailTemplatesByName = {
  'GreenFlow': StartupDetailViewData(
    catalog: _catalogPlaceholder,
    categoryDisplay: 'AGROTECH & SUSTENTABILIDADE',
    longDescription:
        'Revolucionando a agricultura regenerativa através de IA e monitoramento de solo em tempo real. '
        'Uma solução escalável para a segurança alimentar global.',
    captureHeadline: 'R\$ 3.2M',
    captureProgressFraction: 0.8,
    captureProgressLabel: '80% da meta atingida',
    valuationHeadline: 'R\$ 22.0M',
    valuationRoundLabel: 'VALUATION (SÉRIE SEED)',
    valuationTrendText: '+18% vs Previsto',
    chartSeriesByPeriod: _greenFlowCharts(),
    headquarters: 'Florianópolis, SC',
    foundedLabel: 'Março de 2021',
    missionQuote:
        'Acelerar a transição global para sistemas alimentares regenerativos através de tecnologia de ponta.',
    teamMembers: const [
      StartupTeamMember(
        name: 'Ricardo Silveira',
        role: 'CEO & Fundador',
        avatarColor: Color(0xFF6366F1),
      ),
      StartupTeamMember(
        name: 'Ana Luíza Costa',
        role: 'CTO (Ex-Google)',
        avatarColor: Color(0xFFEC4899),
      ),
      StartupTeamMember(
        name: 'Marcos Pereira',
        role: 'Head de Sustentabilidade',
        avatarColor: Color(0xFF22C55E),
      ),
    ],
    performanceMetrics: const [
      StartupPerformanceMetric(
        labelCaps: 'CRESCIMENTO',
        value: '42% a.a.',
        icon: Icons.trending_up_rounded,
        iconBackground: Color(0xFFD1FAE5),
        iconColor: Color(0xFF059669),
      ),
      StartupPerformanceMetric(
        labelCaps: 'CLASSIFICAÇÃO',
        value: 'A+ Prime',
        icon: Icons.star_rounded,
        iconBackground: Color(0xFFFFEDD5),
        iconColor: Color(0xFFEA580C),
      ),
      StartupPerformanceMetric(
        labelCaps: 'TVL (TOTAL VALUE LOCKED)',
        value: 'R\$ 112M',
        icon: Icons.account_balance_wallet_outlined,
        iconBackground: Color(0xFFDBEAFE),
        iconColor: Color(0xFF2563EB),
      ),
      StartupPerformanceMetric(
        labelCaps: 'NÓS ATIVOS',
        value: '1.240',
        icon: Icons.hub_outlined,
        iconBackground: Color(0xFFEDE9FE),
        iconColor: Color(0xFF6234EA),
      ),
    ],
    executiveSummary:
        'A GreenFlow combina sensores de baixo custo com modelos de IA para prever necessidade hídrica e '
        'nutricional da lavoura, reduzindo insumos e aumentando produtividade em pilotos na região Sul.',
    societaryLines: const [
      'Ricardo Silveira — 42%',
      'Ana Luíza Costa — 28%',
      'Pool de funcionários (ESOP) — 10%',
      'Investidores anjo — 20%',
    ],
    publicQa: const [
      StartupPublicQa(
        question: 'Qual o diferencial frente a concorrentes internacionais?',
        answer:
            'Focamos em culturas tropicais e integração com cooperativas locais, com custo de hardware 35% menor.',
      ),
      StartupPublicQa(
        question: 'Há certificações ambientais?',
        answer: 'Estamos em processo de selo B Corp e ISO 14001 para 2027.',
      ),
    ],
    demoVideoTitle: 'Demonstração da plataforma — piloto SC/PR',
  ),
  'CyberMesh': StartupDetailViewData(
    catalog: _catalogPlaceholder,
    categoryDisplay: 'CYBERSECURITY & DADOS',
    longDescription:
        'Plataforma de deteção de intrusão orientada a PMEs, com painel unificado e resposta automatizada a incidentes.',
    captureHeadline: 'R\$ 1.8M',
    captureProgressFraction: 0.55,
    captureProgressLabel: '55% da meta atingida',
    valuationHeadline: 'R\$ 41.0M',
    valuationRoundLabel: 'VALUATION (SÉRIE A)',
    valuationTrendText: '+12% vs Previsto',
    chartSeriesByPeriod: _cyberMeshCharts(),
    headquarters: 'Campinas, SP',
    foundedLabel: 'Agosto de 2020',
    missionQuote:
        'Democratizar segurança de nível enterprise para organizações de qualquer porte.',
    teamMembers: const [
      StartupTeamMember(
        name: 'Juliana Prado',
        role: 'CEO & Fundadora',
        avatarColor: Color(0xFF8B5CF6),
      ),
      StartupTeamMember(
        name: 'Otávio Ramos',
        role: 'CISO (Ex-Banco)',
        avatarColor: Color(0xFF0EA5E9),
      ),
    ],
    performanceMetrics: const [
      StartupPerformanceMetric(
        labelCaps: 'CRESCIMENTO',
        value: '31% a.a.',
        icon: Icons.trending_up_rounded,
        iconBackground: Color(0xFFD1FAE5),
        iconColor: Color(0xFF059669),
      ),
      StartupPerformanceMetric(
        labelCaps: 'CLASSIFICAÇÃO',
        value: 'A',
        icon: Icons.star_rounded,
        iconBackground: Color(0xFFFFEDD5),
        iconColor: Color(0xFFEA580C),
      ),
      StartupPerformanceMetric(
        labelCaps: 'TVL (TOTAL VALUE LOCKED)',
        value: 'R\$ 48M',
        icon: Icons.account_balance_wallet_outlined,
        iconBackground: Color(0xFFDBEAFE),
        iconColor: Color(0xFF2563EB),
      ),
      StartupPerformanceMetric(
        labelCaps: 'NÓS ATIVOS',
        value: '860',
        icon: Icons.hub_outlined,
        iconBackground: Color(0xFFEDE9FE),
        iconColor: Color(0xFF6234EA),
      ),
    ],
    executiveSummary:
        'CyberMesh correlaciona telemetria de rede com feeds de ameaças abertas e gera playbooks de contenção em minutos.',
    societaryLines: const [
      'Juliana Prado — 51%',
      'Fundo Mescla Angel — 30%',
      'Funcionários — 19%',
    ],
    publicQa: const [
      StartupPublicQa(
        question: 'Suportam ambientes híbridos?',
        answer: 'Sim — agentes leves para cloud, on-prem e IoT industrial.',
      ),
    ],
    demoVideoTitle: 'Tour do SOC simulado — protótipo académico',
  ),
  'Healthly': StartupDetailViewData(
    catalog: _catalogPlaceholder,
    categoryDisplay: 'HEALTHTECH & ACESSO',
    longDescription:
        'Telemedicina com prontuário longitudinal e integração a laboratórios parceiros para jornada do doente em um só app.',
    captureHeadline: 'R\$ 5.1M',
    captureProgressFraction: 0.92,
    captureProgressLabel: '92% da meta atingida',
    valuationHeadline: 'R\$ 67.5M',
    valuationRoundLabel: 'VALUATION (SÉRIE B)',
    valuationTrendText: '+9% vs Previsto',
    chartSeriesByPeriod: _healthlyCharts(),
    headquarters: 'São Paulo, SP',
    foundedLabel: 'Janeiro de 2019',
    missionQuote:
        'Reduzir filas e burocracia no cuidado primário com tecnologia centrada no paciente.',
    teamMembers: const [
      StartupTeamMember(
        name: 'Dra. Paula Menezes',
        role: 'CEO & Médica',
        avatarColor: Color(0xFF14B8A6),
      ),
      StartupTeamMember(
        name: 'Igor Nunes',
        role: 'Head de Produto',
        avatarColor: Color(0xFFF59E0B),
      ),
    ],
    performanceMetrics: const [
      StartupPerformanceMetric(
        labelCaps: 'CRESCIMENTO',
        value: '28% a.a.',
        icon: Icons.trending_up_rounded,
        iconBackground: Color(0xFFD1FAE5),
        iconColor: Color(0xFF059669),
      ),
      StartupPerformanceMetric(
        labelCaps: 'CLASSIFICAÇÃO',
        value: 'A+',
        icon: Icons.star_rounded,
        iconBackground: Color(0xFFFFEDD5),
        iconColor: Color(0xFFEA580C),
      ),
      StartupPerformanceMetric(
        labelCaps: 'TVL (TOTAL VALUE LOCKED)',
        value: 'R\$ 210M',
        icon: Icons.account_balance_wallet_outlined,
        iconBackground: Color(0xFFDBEAFE),
        iconColor: Color(0xFF2563EB),
      ),
      StartupPerformanceMetric(
        labelCaps: 'NÓS ATIVOS',
        value: '2.050',
        icon: Icons.hub_outlined,
        iconBackground: Color(0xFFEDE9FE),
        iconColor: Color(0xFF6234EA),
      ),
    ],
    executiveSummary:
        'Healthly concentra agendamento, triagem automatizada e resultados de exames com notificações inteligentes.',
    societaryLines: const [
      'Dra. Paula Menezes — 38%',
      'Venture Health I — 35%',
      'Outros investidores — 27%',
    ],
    publicQa: const [
      StartupPublicQa(
        question: 'Atendem convênios públicos?',
        answer:
            'Pilotos com duas prefeituras em 2026; escala depende de edital.',
      ),
    ],
    demoVideoTitle: 'Fluxo do paciente — vídeo conceitual',
  ),
};

/// Monta o [StartupDetailViewData] final usando sempre o [CatalogStartup] do card tocado.
StartupDetailViewData startupDetailFor(CatalogStartup c) {
  final template = _detailTemplatesByName[c.name];
  if (template == null) return _fallbackFor(c);
  return StartupDetailViewData(
    catalog: c,
    categoryDisplay: template.categoryDisplay,
    longDescription: template.longDescription,
    captureHeadline: template.captureHeadline,
    captureProgressFraction: template.captureProgressFraction,
    captureProgressLabel: template.captureProgressLabel,
    valuationHeadline: template.valuationHeadline,
    valuationRoundLabel: template.valuationRoundLabel,
    valuationTrendText: template.valuationTrendText,
    chartSeriesByPeriod: template.chartSeriesByPeriod,
    headquarters: template.headquarters,
    foundedLabel: template.foundedLabel,
    missionQuote: template.missionQuote,
    teamMembers: template.teamMembers,
    performanceMetrics: template.performanceMetrics,
    executiveSummary: template.executiveSummary,
    societaryLines: template.societaryLines,
    publicQa: template.publicQa,
    demoVideoTitle: template.demoVideoTitle,
    demoVideoUrl: template.demoVideoUrl,
  );
}

StartupDetailViewData _fallbackFor(CatalogStartup c) {
  final charts = fallbackChartSeriesForStartupDetail(c);
  return StartupDetailViewData(
    catalog: c,
    categoryDisplay: c.category,
    longDescription: c.description,
    captureHeadline: 'R\$ —',
    captureProgressFraction: c.captureProgress,
    captureProgressLabel:
        '${(c.captureProgress * 100).round()}% da meta atingida',
    valuationHeadline: 'R\$ —',
    valuationRoundLabel: 'VALUATION',
    valuationTrendText: '—',
    chartSeriesByPeriod: charts,
    headquarters: '—',
    foundedLabel: '—',
    missionQuote: 'Missão em definição.',
    teamMembers: const [],
    performanceMetrics: const [],
    executiveSummary: 'Sumário executivo em elaboração.',
    societaryLines: const ['Estrutura societária em elaboração.'],
    publicQa: const [],
    demoVideoTitle: 'Vídeo demonstrativo em breve',
    demoVideoUrl: null,
  );
}
