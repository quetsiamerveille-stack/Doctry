import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/user.dart';
import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import 'dialogs.dart';

class ShellNavItem {
  const ShellNavItem({required this.label, required this.icon, required this.page});

  final String label;
  final IconData icon;
  final Widget page;
}

class DoctryShell extends StatefulWidget {
  const DoctryShell({
    super.key,
    required this.items,
    required this.onReady,
    this.subtitle = '',
  });

  final List<ShellNavItem> items;
  final Future<void> Function() onReady;
  final String subtitle;

  @override
  State<DoctryShell> createState() => _DoctryShellState();
}

class _DoctryShellState extends State<DoctryShell> {
  int _index = 0;
  bool _ratingHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    await widget.onReady();
    if (!mounted) {
      return;
    }
    await _maybeShowRating();
  }

  Future<void> _maybeShowRating() async {
    if (_ratingHandled) {
      return;
    }
    _ratingHandled = true;
    final AuthProvider auth = context.read<AuthProvider>();
    await auth.checkRatingDue();
    if (!mounted || !auth.ratingDue) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) {
      return;
    }
    final bool rated = await showRatingDialog(context);
    if (!rated && mounted) {
      auth.dismissRating();
    }
  }

  Future<void> _switchProfile(String profile) async {
    final AuthProvider auth = context.read<AuthProvider>();
    final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
    final AdminProvider admin = context.read<AdminProvider>();

    workspace.reset();
    admin.reset();
    final bool ok = await auth.switchProfile(profile);
    if (!mounted) {
      return;
    }
    showDoctrySnackBar(
      context,
      ok
          ? 'Profil actif : ${Fmt.profileLabel(profile)}.'
          : (auth.error ?? 'Impossible de changer de profil.'),
      isError: !ok,
    );
  }

  Future<void> _logout() async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Déconnexion',
      message: 'Voulez-vous vraiment vous déconnecter de DOCTRY ?',
      confirmLabel: 'Se déconnecter',
      confirmColor: AppColors.red,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final AuthProvider auth = context.read<AuthProvider>();
    context.read<WorkspaceProvider>().reset();
    context.read<AdminProvider>().reset();
    await auth.logout();
  }

  Future<void> _openProfileMenu() async {
    await showProfileEditDialog(context);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final AppUser? user = auth.user;
    final double width = MediaQuery.sizeOf(context).width;
    final bool wide = width >= 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 4),
        child: _TopBar(
          user: user,
          subtitle: widget.subtitle,
          unread: context.watch<WorkspaceProvider>().unread,
          isAdminProfile: auth.isAdminProfile,
          isAdminUser: auth.isAdmin,
          onProfileTap: _openProfileMenu,
          onSwitchProfile: _switchProfile,
          onNotifications: () => showNotificationsPanel(context),
          onLogout: _logout,
        ),
      ),
      body: SafeArea(
        top: false,
        child: wide
            ? Row(
                children: <Widget>[
                  _SideNavigation(
                    items: widget.items,
                    index: _index,
                    onChanged: (int value) => setState(() => _index = value),
                  ),
                  Expanded(child: _page(auth)),
                ],
              )
            : _page(auth),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (int value) => setState(() => _index = value),
              destinations: <NavigationDestination>[
                for (final ShellNavItem item in widget.items)
                  NavigationDestination(icon: Icon(item.icon), label: item.label),
              ],
            ),
    );
  }

  Widget _page(AuthProvider auth) {
    if (auth.busy) {
      return const Center(child: CircularProgressIndicator());
    }
    return IndexedStack(
      index: _index,
      children: <Widget>[
        for (final ShellNavItem item in widget.items) item.page,
      ],
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({required this.items, required this.index, required this.onChanged});

  final List<ShellNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      color: AppColors.darkBlue,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int position = 0; position < items.length; position++) ...<Widget>[
            _SideItem(
              item: items[position],
              selected: position == index,
              onTap: () => onChanged(position),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({required this.item, required this.selected, required this.onTap});

  final ShellNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.siam : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: <Widget>[
              Icon(item.icon, size: 20, color: AppColors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.user,
    required this.subtitle,
    required this.unread,
    required this.isAdminProfile,
    required this.isAdminUser,
    required this.onProfileTap,
    required this.onSwitchProfile,
    required this.onNotifications,
    required this.onLogout,
  });

  final AppUser? user;
  final String subtitle;
  final int unread;
  final bool isAdminProfile;
  final bool isAdminUser;
  final VoidCallback onProfileTap;
  final Future<void> Function(String profile) onSwitchProfile;
  final VoidCallback onNotifications;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final String name = user?.fullName ?? 'DOCTRY';

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        boxShadow: <BoxShadow>[
          BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight + 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: <Widget>[
                _ProfileMenu(
                  name: name,
                  subtitle: subtitle,
                  isAdminProfile: isAdminProfile,
                  isAdminUser: isAdminUser,
                  activeProfile: user?.activeProfile ?? 'owner',
                  onEdit: onProfileTap,
                  onSwitchProfile: onSwitchProfile,
                  onLogout: onLogout,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: onNotifications,
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    backgroundColor: AppColors.gold,
                    textColor: AppColors.darkBlue,
                    child: const Icon(Icons.notifications_none, color: AppColors.white),
                  ),
                ),
                IconButton(
                  tooltip: 'Déconnexion',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout, color: AppColors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({
    required this.name,
    required this.subtitle,
    required this.isAdminProfile,
    required this.isAdminUser,
    required this.activeProfile,
    required this.onEdit,
    required this.onSwitchProfile,
    required this.onLogout,
  });

  final String name;
  final String subtitle;
  final bool isAdminProfile;
  final bool isAdminUser;
  final String activeProfile;
  final VoidCallback onEdit;
  final Future<void> Function(String profile) onSwitchProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final String target = activeProfile == 'owner' ? 'finder' : 'owner';

    return PopupMenuButton<String>(
      tooltip: 'Menu du profil',
      color: AppColors.white,
      offset: const Offset(0, 52),
      onSelected: (String value) {
        switch (value) {
          case 'edit':
            onEdit();
          case 'logout':
            onLogout();
          default:
            onSwitchProfile(value);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'edit',
          child: _MenuRow(icon: Icons.person_outline, label: 'Modifier le profil'),
        ),
        if (isAdminUser) ...<PopupMenuEntry<String>>[
          if (!isAdminProfile)
            const PopupMenuItem<String>(
              value: 'admin',
              child: _MenuRow(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Tableau de bord administrateur',
              ),
            ),
          const PopupMenuItem<String>(
            value: 'finder',
            child: _MenuRow(
              icon: Icons.travel_explore_outlined,
              label: 'Changer de profil — Trouveur',
            ),
          ),
          const PopupMenuItem<String>(
            value: 'owner',
            child: _MenuRow(
              icon: Icons.badge_outlined,
              label: 'Changer de profil — Propriétaire',
            ),
          ),
        ] else
          PopupMenuItem<String>(
            value: target,
            child: _MenuRow(
              icon: Icons.swap_horiz,
              label: 'Changer de profil — ${Fmt.profileLabel(target)}',
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: _MenuRow(icon: Icons.logout, label: 'Déconnexion', danger: true),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 5, 14, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircleAvatar(
              radius: 19,
              backgroundColor: AppColors.gold,
              child: Text(
                Fmt.initials(name),
                style: const TextStyle(
                  color: AppColors.darkBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    subtitle.isEmpty ? 'DOCTRY' : subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.gold.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: AppColors.white),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.danger = false});

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color color = danger ? AppColors.red : AppColors.darkBlue;
    return Row(
      children: <Widget>[
        Icon(icon, size: 19, color: danger ? AppColors.red : AppColors.siam),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13.5, color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.title, required this.children, this.onRefresh});

  final String title;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      color: AppColors.siam,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double maxWidth = constraints.maxWidth > 1180 ? 1180 : constraints.maxWidth;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(title, style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 16),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
