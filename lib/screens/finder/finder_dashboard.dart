import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/workspace_provider.dart';
import '../../widgets/doctry_shell.dart';
import '../chat/chat_page.dart';
import 'finder_declaration_page.dart';
import 'finder_home_page.dart';
import 'finder_stats_page.dart';

class FinderDashboard extends StatelessWidget {
  const FinderDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DoctryShell(
      subtitle: 'Espace Trouveur',
      onReady: () => context.read<WorkspaceProvider>().loadFinderWorkspace(),
      items: <ShellNavItem>[
        const ShellNavItem(
          label: 'Accueil',
          icon: Icons.home_outlined,
          page: FinderHomePage(),
        ),
        const ShellNavItem(
          label: 'Chat',
          icon: Icons.chat_outlined,
          page: ChatPage(newConversationLabel: 'Conversation'),
        ),
        const ShellNavItem(
          label: 'Déclaration',
          icon: Icons.qr_code_scanner_outlined,
          page: FinderDeclarationPage(),
        ),
        const ShellNavItem(
          label: 'Statistiques',
          icon: Icons.insights_outlined,
          page: FinderStatsPage(),
        ),
      ],
    );
  }
}
