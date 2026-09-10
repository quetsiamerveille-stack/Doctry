import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/user.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/doctry_shell.dart';
import '../../widgets/doctry_table.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    final AdminProvider admin = context.read<AdminProvider>();
    await admin.loadUsers(search: _search.text.trim());
  }

  Future<void> _toggleBlock(AdminUser user) async {
    final AdminProvider admin = context.read<AdminProvider>();
    final bool confirmed = await showConfirmDialog(
      context,
      title: user.isBlocked ? 'Débloquer l\'utilisateur' : 'Bloquer l\'utilisateur',
      message: user.isBlocked
          ? '${user.fullName} pourra à nouveau se connecter à DOCTRY.'
          : '${user.fullName} ne pourra plus se connecter ni déclarer de document.',
      confirmLabel: user.isBlocked ? 'Débloquer' : 'Bloquer',
      confirmColor: user.isBlocked ? AppColors.green : AppColors.red,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final bool ok = user.isBlocked ? await admin.unblockUser(user.id) : await admin.blockUser(user.id);
    if (!mounted) {
      return;
    }
    showDoctrySnackBar(context, ok ? (admin.info ?? 'Statut mis à jour.') : (admin.error ?? 'Action impossible.'), isError: !ok);
  }

  Future<void> _openCreateDialog() async {
    final AdminProvider admin = context.read<AdminProvider>();
    final _NewUser? result = await showDialog<_NewUser>(
      context: context,
      builder: (BuildContext dialogContext) => const _CreateUserDialog(),
    );
    if (result == null || !mounted) {
      return;
    }
    final bool ok = await admin.createUser(
      email: result.email,
      password: result.password,
      firstName: result.firstName,
      lastName: result.lastName,
      role: result.role,
      phone: result.phone,
    );
    if (!mounted) {
      return;
    }
    showDoctrySnackBar(context, ok ? 'Utilisateur créé avec succès.' : (admin.error ?? 'Création impossible.'), isError: !ok);
  }

  @override
  Widget build(BuildContext context) {
    final AdminProvider admin = context.watch<AdminProvider>();
    final List<AdminUser> users = admin.users;
    final int active = users.where((AdminUser user) => !user.isBlocked).length;

    return PageScaffold(
      title: 'Gestion des utilisateurs',
      onRefresh: admin.loadAll,
      children: <Widget>[
        SectionCard(
          title: 'Rechercher un utilisateur',
          icon: Icons.manage_search_outlined,
          subtitle: '$active utilisateur(s) actif(s) sur ${users.length} affiché(s).',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchUsers(),
                      decoration: InputDecoration(
                        hintText: 'Nom, prénom ou adresse email',
                        prefixIcon: const Icon(Icons.search, color: AppColors.siam),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _search.clear();
                                  _searchUsers();
                                },
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DoctryButton(
                    label: 'Rechercher',
                    icon: Icons.filter_alt_outlined,
                    onPressed: _searchUsers,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  DoctryButton(
                    label: 'Créer un utilisateur',
                    icon: Icons.person_add_alt_1_outlined,
                    variant: DoctryButtonVariant.dark,
                    color: AppColors.darkBlue,
                    onPressed: _openCreateDialog,
                  ),
                  DoctryButton(
                    label: 'Tous les utilisateurs',
                    icon: Icons.groups_outlined,
                    variant: DoctryButtonVariant.outlined,
                    onPressed: () {
                      _search.clear();
                      _searchUsers();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Utilisateurs DOCTRY',
          icon: Icons.group_outlined,
          child: DoctryTable(
            rowCount: users.length,
            emptyMessage: 'Aucun utilisateur enregistré.',
            columns: <DoctryColumn>[
              DoctryColumn(
                label: 'N°',
                cell: (BuildContext context, int index) => Text('${index + 1}'),
              ),
              DoctryColumn(
                label: 'Nom complet',
                compactLabel: 'Nom',
                flex: 2,
                cell: (BuildContext context, int index) => Text(
                  users[index].fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              DoctryColumn(
                label: 'Email',
                flex: 2,
                cell: (BuildContext context, int index) => Text(users[index].email),
              ),
              DoctryColumn(
                label: 'Profil',
                cell: (BuildContext context, int index) =>
                    Text(Fmt.profileLabel(users[index].role)),
              ),
              DoctryColumn(
                label: 'Solde',
                cell: (BuildContext context, int index) =>
                    Text(Fmt.money(users[index].walletBalance)),
              ),
              DoctryColumn(
                label: 'Note',
                cell: (BuildContext context, int index) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.star_rate_rounded, size: 17, color: AppColors.gold),
                    Text(users[index].averageRating.toStringAsFixed(1)),
                  ],
                ),
              ),
              DoctryColumn(
                label: 'Statut',
                cell: (BuildContext context, int index) {
                  final AdminUser user = users[index];
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(
                      label: user.isBlocked ? 'Bloqué' : 'Actif',
                      color: user.isBlocked ? AppColors.red : AppColors.green,
                      icon: user.isBlocked ? Icons.block : Icons.verified_outlined,
                    ),
                  );
                },
              ),
              DoctryColumn(
                label: 'Action',
                cell: (BuildContext context, int index) {
                  final AdminUser user = users[index];
                  final bool busy = admin.busyOn == 'block-${user.id}' ||
                      admin.busyOn == 'unblock-${user.id}';
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: DoctryButton(
                      label: user.isBlocked ? 'Débloquer' : 'Bloquer',
                      icon: user.isBlocked ? Icons.lock_open_outlined : Icons.block,
                      variant: DoctryButtonVariant.outlined,
                      color: user.isBlocked ? AppColors.green : AppColors.red,
                      loading: busy,
                      onPressed: busy ? null : () => _toggleBlock(user),
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

class _NewUser {
  const _NewUser({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.phone,
  });

  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String role;
  final String phone;
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  String _role = 'owner';

  @override
  void dispose() {
    _lastName.dispose();
    _firstName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.pop(
      context,
      _NewUser(
        email: _email.text.trim(),
        password: _password.text,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        role: _role,
        phone: _phone.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer un utilisateur'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  value: _role,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Profil'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(value: 'owner', child: Text('Propriétaire')),
                    DropdownMenuItem<String>(value: 'finder', child: Text('Trouveur')),
                  ],
                  onChanged: (String? value) => setState(() => _role = value ?? 'owner'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: (String? value) =>
                      (value ?? '').trim().isEmpty ? 'Le nom est requis.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                  validator: (String? value) =>
                      (value ?? '').trim().isEmpty ? 'Le prénom est requis.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Adresse email'),
                  validator: (String? value) =>
                      (value ?? '').trim().contains('@') ? null : 'Adresse email invalide.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                  validator: (String? value) =>
                      (value ?? '').trim().length < 6 ? 'Numéro de téléphone invalide.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mot de passe'),
                  validator: (String? value) =>
                      (value ?? '').length < 6 ? '6 caractères minimum.' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        DoctryButton(
          label: 'Créer',
          icon: Icons.person_add_alt_1_outlined,
          onPressed: _submit,
        ),
      ],
    );
  }
}
