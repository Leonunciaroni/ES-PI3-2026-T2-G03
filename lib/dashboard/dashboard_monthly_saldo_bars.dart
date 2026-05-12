// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Agrupa saldo disponível ao **final de cada mês civil** (últimos 12 meses) para o
// gráfico de barras miniatura no Dashboard. Usa a mesma reconstrução em cadeia
// definida em [saldoBrlAoFechoInstanteInclusive].

import 'package:cloud_firestore/cloud_firestore.dart';

import '../carteira/carteira_patrimonio_metrics.dart';

/// Nomes por extenso em português do Brasil (`mes` = 1…12).
const kMesesNomePtBr = <String>[
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// Valor já computado ao fecho solicitado pelo produto mais rótulos amigáveis.
class DashboardMesSaldo {
  DashboardMesSaldo({
    required this.ano,
    required this.mes,
    required this.saldoAoFechoBrl,
  });

  final int ano;
  final int mes;

  /// Sempre dentro de `[1 … 12]`.
  final double saldoAoFechoBrl;

  /// Para apresentações longas tipo “Saldo final de maio de 2026”.
  String textoMesAnoCompletoPtBr() =>
      '${kMesesNomePtBr[mes - 1]} de $ano';

  /// Abreviação curta quando o espaço horizontal é pouco (“mai/2026”).
  String etiquetaMiniPtBr() {
    final dois = mes.toString().padLeft(2, '0');
    return '$dois/$ano';
  }

  DateTime primeiroDiaCivilDesteMesLocal() =>
      DateTime(ano, mes, 1);
}

/// Último microssegundo do mês `[ano]/[mes]` no fuso local.
DateTime dashboardUltimoInstanteMesCivil(int ano, int mes) =>
    DateTime(ano, mes + 1, 0, 23, 59, 59, 999);

/// Monta exatamente 12 pontos cronológicos; para cada um devolve saldo disponível ao
/// fecho solicitado pela timebox de produto.
List<DashboardMesSaldo> dashboardMontarBarrasUltimosMesesSaldo({
  required DateTime agoraRelogio,
  required double brlSaldoCorrente,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> ledgerDesc,
  int numeroMeses = 12,
}) {
  assert(numeroMeses >= 1);
  final resultado = <DashboardMesSaldo>[];
  final deslocamento = numeroMeses - 1;
  for (var indiceMes = 0; indiceMes < numeroMeses; indiceMes++) {
    final primeiroDia = DateTime(
      agoraRelogio.year,
      agoraRelogio.month - deslocamento + indiceMes,
      1,
    );

    DateTime marcaFecho =
        dashboardUltimoInstanteMesCivil(primeiroDia.year, primeiroDia.month);
    if (marcaFecho.isAfter(agoraRelogio)) {
      marcaFecho = agoraRelogio;
    }

    final numero = saldoBrlAoFechoInstanteInclusive(
      brlNow: brlSaldoCorrente,
      docsNewestFirst: ledgerDesc,
      instanteInclusive: marcaFecho,
    );

    resultado.add(
      DashboardMesSaldo(
        ano: primeiroDia.year,
        mes: primeiroDia.month,
        saldoAoFechoBrl: numero,
      ),
    );
  }
  return resultado;
}
