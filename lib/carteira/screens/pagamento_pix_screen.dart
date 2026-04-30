// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Ecrã de pagamento **PIX** (protótipo): QR mock, instruções e contador para pagar.
// O temporizador dá tempo ao utilizador de abrir o app do banco e concluir o PIX.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../theme/app_colors.dart';
import '../format/carteira_brl.dart';
import '../services/simulated_wallet_service.dart';
import '../widgets/carteira_app_bar_logo.dart';

/// Segundos para o utilizador concluir o fluxo antes de confirmar o crédito.
const int kTempoPagamentoPixSegundos = 30;

/// Chave PIX de exemplo só para UI.
const String kChavePixMock = 'mescla.invest.pix@exemplo.com.br';

/// Payload mostrado no QR (string longa estável para gerar imagem).
const String kQrPayloadMock =
    '00020126580014br.gov.bcb.pix0136mescla.invest.pix@exemplo.com.br5204000053039865802BR5925MESCLA'
    'INVEST6009SAO_PAULO62070503***6304ABCD';

/// Exibição da chave: quebra antes de `.com.br` (sufixo na linha de baixo).
String _chavePixParaExibicao(String chave) {
  const sufixo = '.com.br';
  if (chave.endsWith(sufixo)) {
    final antes = chave.substring(0, chave.length - sufixo.length);
    return '$antes\n$sufixo';
  }
  return chave;
}

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
  bool _creditoEmCurso = false;
  bool _creditoSucesso = false;
  bool _creditoFalhou = false;

  static const _radiusCard = 20.0;
  static const _padH = 20.0;

  @override
  void initState() {
    super.initState();
    _segundosRestantes = kTempoPagamentoPixSegundos;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTickRelogio());
  }

  void _onTickRelogio() {
    if (!mounted) return;
    if (_creditoSucesso) {
      _timer?.cancel();
      return;
    }
    setState(() {
      if (_segundosRestantes > 0) {
        _segundosRestantes--;
      }
    });
    if (_segundosRestantes <= 0) {
      _timer?.cancel();
      unawaited(_executarCreditoPix());
    }
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

  Future<void> _executarCreditoPix() async {
    if (!mounted || _creditoEmCurso || _creditoSucesso) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _creditoFalhou = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Para creditar saldo é preciso iniciar sessão no app.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _creditoEmCurso = true;
      _creditoFalhou = false;
    });

    try {
      await SimulatedWalletService.creditPixSimulated(
        amountBrl: widget.valorReais,
      );
      if (!mounted) return;
      setState(() {
        _creditoEmCurso = false;
        _creditoSucesso = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          content: Text(
            'Saldo atualizado: ${formatBrl(widget.valorReais)}',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creditoEmCurso = false;
        _creditoFalhou = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SimulatedWalletService.messageForUser(e)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final contagemVisivel = _segundosRestantes > 0 && !_creditoSucesso;
    final bodyBg = theme.brightness == Brightness.light
        ? const Color(0xFFF3F4F6)
        : AppColors.gradientBottomDark;
    final overlay = AppColors.shellOverlayStyle(theme.brightness);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: bodyBg,
        appBar: AppBar(
          title: const CarteiraAppBarLogo(),
          centerTitle: true,
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: onSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          systemOverlayStyle: overlay,
          iconTheme: IconThemeData(color: onSurface),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Voltar',
          ),
          actions: const [SizedBox(width: 56, height: 56)],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(_padH, 4, _padH, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'PAGAMENTO PIX',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.secondaryLabel(theme),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: AppColors.themeCardSurface(theme),
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(_radiusCard),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                    child: Column(
                      children: [
                        Text(
                          'Total a pagar',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.secondaryLabel(theme),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatBrl(widget.valorReais),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: onSurface,
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
                    color: AppColors.themeCardSurface(theme),
                    elevation: 4,
                    shadowColor: Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.cardDivider(theme)),
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
                if (contagemVisivel) ...[
                  Text(
                    'Tempo restante para pagar',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.secondaryLabel(theme),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: AppColors.themeCardSurface(theme),
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(_radiusCard),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 20,
                      ),
                      child: Text(
                        _formatarContagem(_segundosRestantes),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primary,
                          letterSpacing: 2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ] else if (_creditoEmCurso) ...[
                  Material(
                    color: AppColors.themeCardSurface(theme),
                    elevation: 2,
                    borderRadius: BorderRadius.circular(_radiusCard),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 20,
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: primary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'A confirmar o pagamento e atualizar o saldo…',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.secondaryLabel(theme),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (_creditoFalhou) ...[
                  Material(
                    color: theme.colorScheme.errorContainer.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Não foi possível creditar o saldo. Tente novamente.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.secondaryLabel(theme),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: _creditoEmCurso ? null : () => _executarCreditoPix(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Tentar novamente',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Material(
                  color: AppColors.themeCardSurface(theme),
                  elevation: 1,
                  borderRadius: BorderRadius.circular(_radiusCard),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: primary,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Como pagar',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const _PassoLinha(
                          numero: 1,
                          texto:
                              'Abra o app do seu banco e escolha PIX (QR ou copia e cola).',
                        ),
                        const _PassoLinha(
                          numero: 2,
                          texto:
                              'Confira o valor e o destinatário antes de confirmar.',
                        ),
                        _PassoLinha(
                          numero: 3,
                          texto:
                              'Após o tempo indicado acima, o saldo é atualizado '
                              'automaticamente na sua carteira.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Material(
                  color: primary.withValues(alpha: theme.brightness == Brightness.dark ? 0.12 : 0.05),
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
                                  color: AppColors.secondaryLabel(theme),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SelectableText(
                                _chavePixParaExibicao(kChavePixMock),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                  color: onSurface,
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
                if (_creditoFalhou) ...[
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
                color: AppColors.secondaryLabel(theme),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
