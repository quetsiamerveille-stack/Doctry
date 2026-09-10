import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/chat.dart';
import '../../models/declaration.dart';
import '../../models/json_helpers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workspace_provider.dart';
import '../../widgets/dialogs.dart';
import 'payment_simulator.dart';

Future<bool> runRewardFlow(BuildContext context, LossDeclaration loss) async {
  final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
  await workspace.loadWallet();
  if (!context.mounted) {
    return false;
  }

  final _RewardForm? form = await showDialog<_RewardForm>(
    context: context,
    builder: (BuildContext dialogContext) => _RewardDialog(loss: loss),
  );
  if (form == null || !context.mounted) {
    return false;
  }

  if (workspace.wallet.balance < form.amount) {
    final bool topped = await runTopUpFlow(
      context,
      suggested: form.amount - workspace.wallet.balance,
    );
    if (!topped || !context.mounted) {
      return false;
    }
  }

  final Map<String, dynamic>? initiated = await workspace.initiateEscrow(
    lossId: loss.id,
    amount: form.amount,
    provider: form.provider,
    phone: form.phone,
  );
  if (initiated == null) {
    if (context.mounted) {
      showDoctrySnackBar(
        context,
        workspace.error ?? "Impossible d'initialiser le paiement.",
        isError: true,
      );
    }
    return false;
  }
  if (!context.mounted) {
    return false;
  }

  final PaymentTicket ticket = PaymentTicket.fromJson(initiated);
  final bool? paid = await Navigator.push<bool>(
    context,
    MaterialPageRoute<bool>(
      builder: (_) => PaymentSimulatorScreen(
        title: 'Séquestre de la récompense',
        ticket: ticket,
        onConfirm: (String pin) async {
          final bool ok = await workspace.confirmEscrow(reference: ticket.reference, pin: pin);
          return ok ? null : workspace.error;
        },
      ),
    ),
  );

  if (context.mounted) {
    showDoctrySnackBar(
      context,
      paid == true
          ? workspace.info ?? 'Récompense séquestrée sur le compte de la plateforme.'
          : 'Paiement annulé.',
      isError: paid != true,
    );
  }
  return paid == true;
}

Future<bool> runTopUpFlow(BuildContext context, {double suggested = 0}) async {
  final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
  await workspace.loadWallet();
  if (!context.mounted) {
    return false;
  }

  final _TopUpForm? form = await showDialog<_TopUpForm>(
    context: context,
    builder: (BuildContext dialogContext) => _TopUpDialog(suggested: suggested),
  );
  if (form == null || !context.mounted) {
    return false;
  }

  final PaymentProvider provider = workspace.wallet.providers.firstWhere(
    (PaymentProvider item) => item.code == form.provider,
    orElse: () => PaymentProvider(
      code: form.provider,
      label: form.provider,
      ussd: '',
    ),
  );

  final PaymentTicket ticket = PaymentTicket(
    reference: 'TOPUP-${DateTime.now().millisecondsSinceEpoch}',
    providerLabel: provider.label,
    ussd: provider.ussd,
    amount: form.amount,
    phone: form.phone,
    message: 'Saisissez le code PIN ${provider.label} pour recharger votre compte DOCTRY.',
  );

  final bool? paid = await Navigator.push<bool>(
    context,
    MaterialPageRoute<bool>(
      builder: (_) => PaymentSimulatorScreen(
        title: 'Recharge du compte',
        ticket: ticket,
        onConfirm: (String pin) async {
          final bool ok = await workspace.topUp(
            amount: form.amount,
            provider: form.provider,
            pin: pin,
            phone: form.phone,
          );
          return ok ? null : workspace.error;
        },
      ),
    ),
  );

  if (context.mounted) {
    showDoctrySnackBar(
      context,
      paid == true ? workspace.info ?? 'Compte rechargé.' : 'Recharge annulée.',
      isError: paid != true,
    );
    final AuthProvider auth = context.read<AuthProvider>();
    await auth.refreshMe();
  }
  return paid == true;
}

Future<bool> runReleaseRewardFlow(BuildContext context, LossDeclaration loss) async {
  final WorkspaceProvider workspace = context.read<WorkspaceProvider>();

  final bool confirmed = await showConfirmDialog(
    context,
    title: 'Envoyer la récompense',
    message: 'Un code OTP sera envoyé par email pour libérer '
        '${Fmt.money(loss.rewardAmount)} du compte séquestre de la plateforme '
        'vers le trouveur.',
    confirmLabel: 'Envoyer le code OTP',
    confirmColor: AppColors.green,
  );
  if (!confirmed || !context.mounted) {
    return false;
  }

  final Map<String, dynamic>? request = await workspace.requestRelease(loss.id);
  if (request == null) {
    if (context.mounted) {
      showDoctrySnackBar(
        context,
        workspace.error ?? "Impossible d'envoyer le code OTP.",
        isError: true,
      );
    }
    return false;
  }

  final String ticket = asString(request['ticket']);
  final String devCode = asString(request['dev_code']);
  if (!context.mounted) {
    return false;
  }

  final String? code = await showOtpDialog(
    context,
    OtpRequest(
      title: 'Libération de la récompense',
      message: asString(
        request['message'],
        'Saisissez le code OTP reçu par email pour libérer les fonds séquestrés.',
      ),
      devCode: devCode,
      email: asString(request['email']),
      confirmLabel: 'Libérer les fonds',
      onResend: () async {
        final Map<String, dynamic>? retry = await workspace.requestRelease(loss.id);
        return retry == null ? null : asString(retry['dev_code']);
      },
    ),
  );

  if (code == null || !context.mounted) {
    return false;
  }

  final bool ok =
      await workspace.confirmRelease(lossId: loss.id, ticket: ticket, code: code);
  if (context.mounted) {
    showDoctrySnackBar(
      context,
      ok ? workspace.info ?? 'Récompense libérée.' : workspace.error ?? 'Échec de la libération.',
      isError: !ok,
    );
    if (ok) {
      await context.read<AuthProvider>().refreshMe();
    }
  }
  return ok;
}

Future<bool> runReturnConfirmation(BuildContext context, MatchResult match) async {
  final WorkspaceProvider workspace = context.read<WorkspaceProvider>();

  final bool confirmed = await showConfirmDialog(
    context,
    title: 'Confirmer la restitution',
    message: 'Confirmez-vous avoir récupéré physiquement le document auprès de '
        '${match.counterpartName.isEmpty ? 'le trouveur' : match.counterpartName} ?',
    confirmLabel: 'Restitution effectuée',
    confirmColor: AppColors.green,
  );
  if (!confirmed || !context.mounted) {
    return false;
  }

  final bool ok = await workspace.confirmReturn(lossId: match.lossId, findId: match.findId);
  if (context.mounted) {
    showDoctrySnackBar(
      context,
      ok ? workspace.info ?? 'Restitution confirmée.' : workspace.error ?? 'Échec.',
      isError: !ok,
    );
  }
  return ok;
}

class _RewardForm {
  const _RewardForm({required this.amount, required this.provider, required this.phone});

  final double amount;
  final String provider;
  final String phone;
}

class _RewardDialog extends StatefulWidget {
  const _RewardDialog({required this.loss});

  final LossDeclaration loss;

  @override
  State<_RewardDialog> createState() => _RewardDialogState();
}

class _RewardDialogState extends State<_RewardDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _phone;
  late String _provider;
  String? _error;

  @override
  void initState() {
    super.initState();
    final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
    final double base = widget.loss.rewardAmount > 0
        ? widget.loss.rewardAmount
        : workspace.wallet.minRewardAmount.toDouble();
    _amount = TextEditingController(text: base.toStringAsFixed(0));
    _phone = TextEditingController(text: context.read<AuthProvider>().user?.phone ?? '');
    _provider = workspace.wallet.providers.isNotEmpty
        ? workspace.wallet.providers.first.code
        : 'ORANGE_MONEY';
  }

  @override
  void dispose() {
    _amount.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
    final double value = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    final int minimum = workspace.wallet.minRewardAmount;
    if (value < minimum) {
      setState(() => _error = 'Le montant minimum de la récompense est de $minimum XAF.');
      return;
    }
    Navigator.pop(
      context,
      _RewardForm(amount: value, provider: _provider, phone: _phone.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final WorkspaceProvider workspace = context.watch<WorkspaceProvider>();
    final int minimum = workspace.wallet.minRewardAmount;

    return AlertDialog(
      title: const Text('Associer une récompense'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.siamSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.description_outlined, color: AppColors.siam, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Déclaration n°${widget.loss.number} · '
                        '${Fmt.docType(widget.loss.docType)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Montant de la récompense (XAF)',
                  helperText: 'Minimum $minimum XAF',
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _provider,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Opérateur Mobile Money',
                  prefixIcon: Icon(Icons.phone_iphone),
                ),
                items: <DropdownMenuItem<String>>[
                  for (final PaymentProvider item in workspace.wallet.providers)
                    DropdownMenuItem<String>(
                      value: item.code,
                      child: Text('${item.label} · ${item.ussd}'),
                    ),
                  if (workspace.wallet.providers.isEmpty)
                    const DropdownMenuItem<String>(
                      value: 'ORANGE_MONEY',
                      child: Text('Orange Money'),
                    ),
                ],
                onChanged: (String? value) =>
                    setState(() => _provider = value ?? 'ORANGE_MONEY'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Numéro Mobile Money',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Solde du compte : ${Fmt.money(workspace.wallet.balance)} · '
                'Commission plateforme : '
                '${(workspace.wallet.commissionRate * 100).toStringAsFixed(0)} %',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.siam),
          onPressed: _submit,
          icon: const Icon(Icons.lock_outline, size: 18),
          label: const Text('Valider le paiement'),
        ),
      ],
    );
  }
}

class _TopUpForm {
  const _TopUpForm({required this.amount, required this.provider, required this.phone});

  final double amount;
  final String provider;
  final String phone;
}

class _TopUpDialog extends StatefulWidget {
  const _TopUpDialog({required this.suggested});

  final double suggested;

  @override
  State<_TopUpDialog> createState() => _TopUpDialogState();
}

class _TopUpDialogState extends State<_TopUpDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _phone;
  late String _provider;

  @override
  void initState() {
    super.initState();
    final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
    final double suggested = widget.suggested > 0
        ? widget.suggested.ceilToDouble()
        : (workspace.wallet.minRewardAmount * 4).toDouble();
    _amount = TextEditingController(text: suggested.toStringAsFixed(0));
    _phone = TextEditingController(text: context.read<AuthProvider>().user?.phone ?? '');
    _provider = workspace.wallet.providers.isNotEmpty
        ? workspace.wallet.providers.first.code
        : 'ORANGE_MONEY';
  }

  @override
  void dispose() {
    _amount.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WorkspaceProvider workspace = context.watch<WorkspaceProvider>();

    return AlertDialog(
      title: const Text('Recharger le compte'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Solde actuel : ${Fmt.money(workspace.wallet.balance)}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant à recharger (XAF)',
                prefixIcon: Icon(Icons.add_card_outlined),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _provider,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Opérateur',
                prefixIcon: Icon(Icons.phone_iphone),
              ),
              items: <DropdownMenuItem<String>>[
                for (final PaymentProvider item in workspace.wallet.providers)
                  DropdownMenuItem<String>(value: item.code, child: Text(item.label)),
                if (workspace.wallet.providers.isEmpty)
                  const DropdownMenuItem<String>(
                    value: 'ORANGE_MONEY',
                    child: Text('Orange Money'),
                  ),
              ],
              onChanged: (String? value) =>
                  setState(() => _provider = value ?? 'ORANGE_MONEY'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numéro Mobile Money',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final double value = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
            if (value <= 0) {
              return;
            }
            Navigator.pop(
              context,
              _TopUpForm(amount: value, provider: _provider, phone: _phone.text.trim()),
            );
          },
          child: const Text('Continuer'),
        ),
      ],
    );
  }
}
