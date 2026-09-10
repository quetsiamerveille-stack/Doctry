import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/json_helpers.dart';
import '../../models/stats.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/doctry_shell.dart';
import '../../widgets/doctry_table.dart';

class AdminStatsPage extends StatelessWidget {
  const AdminStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AdminProvider admin = context.watch<AdminProvider>();
    final AdminStats stats = admin.stats;
    final List<Map<String, dynamic>> losses = stats.losses;
    final List<Map<String, dynamic>> finds = stats.finds;
    final List<Map<String, dynamic>> returns = stats.returns;
    final List<Map<String, dynamic>> pending = stats.pendingMatching;

    return PageScaffold(
      title: 'Statistiques',
      onRefresh: admin.loadStats,
      children: <Widget>[
        SectionCard(
          title: 'Synthèse globale DOCTRY',
          icon: Icons.insights_outlined,
          subtitle: 'Vue consolidée de toutes les déclarations de la plateforme.',
          child: DoctryTable(
            rowCount: 1,
            columns: <DoctryColumn>[
              DoctryColumn(
                label: 'Pertes',
                cell: (BuildContext context, int index) =>
                    _BigValue(value: '${losses.length}', color: AppColors.red),
              ),
              DoctryColumn(
                label: 'Retrouvailles',
                cell: (BuildContext context, int index) =>
                    _BigValue(value: '${finds.length}', color: AppColors.siam),
              ),
              DoctryColumn(
                label: 'Restitutions',
                cell: (BuildContext context, int index) =>
                    _BigValue(value: '${returns.length}', color: AppColors.green),
              ),
              DoctryColumn(
                label: 'En attente de matching',
                compactLabel: 'En attente',
                cell: (BuildContext context, int index) =>
                    _BigValue(value: '${pending.length}', color: AppColors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Pertes',
          icon: Icons.report_gmailerrorred_outlined,
          subtitle: 'Nom du propriétaire et date de la déclaration.',
          child: DoctryTable(
            rowCount: losses.length,
            emptyMessage: 'Aucune déclaration de perte enregistrée.',
            columns: <DoctryColumn>[
              DoctryColumn(
                label: 'N°',
                cell: (BuildContext context, int index) => Text('${asInt(losses[index]['number'])}'),
              ),
              DoctryColumn(
                label: 'Nom',
                flex: 2,
                cell: (BuildContext context, int index) => Text(
                  asString(losses[index]['name'], '—'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              DoctryColumn(
                label: 'Document',
                flex: 2,
                cell: (BuildContext context, int index) =>
                    Text(Fmt.docType(asString(losses[index]['doc_type']))),
              ),
              DoctryColumn(
                label: 'Date',
                cell: (BuildContext context, int index) =>
                    Text(Fmt.date(asString(losses[index]['date']))),
              ),
              DoctryColumn(
                label: 'Statut',
                cell: (BuildContext context, int index) =>
                    _lossBadge(asString(losses[index]['status'])),
              ),
              DoctryColumn(
                label: 'Récompense',
                cell: (BuildContext context, int index) => Text(
                  asDouble(losses[index]['reward_amount']) > 0
                      ? Fmt.money(asDouble(losses[index]['reward_amount']))
                      : '—',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Retrouvailles',
          icon: Icons.find_in_page_outlined,
          subtitle: 'Nom du trouveur et date de la déclaration.',
          child: DoctryTable(
            rowCount: finds.length,
            emptyMessage: 'Aucune déclaration de retrouvaille enregistrée.',
            columns: <DoctryColumn>[
              DoctryColumn(
                label: 'N°',
                cell: (BuildContext context, int index) => Text('${asInt(finds[index]['number'])}'),
              ),
              DoctryColumn(
                label: 'Nom',
                flex: 2,
                cell: (BuildContext context, int index) => Text(
                  asString(finds[index]['name'], '—'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              DoctryColumn(
                label: 'Document',
                flex: 2,
                cell: (BuildContext context, int index) =>
                    Text(Fmt.docType(asString(finds[index]['doc_type']))),
              ),
              DoctryColumn(
                label: 'Date',
                cell: (BuildContext context, int index) =>
                    Text(Fmt.date(asString(finds[index]['date']))),
              ),
              DoctryColumn(
                label: 'Source',
                cell: (BuildContext context, int index) =>
                    Text(_sourceLabel(asString(finds[index]['source']))),
              ),
              DoctryColumn(
                label: 'Statut',
                cell: (BuildContext context, int index) => Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(
                    label: Fmt.findStatus(asString(finds[index]['status'])),
                    color: asString(finds[index]['status']) == 'returned'
                        ? AppColors.green
                        : AppColors.siam,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Restitutions',
          icon: Icons.assignment_turned_in_outlined,
          subtitle: 'Date, lieu et acteurs de chaque restitution confirmée.',
          child: DoctryTable(
            rowCount: returns.length,
            emptyMessage: 'Aucune restitution confirmée.',
            columns: <DoctryColumn>[
              DoctryColumn(
                label: 'N°',
                cell: (BuildContext context, int index) => Text('${asInt(returns[index]['number'])}'),
              ),
              DoctryColumn(
                label: 'Date',
                cell: (BuildContext context, int index) =>
                    Text(Fmt.date(asString(returns[index]['date']))),
              ),
              DoctryColumn(
                label: 'Lieu',
                flex: 2,
                cell: (BuildContext context, int index) =>
                    Text(asString(returns[index]['location'], '—')),
              ),
              DoctryColumn(
                label: 'Propriétaire',
                flex: 2,
                cell: (BuildContext context, int index) =>
                    Text(asString(returns[index]['owner'], '—')),
              ),
              DoctryColumn(
                label: 'Trouveur',
                flex: 2,
                cell: (BuildContext context, int index) =>
                    Text(asString(returns[index]['finder'], '—')),
              ),
              DoctryColumn(
                label: 'Récompense',
                cell: (BuildContext context, int index) {
                  final double amount = asDouble(returns[index]['reward_amount']);
                  final String status = asString(returns[index]['reward_status']);
                  return Text(amount > 0 ? '${Fmt.money(amount)} · ${Fmt.rewardStatus(status)}' : '—');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'En attente de matching',
          icon: Icons.psychology_outlined,
          subtitle: 'Déclarations sans correspondance : le moteur IA sera relancé automatiquement.',
          child: DoctryTable(
            rowCount: pending.length,
            emptyMessage: 'Aucune déclaration en attente de matching.',
            columns: <DoctryColumn>[
              DoctryColumn(
                label: 'N°',
                cell: (BuildContext context, int index) => Text('${asInt(pending[index]['number'])}'),
              ),
              DoctryColumn(
                label: 'Nom',
                flex: 2,
                cell: (BuildContext context, int index) =>
                    Text(asString(pending[index]['name'], '—')),
              ),
              DoctryColumn(
                label: 'Document',
                flex: 2,
                cell: (BuildContext context, int index) =>
                    Text(Fmt.docType(asString(pending[index]['doc_type']))),
              ),
              DoctryColumn(
                label: 'Date',
                cell: (BuildContext context, int index) =>
                    Text(Fmt.date(asString(pending[index]['date']))),
              ),
              DoctryColumn(
                label: 'Statut',
                cell: (BuildContext context, int index) =>
                    _lossBadge(asString(pending[index]['status'])),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _lossBadge(String status) {
  final Color color = switch (status) {
    'returned' => AppColors.green,
    'matched' => AppColors.siam,
    'declared' => AppColors.darkBlue,
    _ => AppColors.grey,
  };
  return Align(
    alignment: Alignment.centerLeft,
    child: StatusBadge(label: Fmt.lossStatus(status), color: color),
  );
}

String _sourceLabel(String source) {
  switch (source) {
    case 'qr':
      return 'QR Code';
    case 'photo':
      return 'Photo';
    case 'gallery':
      return 'Galerie';
    case 'camera':
      return 'Caméra';
    case 'manual':
      return 'Manuelle';
    default:
      return source.isEmpty ? '—' : source;
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
