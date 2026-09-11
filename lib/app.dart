import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/finder/finder_dashboard.dart';
import 'screens/install_admin_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/owner/owner_dashboard.dart';
import 'screens/splash_screen.dart';

class DoctryApp extends StatelessWidget {
  const DoctryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DOCTRY',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const RootGate(),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  static const String _onboardingKey = 'doctry_onboarding_seen';
  bool _onboardingRequired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await context.read<AuthProvider>().bootstrap();
    if (!mounted) {
      return;
    }
    // Onboarding affiche une seule fois, uniquement pour les nouveaux
    // visiteurs non authentifies (jamais apres login/OTP).
    final AuthProvider auth = context.read<AuthProvider>();
    if (auth.status == AuthStatus.unauthenticated) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _onboardingRequired = !(prefs.getBool(_onboardingKey) ?? false);
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _onboardingDone() {
    setState(() => _onboardingRequired = false);
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const SplashScreen();
      case AuthStatus.installRequired:
        return const InstallAdminScreen();
      case AuthStatus.unauthenticated:
        return _onboardingRequired
            ? OnboardingScreen(onDone: _onboardingDone)
            : const LoginScreen();
      case AuthStatus.otpPending:
        return const OtpScreen();
      case AuthStatus.authenticated:
        if (auth.isAdminProfile) {
          return const AdminDashboard();
        }
        if (auth.isFinderProfile) {
          return const FinderDashboard();
        }
        return const OwnerDashboard();
    }
  }
}
