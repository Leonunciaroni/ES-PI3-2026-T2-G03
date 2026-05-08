import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:mescla_invest/carteira/screens/pagamento_pix_screen.dart';

void main() {
  testWidgets('PagamentoPixScreen mostra valor total e QR', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PagamentoPixScreen(
          valorReais: 1000,
          quantidadeTokens: 65.35947712418301,
        ),
      ),
    );

    expect(find.textContaining('1.000'), findsWidgets);
    expect(find.text('Total a pagar'), findsOneWidget);
    expect(find.textContaining('PIX'), findsWidgets);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('token'), findsNothing);
  });

  testWidgets('contador inicia visível', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PagamentoPixScreen(
          valorReais: 10,
          quantidadeTokens: 1,
        ),
      ),
    );

    expect(find.text('05:00'), findsOneWidget);
  });
}
