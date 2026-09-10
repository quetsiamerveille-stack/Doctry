import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/media_picker.dart';
import '../../models/declaration.dart';
import '../../providers/workspace_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/doctry_shell.dart';
import '../../widgets/doctry_table.dart';
import 'qr_scanner_screen.dart';

class FinderDeclarationPage extends StatelessWidget {
  const FinderDeclarationPage({super.key});

  Future<void> _scan(BuildContext context) async {
    final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
    final String? payload = await openQrScanner(context);
    if (payload == null || !context.mounted) {
      return;
    }
    final String? location = await _askLocation(context);
    if (!context.mounted) {
      return;
    }
    final bool ok = await workspace.scanQr(
      payload: payload,
      location: location ?? '',
    );
    if (!context.mounted) {
      return;
    }
    _report(context, ok);
  }

  Future<void> _photo(BuildContext context) async {
    final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
    final PickedMedia? media = await showImageSourceSheet(context);
    if (media == null || !context.mounted) {
      return;
    }
    final _FindForm? form = await showDialog<_FindForm>(
      context: context,
      builder: (BuildContext dialogContext) => const _FindDialog(),
    );
    if (form == null || !context.mounted) {
      return;
    }
    final bool ok = await workspace.createFind(
      docType: form.docType,
      description: form.description,
      location: form.location,
      holderName: form.holderName,
      source: form.camera ? 'camera' : 'gallery',
      media: media,
    );
    if (!context.mounted) {
      return;
    }
    _report(context, ok);
  }

  Future<void> _manual(BuildContext context) async {
    final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
    final _FindForm? form = await showDialog<_FindForm>(
      context: context,
      builder: (BuildContext dialogContext) => const _FindDialog(),
    );
    if (form == null || !context.mounted) {
      return;
    }
    final bool ok = await workspace.createFind(
      docType: form.docType,
      description: form.description,
      location: form.location,
      holderName: form.holderName,
      source: 'manual',
    );
    if (!context.mounted) {
      return;
    }
    _report(context, ok);
  }

  void _report(BuildContext context, bool ok) {
    final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
    showDoctrySnackBar(
      context,
      ok ? workspace.info ?? 'Retrouvaille déclarée.' : workspace.error ?? 'Échec.',
      isError: !ok,
    );
  }

  Future<String?> _askLocation(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Déclarer retrouvaille'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Lieu de la retrouvaille (optionnel)',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Déclarer retrouvaille'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final WorkspaceProvider workspace = context.watch<WorkspaceProvider>();
    final List<FindDeclaration> finds = workspace.finds;

    return PageScaffold(
      title: 'Déclaration',
      onRefresh: workspace.loadFinderWorkspace,
      children: <Widget>[
        SectionCard(
          title: 'Déclarer un document retrouvé',
          icon: Icons.qr_code_scanner_outlined,
          subtitle: 'Le moteur de matching IA est déclenché instantanément.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ActionTile(
                      title: 'Scanner',
                      caption: "Ouvre le scanner du téléphone pour lire le QR Code.",
                      icon: Icons.qr_code_scanner,
                      color: AppColors.siam,
                      loading: workspace.busyOn == 'scan',
                      onTap: () => _scan(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionTile(
                      title: 'Photo',
                      caption: 'Exporter depuis la galerie ou filmer le document.',
                      icon: Icons.photo_camera_outlined,
                      color: AppColors.darkBlue,
                      loading: workspace.busyOn == 'find',
                      onTap: () => _photo(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DoctryButton(
                label: 'Déclarer retrouvaille',
                icon: Icons.how_to_reg_outlined,
                color: AppColors.green,
                loading: workspace.busyOn == 'find',
                onPressed: () => _manual(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Mes retrouvailles',
          icon: Icons.find_in_page_outlined,
          subtitle: '${finds.length} déclaration(s) de retrouvaille.',
          child: DoctryTable(
            rowCount: finds.length,
            emptyMessage: 'Aucune retrouvaille déclarée pour le moment.',
            columns: <DoctryColumn>[
              DoctryColumn(
                label: 'N°',
                cell: (BuildContext context, int index) => Text('${finds[index].number}'),
              ),
              DoctryColumn(
                label: 'Type de document',
                compactLabel: 'Type',
                flex: 2,
                cell: (BuildContext context, int index) =>
                    Text(Fmt.docType(finds[index].docType)),
              ),
              DoctryColumn(
                label: 'Retrouvé le',
                compactLabel: 'Date',
                cell: (BuildContext context, int index) =>
                    Text(Fmt.date(finds[index].foundDate)),
              ),
              DoctryColumn(
                label: 'Propriétaire identifié',
                compactLabel: 'Propriétaire',
                flex: 2,
                cell: (BuildContext context, int index) => Text(
                  finds[index].holderName.isEmpty ? '—' : finds[index].holderName,
                ),
              ),
              DoctryColumn(
                label: 'Source',
                cell: (BuildContext context, int index) {
                  final FindDeclaration find = finds[index];
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(
                      label: find.source == 'qr'
                          ? 'QR Code'
                          : find.source == 'camera'
                              ? 'Photo'
                              : find.source == 'gallery'
                                  ? 'Galerie'
                                  : 'Manuelle',
                      color: AppColors.grey,
                      icon: find.fromQr ? Icons.qr_code_2 : Icons.edit_note_outlined,
                    ),
                  );
                },
              ),
              DoctryColumn(
                label: 'Statut',
                cell: (BuildContext context, int index) {
                  final FindDeclaration find = finds[index];
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(
                      label: Fmt.findStatus(find.status),
                      color: find.isReturned
                          ? AppColors.green
                          : find.status == 'matched'
                              ? AppColors.gold
                              : AppColors.siam,
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.caption,
    required this.icon,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  final String title;
  final String caption;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, color: color, size: 26),
                  const Spacer(),
                  if (loading)
                    SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: color),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FindForm {
  const _FindForm({
    required this.docType,
    required this.description,
    required this.location,
    required this.holderName,
    required this.camera,
  });

  final String docType;
  final String description;
  final String location;
  final String holderName;
  final bool camera;
}

class _FindDialog extends StatefulWidget {
  const _FindDialog();

  @override
  State<_FindDialog> createState() => _FindDialogState();
}

class _FindDialogState extends State<_FindDialog> {
  final TextEditingController _description = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _holder = TextEditingController();
  String _docType = 'CNI';
  bool _camera = false;

  @override
  void dispose() {
    _description.dispose();
    _location.dispose();
    _holder.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(
      context,
      _FindForm(
        docType: _docType,
        description: _description.text.trim(),
        location: _location.text.trim(),
        holderName: _holder.text.trim(),
        camera: _camera,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Déclarer retrouvaille'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: _docType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type de document'),
                items: <DropdownMenuItem<String>>[
                  for (final MapEntry<String, String> entry in Fmt.documentTypes.entries)
                    DropdownMenuItem<String>(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() => _docType = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _holder,
                decoration: const InputDecoration(
                  labelText: 'Nom du titulaire (si lisible)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Lieu de la retrouvaille',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  hintText: 'État du document, signes distinctifs…',
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _camera,
                activeColor: AppColors.siam,
                title: const Text('Image capturée avec la caméra',
                    style: TextStyle(fontSize: 13)),
                onChanged: (bool value) => setState(() => _camera = value),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.green),
          onPressed: _submit,
          child: const Text('Déclarer retrouvaille'),
        ),
      ],
    );
  }
}
