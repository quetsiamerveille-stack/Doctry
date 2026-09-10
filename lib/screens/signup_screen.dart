import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../providers/auth_provider.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  String _profile = 'owner';
  bool _obscure = true;

  @override
  void dispose() {
    _lastName.dispose();
    _firstName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final bool ok = await context.read<AuthProvider>().signup(
          profile: _profile,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          phone: _phone.text.trim(),
        );
    if (ok && mounted) {
      Navigator.of(context).popUntil((Route<void> route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.darkBlue,
        elevation: 0,
        title: const Text('Créer un compte'),
      ),
      body: AuthShell(
        children: <Widget>[
          AuthCard(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const DoctryMark(radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Rejoignez la plateforme DOCTRY',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Choix du profil',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _ProfileChoice(
                            label: Fmt.profileLabel('owner'),
                            icon: Icons.badge_outlined,
                            selected: _profile == 'owner',
                            onTap: () => setState(() => _profile = 'owner'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ProfileChoice(
                            label: Fmt.profileLabel('finder'),
                            icon: Icons.travel_explore_outlined,
                            selected: _profile == 'finder',
                            onTap: () => setState(() => _profile = 'finder'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _lastName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (String? value) =>
                          (value ?? '').trim().isEmpty ? 'Saisissez votre nom.' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _firstName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Prénom',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (String? value) =>
                          (value ?? '').trim().isEmpty ? 'Saisissez votre prénom.' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Adresse email',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (String? value) {
                        final String text = (value ?? '').trim();
                        if (text.isEmpty) {
                          return 'Saisissez votre adresse email.';
                        }
                        if (!text.contains('@') || !text.contains('.')) {
                          return 'Adresse email invalide.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone (optionnel)',
                        helperText: 'Utilisé pour les alertes SMS Textsoft',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        helperText: '6 caractères minimum',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.grey,
                          ),
                        ),
                      ),
                      validator: (String? value) =>
                          (value ?? '').length < 6 ? '6 caractères minimum.' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _obscure,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                      ),
                      validator: (String? value) =>
                          value != _password.text ? 'Les mots de passe diffèrent.' : null,
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
                    const SizedBox(height: 20),
                    DoctryButton(
                      label: 'S\'inscrire',
                      icon: Icons.how_to_reg_outlined,
                      loading: auth.busy,
                      onPressed: auth.busy ? null : _submit,
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Retour à la connexion'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileChoice extends StatelessWidget {
  const _ProfileChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tint = selected ? AppColors.siam : AppColors.border;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.siamSoft : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tint, width: selected ? 1.8 : 1),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: selected ? AppColors.siam : AppColors.grey, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.darkBlue : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
