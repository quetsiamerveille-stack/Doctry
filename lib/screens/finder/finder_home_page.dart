import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/declaration.dart';
import '../../models/stats.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workspace_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/doctry_shell.dart';
import '../../widgets/doctry_table.dart';
import '../../widgets/match_card.dart';
import '../chat/chat_thread_screen.dart';
import '../owner/reward_flow.dart';

class FinderHomePage extends StatelessWidget {
  const FinderHomePage({super.key});

  Future<void> _confirmReturn(BuildContext context, MatchResult match) async {
    final bool ok = await runReturnConfirmation(context, match);
    if (ok && context.mounted) {
      await context.read<WorkspaceProvider>().loadFinderWorkspace();
    }
  }

  @override
  Widget build(BuildContext context) {
    final WorkspaceProvider workspace = context.watch<WorkspaceProvider>();
    final AuthProvider auth = context.watch<AuthProvider>();
    final FinderStats stats = workspace.finderStats;
    final List<FindDeclaration> finds = workspace.finds;
    final List<MatchResult> matches = workspace.matches;

    return PageScaffold(
      title: 'Accueil',
      onRefresh: workspace.loadFinderWorkspace,
      children: <Widget>[
        _FinderBanner(
          name: auth.user?.fullName ?? 'Trouveur',
          earnings: stats.earningsTotal,
          balance: stats.walletBalance,
          rating: auth.user?.averageRating ?? 0,
          ratingCount: auth.user?.ratingCount ?? 0,
        ),
        const SizedBox(height: 16),
        _StatGrid(stats: stats),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Correspondances détectées par l\'IA',
          icon: Icons.psychology_outlined,
          subtitle: 'Propriétaires mis en relation automatiquement via le chat interne.',
          child: matches.isEmpty
              ? const EmptyState(
                  message: 'Aucune correspondance pour le moment. '
                      'Déclarez un document retrouvé pour relancer le moteur IA.',
                  icon: Icons.radar_outlined,
                )
              : Column(
                  children: <Widget>[
                    for (final MatchResult match in matches)
                      MatchCard(
                        match: match,
                        onContact: () => openMatchThread(context, match),
                        onConfirmReturn: () => _confirmReturn(context, match),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Dernières retrouvailles',
          icon: Icons.find_in_page_outlined,
          child: DoctryTable(
            rowCount: finds.length > 6 ? 6 : finds.length,
            emptyMessage: 'Aucune retrouvaille déclarée.',
            columns: <DoctryColumn>[
              DoctryColumn(
                label: 'N°',
                cell: (BuildContext context, int index) => Text('${finds[index].number}'),
              ),
              DoctryColumn(
                label: 'Type de document',
                compactLabel: 'Type',
                flex: 2,
                cell: (BuildContext context, int index) =>
                    Text(Fmt.docType(finds[index].docType)),
              ),
              DoctryColumn(
                label: 'Retrouvé le',
                compactLabel: 'Date',
                cell: (BuildContext context, int index) =>
                    Text(Fmt.date(finds[index].foundDate)),
              ),
              DoctryColumn(
                label: 'Statut',
                cell: (BuildContext context, int index) {
                  final FindDeclaration find = finds[index];
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(
                      label: Fmt.findStatus(find.status),
                      color: find.isReturned ? AppColors.green : AppColors.siam,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FinderBanner extends StatelessWidget {
  const _FinderBanner({
    required this.name,
    required this.earnings,
    required this.balance,
    required this.rating,
    required this.ratingCount,
  });

  final String name;
  final double earnings;
  final double balance;
  final double rating;
  final int ratingCount;

  @override
  Widget build(BuildContext context) {
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
            'Vue d\'ensemble des fonctionnalités de retrouveur.',
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _BannerStat(
                icon: Icons.savings_outlined,
                label: 'Récompenses perçues',
                value: Fmt.money(earnings),
              ),
              _BannerStat(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Solde du compte',
                value: Fmt.money(balance),
              ),
              _BannerStat(
                icon: Icons.star_rate_outlined,
                label: 'Note moyenne',
                value: ratingCount == 0
                    ? 'Nouveau membre'
                    : '${rating.toStringAsFixed(1)} / 5 ($ratingCount avis)',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  const _BannerStat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: AppColors.gold, fontSize: 10.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final FinderStats stats;

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
              label: 'Retrouvailles faites',
              value: '${stats.findsDone}',
              icon: Icons.find_in_page_outlined,
              color: AppColors.siam,
            ),
            StatTile(
              label: 'Pertes avec récompenses',
              value: '${stats.rewardedLosses}',
              icon: Icons.card_giftcard_outlined,
              color: AppColors.gold,
            ),
            StatTile(
              label: 'Déclarations en cours',
              value: '${stats.ongoing}',
              icon: Icons.pending_actions_outlined,
              color: AppColors.grey,
            ),
            StatTile(
              label: 'Documents restitués',
              value: '${stats.returnedDocuments}',
              icon: Icons.assignment_turned_in_outlined,
              color: AppColors.green,
            ),
          ],
        );
      },
    );
  }
}
