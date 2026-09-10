import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

class PaymentTicket {
  const PaymentTicket({
    required this.reference,
    required this.providerLabel,
    required this.ussd,
    required this.amount,
    required this.phone,
    required this.message,
  });

  factory PaymentTicket.fromJson(Map<String, dynamic> json) => PaymentTicket(
        reference: '${json['reference'] ?? ''}',
        providerLabel: '${json['provider'] ?? ''}',
        ussd: '${json['ussd'] ?? ''}',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        phone: '${json['phone'] ?? ''}',
        message: '${json['message'] ?? ''}',
      );

  final String reference;
  final String providerLabel;
  final String ussd;
  final double amount;
  final String phone;
  final String message;

  bool get isOrange => providerLabel.toUpperCase().contains('ORANGE');
}

class PaymentSimulatorScreen extends StatefulWidget {
  const PaymentSimulatorScreen({
    super.key,
    required this.ticket,
    required this.onConfirm,
    this.title = 'Paiement sécurisé',
  });

  final PaymentTicket ticket;
  final Future<String?> Function(String pin) onConfirm;
  final String title;

  @override
  State<PaymentSimulatorScreen> createState() => _PaymentSimulatorScreenState();
}

class _PaymentSimulatorScreenState extends State<PaymentSimulatorScreen> {
  final TextEditingController _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Color get _brand => widget.ticket.isOrange ? const Color(0xFFFF7900) : AppColors.gold;

  Future<void> _confirm() async {
    final String pin = _pin.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'Saisissez votre code PIN à 4 chiffres.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final String? failure = await widget.onConfirm(pin);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = failure;
      _pin.clear();
    });
  }

  void _pad(String digit) {
    if (_pin.text.length >= 4) {
      return;
    }
    _pin.text = _pin.text + digit;
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final PaymentTicket ticket = widget.ticket;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.darkBlue,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[_brand, _brand.withValues(alpha: 0.75)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              ticket.isOrange ? Icons.sim_card_outlined : Icons.phone_iphone,
                              color: _brand,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  ticket.providerLabel,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'API de paiement simulée · ${ticket.ussd}',
                                  style: TextStyle(
                                    color: AppColors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        Fmt.money(ticket.amount),
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _Line(label: 'Référence', value: ticket.reference),
                      _Line(
                        label: 'Numéro',
                        value: ticket.phone.isEmpty ? '—' : ticket.phone,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        ticket.message.isEmpty
                            ? 'Saisissez votre code PIN pour valider l\'opération.'
                            : ticket.message,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          for (int index = 0; index < 4; index++)
                            Container(
                              width: 46,
                              height: 54,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: index < _pin.text.length
                                      ? AppColors.siam
                                      : AppColors.border,
                                  width: index < _pin.text.length ? 1.8 : 1,
                                ),
                              ),
                              child: Text(
                                index < _pin.text.length ? '•' : '',
                                style: const TextStyle(
                                  fontSize: 26,
                                  color: AppColors.darkBlue,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _pin,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          counterText: '',
                          labelText: 'Code PIN Mobile Money',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                        onChanged: (_) => setState(() => _error = null),
                        onSubmitted: (_) => _confirm(),
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.red, fontSize: 12.5),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _PinPad(onDigit: _pad, onClear: () => setState(() => _pin.clear())),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.siam,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: _busy ? null : _confirm,
                        icon: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.white),
                              )
                            : const Icon(Icons.lock_outline, size: 19),
                        label: Text(_busy ? 'Traitement…' : 'Valider le paiement'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _busy ? null : () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Annuler'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.85),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({required this.onDigit, required this.onClear});

  final ValueChanged<String> onDigit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    const List<String> keys = <String>[
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      '', '0', 'C',
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.1,
      children: <Widget>[
        for (final String key in keys)
          if (key.isEmpty)
            const SizedBox.shrink()
          else
            Material(
              color: key == 'C' ? AppColors.background : AppColors.siamSoft,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => key == 'C' ? onClear() : onDigit(key),
                child: Center(
                  child: Text(
                    key,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: key == 'C' ? AppColors.red : AppColors.darkBlue,
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
