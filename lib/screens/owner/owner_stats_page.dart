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

class OwnerStatsPage extends StatelessWidget {
  const OwnerStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final WorkspaceProvider workspace = context.watch<WorkspaceProvider>();
    final OwnerStats stats = workspace.ownerStats;
    final List<LossDeclaration> losses = workspace.losses;

    return PageScaffold(
      title: 'Statistiques',
      onRefresh: workspace.loadOwnerStats,
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
                    label: 'Déclarations de perte',
                    compactLabel: 'Pertes',
                    cell: (BuildContext context, int index) =>
                        _BigValue(value: '${stats.lossDeclarations}', color: AppColors.red),
                  ),
                  DoctryColumn(
                    label: 'Déclarations de retrouvaille',
                    compactLabel: 'Retrouvailles',
                    cell: (BuildContext context, int index) =>
                        _BigValue(value: '${stats.findDeclarations}', color: AppColors.siam),
                  ),
                  DoctryColumn(
                    label: 'Documents restitués',
                    compactLabel: 'Restitués',
                    cell: (BuildContext context, int index) =>
                        _BigValue(value: '${stats.returnedDocuments}', color: AppColors.green),
                  ),
                  DoctryColumn(
                    label: 'Documents en attente',
                    compactLabel: 'En attente',
                    cell: (BuildContext context, int index) =>
                        _BigValue(value: '${stats.pendingDocuments}', color: AppColors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _FinanceChip(
                    icon: Icons.lock_outline,
                    label: 'Fonds en séquestre',
                    value: Fmt.money(stats.escrowTotal),
                    color: AppColors.gold,
                  ),
                  _FinanceChip(
                    icon: Icons.lock_open_outlined,
                    label: 'Récompenses libérées',
                    value: Fmt.money(stats.releasedTotal),
                    color: AppColors.green,
                  ),
                  _FinanceChip(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Solde du compte',
                    value: Fmt.money(stats.walletBalance),
                    color: AppColors.siam,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Détail des déclarations de perte',
          icon: Icons.list_alt_outlined,
          child: DoctryTable(
            rowCount: losses.length,
            emptyMessage: 'Aucune déclaration de perte.',
            columns: <DoctryColumn>[
              DoctryColumn(
                label: 'N°',
                cell: (BuildContext context, int index) => Text('${losses[index].number}'),
              ),
              DoctryColumn(
                label: 'Type de document',
                compactLabel: 'Type',
                flex: 2,
                cell: (BuildContext context, int index) =>
                    Text(Fmt.docType(losses[index].docType)),
              ),
              DoctryColumn(
                label: 'Date de perte',
                compactLabel: 'Date',
                cell: (BuildContext context, int index) =>
                    Text(Fmt.date(losses[index].lossDate)),
              ),
              DoctryColumn(
                label: 'Statut',
                cell: (BuildContext context, int index) {
                  final LossDeclaration loss = losses[index];
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(
                      label: Fmt.lossStatus(loss.status),
                      color: loss.isReturned
                          ? AppColors.green
                          : loss.isActive
                              ? AppColors.siam
                              : AppColors.grey,
                    ),
                  );
                },
              ),
              DoctryColumn(
                label: 'Récompense',
                flex: 2,
                cell: (BuildContext context, int index) => Text(
                  losses[index].rewardAmount > 0
                      ? Fmt.money(losses[index].rewardAmount)
                      : '—',
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
