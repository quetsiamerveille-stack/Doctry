import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/declaration.dart';
import '../../models/document.dart';
import '../../models/stats.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workspace_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/doctry_shell.dart';
import '../../widgets/doctry_table.dart';
import '../../widgets/match_card.dart';
import '../../widgets/qr_preview.dart';
import '../chat/chat_thread_screen.dart';
import 'owner_dashboard.dart';
import 'reward_flow.dart';

class OwnerHomePage extends StatelessWidget {
  const OwnerHomePage({super.key});

  Future<void> _reward(BuildContext context, MatchResult match) async {
    final LossDeclaration? loss =
        lossById(context.read<WorkspaceProvider>().losses, match.lossId);
    if (loss == null) {
      return;
    }
    final bool ok = await runRewardFlow(context, loss);
    if (ok && context.mounted) {
      await context.read<WorkspaceProvider>().loadMatches();
    }
  }

  Future<void> _release(BuildContext context, MatchResult match) async {
    final LossDeclaration? loss =
        lossById(context.read<WorkspaceProvider>().losses, match.lossId);
    if (loss == null) {
      return;
    }
    final bool ok = await runReleaseRewardFlow(context, loss);
    if (ok && context.mounted) {
      await context.read<WorkspaceProvider>().loadMatches();
    }
  }

  Future<void> _confirmReturn(BuildContext context, MatchResult match) async {
    final bool ok = await runReturnConfirmation(context, match);
    if (ok && context.mounted) {
      await context.read<WorkspaceProvider>().loadOwnerWorkspace();
    }
  }

  @override
  Widget build(BuildContext context) {
    final WorkspaceProvider workspace = context.watch<WorkspaceProvider>();
    final AuthProvider auth = context.watch<AuthProvider>();
    final OwnerStats stats = workspace.ownerStats;
    final List<MatchResult> matches = workspace.matches;
    final List<DocRecord> documents = workspace.documents;

    return PageScaffold(
      title: 'Accueil',
      onRefresh: workspace.loadOwnerWorkspace,
      children: <Widget>[
        _WelcomeBanner(
          name: auth.user?.fullName ?? 'Propriétaire',
          balance: workspace.wallet.balance,
          escrowTotal: stats.escrowTotal,
          onTopUp: () => runTopUpFlow(context),
        ),
        const SizedBox(height: 16),
        _StatGrid(stats: stats),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Correspondances détectées par l\'IA',
          icon: Icons.psychology_outlined,
          subtitle: 'Alertes générées par le moteur de matching IA.',
          child: matches.isEmpty
              ? const EmptyState(
                  message: 'Aucune correspondance pour le moment. '
                      'Le moteur IA relance l\'analyse à chaque nouvelle déclaration.',
                  icon: Icons.radar_outlined,
                )
              : Column(
                  children: <Widget>[
                    for (final MatchResult match in matches)
                      MatchCard(
                        match: match,
                        onContact: () => openMatchThread(context, match),
                        onConfirmReturn: () => _confirmReturn(context, match),
                        onRelease: () => _release(context, match),
                        onReward: () => _reward(context, match),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Mes documents pré-enregistrés',
          icon: Icons.folder_shared_outlined,
          subtitle: '${documents.length} document(s) protégé(s) par QR Code DOCTRY.',
          child: documents.isEmpty
              ? const EmptyState(
                  message: 'Aucun document pré-enregistré. '
                      'Onglet Document pour générer un QR Code ou ajouter une photo.',
                  icon: Icons.qr_code_2,
                )
              : DoctryTable(
                  rowCount: documents.length > 5 ? 5 : documents.length,
                  emptyMessage: 'Aucun document.',
                  columns: <DoctryColumn>[
                    DoctryColumn(
                      label: 'Type de document',
                      compactLabel: 'Type',
                      flex: 2,
                      cell: (BuildContext context, int index) =>
                          Text(Fmt.docType(documents[index].docType)),
                    ),
                    DoctryColumn(
                      label: 'Titulaire',
                      flex: 2,
                      cell: (BuildContext context, int index) =>
                          Text(documents[index].holderName),
                    ),
                    DoctryColumn(
                      label: 'Pré-enregistré le',
                      compactLabel: 'Date',
                      cell: (BuildContext context, int index) =>
                          Text(Fmt.date(documents[index].createdAt)),
                    ),
                    DoctryColumn(
                      label: 'QR Code',
                      flex: 2,
                      cell: (BuildContext context, int index) => DoctryButton(
                        label: 'Afficher',
                        icon: Icons.qr_code_2,
                        variant: DoctryButtonVariant.outlined,
                        onPressed: () => _showQr(context, documents[index]),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _showQr(BuildContext context, DocRecord document) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(Fmt.docType(document.docType)),
        content: SingleChildScrollView(child: QrPreview(document: document)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({
    required this.name,
    required this.balance,
    required this.escrowTotal,
    required this.onTopUp,
  });

  final String name;
  final double balance;
  final double escrowTotal;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final bool hasEscrow = escrowTotal > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Bonjour $name',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Vue d\'ensemble de toutes les fonctionnalités disponibles.',
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          // Carte de solde : le montant occupe l'espace disponible,
          // le bouton passe sous le montant sur écran étroit.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.account_balance_wallet_outlined,
                        color: AppColors.gold, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Solde du compte DOCTRY',
                            style: TextStyle(color: AppColors.gold, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Fmt.money(balance),
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (hasEscrow) ...<Widget>[
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.lock_outline,
                          color: AppColors.white, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        '${Fmt.money(escrowTotal)} en séquestre',
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: DoctryButton(
                    label: 'Recharger le compte',
                    icon: Icons.add_card_outlined,
                    variant: DoctryButtonVariant.gold,
                    onPressed: onTopUp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final OwnerStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 900 ? 4 : 2;
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 182,
          ),
          children: <Widget>[
            StatTile(
              label: 'Déclarations de perte',
              value: '${stats.lossDeclarations}',
              icon: Icons.report_gmailerrorred_outlined,
              color: AppColors.red,
            ),
            StatTile(
              label: 'Déclarations de retrouvaille',
              value: '${stats.findDeclarations}',
              icon: Icons.find_in_page_outlined,
              color: AppColors.siam,
            ),
            StatTile(
              label: 'Documents restitués',
              value: '${stats.returnedDocuments}',
              icon: Icons.assignment_turned_in_outlined,
              color: AppColors.green,
            ),
            StatTile(
              label: 'Documents en attente',
              value: '${stats.pendingDocuments}',
              icon: Icons.hourglass_bottom_outlined,
              color: AppColors.grey,
            ),
          ],
        );
      },
    );
  }
}
