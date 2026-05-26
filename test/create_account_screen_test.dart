import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/auth/screens/create_account_screen.dart';

void main() {
  // Monta a tela de cadastro dentro de MaterialApp para fornecer tema e navegação.
  Widget buildScreen() {
    return const MaterialApp(home: CreateAccountScreen());
  }

  // Toca em um botão identificado pelo texto e aguarda todas as animações.
  Future<void> tapPrimary(WidgetTester tester, String text) async {
    // Localiza o botão pelo texto visível.
    final button = find.text(text);
    // Garante que o botão esteja no viewport antes do toque.
    await tester.ensureVisible(button);
    // Executa o toque no botão.
    await tester.tap(button);
    // Aguarda animações, navegação de etapa e rebuilds terminarem.
    await tester.pumpAndSettle();
  }

  // Preenche todas as etapas obrigatórias até chegar na tela de termos.
  Future<void> fillValidStepsUntilTerms(WidgetTester tester) async {
    // Preenche a etapa de nome completo.
    await tester.enterText(find.byType(TextField), 'Usuario Teste');
    // Avança para a etapa de e-mail.
    await tapPrimary(tester, 'Continuar');

    // Preenche a etapa de e-mail válido.
    await tester.enterText(find.byType(TextField), 'teste@email.com');
    // Avança para a etapa de telefone.
    await tapPrimary(tester, 'Continuar');

    // Preenche a etapa de celular brasileiro válido.
    await tester.enterText(find.byType(TextField), '(19) 99999-9999');
    // Avança para a etapa de escolha de 2FA.
    await tapPrimary(tester, 'Continuar');

    // Mantém a opção padrão de 2FA e avança para CPF.
    await tapPrimary(tester, 'Continuar');

    // Preenche um CPF válido para passar na validação.
    await tester.enterText(find.byType(TextField), '529.982.247-25');
    // Avança para a etapa de senha.
    await tapPrimary(tester, 'Continuar');

    // Preenche uma senha que atende à checklist.
    await tester.enterText(find.byType(TextField), 'Senha@123');
    // Avança para a etapa de confirmação.
    await tapPrimary(tester, 'Continuar');

    // Repete a senha para passar na validação de igualdade.
    await tester.enterText(find.byType(TextField), 'Senha@123');
    // Avança para a etapa de termos.
    await tapPrimary(tester, 'Continuar');
  }

  testWidgets('Renderiza cadastro em etapas separadas', (
    WidgetTester tester,
  ) async {
    // Renderiza a tela inicial do cadastro.
    await tester.pumpWidget(buildScreen());
    // Aguarda o primeiro layout estabilizar.
    await tester.pumpAndSettle();

    // Confirma que a primeira etapa mostra só nome completo.
    expect(find.text('NOME COMPLETO *'), findsOneWidget);
    // Confirma que e-mail ainda não aparece na primeira etapa.
    expect(find.text('E-MAIL PESSOAL *'), findsNothing);

    // Preenche nome válido para permitir avanço.
    await tester.enterText(find.byType(TextField), 'Usuario Teste');
    // Avança para a segunda etapa.
    await tapPrimary(tester, 'Continuar');

    // Confirma que e-mail aparece na segunda etapa.
    expect(find.text('E-MAIL PESSOAL *'), findsOneWidget);
    // Confirma que telefone ainda não aparece na segunda etapa.
    expect(find.text('TELEFONE CELULAR *'), findsNothing);

    // Preenche e-mail válido.
    await tester.enterText(find.byType(TextField), 'teste@email.com');
    // Avança para telefone.
    await tapPrimary(tester, 'Continuar');

    // Confirma que telefone aparece na terceira etapa.
    expect(find.text('TELEFONE CELULAR *'), findsOneWidget);
    // Confirma o hint esperado do telefone.
    expect(find.text('Ex: (19) 99999-9999'), findsOneWidget);
    // Confirma que CPF ainda não aparece na etapa de telefone.
    expect(find.text('CPF *'), findsNothing);
  });

  testWidgets('Permite marcar aceite dos termos', (WidgetTester tester) async {
    // Renderiza a tela para simular o fluxo real.
    await tester.pumpWidget(buildScreen());
    // Aguarda a tela estabilizar antes das interações.
    await tester.pumpAndSettle();

    // Preenche etapas anteriores para chegar até termos.
    await fillValidStepsUntilTerms(tester);

    // Localiza o checkbox de aceite de termos.
    final checkboxFinder = find.byType(Checkbox);
    // Garante que exista exatamente um checkbox na etapa.
    expect(checkboxFinder, findsOneWidget);

    // Lê o widget checkbox para inspecionar seu valor atual.
    Checkbox checkbox = tester.widget<Checkbox>(checkboxFinder);
    // Confirma que o aceite começa desmarcado.
    expect(checkbox.value, isFalse);

    // Garante que o checkbox esteja visível antes do toque.
    await tester.ensureVisible(checkboxFinder);
    // Marca o checkbox de aceite.
    await tester.tap(checkboxFinder);
    // Aguarda o setState refletir o novo valor.
    await tester.pumpAndSettle();

    // Lê novamente o checkbox depois do toque.
    checkbox = tester.widget<Checkbox>(checkboxFinder);
    // Confirma que o aceite ficou marcado.
    expect(checkbox.value, isTrue);
  });

  testWidgets('Mostra alerta ao criar conta sem aceitar termos', (
    WidgetTester tester,
  ) async {
    // Renderiza a tela de cadastro.
    await tester.pumpWidget(buildScreen());
    // Aguarda o primeiro frame completo.
    await tester.pumpAndSettle();

    // Chega até termos com dados válidos nas etapas anteriores.
    await fillValidStepsUntilTerms(tester);
    // Tenta avançar sem marcar o checkbox.
    await tapPrimary(tester, 'Continuar');

    // Espera a mensagem de erro específica dos termos não aceitos.
    expect(
      find.text(
        'Aceite os Termos de Uso e a Política de Privacidade para continuar.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Rejeita celular sem 9 após o DDD', (WidgetTester tester) async {
    // Renderiza a tela de cadastro.
    await tester.pumpWidget(buildScreen());
    // Aguarda layout e animações iniciais.
    await tester.pumpAndSettle();

    // Preenche nome completo para chegar ao e-mail.
    await tester.enterText(find.byType(TextField), 'Usuario Teste');
    // Avança para e-mail.
    await tapPrimary(tester, 'Continuar');

    // Preenche e-mail válido para chegar ao telefone.
    await tester.enterText(find.byType(TextField), 'teste@email.com');
    // Avança para telefone.
    await tapPrimary(tester, 'Continuar');

    // Onze dígitos, mas o primeiro após o DDD não é 9 (não é celular atual).
    await tester.enterText(find.byType(TextField), '(11) 32345-6789');
    // Tenta avançar com telefone inválido.
    await tapPrimary(tester, 'Continuar');
    // Aguarda o Snackbar aparecer.
    await tester.pump();

    // Confirma que a validação de celular bloqueou o avanço.
    expect(
      find.text(
        'Telefone celular inválido. Informe DDD + 9 dígitos, no formato '
        '(XX) 9XXXX-XXXX.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Exibe etapa final para foto com avatar padrao', (
    WidgetTester tester,
  ) async {
    // Renderiza a tela de cadastro.
    await tester.pumpWidget(buildScreen());
    // Aguarda o primeiro layout.
    await tester.pumpAndSettle();

    // Chega até a etapa de termos com dados válidos.
    await fillValidStepsUntilTerms(tester);

    // Marca o aceite dos termos.
    await tester.tap(find.byType(Checkbox));
    // Aguarda o estado do checkbox atualizar.
    await tester.pumpAndSettle();
    // Avança para a etapa final de foto.
    await tapPrimary(tester, 'Continuar');

    // Confirma que a etapa de foto está visível.
    expect(find.text('Escolha sua foto de perfil'), findsOneWidget);
    // Confirma opção de câmera.
    expect(find.text('Tirar foto'), findsOneWidget);
    // Confirma opção de galeria/upload.
    expect(find.text('Fazer upload'), findsOneWidget);
    // Confirma opção de avatar padrão.
    expect(find.text('Usar avatar padrão'), findsOneWidget);
    // Confirma iniciais geradas de Usuario Teste.
    expect(find.text('UT'), findsOneWidget);
    // Confirma que o botão final cria a conta.
    expect(find.text('Criar Conta →'), findsOneWidget);
  });
}
