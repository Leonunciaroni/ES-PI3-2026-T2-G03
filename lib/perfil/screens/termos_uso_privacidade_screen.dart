// Autor principal: Matheus Teixeira
// RA: 25014927
//
// Termos de Uso e Politica de Privacidade conforme prototipo da task #220.

import 'package:flutter/material.dart';

import '../../theme/mescla_brand_logo.dart';
import '../widgets/mescla_subpage_scaffold.dart';

class TermosUsoPrivacidadeScreen extends StatelessWidget {
  const TermosUsoPrivacidadeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MesclaSubpageScaffold(
      title: 'Termos de Uso',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.light
                  ? const Color(0xFFF7F7FC)
                  : theme.colorScheme.surface,
            ),
            child: const _TermsDocument(),
          ),
        ],
      ),
    );
  }
}

class _TermsDocument extends StatelessWidget {
  const _TermsDocument();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        Center(child: MesclaBrandLogo(boxWidth: 230, boxHeight: 86)),
        SizedBox(height: 14),
        _DocumentTitle('Termos de Uso - MesclaInvest'),
        SizedBox(height: 36),
        _TermsSection(
          title: '1. Aceitacao dos Termos',
          paragraphs: [
            'Ao acessar ou utilizar a plataforma MesclaInvest, o usuario declara estar ciente e de acordo com os presentes Termos de Uso, comprometendo-se a respeitar todas as regras e condicoes estabelecidas neste documento.',
            'O MesclaInvest e um projeto academico desenvolvido no contexto da disciplina Projeto Integrador 3 da Pontificia Universidade Catolica de Campinas (PUC-Campinas), possuindo finalidade exclusivamente educacional e demonstrativa.',
          ],
        ),
        _TermsSection(
          title: '2. Natureza da Plataforma',
          paragraphs: [
            'O MesclaInvest consiste em um ambiente digital de simulacao de investimentos em startups, baseado em negociacao ficticia de tokens digitais.',
            'A plataforma:',
          ],
          bullets: [
            'Nao realiza operacoes financeiras reais;',
            'Nao intermedia investimentos reais;',
            'Nao possui integracao com instituicoes bancarias;',
            'Nao utiliza blockchain real;',
            'Nao representa oferta publica de valores mobiliarios;',
            'Nao garante qualquer retorno financeiro.',
          ],
          footer:
              'Todos os valores, transacoes, tokens e indicadores apresentados possuem carater exclusivamente academico e simulado.',
        ),
        _TermsSection(
          title: '3. Cadastro do Usuario',
          paragraphs: [
            'Para utilizacao da plataforma, o usuario devera realizar cadastro individual, fornecendo informacoes verdadeiras, completas e atualizadas.',
            'O usuario e responsavel por:',
          ],
          bullets: [
            'Manter a confidencialidade de sua senha;',
            'Nao compartilhar sua conta com terceiros;',
            'Garantir a veracidade dos dados informados;',
            'Utilizar a plataforma de forma etica e responsavel.',
          ],
          footer:
              'O fornecimento de informacoes falsas podera resultar em suspensao ou exclusao da conta.',
        ),
        _TermsSection(
          title: '4. Uso Permitido',
          paragraphs: [
            'O usuario compromete-se a utilizar o MesclaInvest exclusivamente para fins academicos, educacionais e demonstrativos.',
            'E proibido:',
          ],
          bullets: [
            'Tentar explorar vulnerabilidades do sistema;',
            'Realizar engenharia reversa da aplicacao;',
            'Utilizar automacoes maliciosas;',
            'Compartilhar conteudos ofensivos ou ilegais;',
            'Manipular indevidamente o funcionamento da plataforma;',
            'Utilizar dados de terceiros sem autorizacao.',
          ],
        ),
        _TermsSection(
          title: '5. Disponibilidade do Sistema',
          paragraphs: [
            'Por se tratar de um prototipo academico, o MesclaInvest podera apresentar:',
          ],
          bullets: [
            'Instabilidades;',
            'Interrupcoes temporarias;',
            'Perda de dados;',
            'Alteracoes de funcionalidades;',
            'Manutencoes sem aviso previo.',
          ],
          footer: 'Nao ha garantia de disponibilidade continua da aplicacao.',
        ),
        _TermsSection(
          title: '6. Limitacao de Responsabilidade',
          paragraphs: [
            'Os responsaveis pelo projeto nao se responsabilizam por:',
          ],
          bullets: [
            'Decisoes tomadas com base nas informacoes simuladas da plataforma;',
            'Perda de dados decorrente de falhas tecnicas;',
            'Interrupcoes do sistema;',
            'Uso indevido realizado por terceiros;',
            'Danos causados por utilizacao inadequada da aplicacao.',
          ],
          footer:
              'O sistema nao deve ser utilizado para armazenamento de informacoes sensiveis ou operacoes reais.',
        ),
        _TermsSection(
          title: '7. Propriedade Intelectual',
          paragraphs: ['Todo o conteudo do MesclaInvest, incluindo:'],
          bullets: [
            'Interface;',
            'Codigo-fonte;',
            'Layouts;',
            'Identidade visual;',
            'Estrutura da aplicacao;',
            'Documentacao;',
          ],
          footer:
              'Destina-se exclusivamente ao contexto academico do Projeto Integrador 3. E proibida a reproducao, comercializacao ou reutilizacao sem autorizacao dos responsaveis.',
        ),
        _TermsSection(
          title: '8. Alteracoes nos Termos',
          paragraphs: [
            'Os presentes Termos de Uso poderao ser modificados a qualquer momento para adequacao do projeto academico, sem necessidade de aviso previo.',
          ],
        ),
        SizedBox(height: 30),
        _DocumentTitle('Politica de Privacidade - MesclaInvest'),
        SizedBox(height: 26),
        _TermsSection(
          title: '1. Introducao',
          paragraphs: [
            'A presente Politica de Privacidade descreve como os dados dos usuarios poderao ser coletados, utilizados e armazenados durante a utilizacao da plataforma MesclaInvest.',
            'O documento possui carater ficticio e academico, sendo utilizado exclusivamente para fins educacionais.',
          ],
        ),
        _TermsSection(
          title: '2. Dados Coletados',
          paragraphs: [
            'Durante a utilizacao da plataforma, poderao ser coletados os seguintes dados:',
          ],
          bullets: [
            'Nome completo;',
            'E-mail;',
            'CPF;',
            'Numero de telefone;',
            'Senha de acesso;',
            'Historico de operacoes simuladas;',
            'Informacoes de autenticacao;',
            'Dados de navegacao dentro da aplicacao.',
          ],
        ),
        _TermsSection(
          title: '3. Finalidade da Coleta',
          paragraphs: ['Os dados poderao ser utilizados para:'],
          bullets: [
            'Permitir autenticacao do usuario;',
            'Garantir funcionamento da plataforma;',
            'Simular operacoes de compra e venda de tokens;',
            'Gerenciar contas cadastradas;',
            'Permitir recuperacao de senha;',
            'Melhorar funcionalidades do sistema;',
            'Gerar analises academicas sobre utilizacao da aplicacao.',
          ],
        ),
        _TermsSection(
          title: '4. Compartilhamento de Dados',
          paragraphs: [
            'Os dados nao serao vendidos ou comercializados.',
            'As informacoes poderao ser acessadas apenas por:',
          ],
          bullets: [
            'Integrantes da equipe desenvolvedora;',
            'Professores orientadores;',
            'Administradores tecnicos da aplicacao;',
            'Ferramentas utilizadas no ambiente academico.',
          ],
        ),
        _TermsSection(
          title: '5. Armazenamento das Informacoes',
          paragraphs: [
            'As informacoes poderao ser armazenadas em servicos de banco de dados e infraestrutura em nuvem utilizados pela aplicacao, incluindo Firebase Firestore.',
            'Apesar da adocao de boas praticas de desenvolvimento, nao ha garantia absoluta de seguranca, considerando tratar-se de um prototipo academico.',
          ],
        ),
        _TermsSection(
          title: '6. Seguranca',
          paragraphs: [
            'O MesclaInvest podera utilizar mecanismos basicos de seguranca, incluindo:',
          ],
          bullets: [
            'Autenticacao por senha;',
            'Criptografia de credenciais;',
            'Controle de acesso;',
            'Autenticacao multifator (2FA/MFA), quando habilitada.',
          ],
          footer:
              'Ainda assim, o usuario reconhece que nenhum sistema e totalmente livre de riscos.',
        ),
        _TermsSection(
          title: '7. Direitos do Usuario',
          paragraphs: ['O usuario podera solicitar:'],
          bullets: [
            'Atualizacao de dados cadastrais;',
            'Recuperacao de acesso;',
            'Exclusao da conta;',
            'Encerramento de utilizacao da plataforma.',
          ],
          footer:
              'As solicitacoes serao tratadas conforme a disponibilidade da equipe responsavel pelo projeto academico.',
        ),
        _TermsSection(
          title: '8. Retencao dos Dados',
          paragraphs: [
            'Os dados poderao permanecer armazenados durante o periodo letivo da disciplina e posteriormente serem removidos, conforme decisao da equipe responsavel.',
          ],
        ),
        _TermsSection(
          title: '9. Consentimento',
          paragraphs: [
            'Ao utilizar o MesclaInvest, o usuario declara estar ciente e concordar com esta Politica de Privacidade e com os Termos de Uso da plataforma.',
          ],
        ),
      ],
    );
  }
}

class _DocumentTitle extends StatelessWidget {
  const _DocumentTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({
    required this.title,
    required this.paragraphs,
    this.bullets = const [],
    this.footer,
  });

  final String title;
  final List<String> paragraphs;
  final List<String> bullets;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final bodyStyle = theme.textTheme.bodySmall?.copyWith(
      color: textColor,
      fontSize: 10.8,
      height: 1.16,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DefaultTextStyle.merge(
        style: bodyStyle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: bodyStyle?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            for (final paragraph in paragraphs) Text(paragraph),
            if (bullets.isNotEmpty) ...[
              const SizedBox(height: 2),
              for (final bullet in bullets) _BulletLine(bullet),
            ],
            if (footer != null) ...[const SizedBox(height: 2), Text(footer!)],
          ],
        ),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final textColor = DefaultTextStyle.of(context).style.color ?? Colors.black;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4.2, right: 5),
          child: SizedBox.square(
            dimension: 4,
            child: DecoratedBox(decoration: BoxDecoration(color: textColor)),
          ),
        ),
        Expanded(child: Text(text)),
      ],
    );
  }
}
