import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/stats.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/doctry_shell.dart';
import '../../widgets/doctry_table.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AdminProvider admin = context.watch<AdminProvider>();
    final AdminOverview overview = admin.overview;
    final List<SmsLogEntry> smsLogs = admin.smsLogs;

    return PageScaffold(
      title: 'Accueil',
      onRefresh: admin.loadAll,
      children: <Widget>[
        _AdminBanner(overview: overview),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Vue globale de l\'administration',
          icon: Icons.dashboard_customize_outlined,
          child: _OverviewGrid(overview: overview),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Services intégrés',
          icon: Icons.settings_suggest_outlined,
          subtitle: 'État des moteurs connectés au backend FastAPI.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _ServiceChip(
                icon: Icons.psychology_outlined,
                label: 'Moteur IA / Matching',
                value: overview.aiEngine,
                active: overview.aiEngine.toLowerCase().contains('nemotron')
                    || overview.aiEngine.toLowerCase().contains('deepseek')
                    || overview.aiEngine.toLowerCase().contains('openrouter'),
              ),
              _ServiceChip(
                icon: Icons.mark_email_read_outlined,
                label: 'Email OTP (Gmail)',
                value: overview.emailDelivery,
                active: overview.emailDelivery == 'sent',
              ),
              _ServiceChip(
                icon: Icons.sms_outlined,
                label: 'SMS Textsoft',
                value: overview.smsDelivery,
                active: overview.smsDelivery == 'sent',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Journal des SMS Textsoft',
          icon: Icons.sms_outlined,
          subtitle: 'Alertes envoyées au propriétaire et au trouveur lors d\'un matching.',
          child: DoctryTable(
            rowCount: smsLogs.length > 10 ? 10 : smsLogs.length,
            emptyMessage: 'Aucun SMS envoyé pour le moment.',
            columns: <DoctryColumn>[
              DoctryColumn(
                label: 'Numéro',
                cell: (BuildContext context, int index) => Text(smsLogs[index].phone),
              ),
              DoctryColumn(
                label: 'Message',
                flex: 4,
                cell: (BuildContext context, int index) => Text(
                  smsLogs[index].body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DoctryColumn(
                label: 'Statut',
                cell: (BuildContext context, int index) {
                  final SmsLogEntry entry = smsLogs[index];
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(
                      label: entry.status == 'sent' ? 'Envoyé' : 'Simulé',
                      color: entry.status == 'sent' ? AppColors.green : AppColors.grey,
                    ),
                  );
                },
              ),
              DoctryColumn(
                label: 'Date',
                cell: (BuildContext context, int index) =>
                    Text(Fmt.dateTime(smsLogs[index].createdAt)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminBanner extends StatelessWidget {
  const _AdminBanner({required this.overview});

  final AdminOverview overview;

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
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shield_outlined, color: AppColors.darkBlue, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Console d\'administration DOCTRY',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Supervision des utilisateurs, des finances et du matching IA.',
                      style: TextStyle(color: AppColors.gold, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _BannerStat(label: 'Fonds en séquestre', value: Fmt.money(overview.escrowBalance)),
              _BannerStat(label: 'Revenus annuels', value: Fmt.money(overview.yearRevenue)),
              _BannerStat(label: 'Revenus mensuels', value: Fmt.money(overview.monthRevenue)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  const _BannerStat({required this.label, required this.value});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.gold, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.overview});

  final AdminOverview overview;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 620
                ? 3
                : 2;
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
              label: 'Utilisateurs actifs',
              value: '${overview.users}',
              icon: Icons.group_outlined,
              color: AppColors.siam,
              caption: '${overview.blockedUsers} bloqué(s)',
            ),
            StatTile(
              label: 'Documents pré-enregistrés',
              value: '${overview.documents}',
              icon: Icons.description_outlined,
              color: AppColors.darkBlue,
            ),
            StatTile(
              label: 'Déclarations de perte',
              value: '${overview.losses}',
              icon: Icons.report_gmailerrorred_outlined,
              color: AppColors.red,
            ),
            StatTile(
              label: 'Déclarations de retrouvaille',
              value: '${overview.finds}',
              icon: Icons.find_in_page_outlined,
              color: AppColors.gold,
            ),
            StatTile(
              label: 'Correspondances IA',
              value: '${overview.matches}',
              icon: Icons.psychology_outlined,
              color: AppColors.siam,
            ),
            StatTile(
              label: 'Documents restitués',
              value: '${overview.returned}',
              icon: Icons.assignment_turned_in_outlined,
              color: AppColors.green,
            ),
          ],
        );
      },
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color color = active ? AppColors.green : AppColors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              Text(
                value.isEmpty ? '—' : value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
