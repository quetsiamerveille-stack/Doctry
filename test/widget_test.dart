import 'package:doctry/core/theme/app_colors.dart';
import 'package:doctry/core/utils/formatters.dart';
import 'package:doctry/models/declaration.dart';
import 'package:doctry/models/document.dart';
import 'package:doctry/models/stats.dart';
import 'package:doctry/models/user.dart';
import 'package:doctry/screens/admin/admin_finance_page.dart';
import 'package:doctry/screens/admin/admin_home_page.dart';
import 'package:doctry/screens/admin/admin_stats_page.dart';
import 'package:doctry/screens/admin/admin_users_page.dart';
import 'package:doctry/screens/chat/chat_page.dart';
import 'package:doctry/screens/finder/finder_declaration_page.dart';
import 'package:doctry/screens/finder/finder_home_page.dart';
import 'package:doctry/screens/finder/finder_stats_page.dart';
import 'package:doctry/screens/install_admin_screen.dart';
import 'package:doctry/screens/login_screen.dart';
import 'package:doctry/screens/otp_screen.dart';
import 'package:doctry/screens/owner/owner_documents_page.dart';
import 'package:doctry/screens/owner/owner_home_page.dart';
import 'package:doctry/screens/owner/owner_stats_page.dart';
import 'package:doctry/screens/signup_screen.dart';
import 'package:doctry/screens/splash_screen.dart';
import 'package:doctry/widgets/brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:doctry/core/config/api_config.dart';
import 'package:doctry/providers/admin_provider.dart';
import 'package:doctry/providers/auth_provider.dart';
import 'package:doctry/providers/workspace_provider.dart';

Widget _wrap(Widget child) => MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<WorkspaceProvider>(create: (_) => WorkspaceProvider()),
        ChangeNotifierProvider<AdminProvider>(create: (_) => AdminProvider()),
      ],
      child: MaterialApp(theme: ThemeData(useMaterial3: true), home: child),
    );

const List<Widget> _authScreens = <Widget>[
  SplashScreen(),
  LoginScreen(),
  SignupScreen(),
  OtpScreen(),
  InstallAdminScreen(),
];

const List<Widget> _dashboardPages = <Widget>[
  OwnerHomePage(),
  OwnerDocumentsPage(),
  OwnerStatsPage(),
  ChatPage(newConversationLabel: 'Commencer une nouvelle conversation'),
  FinderHomePage(),
  FinderDeclarationPage(),
  FinderStatsPage(),
  AdminHomePage(),
  AdminUsersPage(),
  AdminFinancePage(),
  AdminStatsPage(),
];

Future<void> _assertNoOverflow(WidgetTester tester, List<Widget> screens) async {
  for (final Widget screen in screens) {
    await tester.pumpWidget(_wrap(screen));
    expect(tester.takeException(), isNull, reason: screen.runtimeType.toString());
  }
}

void main() {
  group('Charte graphique DOCTRY', () {
    test('respecte la palette imposée', () {
      expect(AppColors.darkBlue, const Color(0xFF1A2B4C));
      expect(AppColors.siam, const Color(0xFF00A8B5));
      expect(AppColors.gold, const Color(0xFFFFD700));
      expect(AppColors.grey, const Color(0xFF808080));
      expect(AppColors.red, const Color(0xFFE53935));
      expect(AppColors.green, const Color(0xFF4CAF50));
    });
  });

  group('Formatters', () {
    test('montants en XAF', () {
      expect(Fmt.money(1500), '1\u202F500 XAF');
    });

    test('libellés de profil', () {
      expect(Fmt.profileLabel('owner'), 'Propriétaire');
      expect(Fmt.profileLabel('finder'), 'Trouveur');
      expect(Fmt.profileLabel('admin'), 'Administrateur');
    });

    test('statuts de récompense', () {
      expect(Fmt.rewardStatus('none'), 'Aucune récompense');
      expect(Fmt.rewardStatus('escrow'), 'Séquestrée');
      expect(Fmt.rewardStatus('released'), 'Libérée');
    });
  });

  group('Modèles de données', () {
    test('AdminOverview tolère un JSON vide', () {
      final AdminOverview overview = AdminOverview.fromJson(<String, dynamic>{});
      expect(overview.users, 0);
      expect(overview.escrowBalance, 0);
    });

    test('FinanceReport expose les revenus annuels et mensuels', () {
      final FinanceReport report = FinanceReport.fromJson(<String, dynamic>{
        'date': '2026-09-06',
        'year_revenue': 12000,
        'month_revenue': 3000,
        'rows': <Map<String, dynamic>>[
          <String, dynamic>{'reference': 'PAY-1', 'amount': 1500, 'commission': 75},
        ],
      });
      expect(report.yearRevenue, 12000);
      expect(report.monthRevenue, 3000);
      expect(report.rows.single.commission, 75);
    });

    test('AdminUser calcule le nom complet', () {
      final AdminUser user = AdminUser.fromJson(<String, dynamic>{
        'id': 'u1',
        'full_name': 'Ada Lovelace',
        'email': 'ada@doctry.app',
        'role': 'owner',
        'is_blocked': false,
      });
      expect(user.fullName, 'Ada Lovelace');
      expect(user.isBlocked, isFalse);
    });

    test('DocRecord détecte un QR Code', () {
      final DocRecord document = DocRecord.fromJson(<String, dynamic>{
        'id': 'd1',
        'doc_type': 'CNI',
        'qr_id': 'QR-1',
        'qr_url': '/api/qr/QR-1.png',
      });
      expect(document.hasQr, isTrue);
      expect(Fmt.docType(document.docType), "Carte nationale d'identité");
    });

    test('LossDeclaration suit le cycle de récompense', () {
      final LossDeclaration loss = LossDeclaration.fromJson(<String, dynamic>{
        'id': 'l1',
        'number': 7,
        'doc_type': 'PASSEPORT',
        'status': 'returned',
        'reward_amount': 5000,
        'reward_status': 'released',
        'matched_find_id': 'f1',
      });
      expect(loss.isReturned, isTrue);
      expect(loss.canReleaseReward, isFalse);
    });
  });

  group('Écrans', () {
    testWidgets('le splash affiche la marque DOCTRY', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const SplashScreen()));
      expect(find.byType(DoctryLogo), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('la page de connexion propose les deux profils', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      expect(find.text('Ravi de vous revoir'), findsOneWidget);
      expect(find.text('Se connecter'), findsWidgets);
      expect(find.text('Se connecter en tant qu\'admin'), findsOneWidget);
    });

    testWidgets('les écrans d\'authentification tiennent sur un mobile étroit',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(380, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _assertNoOverflow(tester, _authScreens);
    });

    testWidgets('les écrans d\'authentification tiennent sur un écran large',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _assertNoOverflow(tester, _authScreens);
    });
  });

  group('Tableaux de bord', () {
    testWidgets('toutes les pages tiennent sur un mobile étroit', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _assertNoOverflow(tester, _dashboardPages);
    });

    testWidgets('toutes les pages tiennent sur une tablette', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(820, 1180);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _assertNoOverflow(tester, _dashboardPages);
    });

    testWidgets('toutes les pages tiennent sur un écran web large', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _assertNoOverflow(tester, _dashboardPages);
    });
  });

  group('Configuration Réseau & Résilience', () {
    test('ApiConfig génère des candidats de repli pour les ports 8000 et 8001', () {
      final List<String> candidates = ApiConfig.getCandidateUrls();
      expect(candidates, isNotEmpty);
      expect(candidates.any((String url) => url.contains('8000') || url.contains('8001')), isTrue);
    });
  });
}
