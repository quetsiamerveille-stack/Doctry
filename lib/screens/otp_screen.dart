import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../providers/auth_provider.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<FocusNode> _nodes = List<FocusNode>.generate(6, (_) => FocusNode());
  final List<TextEditingController> _fields =
      List<TextEditingController>.generate(6, (_) => TextEditingController());

  @override
  void dispose() {
    for (final FocusNode node in _nodes) {
      node.dispose();
    }
    for (final TextEditingController field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  String get _code => _fields.map((TextEditingController item) => item.text).join();

  void _handleInput(int index, String value) {
    if (value.length > 1) {
      _distribute(value);
      return;
    }
    if (value.isEmpty) {
      if (index > 0) {
        _nodes[index - 1].requestFocus();
      }
      return;
    }
    if (index < 5) {
      _nodes[index + 1].requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  void _distribute(String value) {
    final List<String> digits = value.replaceAll(RegExp(r'\D'), '').split('');
    for (int index = 0; index < 6; index++) {
      _fields[index].text = index < digits.length ? digits[index] : '';
    }
    final int focus = digits.length >= 6 ? 5 : digits.length;
    _nodes[focus].requestFocus();
    if (digits.length >= 6) {
      _verify();
    }
  }

  Future<void> _verify() async {
    final String code = _code;
    if (code.length < 6) {
      showDoctrySnackBar(context, 'Saisissez les 6 chiffres du code OTP.', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    final bool ok = await context.read<AuthProvider>().verifyOtp(code);
    if (!ok || !mounted) {
      return;
    }
    for (final TextEditingController field in _fields) {
      field.clear();
    }
  }

  Future<void> _resend() async {
    await context.read<AuthProvider>().resendOtp();
    if (!mounted) {
      return;
    }
    final String? dev = context.read<AuthProvider>().challenge?.devCode;
    if (dev != null && dev.isNotEmpty) {
      _distribute(dev);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final challenge = auth.challenge;

    return Scaffold(
      body: AuthShell(
        children: <Widget>[
          AuthCard(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const DoctryMark(radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Vérification en deux étapes',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          challenge?.isAdmin == true
                              ? 'Espace administrateur'
                              : 'Profil ${Fmt.profileLabel(challenge?.profile ?? 'owner')}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Un code de vérification à 6 chiffres a été envoyé à '
                '${challenge?.email ?? 'votre adresse email'}.',
                style: const TextStyle(fontSize: 13.5),
              ),
              if (challenge != null && challenge.isSimulated && challenge.devCode.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.mark_email_read_outlined,
                          size: 20, color: AppColors.darkBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Service Gmail non configuré : code de simulation ${challenge.devCode}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkBlue,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _distribute(challenge.devCode),
                        child: const Text('Remplir'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double cell = constraints.maxWidth >= 340 ? 44 : 40;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      for (int index = 0; index < 6; index++)
                        SizedBox(
                          width: cell,
                          height: 56,
                          child: TextField(
                            controller: _fields[index],
                            focusNode: _nodes[index],
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            textAlign: TextAlign.center,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkBlue,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (String value) => _handleInput(index, value),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (auth.error != null) ...<Widget>[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.red.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.error_outline, color: AppColors.red, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          auth.error!,
                          style: const TextStyle(color: AppColors.red, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              DoctryButton(
                label: 'Vérifier le code',
                icon: Icons.verified_outlined,
                loading: auth.busy,
                onPressed: auth.busy ? null : _verify,
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: auth.busy ? null : auth.cancelOtp,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Retour'),
                  ),
                  TextButton.icon(
                    onPressed: auth.busy ? null : _resend,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Renvoyer le code'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
