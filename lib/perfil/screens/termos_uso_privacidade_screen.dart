// Autor principal: Matheus Teixeira
// RA: 25014927
//
// Termos de Uso e Política de Privacidade conforme protótipo da task #220.

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
            child: const TermosUsoPrivacidadeDocument(),
          ),
        ],
      ),
    );
  }
}

class TermosUsoPrivacidadeDocument extends StatelessWidget {
  const TermosUsoPrivacidadeDocument({super.key, this.showLogo = true});

  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLogo) ...const [
          Center(child: MesclaBrandLogo(boxWidth: 230, boxHeight: 86)),
          SizedBox(height: 14),
        ],
        const _DocumentTitle('Termos de Uso - MesclaInvest'),
        const SizedBox(height: 36),
        const _TermsSection(
          title: '1. Aceitação dos Termos',
          paragraphs: [
            'Ao acessar ou utilizar a plataforma MesclaInvest, o usuário declara estar ciente e de acordo com os presentes Termos de Uso, comprometendo-se a respeitar todas as regras e condições estabelecidas neste documento.',
            'O MesclaInvest é um projeto acadêmico desenvolvido no contexto da disciplina Projeto Integrador 3 da Pontifícia Universidade Católica de Campinas (PUC-Campinas), com finalidade exclusivamente educacional e demonstrativa.',
          ],
        ),
        const _TermsSection(
          title: '2. Natureza da Plataforma',
          paragraphs: [
            'O MesclaInvest consiste em um ambiente digital de simulação de investimentos em startups, baseado em negociação fictícia de tokens digitais.',
            'A plataforma:',
          ],
          bullets: [
            'Não realiza operações financeiras reais;',
            'Não intermedia investimentos reais;',
            'Não possui integração com instituições bancárias;',
            'Não utiliza blockchain real;',
            'Não representa oferta pública de valores mobiliários;',
            'Não garante qualquer retorno financeiro.',
          ],
          footer:
              'Todos os valores, transações, tokens e indicadores apresentados possuem caráter exclusivamente acadêmico e simulado.',
        ),
        const _TermsSection(
          title: '3. Cadastro do Usuário',
          paragraphs: [
            'Para utilizar a plataforma, o usuário deverá realizar um cadastro individual, fornecendo informações verdadeiras, completas e atualizadas.',
            'O usuário é responsável por:',
          ],
          bullets: [
            'Manter a confidencialidade de sua senha;',
            'Não compartilhar sua conta com terceiros;',
            'Garantir a veracidade dos dados informados;',
            'Utilizar a plataforma de forma ética e responsável.',
          ],
          footer:
              'O fornecimento de informações falsas poderá resultar em suspensão ou exclusão da conta.',
        ),
        const _TermsSection(
          title: '4. Uso Permitido',
          paragraphs: [
            'O usuário compromete-se a utilizar o MesclaInvest exclusivamente para fins acadêmicos, educacionais e demonstrativos.',
            'É proibido:',
          ],
          bullets: [
            'Tentar explorar vulnerabilidades do sistema;',
            'Realizar engenharia reversa da aplicação;',
            'Utilizar automações maliciosas;',
            'Compartilhar conteúdos ofensivos ou ilegais;',
            'Manipular indevidamente o funcionamento da plataforma;',
            'Utilizar dados de terceiros sem autorização.',
          ],
        ),
        const _TermsSection(
          title: '5. Disponibilidade do Sistema',
          paragraphs: [
            'Por se tratar de um protótipo acadêmico, o MesclaInvest poderá apresentar:',
          ],
          bullets: [
            'Instabilidades;',
            'Interrupções temporárias;',
            'Perda de dados;',
            'Alterações de funcionalidades;',
            'Manutenções sem aviso prévio.',
          ],
          footer: 'Não há garantia de disponibilidade contínua da aplicação.',
        ),
        const _TermsSection(
          title: '6. Limitação de Responsabilidade',
          paragraphs: [
            'Os responsáveis pelo projeto não se responsabilizam por:',
          ],
          bullets: [
            'Decisões tomadas com base nas informações simuladas da plataforma;',
            'Perda de dados decorrente de falhas técnicas;',
            'Interrupções do sistema;',
            'Uso indevido realizado por terceiros;',
            'Danos causados pela utilização inadequada da aplicação.',
          ],
          footer:
              'O sistema não deve ser utilizado para armazenamento de informações sensíveis ou operações reais.',
        ),
        const _TermsSection(
          title: '7. Propriedade Intelectual',
          paragraphs: ['Todo o conteúdo do MesclaInvest, incluindo:'],
          bullets: [
            'Interface;',
            'Código-fonte;',
            'Layouts;',
            'Identidade visual;',
            'Estrutura da aplicação;',
            'Documentação;',
          ],
          footer:
              'Destina-se exclusivamente ao contexto acadêmico do Projeto Integrador 3. É proibida a reprodução, comercialização ou reutilização sem autorização dos responsáveis.',
        ),
        const _TermsSection(
          title: '8. Alterações nos Termos',
          paragraphs: [
            'Os presentes Termos de Uso poderão ser modificados a qualquer momento para adequação do projeto acadêmico, sem necessidade de aviso prévio.',
          ],
        ),
        const SizedBox(height: 30),
        const _DocumentTitle('Política de Privacidade - MesclaInvest'),
        const SizedBox(height: 26),
        const _TermsSection(
          title: '1. Introdução',
          paragraphs: [
            'A presente Política de Privacidade descreve como os dados dos usuários poderão ser coletados, utilizados e armazenados durante a utilização da plataforma MesclaInvest.',
            'O documento possui caráter fictício e acadêmico, sendo utilizado exclusivamente para fins educacionais.',
          ],
        ),
        const _TermsSection(
          title: '2. Dados Coletados',
          paragraphs: [
            'Durante a utilização da plataforma, poderão ser coletados os seguintes dados:',
          ],
          bullets: [
            'Nome completo;',
            'E-mail;',
            'CPF;',
            'Número de telefone;',
            'Senha de acesso;',
            'Histórico de operações simuladas;',
            'Informações de autenticação;',
            'Dados de navegação dentro da aplicação.',
          ],
        ),
        const _TermsSection(
          title: '3. Finalidade da Coleta',
          paragraphs: ['Os dados poderão ser utilizados para:'],
          bullets: [
            'Permitir a autenticação do usuário;',
            'Garantir o funcionamento da plataforma;',
            'Simular operações de compra e venda de tokens;',
            'Gerenciar contas cadastradas;',
            'Permitir recuperação de senha;',
            'Melhorar funcionalidades do sistema;',
            'Gerar análises acadêmicas sobre a utilização da aplicação.',
          ],
        ),
        const _TermsSection(
          title: '4. Compartilhamento de Dados',
          paragraphs: [
            'Os dados não serão vendidos ou comercializados.',
            'As informações poderão ser acessadas apenas por:',
          ],
          bullets: [
            'Integrantes da equipe desenvolvedora;',
            'Professores orientadores;',
            'Administradores técnicos da aplicação;',
            'Ferramentas utilizadas no ambiente acadêmico.',
          ],
        ),
        const _TermsSection(
          title: '5. Armazenamento das Informações',
          paragraphs: [
            'As informações poderão ser armazenadas em serviços de banco de dados e infraestrutura em nuvem utilizados pela aplicação, incluindo o Firebase Firestore.',
            'Apesar da adoção de boas práticas de desenvolvimento, não há garantia absoluta de segurança, considerando tratar-se de um protótipo acadêmico.',
          ],
        ),
        const _TermsSection(
          title: '6. Segurança',
          paragraphs: [
            'O MesclaInvest poderá utilizar mecanismos básicos de segurança, incluindo:',
          ],
          bullets: [
            'Autenticação por senha;',
            'Criptografia de credenciais;',
            'Controle de acesso;',
            'Autenticação multifator (2FA/MFA), quando habilitada.',
          ],
          footer:
              'Ainda assim, o usuário reconhece que nenhum sistema é totalmente livre de riscos.',
        ),
        const _TermsSection(
          title: '7. Direitos do Usuário',
          paragraphs: ['O usuário poderá solicitar:'],
          bullets: [
            'Atualização de dados cadastrais;',
            'Recuperação de acesso;',
            'Exclusão da conta;',
            'Encerramento de utilização da plataforma.',
          ],
          footer:
              'As solicitações serão tratadas conforme a disponibilidade da equipe responsável pelo projeto acadêmico.',
        ),
        const _TermsSection(
          title: '8. Retenção dos Dados',
          paragraphs: [
            'Os dados poderão permanecer armazenados durante o período letivo da disciplina e posteriormente ser removidos, conforme decisão da equipe responsável.',
          ],
        ),
        const _TermsSection(
          title: '9. Consentimento',
          paragraphs: [
            'Ao utilizar o MesclaInvest, o usuário declara estar ciente e concordar com esta Política de Privacidade e com os Termos de Uso da plataforma.',
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
