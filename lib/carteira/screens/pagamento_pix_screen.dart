// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Ecrã de pagamento **PIX** (protótipo): QR mock, instruções e contador para pagar.
// O tempo de pagamento é maior que o da **cotação** (20 s no ecrã anterior),
// porque o utilizador precisa de abrir o banco e concluir o PIX.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../theme/app_colors.dart';
import '../format/carteira_brl.dart';
import '../widgets/carteira_app_bar_logo.dart';

/// Segundos para o utilizador “pagar e aprovar” (5 min — exemplo realista).
const int kTempoPagamentoPixSegundos = 300;

/// Chave PIX fictícia só para UI (não é um pagamento real).
const String kChavePixMock = 'mescla.invest.pix@exemplo.com.br';

/// Payload mostrado no QR (string longa estável para gerar imagem).
const String kQrPayloadMock =
    '00020126580014br.gov.bcb.pix0136mescla.invest.pix@exemplo.com.br5204000053039865802BR5925MESCLA'
    'INVEST6009SAO_PAULO62070503***6304ABCD';

/// Segundo passo do fluxo “Adicionar fundos”: mostrar QR e contagem decrescente.
class PagamentoPixScreen extends StatefulWidget {
  const PagamentoPixScreen({
    super.key,
    required this.valorReais,
    required this.quantidadeTokens,
  });

  final double valorReais;
  final double quantidadeTokens;

  @override
  State<PagamentoPixScreen> createState() => _PagamentoPixScreenState();
}

class _PagamentoPixScreenState extends State<PagamentoPixScreen> {
  late int _segundosRestantes;
  Timer? _timer;

  static const _radiusCard = 20.0;
  static const _padH = 20.0;

  @override
  void initState() {
    super.initState();
    _segundosRestantes = kTempoPagamentoPixSegundos;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_segundosRestantes <= 0) {
        _timer?.cancel();
        return;
      }
      setState(() => _segundosRestantes--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatarContagem(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = r.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  String _tokensLabel() {
    return widget.quantidadeTokens.toStringAsFixed(2).replaceAll('.', ',');
  }

  Future<void> _copiarChave(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: kChavePixMock));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: const Text('Chave PIX copiada para a área de transferência.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    const appBarFg = Colors.black;
    final esgotado = _segundosRestantes <= 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.systemUiLightAppBar,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const CarteiraAppBarLogo(),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: appBarFg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          systemOverlayStyle: AppColors.systemUiLightAppBar,
          iconTheme: const IconThemeData(color: appBarFg),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Voltar',
          ),
          actions: const [
            SizedBox(width: 56, height: 56),
          ],
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.gradientTop,
                AppColors.gradientBottom,
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(_padH, 4, _padH, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'PAGAMENTO PIX',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.white,
                    elevation: 3,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(_radiusCard),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                      child: Column(
                        children: [
                          Text(
                            'Total a pagar',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatBrl(widget.valorReais),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              '${_tokensLabel()} tokens',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Escaneie o QR Code',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Material(
                      color: Colors.white,
                      elevation: 4,
                      shadowColor: Colors.black.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.fieldBorder,
                          ),
                        ),
                        child: QrImageView(
                          data: kQrPayloadMock,
                          version: QrVersions.auto,
                          size: 216,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!esgotado) ...[
                    Text(
                      'Tempo restante para pagar',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.fieldBorder),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        _formatarContagem(_segundosRestantes),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primary,
                          letterSpacing: 4,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ] else ...[
                    Material(
                      color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.schedule_rounded, color: theme.colorScheme.error),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tempo esgotado. Volte à carteira e tente de novo.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Material(
                    color: Colors.white,
                    elevation: 1,
                    borderRadius: BorderRadius.circular(_radiusCard),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: primary, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Como pagar',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _PassoLinha(numero: 1, texto: 'Abra o app do seu banco e escolha PIX (QR ou copia e cola).'),
                          _PassoLinha(numero: 2, texto: 'Confira o valor e o destinatário antes de confirmar.'),
                          _PassoLinha(numero: 3, texto: 'O saldo pode levar alguns minutos a atualizar após o pagamento.'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(_radiusCard),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chave PIX',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SelectableText(
                                  kChavePixMock,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            onPressed: () => _copiarChave(context),
                            icon: const Icon(Icons.copy_rounded, size: 20),
                            label: const Text('Copiar'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (esgotado) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Voltar à carteira'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PassoLinha extends StatelessWidget {
  const _PassoLinha({required this.numero, required this.texto});

  final int numero;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$numero',
              style: theme.textTheme.labelLarge?.copyWith(
                color: primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
