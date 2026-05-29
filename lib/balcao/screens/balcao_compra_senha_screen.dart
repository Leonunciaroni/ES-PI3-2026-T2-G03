// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Passo de **confirmação** no fluxo do Balcão: pode ser **biometria local** (se o
// usuário ativou em Segurança) ou **senha** com reautenticação no [FirebaseAuth]
// (a senha não fica guardada na app).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/services/auth_service.dart';
import '../../auth/services/biometric_auth_service.dart';
import '../../auth/services/biometric_shortcut_availability.dart';
import '../../navigation/mescla_material_route.dart';
import '../../carteira/format/carteira_brl.dart';
import '../../carteira/services/simulated_wallet_service.dart';
import '../../catalog/models/catalog_startup.dart';
import '../../theme/app_colors.dart';
import '../balcao_format.dart';
import '../balcao_official_price.dart';
import '../models/balcao_operacao_tipo.dart';
import '../models/balcao_transacao.dart';
import 'balcao_transacao_detalhe_screen.dart';

/// Tela onde o usuário confirma a identidade antes de concluir a operação.
class BalcaoCompraSenhaScreen extends StatefulWidget {
  const BalcaoCompraSenhaScreen({
    super.key,
    required this.startup,
    required this.operacao,
    required this.valorReaisOperacao,
    required this.quantidadeTokensNegocio,
  });

  final CatalogStartup startup;
  final BalcaoOperacaoTipo operacao;

  /// Total em reais alinhado ao contrato do backend ([balcaoResolveMercadoDesdeQuantidadeTokens]).
  final double valorReaisOperacao;

  /// Quantidade inteira de tokens enviada ao `simulateWallet`.
  final int quantidadeTokensNegocio;

  @override
  State<BalcaoCompraSenhaScreen> createState() => _BalcaoCompraSenhaScreenState();
}

class _BalcaoCompraSenhaScreenState extends State<BalcaoCompraSenhaScreen> {
  final _senhaController = TextEditingController();
  bool _ocultarSenha = true;
  String? _erro;
  bool _enviando = false;

  /// Se `true`, bloco biométrico + prompt automático (como a tela de desbloqueio).
  bool _oferecerBiometria = false;

  /// Evita abrir o diálogo do SO duas vezes ao mesmo tempo.
  bool _disparouPromptBiometriaInicial = false;

  int get _quantidadeTokensNegocio => widget.quantidadeTokensNegocio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _atualizarOfertaBiometria());
  }

  /// Só Firestore + armazenamento seguro (igual [AuthGateScreen]), sem pre-check do plugin.
  Future<void> _atualizarOfertaBiometria() async {
    final bool ok =
        await BiometricShortcutAvailability.userWantsBiometricShortcut();
    if (!mounted) return;
    setState(() => _oferecerBiometria = ok);
    if (!ok || _disparouPromptBiometriaInicial) return;
    _disparouPromptBiometriaInicial = true;
    // Pequena pausa: a tela desenha primeiro; depois abrimos o diálogo do SO (como no login).
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted || !_oferecerBiometria) return;
    await _onConfirmarComBiometria();
  }

  @override
  void dispose() {
    _senhaController.dispose();
    super.dispose();
  }

  String get _nomeToken {
    final s = widget.startup.sigla?.trim();
    if (s != null && s.isNotEmpty) return s.toUpperCase();
    final n = widget.startup.name;
    if (n.length <= 5) return n.toUpperCase();
    return n.substring(0, 4).toUpperCase();
  }

  String get _razaoBiometriaBalcao {
    return widget.operacao == BalcaoOperacaoTipo.compra
        ? 'Confirme a compra de tokens no Mescla Invest.'
        : 'Confirme a venda de tokens no Mescla Invest.';
  }

  /// Caminho alternativo: o SO valida biometria; não chamamos [reauthenticateWithCredential].
  Future<void> _onConfirmarComBiometria() async {
    if (_enviando) return;

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(
        () => _erro = 'Sessão expirada. Entre de novo com seu e-mail e senha.',
      );
      return;
    }

    setState(() {
      _erro = null;
      _enviando = true;
    });

    final BiometricAuthOutcome resultado =
        await BiometricAuthService.instance.authenticate(
      localizedReason: _razaoBiometriaBalcao,
      skipPluginAvailabilityPrecheck: true,
    );

    if (resultado != BiometricAuthOutcome.success) {
      if (mounted) {
        setState(() {
          _erro = BiometricAuthService.messageForOutcome(resultado);
          _enviando = false;
        });
      }
      return;
    }

    await _executarNegocioAposIdentidadeVerificada(user);
  }

  /// Executa cotação, validações e `simulateWallet` depois de saber que o usuário
  /// se identificou (senha ou biometria local).
  Future<void> _executarNegocioAposIdentidadeVerificada(User user) async {
    try {
      if (widget.startup.firestoreId == null ||
          widget.startup.firestoreId!.isEmpty) {
        throw StateError(
          'Esta startup não tem ID Firestore necessário ao balcão simulado.',
        );
      }

      final fid = widget.startup.firestoreId!;
      final precoOficial = await fetchPrecoTokenOficialBrl(fid);
      if (!mounted) return;

      if (precoOficial == null) {
        setState(() {
          _erro =
              'Cotação indisponível no servidor. Tente novamente em instantes.';
          _enviando = false;
        });
        return;
      }

      if (!balcaoAmountMatchesTrade(
        widget.valorReaisOperacao,
        _quantidadeTokensNegocio,
        precoOficial,
      )) {
        setState(() {
          _erro =
              'A cotação no servidor atualizou-se. Volte e confira o valor total antes de repetir.';
          _enviando = false;
        });
        return;
      }

      switch (widget.operacao) {
        case BalcaoOperacaoTipo.compra:
          // Escrow P2P: parte do saldo BRL pode estar bloqueada em ordens abertas.
          final walletSnap =
              await SimulatedWalletPaths.walletDoc(user.uid).get();
          if (!mounted) return;
          final walletData = walletSnap.data();
          final brlBalance = walletData?['brlBalance'] is num
              ? (walletData!['brlBalance'] as num).toDouble()
              : 0.0;
          final brlLocked = walletData?['brlLockedInOrders'] is num
              ? (walletData!['brlLockedInOrders'] as num).toDouble()
              : 0.0;
          final brlDisponivel = brlBalance - brlLocked;
          if (widget.valorReaisOperacao > brlDisponivel + balcaoEpsilonBrl) {
            setState(() {
              _erro =
                  'Saldo atualizado: o disponível não cobre mais este total. Volte ao passo anterior.';
              _enviando = false;
            });
            return;
          }
          await SimulatedWalletService.tradeBuy(
            startup: widget.startup,
            valorReais: widget.valorReaisOperacao,
            quantidadeTokens: _quantidadeTokensNegocio,
          );
          break;
        case BalcaoOperacaoTipo.venda:
          // Escrow P2P: tokens podem estar reservados em ordens de venda abertas.
          final posSnap = await SimulatedWalletPaths.positionsCol(user.uid)
              .doc(fid)
              .get();
          if (!mounted) return;
          final posData = posSnap.data();
          final tokensHeld = posData?['tokensHeld'] is num
              ? (posData!['tokensHeld'] as num).toDouble()
              : 0.0;
          final tokensLocked = posData?['tokensLockedInOrders'] is int
              ? posData!['tokensLockedInOrders'] as int
              : posData?['tokensLockedInOrders'] is num
                  ? (posData!['tokensLockedInOrders'] as num).toInt()
                  : 0;
          final tokensDisponiveis = tokensHeld.floor() - tokensLocked;
          if (_quantidadeTokensNegocio > tokensDisponiveis) {
            setState(() {
              _erro =
                  'A sua posição mudou desde o passo anterior. Volte para ajustar a quantidade.';
              _enviando = false;
            });
            return;
          }
          await SimulatedWalletService.tradeSell(
            startup: widget.startup,
            valorReais: widget.valorReaisOperacao,
            quantidadeTokens: _quantidadeTokensNegocio,
          );
          break;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = SimulatedWalletService.messageForUser(e);
        _enviando = false;
      });
      return;
    }

    setState(() => _enviando = false);
    if (!mounted) return;

    final agora = DateTime.now();
    final detalhe = BalcaoTransacaoDetalhe(
      operacao: widget.operacao,
      nomeToken: _nomeToken,
      quantidadeTokens: _quantidadeTokensNegocio,
      valorReais: widget.valorReaisOperacao,
      dataHora: agora,
      status: 'Concluída',
    );

    Navigator.of(context).pushReplacement(
      MesclaMaterialRoute.fadeSlide<void>(
        (context) => BalcaoTransacaoDetalheScreen(detalhe: detalhe),
      ),
    );
  }

  /// Confere a senha com o Firebase: tem de ser a mesma do login (e-mail + senha).
  Future<void> _onConfirmar() async {
    if (_enviando) return;

    final password = _senhaController.text;
    if (password.isEmpty) {
      setState(() => _erro = 'Informe sua senha.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(
        () => _erro = 'Sessão expirada. Entre de novo com seu e-mail e senha.',
      );
      return;
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      setState(
        () => _erro =
            'Esta conta não usa senha de e-mail. Não é possível validar aqui.',
      );
      return;
    }

    setState(() {
      _enviando = true;
      _erro = null;
    });

    try {
      final cred = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.code == 'invalid-credential' || e.code == 'wrong-password'
              ? 'Senha incorreta. Use a mesma senha do login.'
              : AuthService.messageForError(e);
          _enviando = false;
        });
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = AuthService.messageForError(e);
          _enviando = false;
        });
      }
      return;
    }

    if (!mounted) return;

    await _executarNegocioAposIdentidadeVerificada(user);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final bodyBg = theme.brightness == Brightness.light
        ? AppColors.gradientBottom
        : AppColors.gradientBottomDark;
    final overlay = AppColors.shellOverlayStyle(theme.brightness);

    final tituloAppBar = widget.operacao == BalcaoOperacaoTipo.compra
        ? 'Confirmar compra'
        : 'Confirmar venda';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: bodyBg,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: onSurface,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: overlay,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _enviando ? null : () => Navigator.of(context).pop(),
            tooltip: 'Voltar',
          ),
          title: Text(
            tituloAppBar,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Token $_nomeToken · ${widget.startup.name}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${formatBrl(widget.valorReaisOperacao)} · ${formatQuantidadeTokensBr(_quantidadeTokensNegocio.toDouble())} tokens',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                ),
              ),
              const SizedBox(height: 20),
              if (_oferecerBiometria) ...[
                Material(
                  color: AppColors.themeCardSurface(theme),
                  borderRadius: BorderRadius.circular(16),
                  elevation: 1,
                  shadowColor: Colors.black.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.fingerprint_rounded,
                          size: 44,
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Primeiro: biometria deste aparelho',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'O sistema deve pedir rosto ou digital (como ao abrir o app). '
                          'Se cancelar, use a senha mais abaixo.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.secondaryLabel(theme),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _enviando ? null : _onConfirmarComBiometria,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: const Text('Tentar biometria de novo'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.cardDivider(theme))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'ou senha do login',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.cardDivider(theme))),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              TextField(
                controller: _senhaController,
                obscureText: _ocultarSenha,
                enabled: !_enviando,
                keyboardType: TextInputType.visiblePassword,
                onChanged: (_) {
                  if (_erro != null) setState(() => _erro = null);
                },
                decoration: InputDecoration(
                  labelText: 'Senha do login',
                  hintText: 'Sua senha de acesso',
                  filled: true,
                  fillColor: AppColors.searchFieldFillForTheme(theme),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.cardDivider(theme)),
                  ),
                  suffixIcon: IconButton(
                    onPressed: _enviando
                        ? null
                        : () => setState(() => _ocultarSenha = !_ocultarSenha),
                    icon: Icon(
                      _ocultarSenha
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 10),
                Text(
                  _erro!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _enviando ? null : _onConfirmar,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _enviando
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.operacao == BalcaoOperacaoTipo.compra
                            ? 'Confirmar compra'
                            : 'Confirmar venda',
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                _oferecerBiometria
                    ? 'A biometria confirma só neste aparelho; a senha revalida a conta no Firebase.'
                    : 'Usamos a mesma senha com que você entra no app.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
