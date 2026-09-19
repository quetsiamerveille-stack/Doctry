import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/api_config.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../providers/auth_provider.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import '../widgets/server_config_dialog.dart';
import 'install_admin_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _adminEmail = TextEditingController();
  final TextEditingController _adminPassword = TextEditingController();

  String _profile = 'owner';
  bool _adminSectionOpen = false;
  bool _obscure = true;
  bool _adminObscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _adminEmail.dispose();
    _adminPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    await context.read<AuthProvider>().login(
          profile: _profile,
          email: _email.text.trim(),
          password: _password.text,
        );
  }

  Future<void> _submitAdmin() async {
    if (_adminEmail.text.trim().isEmpty || _adminPassword.text.isEmpty) {
      return;
    }
    FocusScope.of(context).unfocus();
    await context.read<AuthProvider>().adminLogin(
          email: _adminEmail.text.trim(),
          password: _adminPassword.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();

    return Scaffold(
      body: AuthShell(
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: <Widget>[
                    const DoctryMark(radius: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Ravi de vous revoir',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 2),
                          const Text(
                            'Connectez-vous à votre espace DOCTRY',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!auth.server.online) _offlineBanner(auth),
              if (auth.server.online && auth.server.adminInstallRequired) _installBanner(),
              const SizedBox(height: 4),
              AuthCard(
                children: <Widget>[
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        DropdownButtonFormField<String>(
                          value: _profile,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Profil',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          items: <DropdownMenuItem<String>>[
                            for (final String value in <String>['owner', 'finder'])
                              DropdownMenuItem<String>(
                                value: value,
                                child: Text(Fmt.profileLabel(value)),
                              ),
                          ],
                          onChanged: (String? value) =>
                              setState(() => _profile = value ?? 'owner'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const <String>[AutofillHints.email],
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
                        if (!auth.useSupabaseOtp) ...<Widget>[
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            autofillHints: const <String>[AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AppColors.grey,
                                ),
                              ),
                            ),
                            validator: (String? value) =>
                                (value ?? '').isEmpty ? 'Saisissez votre mot de passe.' : null,
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (auth.useSupabaseOtp)
                          const Text(
                            'Vous recevrez un code de vérification par email.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        if (auth.error != null && !_adminSectionOpen) ...<Widget>[
                          const SizedBox(height: 12),
                          _ErrorBanner(message: auth.error!),
                        ],
                        const SizedBox(height: 18),
                        DoctryButton(
                          label: 'Se connecter',
                          icon: Icons.login,
                          loading: auth.busy,
                          onPressed: auth.busy ? null : _submit,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: auth.busy
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const SignupScreen(),
                                    ),
                                  ),
                          child: const Text('Pas de compte ? S\'inscrire'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _adminSection(auth),
              const SizedBox(height: 18),
              _serverFooter(auth),
            ],
      ),
    );
  }

  Widget _offlineBanner(AuthProvider auth) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.cloud_off, color: AppColors.red, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Backend FastAPI injoignable sur ${ApiConfig.baseUrl}. '
              'Démarrez-le puis réessayez.',
              style: const TextStyle(fontSize: 12.5, color: AppColors.darkBlue),
            ),
          ),
          TextButton(
            onPressed: () => showServerConfigDialog(context),
            child: const Text('Configurer'),
          ),
        ],
      ),
    );
  }

  Widget _installBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.shield_outlined, color: AppColors.darkBlue, size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Aucun administrateur n\'est encore installé sur cette plateforme DOCTRY.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.darkBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DoctryButton(
            label: 'Installer l\'administrateur',
            icon: Icons.app_registration_outlined,
            variant: DoctryButtonVariant.gold,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const InstallAdminScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminSection(AuthProvider auth) {
    return AuthCard(
      children: <Widget>[
        if (!_adminSectionOpen)
          DoctryButton(
            label: 'Se connecter en tant qu\'admin',
            icon: Icons.admin_panel_settings_outlined,
            variant: DoctryButtonVariant.outlined,
            color: AppColors.darkBlue,
            onPressed: auth.busy
                ? null
                : () => setState(() {
                      _adminSectionOpen = true;
                      auth.clearMessages();
                    }),
          )
        else ...<Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.shield_outlined, color: AppColors.darkBlue, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Espace administrateur',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                onPressed: () => setState(() => _adminSectionOpen = false),
                icon: const Icon(Icons.close, size: 20, color: AppColors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _adminEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email administrateur',
              prefixIcon: Icon(Icons.alternate_email),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _adminPassword,
            obscureText: _adminObscure,
            onSubmitted: (_) => _submitAdmin(),
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _adminObscure = !_adminObscure),
                icon: Icon(
                  _adminObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.grey,
                ),
              ),
            ),
          ),
          if (auth.error != null && _adminSectionOpen) ...<Widget>[
            const SizedBox(height: 12),
            _ErrorBanner(message: auth.error!),
          ],
          const SizedBox(height: 16),
          DoctryButton(
            label: 'Connexion administrateur',
            icon: Icons.login,
            color: AppColors.darkBlue,
            loading: auth.busy,
            onPressed: auth.busy ? null : _submitAdmin,
          ),
        ],
      ],
    );
  }

  Widget _serverFooter(AuthProvider auth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          auth.server.online ? Icons.cloud_done_outlined : Icons.cloud_off,
          size: 15,
          color: auth.server.online ? AppColors.green : AppColors.red,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '${ApiConfig.baseUrl} · IA ${auth.server.aiEngine} · '
            'Email ${auth.server.emailDelivery} · SMS ${auth.server.smsDelivery}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
        IconButton(
          tooltip: 'Configurer le serveur',
          visualDensity: VisualDensity.compact,
          onPressed: () => showServerConfigDialog(context),
          icon: const Icon(Icons.settings_outlined, size: 17, color: AppColors.grey),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              message,
              style: const TextStyle(color: AppColors.red, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
