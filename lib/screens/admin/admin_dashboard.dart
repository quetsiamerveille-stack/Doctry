import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';
import '../../providers/workspace_provider.dart';
import '../../widgets/doctry_shell.dart';
import 'admin_finance_page.dart';
import 'admin_home_page.dart';
import 'admin_stats_page.dart';
import 'admin_users_page.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final AdminProvider admin = context.read<AdminProvider>();
    final WorkspaceProvider workspace = context.read<WorkspaceProvider>();

    return DoctryShell(
      subtitle: 'Administration DOCTRY',
      onReady: () async {
        await admin.loadAll();
        await workspace.loadNotifications();
      },
      items: <ShellNavItem>[
        const ShellNavItem(
          label: 'Accueil',
          icon: Icons.home_outlined,
          page: AdminHomePage(),
        ),
        const ShellNavItem(
          label: 'Utilisateurs',
          icon: Icons.manage_accounts_outlined,
          page: AdminUsersPage(),
        ),
        const ShellNavItem(
          label: 'Finance',
          icon: Icons.payments_outlined,
          page: AdminFinancePage(),
        ),
        const ShellNavItem(
          label: 'Statistiques',
          icon: Icons.insights_outlined,
          page: AdminStatsPage(),
        ),
      ],
    );
  }
}
