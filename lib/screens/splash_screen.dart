import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../widgets/brand.dart';

/// Splash DOCTRY : logo anime (pulse + fondu), tagline et progression.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.message});

  final String? message;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.96, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ScaleTransition(
                  scale: _pulse,
                  child: const DoctryLogo(size: 132, dark: true),
                ),
                const SizedBox(height: 26),
                Text(
                  'Gestion intelligente des documents d\'identité',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.86),
                    fontSize: 14,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 44),
                SizedBox(
                  width: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: AppColors.white.withValues(alpha: 0.18),
                      color: AppColors.gold,
                    ),
                  ),
                ),
                if (widget.message != null && widget.message!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 34),
                    child: Text(
                      widget.message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.gold.withValues(alpha: 0.95),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
