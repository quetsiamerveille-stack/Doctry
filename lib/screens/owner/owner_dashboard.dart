import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/declaration.dart';
import '../../providers/workspace_provider.dart';
import '../../widgets/doctry_shell.dart';
import '../chat/chat_page.dart';
import 'owner_documents_page.dart';
import 'owner_home_page.dart';
import 'owner_stats_page.dart';

class OwnerDashboard extends StatelessWidget {
  const OwnerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DoctryShell(
      subtitle: 'Espace Propriétaire',
      onReady: () => context.read<WorkspaceProvider>().loadOwnerWorkspace(),
      items: <ShellNavItem>[
        const ShellNavItem(
          label: 'Accueil',
          icon: Icons.home_outlined,
          page: OwnerHomePage(),
        ),
        const ShellNavItem(
          label: 'Document',
          icon: Icons.description_outlined,
          page: OwnerDocumentsPage(),
        ),
        const ShellNavItem(
          label: 'Chat',
          icon: Icons.chat_outlined,
          page: ChatPage(newConversationLabel: 'Commencer une nouvelle conversation'),
        ),
        const ShellNavItem(
          label: 'Statistiques',
          icon: Icons.insights_outlined,
          page: OwnerStatsPage(),
        ),
      ],
    );
  }
}

LossDeclaration? lossForDocument(List<LossDeclaration> losses, String documentId) {
  if (documentId.isEmpty) {
    return null;
  }
  for (final LossDeclaration loss in losses) {
    if (loss.documentId == documentId && !loss.isReturned) {
      return loss;
    }
  }
  return null;
}

LossDeclaration? lossById(List<LossDeclaration> losses, String lossId) {
  for (final LossDeclaration loss in losses) {
    if (loss.id == lossId) {
      return loss;
    }
  }
  return null;
}
