import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../widgets/brand.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const String _seenKey = 'doctry_onboarding_seen';

  final PageController _controller = PageController();
  int _page = 0;

  static const int _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
    if (!mounted) {
      return;
    }
    widget.onDone?.call();
  }

  void _next() {
    if (_page >= _pageCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLast = _page == _pageCount - 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text(
                      'Passer',
                      style: TextStyle(color: AppColors.white, fontSize: 13.5),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (int index) => setState(() => _page = index),
                  children: const <Widget>[
                    _OnboardingPage(
                      icon: Icons.qr_code_2,
                      title: 'Protégez vos documents',
                      description:
                          'Pré-enregistrez vos pièces d\'identité par QR Code '
                          'ou photo. En cas de perte, DOCTRY les identifie '
                          'instantanément.',
                    ),
                    _OnboardingPage(
                      icon: Icons.psychology_outlined,
                      title: 'Matching IA automatique',
                      description:
                          'Notre moteur IA compare chaque déclaration de perte '
                          'et de retrouvaille, floute les zones sensibles et '
                          'met les parties en relation.',
                    ),
                    _OnboardingPage(
                      icon: Icons.payments_outlined,
                      title: 'Récompenses sécurisées',
                      description:
                          'La récompense est bloquée sur un compte séquestre '
                          'Orange Money ou MTN, puis libérée vers le trouveur '
                          'après restitution confirmée.',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        for (int index = 0; index < _pageCount; index++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: index == _page ? 26 : 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: index == _page
                                  ? AppColors.gold
                                  : AppColors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.darkBlue,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _next,
                        icon: Icon(isLast ? Icons.rocket_launch_outlined : Icons.arrow_forward),
                        label: Text(
                          isLast ? 'Commencer' : 'Suivant',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const DoctryLogo(size: 34, dark: true),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.7), width: 1.6),
            ),
            child: Icon(icon, size: 78, color: AppColors.gold),
          ),
          const SizedBox(height: 34),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.88),
              fontSize: 14.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
