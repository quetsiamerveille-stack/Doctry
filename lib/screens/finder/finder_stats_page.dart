import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/declaration.dart';
import '../../models/stats.dart';
import '../../providers/workspace_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/doctry_shell.dart';
import '../../widgets/doctry_table.dart';

class FinderStatsPage extends StatelessWidget {
  const FinderStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final WorkspaceProvider workspace = context.watch<WorkspaceProvider>();
    final FinderStats stats = workspace.finderStats;
    final List<FindDeclaration> finds = workspace.finds;
    final List<MatchResult> matches = workspace.matches;

    return PageScaffold(
      title: 'Statistiques',
      onRefresh: workspace.loadFinderWorkspace,
      children: <Widget>[
        SectionCard(
          title: 'Synthèse de votre activité',
          icon: Icons.insights_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DoctryTable(
                rowCount: 1,
                columns: <DoctryColumn>[
                  DoctryColumn(
                    label: 'Retrouvailles faites',
                    compactLabel: 'Retrouvailles',
                    cell: (BuildContext context, int index) =>
                        _BigValue(value: '${stats.findsDone}', color: AppColors.siam),
                  ),
                  DoctryColumn(
                    label: 'Déclarations de pertes avec récompenses associées',
                    compactLabel: 'Pertes récompensées',
                    flex: 2,
                    cell: (BuildContext context, int index) =>
                        _BigValue(value: '${stats.rewardedLosses}', color: AppColors.gold),
                  ),
                  DoctryColumn(
                    label: 'Déclarations en cours',
                    compactLabel: 'En cours',
                    cell: (BuildContext context, int index) =>
                        _BigValue(value: '${stats.ongoing}', color: AppColors.grey),
                  ),
                  DoctryColumn(
                    label: 'Documents restitués',
                    compactLabel: 'Restitués',
                    cell: (BuildContext context, int index) =>
                        _BigValue(value: '${stats.returnedDocuments}', color: AppColors.green),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _FinanceChip(
                      icon: Icons.savings_outlined,
                      label: 'Récompenses perçues',
                      value: Fmt.money(stats.earningsTotal),
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FinanceChip(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Solde du compte',
                      value: Fmt.money(stats.walletBalance),
                      color: AppColors.siam,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Détail des retrouvailles',
          icon: Icons.find_in_page_outlined,
          child: DoctryTable(
            rowCount: finds.length,
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
                label: 'Propriétaire',
                flex: 2,
                cell: (BuildContext context, int index) =>
                    Text(finds[index].holderName.isEmpty ? '—' : finds[index].holderName),
              ),
              DoctryColumn(
                label: 'Date',
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
        const SizedBox(height: 16),
        SectionCard(
          title: 'Récompenses associées',
          icon: Icons.card_giftcard_outlined,
          child: DoctryTable(
            rowCount: matches.length,
            emptyMessage: 'Aucune récompense associée à vos retrouvailles.',
            columns: <DoctryColumn>[
              DoctryColumn(
                label: 'Document',
                flex: 2,
                cell: (BuildContext context, int index) =>
                    Text(Fmt.docType(matches[index].docType)),
              ),
              DoctryColumn(
                label: 'Propriétaire',
                flex: 2,
                cell: (BuildContext context, int index) => Text(
                  matches[index].counterpartName.isEmpty
                      ? '—'
                      : matches[index].counterpartName,
                ),
              ),
              DoctryColumn(
                label: 'Récompense',
                cell: (BuildContext context, int index) => Text(
                  matches[index].rewardAmount > 0
                      ? Fmt.money(matches[index].rewardAmount)
                      : '—',
                ),
              ),
              DoctryColumn(
                label: 'Statut',
                flex: 2,
                cell: (BuildContext context, int index) {
                  final MatchResult match = matches[index];
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(
                      label: Fmt.rewardStatus(match.rewardStatus),
                      color: match.rewardStatus == 'released'
                          ? AppColors.green
                          : match.rewardStatus == 'escrow'
                              ? AppColors.gold
                              : AppColors.grey,
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

class _BigValue extends StatelessWidget {
  const _BigValue({required this.value, required this.color});

  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
    );
  }
}

class _FinanceChip extends StatelessWidget {
  const _FinanceChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
