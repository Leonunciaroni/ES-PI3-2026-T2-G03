// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Barras mensais no canto inferior direito do hero: 12 meses, espaçamento uniforme,
// topo arredondado e base reta. Ordem visual: **mais antigo à esquerda**, mês atual à **direita**.

import 'package:flutter/material.dart';

import '../dashboard_monthly_saldo_bars.dart';

/// Barras clicáveis e [SnackBar] com mês por extenso + saldo ao fim daquele mês civil.
class DashboardHeroMonthlySaldoBars extends StatefulWidget {
  const DashboardHeroMonthlySaldoBars({
    super.key,
    required this.series,
    required this.formatarBr,
    this.alturaPainelBarras = 64,
    this.alturaRodapeSelecao = 32,
    this.rotuloTituloSnack = 'Saldo ao fim de',
    this.rotuloTituloPainelInferior =
        'Saldo ao fim do mês:',
    /// Espaço horizontal fixo entre barras (uniforme).
    this.espacoEntreBarras = 10,
  });

  /// Ordem dos dados e da UI: mais antigo → mais novo (esquerda → direita).
  final List<DashboardMesSaldo> series;

  /// Mesma política monetária do cartão pai (separadores de milhar brasileiros).
  final String Function(double valor) formatarBr;

  final double alturaPainelBarras;
  final double alturaRodapeSelecao;

  /// Primeira frase rápida do [SnackBar] antes do texto longo (“maio …”).
  final String rotuloTituloSnack;

  /// Prefixo opcional quando uma barra fica destacada sob o quadro lilás.
  final String rotuloTituloPainelInferior;

  /// Gap horizontal uniforme entre barras (pixels).
  final double espacoEntreBarras;

  @override
  State<DashboardHeroMonthlySaldoBars> createState() =>
      _DashboardHeroMonthlySaldoBarsState();
}

class _DashboardHeroMonthlySaldoBarsState
    extends State<DashboardHeroMonthlySaldoBars> {
  /// `null` = nunca selecionou (evita ocupar texto antes do primeiro toque útil).
  int? _indiceSelecionado;

  @override
  void didUpdateWidget(covariant DashboardHeroMonthlySaldoBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.series, widget.series) ||
        widget.series.length != oldWidget.series.length) {
      _indiceSelecionado = null;
    }
  }

  double _alfaBarra({
    required int indice,
    required int ultimoIndice,
    required bool selecionada,
  }) {
    if (selecionada) {
      return 0.72;
    }
    // Último mês (mais recente): mais destaque; mais antigas: lavanda suave — alinhado ao Figma.
    if (indice == ultimoIndice) {
      return 0.52;
    }
    final progresso =
        ultimoIndice > 0 ? indice / ultimoIndice : 1.0;
    return (0.26 + progresso * 0.14).clamp(0.26, 0.42);
  }

  /// [larguraLinha] é a largura útil da linha de barras; [n] o número de barras.
  ({double gap, double larguraBarra}) _metricasBarrasUniformes({
    required double larguraLinha,
    required int n,
  }) {
    if (n <= 0 || larguraLinha <= 0) {
      return (gap: widget.espacoEntreBarras, larguraBarra: 4);
    }
    var gap = widget.espacoEntreBarras.clamp(4.0, 14.0);
    final gapsTotal = gap * (n - 1);
    var larguraBarra = (larguraLinha - gapsTotal) / n;
    const minBarra = 3.5;
    while (larguraBarra < minBarra && gap > 4) {
      gap -= 0.5;
      larguraBarra = (larguraLinha - gap * (n - 1)) / n;
    }
    if (larguraBarra < minBarra) {
      larguraBarra = minBarra;
    }
    return (gap: gap, larguraBarra: larguraBarra);
  }

  /// Uma barra na linha; [indiceSerie] é o índice em [series] (0 = mais antigo).
  Widget _celulaBarraHero({
    required int indiceSerie,
    required List<DashboardMesSaldo> serie,
    required List<double> magnitudesAbsolutas,
    required double tetoValor,
    required double larguraBarra,
    required double painelBarrasPx,
    required double raioTopoBarra,
    required int ultimoIndice,
    required ThemeData tema,
    required BuildContext contextHero,
  }) {
    final i = indiceSerie;
    return SizedBox(
      width: larguraBarra,
      height: painelBarrasPx,
      child: Semantics(
        button: true,
        label: '${serie[i].textoMesAnoCompletoPtBr()}, botão',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(raioTopoBarra),
            ),
            splashColor: Colors.white.withValues(alpha: 0.28),
            highlightColor: Colors.white.withValues(alpha: 0.12),
            onTap: () {
              final escolha = serie[i];
              setState(() => _indiceSelecionado = i);
              final mensageiro = ScaffoldMessenger.maybeOf(contextHero);
              mensageiro?.removeCurrentSnackBar();
              mensageiro?.showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 3),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.rotuloTituloSnack} '
                        '${escolha.textoMesAnoCompletoPtBr()}',
                        style: tema.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Saldo final: '
                        '${widget.formatarBr(escolha.saldoAoFechoBrl)}',
                      ),
                    ],
                  ),
                ),
              );
            },
            child: LayoutBuilder(
              builder: (_, cotasCaixaBarrasPai) {
                final proporcaoBarraCheia =
                    (magnitudesAbsolutas[i] / tetoValor).clamp(0.08, 1.0);
                final alturaUtilBarra =
                    (cotasCaixaBarrasPai.maxHeight - 2).clamp(
                  8.0,
                  cotasCaixaBarrasPai.maxHeight,
                );
                final alturaPreenchida = alturaUtilBarra * proporcaoBarraCheia;
                final selecionada = (_indiceSelecionado ?? -1) == i;
                final alfa = _alfaBarra(
                  indice: i,
                  ultimoIndice: ultimoIndice,
                  selecionada: selecionada,
                );
                return SizedBox(
                  height: cotasCaixaBarrasPai.maxHeight,
                  width: larguraBarra,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: larguraBarra,
                      height: alturaPreenchida,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: alfa),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(raioTopoBarra),
                        ),
                        border: selecionada
                            ? Border.all(
                                color: Colors.white.withValues(alpha: 0.55),
                                width: 1,
                              )
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serie = widget.series;
    final tema = Theme.of(context);
    if (serie.isEmpty) return const SizedBox.shrink();

    final magnitudesAbsolutas =
        serie.map((e) => e.saldoAoFechoBrl.abs()).toList();
    double tetoValor = magnitudesAbsolutas.fold<double>(
      1.0,
      (acumulo, atual) =>
          atual > acumulo ? atual : acumulo,
    );
    if (tetoValor < 1.0) tetoValor = 1.0;

    final painelBarrasPx = widget.alturaPainelBarras.clamp(36.0, 128.0);
    final ultimoIndice = serie.length - 1;
    final raioTopoBarra = 4.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: painelBarrasPx,
          child: LayoutBuilder(
            builder: (context, limitesLinhaBarras) {
              final larguraLinha = limitesLinhaBarras.maxWidth.isFinite
                  ? limitesLinhaBarras.maxWidth
                  : 280.0;
              final metricas = _metricasBarrasUniformes(
                larguraLinha: larguraLinha,
                n: serie.length,
              );
              final gap = metricas.gap;
              final larguraBarra = metricas.larguraBarra;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var indiceSerie = 0;
                      indiceSerie < serie.length;
                      indiceSerie++) ...[
                    if (indiceSerie > 0) SizedBox(width: gap),
                    _celulaBarraHero(
                      indiceSerie: indiceSerie,
                      serie: serie,
                      magnitudesAbsolutas: magnitudesAbsolutas,
                      tetoValor: tetoValor,
                      larguraBarra: larguraBarra,
                      painelBarrasPx: painelBarrasPx,
                      raioTopoBarra: raioTopoBarra,
                      ultimoIndice: ultimoIndice,
                      tema: tema,
                      contextHero: context,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        SizedBox(
          height: widget.alturaRodapeSelecao,
          child: (_indiceSelecionado != null)
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${widget.rotuloTituloPainelInferior} '
                      '${widget.formatarBr(serie[_indiceSelecionado!].saldoAoFechoBrl)} '
                      '(${serie[_indiceSelecionado!].textoMesAnoCompletoPtBr()})',
                      maxLines: 2,
                      textAlign: TextAlign.right,
                      style: tema.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
