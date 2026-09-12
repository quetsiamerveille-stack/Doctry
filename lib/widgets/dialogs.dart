import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../core/utils/media_picker.dart';
import '../models/chat.dart';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import 'common.dart';
import 'user_avatar.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  Color confirmColor = AppColors.siam,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(fontSize: 14)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<PickedMedia?> showImageSourceSheet(BuildContext context) async {
  final ImageSource? source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (BuildContext sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Ajouter une image du document',
              style: Theme.of(sheetContext).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            DoctryButton(
              label: 'Exporter depuis la galerie',
              icon: Icons.photo_library_outlined,
              onPressed: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 10),
            DoctryButton(
              label: 'Filmer',
              icon: Icons.photo_camera_outlined,
              variant: DoctryButtonVariant.outlined,
              onPressed: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) {
    return null;
  }
  return MediaPicker.pick(source);
}

Future<bool> showProfileEditDialog(BuildContext context) async {
  final AuthProvider auth = context.read<AuthProvider>();
  final bool adminMode = auth.isAdminProfile;
  final TextEditingController firstName =
      TextEditingController(text: auth.user?.firstName ?? '');
  final TextEditingController lastName = TextEditingController(text: auth.user?.lastName ?? '');
  final TextEditingController email = TextEditingController(text: auth.user?.email ?? '');
  final TextEditingController currentPassword = TextEditingController();
  final TextEditingController newPassword = TextEditingController();
  final TextEditingController phone = TextEditingController(text: auth.user?.phone ?? '');

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext stateContext, StateSetter setState) {
          return AlertDialog(
            title: const Text('Modifier le profil'),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // --- Photo de profil ---
                    Center(
                      child: auth.user == null
                          ? const SizedBox.shrink()
                          : UserAvatar(
                              user: auth.user!,
                              size: 96,
                              editBadge: true,
                              onTap: auth.busy
                                  ? null
                                  : () async {
                                      final PickedMedia? media =
                                          await MediaPicker.pick(ImageSource.gallery);
                                      if (media == null) {
                                        return;
                                      }
                                      setState(() {});
                                      final bool ok = await auth.uploadProfilePhoto(
                                        bytes: media.bytes,
                                        filename: media.filename,
                                        mimeType: media.mimeType,
                                      );
                                      if (!stateContext.mounted) {
                                        return;
                                      }
                                      setState(() {});
                                      if (ok) {
                                        showDoctrySnackBar(
                                          stateContext,
                                          'Photo de profil mise à jour.',
                                        );
                                      }
                                    },
                            ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Toucher la photo pour la changer',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: lastName,
                      decoration: const InputDecoration(labelText: 'Nom'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: firstName,
                      decoration: const InputDecoration(labelText: 'Prénom'),
                    ),
                    const SizedBox(height: 12),
                    if (adminMode)
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      )
                    else
                      TextField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Téléphone'),
                      ),
                    const Divider(height: 30),
                    Text(
                      'Changer le mot de passe',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: currentPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe actuel',
                        prefixIcon: Icon(Icons.lock_outline),
                        helperText: 'Obligatoire pour modifier le mot de passe',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        prefixIcon: Icon(Icons.key_outlined),
                        helperText: 'Laisser vide pour conserver le mot de passe actuel',
                      ),
                    ),
                    if (auth.error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        auth.error!,
                        style: const TextStyle(color: AppColors.red, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: auth.busy
                    ? null
                    : () async {
                        // Validation locale : nouveau mot de passe exige l'actuel
                        if (newPassword.text.trim().isNotEmpty &&
                            currentPassword.text.trim().isEmpty) {
                          auth.setValidationError(
                            'Saisissez votre mot de passe actuel pour le changer.',
                          );
                          setState(() {});
                          return;
                        }
                        setState(() {});
                        final bool ok = adminMode
                            ? await auth.updateAdminProfile(
                                firstName: firstName.text.trim(),
                                lastName: lastName.text.trim(),
                                email: email.text.trim(),
                                password: newPassword.text.trim(),
                                currentPassword: currentPassword.text.trim(),
                              )
                            : await auth.updateProfile(
                                firstName: firstName.text.trim(),
                                lastName: lastName.text.trim(),
                                phone: phone.text.trim(),
                                password: newPassword.text.trim(),
                                currentPassword: currentPassword.text.trim(),
                              );
                        if (!dialogContext.mounted) {
                          return;
                        }
                        setState(() {});
                        if (ok) {
                          Navigator.pop(dialogContext, true);
                        }
                      },
                child: auth.busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                      )
                    : const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );

  firstName.dispose();
  lastName.dispose();
  email.dispose();
  currentPassword.dispose();
  newPassword.dispose();
  phone.dispose();
  return result ?? false;
}

Future<void> showNotificationsPanel(BuildContext context) async {
  final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
  await workspace.loadNotifications();
  if (!context.mounted) {
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.35,
        builder: (BuildContext context, ScrollController controller) {
          return Consumer<WorkspaceProvider>(
            builder: (BuildContext context, WorkspaceProvider value, Widget? child) {
              final List<AppNotification> items = value.notifications;
              return Column(
                children: <Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: 46,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 10, 6),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.notifications_active_outlined, color: AppColors.siam),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Notifications',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: items.isEmpty ? null : value.markNotificationsRead,
                          icon: const Icon(Icons.done_all, size: 18),
                          label: const Text('Tout lire'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: items.isEmpty
                        ? const EmptyState(
                            message: 'Aucune notification pour le moment.',
                            icon: Icons.notifications_none,
                          )
                        : ListView.separated(
                            controller: controller,
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (BuildContext context, int index) {
                              final AppNotification item = items[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _notificationColor(item.kind)
                                      .withValues(alpha: 0.14),
                                  child: Icon(
                                    _notificationIcon(item.kind),
                                    color: _notificationColor(item.kind),
                                    size: 18,
                                  ),
                                ),
                                title: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontWeight:
                                        item.read ? FontWeight.w500 : FontWeight.w800,
                                    fontSize: 13.5,
                                    color: AppColors.darkBlue,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const SizedBox(height: 2),
                                    Text(item.body, style: const TextStyle(fontSize: 12.5)),
                                    const SizedBox(height: 3),
                                    Text(
                                      Fmt.relative(item.createdAt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: item.read
                                    ? null
                                    : Container(
                                        width: 9,
                                        height: 9,
                                        decoration: const BoxDecoration(
                                          color: AppColors.gold,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

Color _notificationColor(String kind) {
  switch (kind) {
    case 'match':
      return AppColors.green;
    case 'payment':
      return AppColors.gold;
    case 'warning':
      return AppColors.red;
    default:
      return AppColors.siam;
  }
}

IconData _notificationIcon(String kind) {
  switch (kind) {
    case 'match':
      return Icons.link;
    case 'payment':
      return Icons.account_balance_wallet_outlined;
    case 'warning':
      return Icons.warning_amber_rounded;
    default:
      return Icons.info_outline;
  }
}

Future<bool> showRatingDialog(BuildContext context) async {
  int stars = 5;
  final TextEditingController comment = TextEditingController();

  final bool? result = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: const Text('Votre avis compte'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Comment évaluez-vous votre expérience sur DOCTRY ?',
                    style: TextStyle(fontSize: 13.5),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (int index = 1; index <= 5; index++)
                        IconButton(
                          iconSize: 34,
                          onPressed: () => setState(() => stars = index),
                          icon: Icon(
                            index <= stars ? Icons.star : Icons.star_border,
                            color: AppColors.gold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: comment,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Commentaire (optionnel)',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Plus tard'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.darkBlue,
                ),
                onPressed: () async {
                  final bool ok = await dialogContext
                      .read<AuthProvider>()
                      .submitRating(stars: stars, comment: comment.text.trim());
                  if (ok && dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                },
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Envoyer'),
              ),
            ],
          );
        },
      );
    },
  );

  comment.dispose();
  return result ?? false;
}

class OtpRequest {
  const OtpRequest({
    required this.title,
    required this.message,
    required this.devCode,
    required this.email,
    this.confirmLabel = 'Valider',
    this.onResend,
  });

  final String title;
  final String message;
  final String devCode;
  final String email;
  final String confirmLabel;
  final Future<String?> Function()? onResend;
}

Future<String?> showOtpDialog(BuildContext context, OtpRequest request) {
  final TextEditingController controller = TextEditingController();
  String? error;
  bool busy = false;

  return showDialog<String>(
    barrierDismissible: false,
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(request.title),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(request.message, style: const TextStyle(fontSize: 13.5)),
                  if (request.devCode.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.goldSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.gold),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.mark_email_read_outlined,
                              size: 18, color: AppColors.darkBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Simulation email — code : ${request.devCode}',
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
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 8),
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '000000',
                    ),
                  ),
                  if (error != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              if (request.onResend != null)
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          final String? newCode = await request.onResend!();
                          setState(() {
                            busy = false;
                            if (newCode != null && newCode.isNotEmpty) {
                              controller.text = newCode;
                            }
                          });
                        },
                  child: const Text('Renvoyer'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () {
                        final String code = controller.text.trim();
                        if (code.length < 4) {
                          setState(() => error = 'Saisissez le code complet.');
                          return;
                        }
                        setState(() {
                          error = null;
                          busy = true;
                        });
                        Navigator.pop(dialogContext, code);
                      },
                child: busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                      )
                    : Text(request.confirmLabel),
              ),
            ],
          );
        },
      );
    },
  ).then((String? value) {
    controller.dispose();
    return value;
  });
}

void showDoctrySnackBar(BuildContext context, String message, {bool isError = false}) {
  if (message.trim().isEmpty) {
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppColors.red : AppColors.darkBlue,
        content: Row(
          children: <Widget>[
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
                color: AppColors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
      ),
    );
}
