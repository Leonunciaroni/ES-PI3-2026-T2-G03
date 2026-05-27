// Autor principal: Mariana Silva Ferrarez
// RA: 25002010

import 'package:flutter/material.dart';

import '../../dashboard/screens/dashboard_screen.dart';
import '../widgets/tutorial_page_widget.dart';

class AppTutorialScreen extends StatefulWidget {
  const AppTutorialScreen({super.key});

  @override
  State<AppTutorialScreen> createState() => _AppTutorialScreenState();
}

class _AppTutorialScreenState extends State<AppTutorialScreen> {
  final PageController _pageController = PageController();

  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': Icons.rocket_launch_outlined,
      'title': 'Bem-vindo ao Mescla Invest',
      'description':
          'Conheça uma nova forma de explorar oportunidades de investimento em startups.',
    },
    {
      'icon': Icons.storefront_outlined,
      'title': 'Explore oportunidades',
      'description':
          'No balcão, você encontra startups disponíveis e pode conhecer melhor cada projeto.',
    },
    {
      'icon': Icons.account_balance_wallet_outlined,
      'title': 'Acompanhe sua carteira',
      'description':
          'Visualize seus investimentos, movimentações e informações importantes em um só lugar.',
    },
    {
      'icon': Icons.verified_user_outlined,
      'title': 'Segurança em primeiro lugar',
      'description':
          'Sua conta conta com verificação de dados e recursos de proteção como MFA.',
    },
  ];

  void _goToDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const DashboardScreen(),
      ),
      (route) => false,
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _goToDashboard();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLastPage = _currentPage == _pages.length - 1;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () {
                  _goToDashboard();
                },
                child: const Text('Pular'),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];

                  return TutorialPageWidget(
                    icon: page['icon'],
                    title: page['title'],
                    description: page['description'],
                  );
                },
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _nextPage,
                  child: Text(
                    isLastPage ? 'Começar' : 'Próximo',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}