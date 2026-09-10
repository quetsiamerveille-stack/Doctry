import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/stats.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/doctry_shell.dart';
import '../../widgets/doctry_table.dart';

class AdminFinancePage extends StatefulWidget {
  const AdminFinancePage({super.key});

  @override
  State<AdminFinancePage> createState() => _AdminFinancePageState();
}

class _AdminFinancePageState extends State<AdminFinancePage> {
  DateTime? _selected;
  late final TextEditingController _dateField;

  @override
  void initState() {
    super.initState();
    _dateField = TextEditingController();
  }

  @override
  void dispose() {
    _dateField.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selected ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Sélectionner une date',
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selected = picked;
      _dateField.text = Fmt.longDate(picked);
    });
  }

  Future<void> _search() async {
    final AdminProvider admin = context.read<AdminProvider>();
    final DateTime date = _selected ?? DateTime.now();
    final String iso = '${date.year}-${Fmt.two(date.month)}-${Fmt.two(date.day)}';
    await admin.searchFinance(iso);
  }

  Future<void> _reset() async {
    final AdminProvider admin = context.read<AdminProvider>();
    setState(() {
      _selected = null;
      _dateField.clear();
    });
    await admin.loadFinance();
  }

  @override
  Widget build(BuildContext context) {
    final AdminProvider admin = context.watch<AdminProvider>();
    final FinanceReport finance = admin.finance;
    final List<FinanceRow> rows = finance.rows;

    return PageScaffold(
      title: 'Finance',
      onRefresh: admin.loadAll,
      children: <Widget>[
        SectionCard(
          title: 'Recherche par date',
          icon: Icons.event_available_outlined,
          subtitle: 'Affiche les revenus de la plateforme pour une date précise.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _dateField,
                      readOnly: true,
                      onTap: _pickDate,
                      decoration: InputDecoration(
                        hintText: 'Choisir une date',
                        prefixIcon: const Icon(Icons.calendar_month_outlined, color: AppColors.siam),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DoctryButton(
                    label: 'Rechercher',
                    icon: Icons.search,
                    loading: admin.busyOn == 'finance',
                    onPressed: _search,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: DoctryButton(
                  label: 'Vue globale',
                  icon: Icons.restart_alt,
                  variant: DoctryButtonVariant.outlined,
                  onPressed: _reset,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Revenus de la plateforme',
          icon: Icons.payments_outlined,
          subtitle: finance.date.isEmpty
              ? 'Commissions prélevées sur les récompenses libérées.'
              : 'Commissions au ${Fmt.date(finance.date)}.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DoctryTable(
                rowCount: 1,
                columns: <DoctryColumn>[
                  DoctryColumn(
                    label: 'Revenus Annuels',
                    compactLabel: 'Annuel',
                    cell: (BuildContext context, int index) =>
                        _BigValue(value: Fmt.money(finance.yearRevenue), color: AppColors.darkBlue),
                  ),
                  DoctryColumn(
                    label: 'Revenus Mensuels',
                    compactLabel: 'Mensuel',
                    cell: (BuildContext context, int index) =>
                        _BigValue(value: Fmt.money(finance.monthRevenue), color: AppColors.siam),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _FinanceChip(
                    icon: Icons.today_outlined,
                    label: finance.date.isEmpty ? 'Revenus du jour' : 'Revenus au ${Fmt.date(finance.date)}',
                    value: Fmt.money(finance.dayRevenue),
                    color: AppColors.gold,
                  ),
                  _FinanceChip(
                    icon: Icons.savings_outlined,
                    label: 'Revenus cumulés',
                    value: Fmt.money(finance.totalRevenue),
                    color: AppColors.green,
                  ),
                  _FinanceChip(
                    icon: Icons.lock_outline,
                    label: 'Fonds en séquestre',
                    value: Fmt.money(finance.escrowBalance),
                    color: AppColors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Détail des transactions',
          icon: Icons.receipt_long_outlined,
          subtitle: '${rows.length} opération(s) enregistrée(s).',
          child: DoctryTable(
            rowCount: rows.length,
            emptyMessage: 'Aucune transaction pour cette période.',
            columns: <DoctryColumn>[
              DoctryColumn(
                label: 'N°',
                cell: (BuildContext context, int index) => Text('${index + 1}'),
              ),
              DoctryColumn(
                label: 'Référence',
                flex: 2,
                cell: (BuildContext context, int index) => Text(rows[index].reference),
              ),
              DoctryColumn(
                label: 'Opérateur',
                cell: (BuildContext context, int index) => Text(_providerLabel(rows[index].provider)),
              ),
              DoctryColumn(
                label: 'Montant',
                cell: (BuildContext context, int index) => Text(Fmt.money(rows[index].amount)),
              ),
              DoctryColumn(
                label: 'Commission DOCTRY',
                compactLabel: 'Commission',
                cell: (BuildContext context, int index) => Text(
                  Fmt.money(rows[index].commission),
                  style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700),
                ),
              ),
              DoctryColumn(
                label: 'Date',
                cell: (BuildContext context, int index) => Text(Fmt.dateTime(rows[index].createdAt)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _providerLabel(String code) {
  final String value = code.toUpperCase();
  if (value.contains('ORANGE')) {
    return 'Orange Money';
  }
  if (value.contains('MTN')) {
    return 'MTN MoMo';
  }
  return code.isEmpty ? '—' : code;
}

class _BigValue extends StatelessWidget {
  const _BigValue({required this.value, required this.color});

  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
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
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
