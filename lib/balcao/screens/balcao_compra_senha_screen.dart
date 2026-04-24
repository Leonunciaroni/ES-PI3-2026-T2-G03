// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Passo de **senha** no fluxo do Balcão. A validação é feita com a **mesma senha
// do login, via reautenticação no [FirebaseAuth] (a senha não fica armazenada na app).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/services/auth_service.dart';
import '../../carteira/format/carteira_brl.dart';
import '../../catalog/models/catalog_startup.dart';
import '../../theme/app_colors.dart';
import '../balcao_format.dart';
import '../models/balcao_operacao_tipo.dart';
import '../models/balcao_transacao.dart';
import 'balcao_transacao_detalhe_screen.dart';

/// Ecrã onde o utilizador confirma a identidade antes de concluir a operação.
class BalcaoCompraSenhaScreen extends StatefulWidget {
  const BalcaoCompraSenhaScreen({
    super.key,
    required this.startup,
    required this.operacao,
    required this.valorReaisOperacao,
  });

  final CatalogStartup startup;
  final BalcaoOperacaoTipo operacao;
  final double valorReaisOperacao;

  @override
  State<BalcaoCompraSenhaScreen> createState() => _BalcaoCompraSenhaScreenState();
}

class _BalcaoCompraSenhaScreenState extends State<BalcaoCompraSenhaScreen> {
  final _senhaController = TextEditingController();
  bool _ocultarSenha = true;
  String? _erro;
  bool _enviando = false;

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

  double get _quantidadeTokens {
    final p = widget.startup.tokenPrice;
    if (p <= 0) return 0;
    return widget.valorReaisOperacao / p;
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
    setState(() => _enviando = false);

    final agora = DateTime.now();
    final detalhe = BalcaoTransacaoDetalhe(
      operacao: widget.operacao,
      nomeToken: _nomeToken,
      quantidadeTokens: _quantidadeTokens,
      valorReais: widget.valorReaisOperacao,
      dataHora: agora,
      status: 'Concluída',
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => BalcaoTransacaoDetalheScreen(detalhe: detalhe),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final tituloAppBar = widget.operacao == BalcaoOperacaoTipo.compra
        ? 'Confirmar compra'
        : 'Confirmar venda';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.systemUiLightAppBar,
      child: Scaffold(
        backgroundColor: AppColors.gradientBottom,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: scheme.onSurface,
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
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${formatBrl(widget.valorReaisOperacao)} ≈ ${formatQuantidadeTokensBr(_quantidadeTokens)} tokens',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
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
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.fieldBorder),
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
                'Usamos a mesma senha com que você entra no app.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
