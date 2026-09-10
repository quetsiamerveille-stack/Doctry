import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/media_picker.dart';
import '../../models/declaration.dart';
import '../../models/document.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workspace_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/doctry_shell.dart';
import '../../widgets/doctry_table.dart';
import '../../widgets/match_card.dart';
import '../../widgets/qr_preview.dart';
import '../chat/chat_thread_screen.dart';
import 'owner_dashboard.dart';
import 'reward_flow.dart';

class OwnerDocumentsPage extends StatefulWidget {
  const OwnerDocumentsPage({super.key});

  @override
  State<OwnerDocumentsPage> createState() => _OwnerDocumentsPageState();
}

class _OwnerDocumentsPageState extends State<OwnerDocumentsPage> {
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    final WorkspaceProvider workspace = context.watch<WorkspaceProvider>();

    return PageScaffold(
      title: 'Document',
      onRefresh: workspace.loadOwnerWorkspace,
      children: <Widget>[
        SectionCard(
          title: 'Pré-enregistrer',
          icon: Icons.add_card_outlined,
          subtitle: 'Protégez votre document par QR Code ou par photo.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const <ButtonSegment<int>>[
                    ButtonSegment<int>(
                      value: 0,
                      label: Text('Par QR code'),
                      icon: Icon(Icons.qr_code_2, size: 17),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      label: Text('Par photo'),
                      icon: Icon(Icons.photo_camera_outlined, size: 17),
                    ),
                  ],
                  selected: <int>{_mode},
                  onSelectionChanged: (Set<int> value) => setState(() => _mode = value.first),
                ),
              ),
              const SizedBox(height: 18),
              _mode == 0
                  ? const _QrRegistrationForm()
                  : const _PhotoRegistrationForm(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _LossTableSection(),
        const SizedBox(height: 16),
        const _LossDeclarationsSection(),
        const SizedBox(height: 16),
        const _OwnerMatchesSection(),
      ],
    );
  }
}

class _DocTypeField extends StatelessWidget {
  const _DocTypeField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: Fmt.documentTypes.containsKey(value) ? value : 'CNI',
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Type de document'),
      items: <DropdownMenuItem<String>>[
        for (final MapEntry<String, String> entry in Fmt.documentTypes.entries)
          DropdownMenuItem<String>(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: (String? selected) {
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }
}

class _QrRegistrationForm extends StatefulWidget {
  const _QrRegistrationForm();

  @override
  State<_QrRegistrationForm> createState() => _QrRegistrationFormState();
}

class _QrRegistrationFormState extends State<_QrRegistrationForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _lastName;
  late final TextEditingController _firstName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  String _docType = 'CNI';

  @override
  void initState() {
    super.initState();
    final AuthProvider auth = context.read<AuthProvider>();
    _lastName = TextEditingController(text: auth.user?.lastName ?? '');
    _firstName = TextEditingController(text: auth.user?.firstName ?? '');
    _phone = TextEditingController(text: auth.user?.phone ?? '');
    _email = TextEditingController(text: auth.user?.email ?? '');
  }

  @override
  void dispose() {
    _lastName.dispose();
    _firstName.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
    final bool ok = await workspace.registerByQr(
      docType: _docType,
      lastName: _lastName.text.trim(),
      firstName: _firstName.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
    );
    if (!mounted) {
      return;
    }
    showDoctrySnackBar(
      context,
      ok ? workspace.info ?? 'QR Code généré.' : workspace.error ?? 'Échec de la génération.',
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final WorkspaceProvider workspace = context.watch<WorkspaceProvider>();
    final DocRecord? document = workspace.lastDocument;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _DocTypeField(
            value: _docType,
            onChanged: (String value) => setState(() => _docType = value),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: (String? value) =>
                      (value ?? '').trim().isEmpty ? 'Le nom est requis.' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                  validator: (String? value) =>
                      (value ?? '').trim().isEmpty ? 'Le prénom est requis.' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone'),
            validator: (String? value) =>
                (value ?? '').trim().isEmpty ? 'Le téléphone est requis.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (String? value) =>
                (value ?? '').trim().isEmpty ? "L'email est requis." : null,
          ),
          const SizedBox(height: 16),
          DoctryButton(
            label: 'Générer',
            icon: Icons.qr_code_2,
            loading: workspace.busyOn == 'qr',
            onPressed: _generate,
          ),
          if (document != null && document.hasQr) ...<Widget>[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
            Center(child: QrPreview(document: document)),
            const SizedBox(height: 10),
            Text(
              'QR Code généré par le backend FastAPI pour '
              '${Fmt.docType(document.docType)} — ${document.holderName}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoRegistrationForm extends StatefulWidget {
  const _PhotoRegistrationForm();

  @override
  State<_PhotoRegistrationForm> createState() => _PhotoRegistrationFormState();
}

class _PhotoRegistrationFormState extends State<_PhotoRegistrationForm> {
  String _docType = 'CNI';
  PickedMedia? _media;

  Future<void> _pick() async {
    final PickedMedia? media = await showImageSourceSheet(context);
    if (media != null && mounted) {
      setState(() => _media = media);
    }
  }

  Future<void> _submit() async {
    final PickedMedia? media = _media;
    if (media == null) {
      showDoctrySnackBar(context, 'Choisissez d\'abord une image du document.', isError: true);
      return;
    }
    final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
    final bool ok = await workspace.registerByPhoto(
      media: media,
      docType: _docType,
      source: media.filename.toLowerCase().endsWith('.mp4') ? 'camera' : 'gallery',
    );
    if (!mounted) {
      return;
    }
    if (ok) {
      setState(() => _media = null);
    }
    showDoctrySnackBar(
      context,
      ok ? workspace.info ?? 'Document enregistré.' : workspace.error ?? 'Échec.',
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final WorkspaceProvider workspace = context.watch<WorkspaceProvider>();
    final DocRecord? last = workspace.lastDocument;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DocTypeField(
          value: _docType,
          onChanged: (String value) => setState(() => _docType = value),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: DoctryButton(
                label: 'Exporter depuis la galerie',
                icon: Icons.photo_library_outlined,
                variant: DoctryButtonVariant.outlined,
                onPressed: _pick,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DoctryButton(
                label: 'Filmer',
                icon: Icons.videocam_outlined,
                variant: DoctryButtonVariant.outlined,
                color: AppColors.darkBlue,
                onPressed: _pick,
              ),
            ),
          ],
        ),
        if (_media != null) ...<Widget>[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.siamSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.image_outlined, color: AppColors.siam),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _media!.filename,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkBlue,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _media = null),
                  icon: const Icon(Icons.close, size: 18, color: AppColors.red),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DoctryButton(
            label: 'Valider et enregistrer',
            icon: Icons.check_circle_outline,
            color: AppColors.green,
            loading: workspace.busyOn == 'photo',
            onPressed: _submit,
          ),
        ],
        if (last != null && last.hasImage) ...<Widget>[
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _PhotoPreview(
                  caption: 'Original',
                  url: workspace.publicUrl(last.imageUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PhotoPreview(
                  caption: 'Zones sensibles floutées par l\'IA',
                  url: workspace.publicUrl(last.blurredUrl),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.caption, required this.url});

  final String caption;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 150,
              color: AppColors.background,
              child: const Icon(Icons.image_not_supported_outlined, color: AppColors.grey),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(caption, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _LossTableSection extends StatelessWidget {
  const _LossTableSection();

  Future<void> _declareFromDocument(BuildContext context, DocRecord document) async {
    final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Déclarer la perte',
      message: 'Activer la déclaration de perte pour '
          '${Fmt.docType(document.docType)} de ${document.holderName} ? '
          'Le moteur de matching IA sera lancé immédiatement.',
      confirmLabel: 'Déclaration active',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final bool ok = await workspace.createLoss(
      docType: document.docType,
      documentId: document.id,
      description: 'Perte déclarée depuis un document pré-enregistré.',
    );
    if (!context.mounted) {
      return;
    }
    showDoctrySnackBar(
      context,
      ok ? workspace.info ?? 'Déclaration activée.' : workspace.error ?? 'Échec.',
      isError: !ok,
    );
    if (ok) {
      final LossDeclaration? loss = lossForDocument(workspace.losses, document.id);
      if (loss != null && context.mounted) {
        await runRewardFlow(context, loss);
      }
    }
  }

  Future<void> _badgeMenu(BuildContext context, DocRecord document, LossDeclaration? loss) async {
    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => SimpleDialog(
        title: const Text('Statut de la déclaration'),
        children: <Widget>[
          if (loss == null)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'activate'),
              child: const _DialogRow(
                icon: Icons.flag_outlined,
                label: 'Activer la déclaration de perte',
              ),
            )
          else ...<Widget>[
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'reward'),
              child: const _DialogRow(
                icon: Icons.card_giftcard_outlined,
                label: 'Associer une récompense',
              ),
            ),
            if (loss.rewardStatus == 'escrow')
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, 'release'),
                child: const _DialogRow(
                  icon: Icons.send_to_mobile_outlined,
                  label: 'Envoyer la récompense',
                ),
              ),
            if (!loss.isReturned)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, 'return'),
                child: const _DialogRow(
                  icon: Icons.handshake_outlined,
                  label: 'Confirmer la restitution',
                ),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'relaunch'),
              child: const _DialogRow(
                icon: Icons.psychology_outlined,
                label: 'Relancer le matching IA',
              ),
            ),
          ],
          if (document.hasQr)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'qr'),
              child: const _DialogRow(icon: Icons.qr_code_2, label: 'Afficher le QR Code'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext),
            child: const _DialogRow(icon: Icons.close, label: 'Fermer'),
          ),
        ],
      ),
    );

    if (action == null || !context.mounted) {
      return;
    }
    final WorkspaceProvider workspace = context.read<WorkspaceProvider>();

    switch (action) {
      case 'activate':
        await _declareFromDocument(context, document);
      case 'qr':
        await showDialog<void>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(Fmt.docType(document.docType)),
            content: SingleChildScrollView(child: QrPreview(document: document)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      case 'reward':
        if (loss != null) {
          await runRewardFlow(context, loss);
        }
      case 'release':
        if (loss != null) {
          await runReleaseRewardFlow(context, loss);
        }
      case 'relaunch':
        if (loss != null) {
          final bool ok = await workspace.activateLoss(loss.id);
          if (context.mounted) {
            showDoctrySnackBar(
              context,
              ok ? workspace.info ?? 'Matching relancé.' : workspace.error ?? 'Échec.',
              isError: !ok,
            );
          }
        }
      case 'return':
        if (loss != null && loss.matchedFindId.isNotEmpty) {
          final bool ok = await workspace.confirmReturn(
            lossId: loss.id,
            findId: loss.matchedFindId,
          );
          if (context.mounted) {
            showDoctrySnackBar(
              context,
              ok ? workspace.info ?? 'Restitution confirmée.' : workspace.error ?? 'Échec.',
              isError: !ok,
            );
          }
        } else if (context.mounted) {
          showDoctrySnackBar(
            context,
            'Aucun trouveur associé à cette déclaration pour le moment.',
            isError: true,
          );
        }
    }
  }

  Future<void> _openManualForm(BuildContext context) async {
    final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
    final _ManualLoss? form = await showDialog<_ManualLoss>(
      context: context,
      builder: (BuildContext dialogContext) => const _ManualLossDialog(),
    );
    if (form == null || !context.mounted) {
      return;
    }
    final bool ok = await workspace.createLoss(
      docType: form.docType,
      description: form.description,
      lossDate: form.date.toUtc().toIso8601String(),
      number: form.number,
    );
    if (!context.mounted) {
      return;
    }
    showDoctrySnackBar(
      context,
      ok ? workspace.info ?? 'Perte déclarée.' : workspace.error ?? 'Échec.',
      isError: !ok,
    );
    if (!ok) {
      return;
    }
    final LossDeclaration? created = workspace.losses.isEmpty ? null : workspace.losses.first;
    if (created != null && context.mounted) {
      await runRewardFlow(context, created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final WorkspaceProvider workspace = context.watch<WorkspaceProvider>();
    final List<DocRecord> documents = workspace.documents;

    return SectionCard(
      title: 'Déclarer une perte',
      icon: Icons.report_gmailerrorred_outlined,
      subtitle: 'Cliquez sur le badge « Perdu » pour activer la déclaration.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DoctryTable(
            rowCount: documents.length,
            emptyMessage: 'Aucun document pré-enregistré. Utilisez le formulaire ci-dessous.',
            columns: <DoctryColumn>[
              DoctryColumn(
                label: 'N°',
                compactLabel: 'N°',
                cell: (BuildContext context, int index) => Text('${index + 1}'),
              ),
              DoctryColumn(
                label: 'Type de document',
                compactLabel: 'Type',
                flex: 2,
                cell: (BuildContext context, int index) =>
                    Text(Fmt.docType(documents[index].docType)),
              ),
              DoctryColumn(
                label: 'Date de pré-enregistrement',
                compactLabel: 'Pré-enregistrement',
                flex: 2,
                cell: (BuildContext context, int index) =>
                    Text(Fmt.date(documents[index].createdAt)),
              ),
              DoctryColumn(
                label: 'Nom du propriétaire',
                compactLabel: 'Propriétaire',
                flex: 2,
                cell: (BuildContext context, int index) => Text(documents[index].holderName),
              ),
              DoctryColumn(
                label: 'Statut',
                flex: 2,
                cell: (BuildContext context, int index) {
                  final DocRecord document = documents[index];
                  final LossDeclaration? loss =
                      lossForDocument(workspace.losses, document.id);
                  final bool active = loss != null;
                  final Color color = loss == null
                      ? AppColors.grey
                      : loss.isReturned
                          ? AppColors.green
                          : AppColors.siam;
                  final String label = loss == null
                      ? 'Perdu'
                      : loss.isReturned
                          ? 'Restitué'
                          : 'Perdu';
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(
                      label: label,
                      color: color,
                      icon: active ? Icons.flag : Icons.flag_outlined,
                      onTap: () => _badgeMenu(context, document, loss),
                    ),
                  );
                },
              ),
              DoctryColumn(
                label: 'Récompense',
                flex: 2,
                cell: (BuildContext context, int index) {
                  final LossDeclaration? loss =
                      lossForDocument(workspace.losses, documents[index].id);
                  if (loss == null || loss.rewardAmount <= 0) {
                    return const Text('—');
                  }
                  return Text(
                    '${Fmt.money(loss.rewardAmount)}\n${Fmt.rewardStatus(loss.rewardStatus)}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.goldSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
            ),
            child: const Text(
              'Le document perdu n\'est pas pré-enregistré ? Utilisez le formulaire '
              'pour créer une déclaration manuelle.',
              style: TextStyle(fontSize: 12, color: AppColors.darkBlue),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: DoctryButton(
              label: 'Formulaire',
              icon: Icons.edit_note_outlined,
              variant: DoctryButtonVariant.dark,
              color: AppColors.darkBlue,
              onPressed: () => _openManualForm(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogRow extends StatelessWidget {
  const _DialogRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 19, color: AppColors.siam),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _ManualLoss {
  const _ManualLoss({
    required this.number,
    required this.docType,
    required this.date,
    required this.description,
  });

  final int number;
  final String docType;
  final DateTime date;
  final String description;
}

class _ManualLossDialog extends StatefulWidget {
  const _ManualLossDialog();

  @override
  State<_ManualLossDialog> createState() => _ManualLossDialogState();
}

class _ManualLossDialogState extends State<_ManualLossDialog> {
  final TextEditingController _number = TextEditingController();
  final TextEditingController _description = TextEditingController();
  String _docType = 'CNI';
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _number.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _submit() {
    Navigator.pop(
      context,
      _ManualLoss(
        number: int.tryParse(_number.text.trim()) ?? 0,
        docType: _docType,
        date: _date,
        description: _description.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Déclarer une perte'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _number,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'N°',
                  helperText: 'Laisser vide pour une numérotation automatique',
                ),
              ),
              const SizedBox(height: 12),
              _DocTypeField(
                value: _docType,
                onChanged: (String value) => setState(() => _docType = value),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          Fmt.longDate(_date),
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined,
                          size: 17, color: AppColors.siam),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  hintText: 'Circonstances de la perte, lieu, signes distinctifs…',
                ),
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
          style: FilledButton.styleFrom(backgroundColor: AppColors.siam),
          onPressed: _submit,
          child: const Text('Déclarer'),
        ),
      ],
    );
  }
}

class _LossDeclarationsSection extends StatelessWidget {
  const _LossDeclarationsSection();

  @override
  Widget build(BuildContext context) {
    final WorkspaceProvider workspace = context.watch<WorkspaceProvider>();
    final List<LossDeclaration> losses = workspace.losses;

    return SectionCard(
      title: 'Mes déclarations de perte',
      icon: Icons.list_alt_outlined,
      subtitle: 'Suivi des déclarations et libération des récompenses sous séquestre.',
      child: losses.isEmpty
          ? const EmptyState(
              message: 'Aucune déclaration de perte enregistrée.',
              icon: Icons.report_gmailerrorred_outlined,
            )
          : DoctryTable(
              rowCount: losses.length,
              columns: <DoctryColumn>[
                DoctryColumn(
                  label: 'N°',
                  cell: (BuildContext context, int index) => Text('${losses[index].number}'),
                ),
                DoctryColumn(
                  label: 'Type de document',
                  compactLabel: 'Type',
                  flex: 2,
                  cell: (BuildContext context, int index) =>
                      Text(Fmt.docType(losses[index].docType)),
                ),
                DoctryColumn(
                  label: 'Date de perte',
                  compactLabel: 'Date',
                  cell: (BuildContext context, int index) =>
                      Text(Fmt.date(losses[index].lossDate)),
                ),
                DoctryColumn(
                  label: 'Statut',
                  cell: (BuildContext context, int index) {
                    final LossDeclaration loss = losses[index];
                    final Color color = loss.isReturned
                        ? AppColors.green
                        : loss.isActive
                            ? AppColors.siam
                            : AppColors.grey;
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: StatusBadge(label: Fmt.lossStatus(loss.status), color: color),
                    );
                  },
                ),
                DoctryColumn(
                  label: 'Récompense',
                  flex: 2,
                  cell: (BuildContext context, int index) {
                    final LossDeclaration loss = losses[index];
                    return Text(
                      loss.rewardAmount > 0
                          ? '${Fmt.money(loss.rewardAmount)} · ${Fmt.rewardStatus(loss.rewardStatus)}'
                          : 'Aucune',
                      style: const TextStyle(fontSize: 11.5),
                    );
                  },
                ),
                DoctryColumn(
                  label: 'Actions',
                  flex: 2,
                  cell: (BuildContext context, int index) {
                    final LossDeclaration loss = losses[index];
                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        if (loss.rewardStatus == 'none')
                          _MiniAction(
                            label: 'Récompense',
                            icon: Icons.card_giftcard_outlined,
                            onTap: () => runRewardFlow(context, loss),
                          ),
                        if (loss.canReleaseReward)
                          _MiniAction(
                            label: 'Envoyer la récompense',
                            icon: Icons.send_to_mobile_outlined,
                            color: AppColors.gold,
                            onTap: () => runReleaseRewardFlow(context, loss),
                          ),
                        if (!loss.isReturned && loss.matchedFindId.isNotEmpty)
                          _MiniAction(
                            label: 'Restitué',
                            icon: Icons.handshake_outlined,
                            color: AppColors.green,
                            onTap: () => workspace.confirmReturn(
                              lossId: loss.id,
                              findId: loss.matchedFindId,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = AppColors.siam,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      avatar: Icon(icon, size: 15, color: color),
      label: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _OwnerMatchesSection extends StatelessWidget {
  const _OwnerMatchesSection();

  @override
  Widget build(BuildContext context) {
    final WorkspaceProvider workspace = context.watch<WorkspaceProvider>();

    if (workspace.matches.isEmpty) {
      return const SizedBox.shrink();
    }

    return SectionCard(
      title: 'Alertes de matching',
      icon: Icons.radar_outlined,
      subtitle: 'Documents similaires trouvés par le moteur IA.',
      child: Column(
        children: <Widget>[
          for (final MatchResult match in workspace.matches)
            MatchCard(
              match: match,
              onContact: () => openMatchThread(context, match),
              onConfirmReturn: () async {
                final bool ok = await runReturnConfirmation(context, match);
                if (ok && context.mounted) {
                  await context.read<WorkspaceProvider>().loadOwnerWorkspace();
                }
              },
              onRelease: () async {
                final LossDeclaration? loss =
                    lossById(context.read<WorkspaceProvider>().losses, match.lossId);
                if (loss != null) {
                  await runReleaseRewardFlow(context, loss);
                }
              },
              onReward: () async {
                final LossDeclaration? loss =
                    lossById(context.read<WorkspaceProvider>().losses, match.lossId);
                if (loss != null) {
                  await runRewardFlow(context, loss);
                }
              },
            ),
        ],
      ),
    );
  }
}
